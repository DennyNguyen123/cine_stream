abstract class SubtitleRepository {
  Future<String?> getSubtitleContent(String url);
  void clearCache();
}
