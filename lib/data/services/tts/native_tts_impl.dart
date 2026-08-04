import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cine_stream/domain/services/tts_service.dart';

class NativeTtsImpl implements TtsService {
  final FlutterTts _tts;

  NativeTtsImpl({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  @override
  Future<void> init() async {
    // Cấu hình iOS Audio Session category để không bị đè tiếng phim
    try {
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ]);
    } catch (_) {}
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {}
  }

  @override
  Future<void> speak(
    String text, {
    required int durationMs,
    required double videoPlaybackSpeed,
    String? languageCode,
  }) async {
    await stop();

    // 1. Strip HTML tags và làm sạch text
    String cleanText = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Strip nhạc ký tự đặc biệt nốt nhạc ♪
    cleanText = cleanText.replaceAll('♪', '').trim();

    if (cleanText.isEmpty) return;

    // 2. Cắt text nếu vượt quá 500 ký tự
    if (cleanText.length > 500) {
      cleanText = cleanText.substring(0, 500);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedVoiceName = prefs.getString('tts_voice') ?? '';
      print('[Native TTS] selectedVoiceName: "$selectedVoiceName"');

      if (selectedVoiceName.isNotEmpty) {
        final List<dynamic>? voices = await _tts.getVoices;
        print('[Native TTS] Available voices: $voices');
        if (voices != null) {
          bool voiceFound = false;
          for (final dynamic voice in voices) {
            String name = '';
            if (voice is Map) {
              name = (voice['name'] ?? voice['locale'] ?? '').toString();
            } else {
              name = voice.toString();
            }
            if (name == selectedVoiceName) {
              try {
                if (voice is Map) {
                  await _tts.setVoice(
                    Map<String, String>.from(
                      voice.map((k, v) => MapEntry(k.toString(), v.toString())),
                    ),
                  );
                } else {
                  await _tts.setVoice({'name': name, 'locale': ''});
                }
              } catch (e) {
                print('[Native TTS] setVoice failed: $e');
              }
              voiceFound = true;
              break;
            }
          }
          if (!voiceFound) {
            print(
              '[Native TTS] Warning: selected voice "$selectedVoiceName" not found in available voices. Falling back to language selection.',
            );
            // Fallback sang thiết lập ngôn ngữ nếu không tìm thấy giọng
            String targetLang = languageCode ?? 'en-US';
            try {
              await _tts.setLanguage(targetLang);
            } catch (_) {}
          }
        }
      } else {
        // 3. Thiết lập ngôn ngữ động (chỉ khi không chỉ định giọng cụ thể)
        String targetLang = languageCode ?? 'en-US';
        try {
          final isAvail = await _tts.isLanguageAvailable(targetLang);
          if (isAvail == true) {
            await _tts.setLanguage(targetLang);
          } else {
            await _tts.setLanguage('en-US');
          }
        } catch (e) {
          print(
            '[Native TTS] isLanguageAvailable not supported or failed: $e. Attempting direct setLanguage.',
          );
          try {
            await _tts.setLanguage(targetLang);
          } catch (_) {}
        }
      }
    } catch (e) {
      print('[Native TTS] Error in configuration/language selection: $e');
      // Fallback nếu method channel lỗi
    }

    // 4. Tính toán tốc độ đọc (speech rate)
    int wordCount = cleanText.split(RegExp(r'\s+')).length;
    double expectedDurationSec = wordCount / 2.5;
    double durationSec = durationMs / 1000.0;

    double rate = 0.5; // Tốc độ mặc định của flutter_tts
    if (durationSec > 0 && expectedDurationSec > durationSec) {
      // Tăng tốc độ đọc tỉ lệ thuận
      rate = 0.5 * (expectedDurationSec / durationSec);
      if (rate > 1.0) rate = 1.0;
    }

    // Nhân thêm với tốc độ phát của video
    rate = rate * videoPlaybackSpeed;
    if (rate > 1.0) rate = 1.0;
    if (rate < 0.1) rate = 0.1;

    try {
      await _tts.setSpeechRate(rate);
      await _tts.speak(cleanText);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _tts.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> prefetch(
    String text, {
    required int durationMs,
    required double videoPlaybackSpeed,
    String? languageCode,
  }) async {
    // No-op for Native TTS because it runs offline.
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  @override
  Future<List<String>> getVoices() async {
    // Tránh gọi native method channel trên thread phụ của Windows
    final completer = Completer<List<String>>();
    scheduleMicrotask(() async {
      try {
        final List<dynamic>? voices = await _tts.getVoices;
        if (voices != null) {
          final list = voices
              .map((v) {
                if (v is Map) {
                  return (v['name'] ?? v['locale'] ?? '').toString();
                }
                return v.toString();
              })
              .where((name) => name.isNotEmpty)
              .toList();
          completer.complete(list);
          return;
        }
      } catch (_) {}
      completer.complete([]);
    });
    return completer.future;
  }
}
