abstract class TtsService {
  Future<void> init();
  Future<void> speak(
    String text, {
    required int durationMs,
    required double videoPlaybackSpeed,
    String? languageCode,
  });
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> dispose();
  Future<List<String>> getVoices();
}
