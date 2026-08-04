import 'package:shared_preferences/shared_preferences.dart';
import 'package:cine_stream/domain/services/tts_service.dart';

class TtsServiceFacade implements TtsService {
  final SharedPreferences _prefs;
  final TtsService _nativeTts;
  final TtsService _openAiTts;
  final TtsService _edgeTts;

  TtsServiceFacade({
    required SharedPreferences prefs,
    required TtsService nativeTts,
    required TtsService openAiTts,
    required TtsService edgeTts,
  }) : _prefs = prefs,
       _nativeTts = nativeTts,
       _openAiTts = openAiTts,
       _edgeTts = edgeTts;

  TtsService get _activeService {
    final engine = _prefs.getString('tts_engine') ?? 'native';
    if (engine == 'openai') {
      return _openAiTts;
    }
    if (engine == 'edge') {
      return _edgeTts;
    }
    return _nativeTts;
  }

  @override
  Future<void> init() async {
    await _nativeTts.init();
    await _openAiTts.init();
    await _edgeTts.init();
  }

  @override
  Future<void> speak(
    String text, {
    required int durationMs,
    required double videoPlaybackSpeed,
    String? languageCode,
  }) async {
    await _activeService.speak(
      text,
      durationMs: durationMs,
      videoPlaybackSpeed: videoPlaybackSpeed,
      languageCode: languageCode,
    );
  }

  @override
  Future<void> prefetch(
    String text, {
    required int durationMs,
    required double videoPlaybackSpeed,
    String? languageCode,
  }) async {
    await _activeService.prefetch(
      text,
      durationMs: durationMs,
      videoPlaybackSpeed: videoPlaybackSpeed,
      languageCode: languageCode,
    );
  }

  @override
  Future<void> stop() async {
    await _nativeTts.stop();
    await _openAiTts.stop();
    await _edgeTts.stop();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _activeService.setVolume(volume);
  }

  @override
  Future<void> dispose() async {
    await _nativeTts.dispose();
    await _openAiTts.dispose();
    await _edgeTts.dispose();
  }

  @override
  Future<List<String>> getVoices() async {
    return _activeService.getVoices();
  }
}
