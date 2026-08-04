import 'dart:async';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cine_stream/domain/services/tts_service.dart';
import 'package:cine_stream/data/services/log_service.dart';
import 'package:cine_stream/di/injection.dart';
import 'package:flutter/foundation.dart';

class EdgeTtsImpl implements TtsService {
  final Dio _dio;
  final AudioPlayer _player;
  final SharedPreferences _prefs;

  String? _cachedKey;
  String? _cachedToken;
  String? _cachedCookie;
  DateTime? _tokenTime;

  bool _isDisposed = false;
  Future<void> _lock = Future.value();
  CancelToken? _cancelToken;
  Completer<void>? _playCompleter;

  final Map<String, Uint8List> _prefetchCache = {};
  static const int _maxCacheSize = 30;

  void _addToCache(String key, Uint8List bytes) {
    if (_prefetchCache.length >= _maxCacheSize) {
      _prefetchCache.remove(_prefetchCache.keys.first);
    }
    _prefetchCache[key] = bytes;
  }

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  EdgeTtsImpl({Dio? dio, AudioPlayer? player, required SharedPreferences prefs})
    : _dio = dio ?? Dio(),
      _player = player ?? AudioPlayer(),
      _prefs = prefs;

  @override
  Future<void> init() async {
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

  Future<void> _getToken({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedToken != null &&
        _tokenTime != null &&
        now.difference(_tokenTime!) < const Duration(minutes: 5)) {
      return;
    }

    try {
      final response = await _dio.get<String>(
        'https://www.bing.com/translator',
        options: Options(
          headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'vi,en-US;q=0.9,en;q=0.8',
          },
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Failed to load Bing translator page');
      }

      final rawCookies = response.headers['set-cookie'] ?? [];
      final cookieString = rawCookies.map((c) => c.split(';').first).join('; ');

      final html = response.data!;
      final regExp = RegExp(
        r'params_AbusePreventionHelper\s*=\s*\[([^,]+),([^,]+),',
      );
      final match = regExp.firstMatch(html);
      if (match == null) {
        throw Exception('AbusePreventionHelper parameters not found in HTML');
      }

      _cachedKey = match.group(1)?.replaceAll('"', '').trim();
      _cachedToken = match.group(2)?.replaceAll('"', '').trim();
      _cachedCookie = cookieString;
      _tokenTime = now;

      debugPrint(
        '[EdgeTTS] Got new token: key=$_cachedKey, token=$_cachedToken',
      );
    } catch (e) {
      debugPrint('[EdgeTTS] Error getting token: $e');
      rethrow;
    }
  }

  Future<Response<List<int>>> _sendTtsRequest(
    String text,
    String voiceId,
    double videoPlaybackSpeed,
    CancelToken? cancelToken,
  ) async {
    final parts = voiceId.split('-');
    final xmlLang = parts.length >= 2 ? parts.sublist(0, 2).join('-') : 'vi-VN';
    final gender = voiceId.toLowerCase().contains('male') ? 'Male' : 'Female';

    // Tính toán prosody rate từ videoPlaybackSpeed
    final ratePercent = (videoPlaybackSpeed - 1.0) * 100;
    final prosodyRate = ratePercent >= 0
        ? '+${ratePercent.toStringAsFixed(2)}%'
        : '${ratePercent.toStringAsFixed(2)}%';

    final ssml =
        "<speak version='1.0' xml:lang='$xmlLang'><voice xml:lang='$xmlLang' xml:gender='$gender' name='$voiceId'><prosody rate='$prosodyRate'>$text</prosody></voice></speak>";

    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': '*/*',
      'Origin': 'https://www.bing.com',
      'Referer': 'https://www.bing.com/translator',
      'User-Agent': _userAgent,
    };
    if (_cachedCookie != null && _cachedCookie!.isNotEmpty) {
      headers['Cookie'] = _cachedCookie!;
    }

    // Build URL-encoded request body thủ công để đảm bảo định dạng SSML an toàn
    final body =
        'ssml=${Uri.encodeComponent(ssml)}'
        '&token=${Uri.encodeComponent(_cachedToken ?? '')}'
        '&key=${Uri.encodeComponent(_cachedKey ?? '')}';

    return _dio.post<List<int>>(
      'https://www.bing.com/tfettts?isVertical=1&&IG=1&IID=translator.5023&SFX=1',
      data: body,
      options: Options(headers: headers, responseType: ResponseType.bytes),
      cancelToken: cancelToken,
    );
  }

  @override
  Future<void> speak(
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

    final completer = Completer<void>();
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
        getIt<LogService>().error('Edge TTS speak failed', e, stack);
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
      debugPrint(
        '[EdgeTTS] Prefetched and cached speech for text: "$cleanText"',
      );
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
    final voice = _prefs.getString('tts_voice') ?? 'vi-VN-HoaiMyNeural';

    await _getToken();

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
    // Giới hạn an toàn của Edge TTS API là 4.0x (tương đương prosody +300%)
    final finalSpeed = (speedMultiplier * videoPlaybackSpeed).clamp(0.25, 4.0);

    Response<List<int>> response;
    try {
      response = await _sendTtsRequest(text, voice, finalSpeed, cancelToken);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 429) {
        debugPrint(
          '[EdgeTTS] Token expired or rate limited (status ${e.response?.statusCode}), retrying...',
        );
        await _getToken(forceRefresh: true);
        response = await _sendTtsRequest(text, voice, finalSpeed, cancelToken);
      } else {
        rethrow;
      }
    }

    if (response.data == null || response.statusCode != 200) {
      throw Exception(
        'Failed to fetch TTS from Edge (status ${response.statusCode})',
      );
    }

    final bytes = Uint8List.fromList(response.data!);
    if (bytes.length < 1024) {
      throw Exception('Edge TTS returned empty audio');
    }
    return bytes;
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
      debugPrint('[EdgeTTS] Cache hit for text: "$text"');
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
    return [
      'vi-VN-HoaiMyNeural',
      'vi-VN-NamMinhNeural',
      'en-US-AvaNeural',
      'en-US-AndrewNeural',
      'en-US-EmmaNeural',
      'en-US-BrianNeural',
    ];
  }
}
