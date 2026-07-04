import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'package:cine_stream/domain/services/tts_service.dart';
import 'package:cine_stream/data/services/tts/native_tts_impl.dart';
import 'package:cine_stream/data/services/tts/openai_tts_impl.dart';
import 'package:cine_stream/data/services/tts/edge_tts_impl.dart';
import 'package:cine_stream/data/services/tts/tts_service_facade.dart';
import 'package:cine_stream/data/services/log_service.dart';
import 'package:cine_stream/di/injection.dart';

// Mocks thủ công để test chính xác hoạt động nội bộ
class MockFlutterTts implements FlutterTts {
  String? lastSpokenText;
  double? lastVolume;
  double? lastSpeechRate;
  double? lastPitch;
  String? lastLanguage;
  bool isInitCalled = false;
  bool isStopCalled = false;
  bool isLanguageAvailableResult = true;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    lastSpokenText = text;
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    isStopCalled = true;
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    lastLanguage = language;
    return true;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    lastSpeechRate = rate;
    return 1;
  }

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    return isLanguageAvailableResult;
  }

  @override
  Future<dynamic> setVolume(double volume) async => lastVolume = volume;
  @override
  Future<dynamic> setPitch(double pitch) async => lastPitch = pitch;

  @override
  Future<void> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode? optionsOverride,
  ]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAudioPlayer extends AudioPlayer {
  bool isStopCalled = false;
  bool isPlayCalled = false;
  bool isDisposeCalled = false;
  Source? lastSource;
  final List<String> callOrder = [];

  @override
  Future<void> stop() async {
    isStopCalled = true;
    callOrder.add('stop');
    // Giả lập bất đồng bộ nhẹ để test Race Condition / Mutex
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<void> play(Source source, {
    double? volume,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
    double? balance,
  }) async {
    isPlayCalled = true;
    lastSource = source;
    callOrder.add('play');
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<void> dispose() async {
    isDisposeCalled = true;
  }
}

class MockDio extends Fake implements Dio {
  int postCallCount = 0;
  String? lastUrl;
  dynamic lastData;
  Options? lastOptions;
  CancelToken? lastCancelToken;
  bool shouldThrow = false;
  int delayMs = 0;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    postCallCount++;
    lastUrl = path;
    lastData = data;
    lastOptions = options;
    lastCancelToken = cancelToken;

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.cancel,
        error: 'Cancelled',
      );
    }

    if (shouldThrow) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 429,
        ),
      );
    }

    final responseData = Uint8List.fromList([1, 2, 3, 4]);
    return Response<T>(
      data: responseData as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    if (!getIt.isRegistered<LogService>()) {
      getIt.registerLazySingleton<LogService>(() => LogService());
    }

    // Mock Method Channels của audioplayers và flutter_tts để tránh lỗi MissingPluginException
    const MethodChannel('xyz.luan/audioplayers').setMockMethodCallHandler((methodCall) async {
      if (methodCall.method == 'create') {
        return null;
      }
      return null;
    });
    const MethodChannel('xyz.luan/audioplayers/global').setMockMethodCallHandler((methodCall) async {
      return null;
    });
    const MethodChannel('flutter_tts').setMockMethodCallHandler((methodCall) async {
      return null;
    });
  });

  group('TTS Voice-over 13 ULTIMATE TESTs & Core Logic', () {
    test('1. Graceful Fail-over (OpenAI 429 -> Native) - Removed Fallback', () async {
      final mockDio = MockDio()..shouldThrow = true;
      final mockTts = MockFlutterTts();
      final mockPlayer = MockAudioPlayer();

      final nativeImpl = NativeTtsImpl(tts: mockTts);
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);

      await openAiImpl.speak('Test speech fallback', durationMs: 2000, videoPlaybackSpeed: 1.0);

      // Vì đã bỏ fallback theo yêu cầu, Native không được gọi nữa
      expect(mockTts.lastSpokenText, isNull);
    });

    test('2. Engine Warm-up (init called once)', () async {
      final mockTts = MockFlutterTts();
      final nativeImpl = NativeTtsImpl(tts: mockTts);
      final facade = TtsServiceFacade(
        prefs: prefs,
        nativeTts: nativeImpl,
        openAiTts: OpenAiTtsImpl(dio: MockDio(), player: MockAudioPlayer(), prefs: prefs, nativeFallback: nativeImpl),
        edgeTts: EdgeTtsImpl(dio: MockDio(), player: MockAudioPlayer(), prefs: prefs),
      );

      await facade.init();
      // warm-up nên set language default hoặc setup category
      expect(mockTts.lastLanguage, isNotNull);
    });

    test('3. Text Truncation Limit (600 chars -> 500)', () async {
      final mockTts = MockFlutterTts();
      final nativeImpl = NativeTtsImpl(tts: mockTts);

      final longText = 'A' * 600;
      await nativeImpl.speak(longText, durationMs: 2000, videoPlaybackSpeed: 1.0);

      expect(mockTts.lastSpokenText?.length, equals(500));
      expect(mockTts.lastSpokenText, equals('A' * 500));
    });

    test('4. Voice Selection Payload', () async {
      await prefs.setString('tts_voice', 'nova');
      await prefs.setString('tts_api_key', 'test-key');
      await prefs.setString('tts_base_url', 'https://api.openai.com/v1');

      final mockDio = MockDio();
      final mockPlayer = MockAudioPlayer();
      final nativeImpl = NativeTtsImpl(tts: MockFlutterTts());
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);

      await openAiImpl.speak('Hello', durationMs: 2000, videoPlaybackSpeed: 1.0);

      expect(mockDio.lastData, isNotNull);
      final dataMap = mockDio.lastData as Map<String, dynamic>;
      expect(dataMap['voice'], equals('nova'));
    });

    test('5. Mutex Race Condition (Sequential Stop/Play execution)', () async {
      final mockDio = MockDio();
      final mockPlayer = MockAudioPlayer();
      final nativeImpl = NativeTtsImpl(tts: MockFlutterTts());
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);

      await prefs.setString('tts_api_key', 'test-key');
      await prefs.setString('tts_base_url', 'https://api.openai.com/v1');

      // Gọi speak 3 lần đồng thời không await
      final p1 = openAiImpl.speak('First text', durationMs: 2000, videoPlaybackSpeed: 1.0);
      final p2 = openAiImpl.speak('Second text', durationMs: 2000, videoPlaybackSpeed: 1.0);
      final p3 = openAiImpl.speak('Third text', durationMs: 2000, videoPlaybackSpeed: 1.0);

      await Future.wait<void>([p1, p2, p3]);

      // Call order phải tuân thủ stop -> play cho mỗi lần speak
      // Nên sẽ có dạng stop, play, stop, play...
      expect(mockPlayer.callOrder.length, greaterThanOrEqualTo(2));
      for (int i = 0; i < mockPlayer.callOrder.length; i++) {
        if (i % 2 == 0) {
          expect(mockPlayer.callOrder[i], equals('stop'));
        } else {
          expect(mockPlayer.callOrder[i], equals('play'));
        }
      }
    });

    test('6. URL Sanitization (Trailing Slash)', () async {
      await prefs.setString('tts_base_url', 'https://proxy.com/v1/');
      await prefs.setString('tts_api_key', 'test-key');
      final mockDio = MockDio();
      final mockPlayer = MockAudioPlayer();
      final nativeImpl = NativeTtsImpl(tts: MockFlutterTts());
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);

      await openAiImpl.speak('Hello', durationMs: 2000, videoPlaybackSpeed: 1.0);

      // Base URL phải được sanitize không có double slash
      expect(mockDio.lastUrl, equals('https://proxy.com/v1/audio/speech'));
    });

    test('7. OpenAI Speed Payload', () async {
      await prefs.setString('tts_api_key', 'test-key');
      await prefs.setString('tts_base_url', 'https://api.openai.com/v1');
      final mockDio = MockDio();
      final mockPlayer = MockAudioPlayer();
      final nativeImpl = NativeTtsImpl(tts: MockFlutterTts());
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);

      await openAiImpl.speak('Speed check', durationMs: 2000, videoPlaybackSpeed: 2.0);

      final dataMap = mockDio.lastData as Map<String, dynamic>;
      expect(dataMap['speed'], equals(2.0));
    });

    test('8. Resource Disposal', () async {
      await prefs.setString('tts_api_key', 'test-key');
      await prefs.setString('tts_base_url', 'https://api.openai.com/v1');
      
      final mockDio = MockDio()..delayMs = 100;
      final mockPlayer = MockAudioPlayer();
      final nativeImpl = NativeTtsImpl(tts: MockFlutterTts());
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);

      // Gọi speak nhưng không await (giả lập đang chạy)
      final future = openAiImpl.speak('Long request', durationMs: 5000, videoPlaybackSpeed: 1.0);
      
      // Chờ một chút để dio nhận request
      await Future.delayed(const Duration(milliseconds: 50));

      // Dispose ngay lập tức
      await openAiImpl.dispose();

      expect(mockPlayer.isDisposeCalled, isTrue);
      expect(mockDio.lastCancelToken?.isCancelled, isTrue);

      try {
        await future;
      } catch (_) {}
    });

    test('9. Engine Delegation (Facade)', () async {
      final mockTts = MockFlutterTts();
      final mockDio = MockDio();
      final mockPlayer = MockAudioPlayer();

      final nativeImpl = NativeTtsImpl(tts: mockTts);
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);
      final edgeTts = EdgeTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs);
      final facade = TtsServiceFacade(
        prefs: prefs,
        nativeTts: nativeImpl,
        openAiTts: openAiImpl,
        edgeTts: edgeTts,
      );

      // Trường hợp 1: tts_engine = native
      await prefs.setString('tts_engine', 'native');
      await facade.speak('Engine test', durationMs: 2000, videoPlaybackSpeed: 1.0);
      expect(mockTts.lastSpokenText, equals('Engine test'));

      // Trường hợp 2: tts_engine = openai
      mockTts.lastSpokenText = null;
      await prefs.setString('tts_engine', 'openai');
      await prefs.setString('tts_api_key', 'key');
      await prefs.setString('tts_base_url', 'url');
      await facade.speak('Engine test', durationMs: 2000, videoPlaybackSpeed: 1.0);
      
      expect(mockTts.lastSpokenText, isNull); // Không chạy qua native nữa
      expect(mockPlayer.isPlayCalled, isTrue);
    });

    test('10. Empty API Key Fallback - Removed Fallback', () async {
      final mockTts = MockFlutterTts();
      final mockDio = MockDio();
      final mockPlayer = MockAudioPlayer();

      final nativeImpl = NativeTtsImpl(tts: mockTts);
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);
      final edgeTts = EdgeTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs);
      final facade = TtsServiceFacade(
        prefs: prefs,
        nativeTts: nativeImpl,
        openAiTts: openAiImpl,
        edgeTts: edgeTts,
      );

      await prefs.setString('tts_engine', 'openai');
      await prefs.setString('tts_api_key', ''); // Rỗng API key

      await facade.speak('Fallback text', durationMs: 2000, videoPlaybackSpeed: 1.0);

      // Không chuyển sang Native đọc nữa vì đã gỡ bỏ fallback
      expect(mockTts.lastSpokenText, isNull);
      expect(mockDio.postCallCount, equals(0)); // Không gửi HTTP request nào
    });

    test('11. POST & BytesSource Architecture', () async {
      await prefs.setString('tts_api_key', 'key');
      await prefs.setString('tts_base_url', 'url');
      final mockDio = MockDio();
      final mockPlayer = MockAudioPlayer();
      final nativeImpl = NativeTtsImpl(tts: MockFlutterTts());
      final openAiImpl = OpenAiTtsImpl(dio: mockDio, player: mockPlayer, prefs: prefs, nativeFallback: nativeImpl);

      await openAiImpl.speak('Hello POST', durationMs: 2000, videoPlaybackSpeed: 1.0);

      expect(mockPlayer.lastSource, isA<BytesSource>());
      final bytesSource = mockPlayer.lastSource as BytesSource;
      expect(bytesSource.bytes, equals(Uint8List.fromList([1, 2, 3, 4])));
    });

    test('12. Language Availability Check (Native Fallback)', () async {
      final mockTts = MockFlutterTts()..isLanguageAvailableResult = false;
      final nativeImpl = NativeTtsImpl(tts: mockTts);

      await nativeImpl.speak('Xin chào', durationMs: 2000, videoPlaybackSpeed: 1.0, languageCode: 'vi-VN');

      // Do tiếng Việt không khả dụng, phải fallback sang en-US hoặc default
      expect(mockTts.lastLanguage, equals('en-US'));
      expect(mockTts.lastSpokenText, equals('Xin chào'));
    });

    test('HTML Stripping & Sanitization validation', () async {
      final mockTts = MockFlutterTts();
      final nativeImpl = NativeTtsImpl(tts: mockTts);

      await nativeImpl.speak('<i>Hello</i> World!', durationMs: 2000, videoPlaybackSpeed: 1.0);
      expect(mockTts.lastSpokenText, equals('Hello World!'));

      mockTts.lastSpokenText = null;
      await nativeImpl.speak('♪ Music ♪', durationMs: 2000, videoPlaybackSpeed: 1.0);
      expect(mockTts.lastSpokenText, equals('Music'));
    });
  });
}
