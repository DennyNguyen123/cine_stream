import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cine_stream/domain/services/tts_service.dart';
import 'package:cine_stream/data/services/log_service.dart';
import 'package:cine_stream/di/injection.dart';

class OpenAiTtsImpl implements TtsService {
  final Dio _dio;
  final AudioPlayer _player;
  final SharedPreferences _prefs;
  final TtsService _nativeFallback;

  CancelToken? _cancelToken;
  bool _isDisposed = false;
  Completer<void>? _playCompleter;

  final Map<String, Uint8List> _prefetchCache = {};
  static const int _maxCacheSize = 30;

  void _addToCache(String key, Uint8List bytes) {
    if (_prefetchCache.length >= _maxCacheSize) {
      _prefetchCache.remove(_prefetchCache.keys.first);
    }
    _prefetchCache[key] = bytes;
  }

  // Mutex đơn giản sử dụng Future chain để đảm bảo stop và play chạy tuần tự,
  // tránh IllegalStateException trên ExoPlayer khi nhiều âm thanh được trigger dồn dập.
  Future<void> _lock = Future.value();

  String _sanitizeConfig(String input) {
    return input.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '').trim();
  }

  OpenAiTtsImpl({
    Dio? dio,
    AudioPlayer? player,
    required SharedPreferences prefs,
    required TtsService nativeFallback,
  }) : _dio = dio ?? Dio(),
       _player = player ?? AudioPlayer(),
       _prefs = prefs,
       _nativeFallback = nativeFallback;

  @override
  Future<void> init() async {
    // iOS Audio Context Config
    try {
      await AudioPlayer.global.setAudioContext(
        const AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [AVAudioSessionOptions.mixWithOthers],
          ),
          android: AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            contentType: AndroidContentType.movie,
            usageType: AndroidUsageType.media,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Future<void> speak(
    String text, {
    required int durationMs,
    required double videoPlaybackSpeed,
    String? languageCode,
  }) async {
    // Clean text trước khi check rỗng
    String cleanText = text.replaceAll(RegExp(r'<[^>]*>'), '');
    cleanText = cleanText.replaceAll('♪', '').trim();
    if (cleanText.isEmpty) return;

    if (cleanText.length > 500) {
      cleanText = cleanText.substring(0, 500);
    }

    final completer = Completer<void>();

    // Đẩy việc thực thi speak vào queue lock
    _lock = _lock.then((_) async {
      try {
        if (_isDisposed) return;
        await _executeSpeak(
          cleanText,
          durationMs,
          videoPlaybackSpeed,
          languageCode,
        );
      } catch (e, stack) {
        getIt<LogService>().error('OpenAI TTS speak failed', e, stack);
      } finally {
        completer.complete();
      }
    });

    return completer.future;
  }

  @override
  Future<void> prefetch(
    String text, {
    required int durationMs,
    required double videoPlaybackSpeed,
    String? languageCode,
  }) async {
    String cleanText = text.replaceAll(RegExp(r'<[^>]*>'), '');
    cleanText = cleanText.replaceAll('♪', '').trim();
    if (cleanText.isEmpty) return;

    if (cleanText.length > 500) {
      cleanText = cleanText.substring(0, 500);
    }

    final cacheKey = '${cleanText}_${durationMs}_$videoPlaybackSpeed';
    if (_prefetchCache.containsKey(cacheKey)) return;

    try {
      final bytes = await _generateSpeechBytes(
        cleanText,
        durationMs,
        videoPlaybackSpeed,
        languageCode,
        null,
      );
      _addToCache(cacheKey, bytes);
      print('[OpenAI TTS] Prefetched and cached speech for text: "$cleanText"');
    } catch (_) {
      // Prefetch fails silently
    }
  }

  Future<Uint8List> _generateSpeechBytes(
    String text,
    int durationMs,
    double videoPlaybackSpeed,
    String? languageCode,
    CancelToken? cancelToken,
  ) async {
    final apiKey = _prefs.getString('tts_api_key') ?? '';
    final baseUrlRaw = _prefs.getString('tts_base_url') ?? '';
    final model = _prefs.getString('tts_model') ?? 'tts-1';
    final voice = _prefs.getString('tts_voice') ?? '';

    final cleanKey = _sanitizeConfig(apiKey);
    var cleanUrl = _sanitizeConfig(baseUrlRaw);

    if (cleanKey.isEmpty || cleanUrl.isEmpty) {
      throw Exception('OpenAI API credentials not configured');
    }

    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    final fullUrl = '$cleanUrl/audio/speech';

    // Tính toán tốc độ đọc tự động dựa trên độ dài văn bản và thời gian hiển thị
    double speedMultiplier = 1.25; // Nâng tốc độ nền lên thêm 25%
    if (durationMs > 0) {
      final cleanText = text
          .replaceAll(RegExp(r'\[.*?\]|\(.*?\)', dotAll: true), '')
          .trim();
      final wordCount = cleanText
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      if (wordCount > 0) {
        // Ước lượng thời gian cần thiết (tăng 20% độ nhạy): tối thiểu 456ms cho mỗi từ và 96ms cho mỗi ký tự
        final estimatedMsByWords = wordCount * 456;
        final estimatedMsByChars = cleanText.length * 96;
        final estimatedMs = estimatedMsByWords > estimatedMsByChars
            ? estimatedMsByWords
            : estimatedMsByChars;

        final calculatedMultiplier = estimatedMs / durationMs;
        if (calculatedMultiplier > speedMultiplier) {
          speedMultiplier = calculatedMultiplier;
        }
      }
    }
    if (speedMultiplier > 5.0) {
      speedMultiplier = 5.0; // Trần tốc độ 5x theo yêu cầu
    }
    // Giới hạn an toàn của OpenAI API là 4.0x
    final finalSpeed = (speedMultiplier * videoPlaybackSpeed).clamp(0.25, 4.0);

    final Response<List<int>> response = await _dio.post<List<int>>(
      fullUrl,
      data: {
        'model': model,
        'input': text,
        'voice': voice,
        'speed': finalSpeed,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $cleanKey',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );

    if (response.data == null || response.statusCode != 200) {
      throw Exception('Failed to fetch TTS from OpenAI');
    }

    return Uint8List.fromList(response.data!);
  }

  Future<void> _executeSpeak(
    String text,
    int durationMs,
    double videoPlaybackSpeed,
    String? languageCode,
  ) async {
    await stop();
    _cancelToken = CancelToken();

    final cacheKey = '${text}_${durationMs}_$videoPlaybackSpeed';
    Uint8List bytes;
    if (_prefetchCache.containsKey(cacheKey)) {
      bytes = _prefetchCache.remove(cacheKey)!;
      print('[OpenAI TTS] Cache hit for text: "$text"');
    } else {
      bytes = await _generateSpeechBytes(
        text,
        durationMs,
        videoPlaybackSpeed,
        languageCode,
        _cancelToken,
      );
    }

    if (_isDisposed) return;

    _playCompleter = Completer<void>();
    final subscription = _player.onPlayerComplete.listen((_) {
      if (_playCompleter != null && !_playCompleter!.isCompleted) {
        _playCompleter!.complete();
      }
    });

    try {
      await _player.play(BytesSource(bytes));
      await _playCompleter!.future;
    } finally {
      await subscription.cancel();
      _playCompleter = null;
    }
  }

  @override
  Future<void> stop() async {
    _cancelToken?.cancel('Speech stopped');
    _cancelToken = null;
    if (_playCompleter != null && !_playCompleter!.isCompleted) {
      _playCompleter!.complete();
    }
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    try {
      await stop();
    } catch (_) {}
    try {
      await _player.dispose();
    } catch (_) {}
  }

  @override
  Future<List<String>> getVoices() async {
    return ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];
  }
}
