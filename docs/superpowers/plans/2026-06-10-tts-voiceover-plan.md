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

### Task 2: Create TTS Core Services
**Files:**
- Create: `lib/domain/services/tts_service.dart`
- Create: `lib/data/services/tts/native_tts_impl.dart`
- Create: `lib/data/services/tts/openai_tts_impl.dart`
- Modify: `lib/di/injection.dart`

- [ ] **Step 1: Define Interface & Write Tests (TDD RED)**
Write the `TtsService` abstract class in `lib/domain/services/tts_service.dart`.
Write unit tests for `NativeTtsImpl` and `OpenAiTtsImpl` in `test/domain/services/tts_service_test.dart`. 
**Mandatory Test Cases:**
- `NativeTtsImpl`: Calculates correct speed based on text vs duration ratio.
- `OpenAiTtsImpl`: Fetches correctly and plays audio via `audioplayers`.
- **(NEW) API Error Handling**: Ensure `OpenAiTtsImpl` handles HTTP errors (e.g. Invalid API Key) gracefully without crashing the app.
- **(NEW) Concurrent Speech**: Ensure calling `speak()` while another is playing immediately stops the previous one.
Run tests and ensure they **FAIL (RED)**.

- [ ] **Step 2: Implement Native TTS (TDD GREEN)**
Write `NativeTtsImpl` using `flutter_tts`. 
*Performance Rule:* Must calculate dynamic speech rate gracefully. Always call `stop()` internally before firing a new `speak()` to prevent engine queue overflow.

- [ ] **Step 3: Implement OpenAI TTS (TDD GREEN)**
Write `OpenAiTtsImpl` using `dio` to fetch `/v1/audio/speech` and `audioplayers` to stream the audio.
*Performance & Anti-Leak Rules:*
- **Single Instance:** MUST reuse a SINGLE `AudioPlayer` instance. Do NOT create `AudioPlayer()` inside `speak()`. Call `player.stop()` before playing a new stream. (Prevents RAM overflow / OOM).
- **Cancel Tokens:** Use `CancelToken` from Dio. If `stop()` is called while an HTTP request is pending, abort the request immediately to save Network bandwidth and CPU.

- [ ] **Step 4: Register in DI**
Register the services in `lib/di/injection.dart`.

### Task 3: Setup App Settings & QR Sync (WebDAV)
**Files:**
- Modify: `lib/presentation/screens/settings/mobile_sync_screen.dart`
- Modify: `lib/presentation/screens/settings/tv_sync_screen.dart`
- Create: `lib/presentation/widgets/voiceover_settings_dialog.dart`

- [ ] **Step 1: Update QR Payload on Mobile**
Modify `_sendConfig()` in `mobile_sync_screen.dart` to include keys: `tts_engine`, `tts_source`, `tts_base_url`, `tts_api_key`, `tts_model`. 

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
- **Progressive Disclosure:** Nếu chọn Engine là `System Default`, *ẨN (Hide)* các ô nhập liệu `API Key` và `Base URL` để giao diện gọn gàng. Chỉ hiện ra khi chọn `OpenAI Compatible`.
- **ALL UI TEXT MUST BE IN ENGLISH.**
- Các dropdown và form field phải được bọc `Focus` widget cho D-pad.

### Task 4: Integrate into Player UI
**Files:**
- Modify: `lib/presentation/widgets/tv_controls.dart`
- Modify: `lib/presentation/screens/player_screen.dart`

- [ ] **Step 1: UI/UX & Player Logic - Write Widget Tests (TDD RED)**
Write tests for `tv_controls_test.dart` and `player_screen_test.dart`. 
**Mandatory Test Cases:**
- Mock `VideoPlayerController` position: Ensure `TtsService.speak()` is called EXACTLY when the cue changes.
- Subtitle Source: Ensure it reads from `_currentPrimaryCue` or `_currentSecondaryCue` based on settings.
- **(NEW) Subtitle Delay Sync**: Ensure that if `_topSubDelayMs` or `_bottomSubDelayMs` is modified, the Voice-over strictly respects this delay (because it listens to the shifted `_currentPrimaryCue`).
- Playback Interruption: Assert that `TtsService.stop()` is called IMMEDIATELY when the video is paused, when the user seeks, or when Voice-over is toggled OFF.
Watch it fail.

- [ ] **Step 2: Implement Voice-over Toggle Button (TV Remote Support) (TDD GREEN)**
In `tv_controls.dart`, add a new parameter `bool isVoiceOverEnabled` and `VoidCallback onVoiceOverToggle`. 
Sử dụng hàm `_buildIconButton(isVoiceOverEnabled ? Icons.record_voice_over : Icons.voice_over_off, ...)` đặt cạnh nút Subtitle.
*UI/UX Pro Max Rules (Android TV Focus):* 
- Phải truyền tham số `downFocusNode: _playPauseNode` để khi người dùng bấm phím Mũi tên Xuống trên Remote, nó sẽ trỏ đúng về nút Play/Pause.
- Highlight trạng thái Active bằng `AppColors.primary`.
- **Tooltip/Label phải là Tiếng Anh:** "Voice-over".

- [ ] **Step 3: Update `_videoListener` (Performance Critical)**
In `player_screen.dart`, add state `SubtitleCue? _lastSpokenCue`. Inside `_videoListener()`, detect when `_currentPrimaryCue` changes. 
*Anti-Spam & CPU Rule:* 
- ONLY call `speak()` if `_currentPrimaryCue != _lastSpokenCue`.
- **Seek Debounce:** Do NOT call `speak()` if `_isSeeking` is true. If the user scrubs the timeline rapidly, wait until seeking finishes before speaking. This prevents spamming the OpenAI API (saving huge costs) and overloading CPU.

- [ ] **Step 4: Handle Player State & Memory Cleanup**
When `_controller.pause()` or a seek is triggered, immediately call `getIt<TtsService>().stop()`.
In `dispose()`, MUST call `getIt<TtsService>().dispose()` to shut down TTS engines and free up memory.
