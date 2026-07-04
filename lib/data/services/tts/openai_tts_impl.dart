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
  })  : _dio = dio ?? Dio(),
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
            options: [
              AVAudioSessionOptions.mixWithOthers,
            ],
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
        await _executeSpeak(cleanText, durationMs, videoPlaybackSpeed, languageCode);
      } catch (e, stack) {
        getIt<LogService>().error('OpenAI TTS speak failed', e, stack);
      } finally {
        completer.complete();
      }
    });

    return completer.future;
  }

  Future<void> _executeSpeak(
    String text,
    int durationMs,
    double videoPlaybackSpeed,
    String? languageCode,
  ) async {
    // 1. Stop bất kỳ luồng phát hiện tại và cancel API request cũ
    await stop();

    final apiKey = _prefs.getString('tts_api_key') ?? '';
    final baseUrlRaw = _prefs.getString('tts_base_url') ?? '';
    final model = _prefs.getString('tts_model') ?? 'tts-1';
    final voice = _prefs.getString('tts_voice') ?? '';

    final cleanKey = _sanitizeConfig(apiKey);
    var cleanUrl = _sanitizeConfig(baseUrlRaw);

    if (cleanKey.isEmpty || cleanUrl.isEmpty) {
      // API Key hoặc Base URL trống thì nhảy sang ném Exception để fallback ngay
      throw Exception('OpenAI API credentials not configured');
    }

    // Sanitize Base URL
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    final fullUrl = '$cleanUrl/audio/speech';
    
    // Log Hex và key length để kiểm tra ký tự lạ
    final hexUrl = cleanUrl.codeUnits.map((u) => u.toRadixString(16).padLeft(4, '0')).join(' ');
    print('[OpenAI TTS] cleanUrl: "$cleanUrl"');
    print('[OpenAI TTS] cleanUrl Hex: $hexUrl');
    print('[OpenAI TTS] cleanKey length: ${cleanKey.length}, first 4: ${cleanKey.length > 4 ? cleanKey.substring(0, 4) : cleanKey}');
    print('[OpenAI TTS] Payload: model=$model, voice=$voice, speed=$videoPlaybackSpeed');

    _cancelToken = CancelToken();

    // 2. Gọi API OpenAI TTS POST
    final Response<List<int>> response;
    try {
      response = await _dio.post<List<int>>(
        fullUrl,
        data: {
          'model': model,
          'input': text,
          'voice': voice,
          'speed': videoPlaybackSpeed,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $cleanKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
        cancelToken: _cancelToken,
      );
    } on DioException catch (e) {
      String responseBody = '';
      if (e.response?.data is List<int>) {
        try {
          responseBody = String.fromCharCodes(e.response!.data as List<int>);
        } catch (_) {}
      } else if (e.response?.data is String) {
        responseBody = e.response!.data as String;
      }
      print('[OpenAI TTS] DioException details: statusCode=${e.response?.statusCode}, message=${e.message}, responseBody=$responseBody');
      rethrow;
    }

    if (response.data == null || response.statusCode != 200) {
      throw Exception('Failed to fetch TTS from OpenAI');
    }

    if (_isDisposed) return;

    // 3. Phát âm thanh bằng BytesSource
    final bytes = Uint8List.fromList(response.data!);
    await _player.play(BytesSource(bytes));
  }

  @override
  Future<void> stop() async {
    _cancelToken?.cancel('Speech stopped');
    _cancelToken = null;
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
