# TTS Voice-over Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement automatic TTS voice-over for subtitles with Native and OpenAI engine support, toggleable via UI and syncable via QR code.

**Architecture:** A Strategy pattern `TtsService` with `NativeTtsImpl` and `OpenAiTtsImpl`. Integrated into `PlayerScreen`'s `_videoListener`.

**Tech Stack:** `flutter_tts`, `dio`, `shared_preferences`, Dart.

---

### Task 1: Add Dependencies
**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add packages**
```yaml
  # Audio
  flutter_tts: ^3.8.3
  audioplayers: ^5.2.1 # Required for playing OpenAI audio stream smoothly
```
- [ ] **Step 2: Run pub get**
Run: `flutter pub get`
Expected: Passes without errors.

- [ ] **Step 3: Update Android Manifest for API 30+ (CRITICAL)**
Modify `android/app/src/main/AndroidManifest.xml` to include the TTS intent inside `<queries>`. If this is missing, Android 11+ devices (and modern Android TVs) will block the app from accessing the system's Native TTS engine, causing it to fail silently.
```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
        ...
```

### Task 2: Create TTS Core Services
**Files:**
- Create: `lib/domain/services/tts_service.dart` (Abstract Interface)
- Create: `lib/data/services/tts/native_tts_impl.dart`
- Create: `lib/data/services/tts/openai_tts_impl.dart`
- Create: `lib/data/services/tts/tts_service_facade.dart` (Orchestrator)
- Modify: `lib/di/injection.dart`

- [ ] **Step 1: Define Interface & Write Tests (TDD RED)**
Write the `TtsService` abstract class in `lib/domain/services/tts_service.dart`.
*Architecture Rule:* The implementation of `TtsService` registered in DI MUST be a Facade (`TtsServiceFacade`) that holds both `NativeTtsImpl` and `OpenAiTtsImpl` and orchestrates them.
*Signature:* `Future<void> speak(String text, {required int durationMs, required double videoPlaybackSpeed, String? languageCode})`
Write unit tests for `TtsServiceFacade`, `NativeTtsImpl` and `OpenAiTtsImpl` in `test/domain/services/tts_service_test.dart`. 
**Mandatory Test Cases (Including Performance Checks):**
- `NativeTtsImpl`: Calculates correct speed based on text vs duration ratio.
- `OpenAiTtsImpl`: Fetches correctly and plays audio via `audioplayers`.
- **API Error Handling**: Ensure `OpenAiTtsImpl` handles HTTP errors gracefully.
- **Concurrent Speech**: Ensure calling `speak()` while another is playing immediately stops the previous one.
- **(PERFORMANCE TEST 1) Memory Leak Prevention**: Assert that `OpenAiTtsImpl` reuses a single `AudioPlayer` instance and does not create new ones.
- **(PERFORMANCE TEST 2) Network Spike Prevention**: Mock an HTTP delay, call `speak()`, then immediately call `stop()`. Assert that the Dio `CancelToken` aborts the request.
- **(DEEP REVIEW 1) HTML Stripping & Validation**: Assert that strings like `"<i>Hello</i>"` are sanitized to `"Hello"` before passing to engine. Assert that empty strings or `"♪"` do NOT trigger the engine.
- **(DEEP REVIEW 2) Video Speed Sync**: Assert that the calculated TTS speech rate increases proportionally when `videoPlaybackSpeed` = 2.0x.
- **(ULTIMATE TEST 1) Graceful Fail-over**: Mock a `DioException` (e.g., 429 Timeout). Assert that `OpenAiTtsImpl` swallows the error and immediately delegates the text to `NativeTtsImpl.speak()`.
- **(ULTIMATE TEST 3) Text Truncation Limit**: Pass a 600-character string to `speak()`. Assert that the text sent to the engine is truncated to exactly 500 characters.
- **(ULTIMATE TEST 4) Voice Selection Payload**: Assert that the `dio` request payload sent to OpenAI `/v1/audio/speech` correctly includes the `voice` parameter (e.g., `nova` or `onyx`) matching the value in `SharedPreferences`.
- **(ULTIMATE TEST 5) Mutex Race Condition**: Simulate calling `speak()` 3 times concurrently without awaiting. Assert that the underlying `AudioPlayer` methods (`stop` and `play`) are executed strictly sequentially without overlapping.
- **(ULTIMATE TEST 6) URL Sanitization**: Set `tts_base_url` to `https://proxy.com/v1/` (with trailing slash). Assert that the intercepted `dio` request resolves to `https://proxy.com/v1/audio/speech` without double slashes.
- **(ULTIMATE TEST 7) OpenAI Speed Payload**: Assert that the `dio` JSON payload includes the `"speed"` parameter mapped directly from `videoPlaybackSpeed` to ensure the cloud voice speeds up when the movie is fast-forwarded.
- **(ULTIMATE TEST 8) Resource Disposal**: Assert that calling `TtsService.dispose()` correctly triggers `dispose()` on the `AudioPlayer` singleton and aborts any active `dio` request, leaving no ghost instances in RAM.
- **(ULTIMATE TEST 9) Engine Delegation (Facade)**: Assert that `TtsService.speak()` correctly delegates the call to `OpenAiTtsImpl` if `tts_engine == 'openai'` and to `NativeTtsImpl` if `tts_engine == 'native'`.
- **(ULTIMATE TEST 10) Empty API Key Fallback**: Assert that if `tts_engine == 'openai'` but `tts_api_key` is empty, the facade skips OpenAI and immediately falls back to `NativeTtsImpl` without making an invalid HTTP request.
- **(ULTIMATE TEST 11) POST & BytesSource Architecture**: Assert that `OpenAiTtsImpl` uses `dio` to make a POST request to OpenAI, and passes the resulting bytes to `AudioPlayer` using `BytesSource` (NOT `UrlSource`).
- **(ULTIMATE TEST 12) Language Availability Check**: Mock `flutterTts.isLanguageAvailable()` to return false (simulating an Android TV without Vietnamese installed). Assert that `NativeTtsImpl` handles this gracefully without crashing the video player.
Run tests and ensure they **FAIL (RED)**.

- [ ] **Step 2: Implement Native TTS (TDD GREEN)**
Write `NativeTtsImpl` using `flutter_tts`. 
*Language Rule:* MUST use the passed `languageCode` to dynamically call `await flutterTts.setLanguage(mappedLang)`. You MUST first check `await flutterTts.isLanguageAvailable(mappedLang)`. Many Android TVs do not have Vietnamese TTS installed. If unavailable, fallback to 'en-US' or system default gracefully to prevent platform crashes.
*Performance Rule:* Must calculate dynamic speech rate gracefully by factoring in `videoPlaybackSpeed`. Always call `stop()` internally before firing a new `speak()`.
*Text Sanitization & Limit Rule:* Use RegExp `RegExp(r'<[^>]*>')` to strip HTML tags before reading. Filter out empty text. TRUNCATE text if it exceeds 500 characters to prevent queue blocking and API 400 errors.
*iOS Critical Rule:* Must configure iOS Audio Session to mix with other audio, otherwise the TTS voice will mute the movie's audio: `flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [IosTextToSpeechAudioCategoryOptions.mixWithOthers]);`

- [ ] **Step 3: Implement OpenAI TTS (TDD GREEN)**
Write `OpenAiTtsImpl` using `dio` to fetch `/v1/audio/speech` and `audioplayers` to stream the audio.
*API Integration Rule (FATAL FIX):* `audioplayers` does NOT support POST requests or custom Headers. You MUST use `dio` to send the POST request to OpenAI, get the response as `Response<List<int>>` (bytes), and then use `await player.play(BytesSource(Uint8List.fromList(response.data!)))`. Do NOT attempt to pass the OpenAI URL directly into `AudioPlayer`.
*Base URL Sanitization Rule:* When reading `tts_base_url`, ensure it resolves correctly. If the user inputs `https://proxy.com/v1/`, the code must intelligently append `audio/speech` without causing double slashes like `/v1//v1/`.
*Performance & Anti-Leak Rules:*
- **Single Instance & Mutex:** MUST reuse a SINGLE `AudioPlayer` instance. Because `audioplayers` is asynchronous, you MUST use a Mutex lock or `Completer` to ensure `player.stop()` completely finishes before `player.play()` is called. Calling `play()` concurrently on the same instance due to rapid subtitle changes will trigger an `IllegalStateException` crash in ExoPlayer.
- **Cancel Tokens:** Use `CancelToken` from Dio. If `stop()` is called while an HTTP request is pending, abort the request immediately to save Network bandwidth and CPU.
*iOS Critical Rule:* Configure `AudioPlayer.global.setAudioContext()` with `AudioContextConfig(route: AudioContextConfigRoute.system, respectSilence: false, duckAudio: false)` (with mixWithOthers) so it plays simultaneously with the movie track on iOS without pausing the video.
*Android Audio Focus Rule:* Configure `AndroidAudioContext` with `audioFocus: AndroidAudioFocus.none` so that playing OpenAI audio does NOT trigger Android OS to pause the movie's ExoPlayer audio track.
*State Management Rule:* All services MUST read settings (API Key, Base URL, etc.) dynamically from `SharedPreferences` inside the `speak()` method (or via a reload method). Do NOT cache these globally in the constructor, otherwise the player won't detect new keys after returning from Settings.
*Fail-over Rule (Graceful Degradation):* If `OpenAiTtsImpl` throws a `DioException` (Timeout, No Internet, 429 Rate Limit, 401 Unauthorized), catch the error and SILENTLY fallback to `flutter_tts` to read the current line, ensuring the user's experience is not interrupted.

- [ ] **Step 4: Register in DI**
Register the services in `lib/di/injection.dart`.

### Task 3: Setup App Settings & QR Sync (WebDAV)
**Files:**
- Modify: `lib/presentation/screens/settings/mobile_sync_screen.dart`
- Modify: `lib/presentation/screens/settings/tv_sync_screen.dart`
- Create: `lib/presentation/widgets/voiceover_settings_dialog.dart`

- [ ] **Step 1: Update QR Payload on Mobile**
Modify `_sendConfig()` in `mobile_sync_screen.dart` to include keys: `tts_engine`, `tts_base_url`, `tts_api_key`, `tts_model`, `tts_voice` into the existing `jsonEncode({...})` payload alongside the WebDAV keys.

- [ ] **Step 2: Update QR Receiver on TV**
Modify `_start()` in `tv_sync_screen.dart` to parse the new `tts_` keys from the incoming `data` map and save them to `SharedPreferences`.

- [ ] **Step 3: UI/UX & Sync - Write Tests (TDD RED)**
Write widget tests in `test/presentation/screens/settings/app_settings_screen_test.dart` asserting that the inputs, dropdowns, and D-pad focus highlight exist and function. Ensure API fields are hidden when Native TTS is selected. 
**Mandatory Sync Test:** Write unit tests ensuring `mobile_sync_screen.dart` correctly packs `tts_` keys into the JSON payload, and `tv_sync_screen.dart` correctly parses them into `SharedPreferences`.
Watch it fail.

- [ ] **Step 4: Unified Settings Screen UI (TDD GREEN)**
Rename/Refactor `WebdavSetupScreen` into a unified `AppSettingsScreen`.
*UI/UX Pro Max Analysis & Rules:*
- **Vấn đề phân mảnh UX cũ:** Nút "Show/Scan QR" hiện đang nằm gọn trong WebDAV. Nếu tách Voice-over ra màn hình khác, người dùng sẽ bối rối không biết QR này đồng bộ cái gì.
- **Giải pháp (Unified Hierarchy):** Gộp toàn bộ vào `AppSettingsScreen` chia làm 3 Section (Card): `Quick Sync (QR)`, `WebDAV Config`, và `Voice-over Config`.
- **Progressive Disclosure:** Nếu chọn Engine là `System Default`, *ẨN (Hide)* các ô nhập liệu `API Key`, `Base URL`, `Model`, `Voice` để giao diện gọn gàng. Chỉ hiện ra khi chọn `OpenAI Compatible`.
- **OpenAI Voice Selection:** Bổ sung Dropdown cho phép người dùng chọn Giọng (Voice) của OpenAI (Alloy, Echo, Fable, Onyx, Nova, Shimmer). Lưu vào biến `tts_voice`.
- **ALL UI TEXT MUST BE IN ENGLISH.**
- Các dropdown và form field phải được bọc `Focus` widget cho D-pad.
- **Navigation Rule**: In `player_settings_dialog.dart`, when the user clicks the Voice-over shortcut, the app MUST pause the video (`_controller.pause()`) before executing `Navigator.push` to open the full `AppSettingsScreen`.

### Task 4: Integrate into Player UI
**Files:**
- Modify: `lib/presentation/widgets/tv_controls.dart`
- Modify: `lib/presentation/screens/player_screen.dart`

- [ ] **Step 1: UI/UX & Player Logic - Write Widget Tests (TDD RED)**
Write tests for `tv_controls_test.dart` and `player_screen_test.dart`. 
**Mandatory Test Cases (Including Performance Checks):**
- Mock `VideoPlayerController` position: Ensure `TtsService.speak()` is called EXACTLY when the cue changes.
- Subtitle Source: Ensure it reads from `_currentPrimaryCue` or `_currentSecondaryCue` based on settings.
- Subtitle Delay Sync: Ensure that if `_topSubDelayMs` or `_bottomSubDelayMs` is modified, the Voice-over strictly respects this delay.
- Playback Interruption: Assert that `TtsService.stop()` is called IMMEDIATELY when the video is paused, when the user seeks, or when Voice-over is toggled OFF.
- **(PERFORMANCE TEST 3) API Spam Prevention (Seek Debounce)**: Set `_isSeeking = true` or rapidly change `_currentPrimaryCue`. Assert that `TtsService.speak()` is **NOT** called until seeking finishes.
- **(ULTIMATE TEST 2) Engine Warm-up**: Assert that `TtsService.init()` is called exactly once when `PlayerScreen` initializes.
Watch it fail.

- [ ] **Step 2: Implement Voice-over Toggle Button (TDD GREEN)**
In `tv_controls.dart` (the ONLY controls widget used for ALL platforms in this project), add a new parameter `bool isVoiceOverEnabled` and `VoidCallback onVoiceOverToggle`. 
Sử dụng hàm `_buildIconButton(isVoiceOverEnabled ? Icons.record_voice_over : Icons.voice_over_off, ...)` đặt cạnh nút Subtitle.
*Persistent State Rule:* The `isVoiceOverEnabled` state MUST be saved to and loaded from `SharedPreferences`. If the user turns it off in episode 1, it must remain off in episode 2. Do NOT use a transient local boolean variable for this global preference.
*UI/UX Pro Max Rules (Android TV Focus):* 
- Phải truyền tham số `downFocusNode: _playPauseNode` để khi người dùng bấm phím Mũi tên Xuống trên Remote, nó sẽ trỏ đúng về nút Play/Pause.
- Highlight trạng thái Active bằng `AppColors.primary`.
- **Tooltip/Label phải là Tiếng Anh:** "Voice-over".

- [ ] **Step 3: Update `_videoListener` (Performance Critical)**
In `player_screen.dart`:
*Engine Warm-up Rule:* In `initState`, call `getIt<TtsService>().init()` to warm up the TTS engine (especially Native TTS) so it doesn't swallow the first word of the movie.
*Anti-Spam & CPU Rule:* 
- ONLY call `speak()` if `_currentPrimaryCue != _lastSpokenCue` and the sanitized text is not empty.
- Pass `durationMs = endMs - startMs`, `videoPlaybackSpeed = _playbackSpeed`, and the **Subtitle's Language Code** (extracted from the active subtitle track) to `speak()`.
- **Seek Debounce:** Do NOT call `speak()` if `_isSeeking` is true. If the user scrubs the timeline rapidly, wait until seeking finishes before speaking. This prevents spamming the OpenAI API (saving huge costs) and overloading CPU.

- [ ] **Step 4: Handle Player State, App Lifecycle & Cleanup**
When `_controller.pause()` or a seek is triggered, immediately call `getIt<TtsService>().stop()`.
*App Lifecycle Rule:* The `_PlayerScreenState` class MUST add `WidgetsBindingObserver` mixin and override `didChangeAppLifecycleState`. If the app goes to background (`AppLifecycleState.paused` or `inactive`), immediately call `getIt<TtsService>().stop()`. Remember to call `WidgetsBinding.instance.addObserver(this)` in `initState` and `removeObserver(this)` in `dispose`.
In `dispose()`, MUST call `getIt<TtsService>().dispose()` to shut down TTS engines and free up memory.

**Test Case (App Lifecycle):**
- **(ULTIMATE TEST 13) App Background Stop**: Simulate `AppLifecycleState.paused`. Assert that `TtsService.stop()` is called immediately.
