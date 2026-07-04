import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:cine_stream/di/injection.dart';
import 'package:cine_stream/domain/services/tts_service.dart';
import 'package:cine_stream/data/services/log_service.dart';
import 'package:flutter/services.dart';
import 'package:cine_stream/presentation/screens/player_screen.dart';
import 'package:cine_stream/domain/entities/stream_info.dart';

// Mock TtsService để test hành vi của PlayerScreen
class MockTtsService implements TtsService {
  int initCallCount = 0;
  int speakCallCount = 0;
  int stopCallCount = 0;
  int disposeCallCount = 0;
  String? lastSpokenText;

  @override
  Future<void> init() async {
    initCallCount++;
  }

  @override
  Future<void> speak(
    String text, {
    required int durationMs,
    required double videoPlaybackSpeed,
    String? languageCode,
  }) async {
    speakCallCount++;
    lastSpokenText = text;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<List<String>> getVoices() async {
    return ['Voice 1', 'Voice 2'];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockTtsService mockTts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'cinestream_tts_enabled': true, // Bật mặc định để chạy test trigger speak
    });
    final prefs = await SharedPreferences.getInstance();

    if (!getIt.isRegistered<SharedPreferences>()) {
      getIt.registerLazySingleton<SharedPreferences>(() => prefs);
    }

    mockTts = MockTtsService();
    if (!getIt.isRegistered<TtsService>()) {
      getIt.registerLazySingleton<TtsService>(() => mockTts);
    }

    if (!getIt.isRegistered<LogService>()) {
      getIt.registerLazySingleton<LogService>(() => LogService());
    }

    // Mock Method Channel cho video_player
    const MethodChannel('flutter.io/videoPlayer').setMockMethodCallHandler((methodCall) async {
      if (methodCall.method == 'init') {
        return null;
      }
      if (methodCall.method == 'create') {
        return {'textureId': 1};
      }
      return null;
    });
  });

  tearDown(() {
    getIt.reset();
  });

  group('PlayerScreen TTS Integration Tests', () {
    testWidgets('1. (ULTIMATE TEST 2) Warm-up & lifecycle hooks', (WidgetTester tester) async {
      final streamInfo = StreamInfo(
        videoUrl: '', // Sử dụng chuỗi rỗng để kích hoạt nhánh mock controller
        headers: {},
      );

      // Render PlayerScreen
      await tester.pumpWidget(MaterialApp(
        home: PlayerScreen(
          streamInfo: streamInfo,
          title: 'Test Movie',
          movieId: 'id-123',
          movieTitle: 'Test Movie',
          episodeId: 'ep-1',
          episodeNumber: 1.0,
          allEpisodes: const [],
        ),
      ));

      // 1. Kiểm tra init() TTS đã được gọi trong initState
      expect(mockTts.initCallCount, equals(1));

      // 2. Kích hoạt lifecycle paused và kiểm tra stop() được gọi
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(mockTts.stopCallCount, equals(1));

      // 3. Dispose PlayerScreen và kiểm tra dispose() của TTS được gọi
      await tester.pumpWidget(const SizedBox());
      expect(mockTts.disposeCallCount, equals(1));
    });
  });
}
