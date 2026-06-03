import 'package:dio/dio.dart';
import '../../../../domain/entities/subtitle.dart';

class VdrkSubtitleExtractor {
  static final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
    followRedirects: true,
    validateStatus: (status) => status != null && status < 500,
  ));

  /// Fetch subtitles from sub.vdrk.site (free, no key needed)
  static Future<List<SubtitleTrack>> fetchSubtitles(String tmdbId, {bool isTv = false, int? s, int? e}) async {
    try {
      final url = isTv
          ? 'https://sub.vdrk.site/v2/tv/$tmdbId/$s/$e'
          : 'https://sub.vdrk.site/v2/movie/$tmdbId';
      
      print('[SubtitleExtractor] Fetching subtitles: $url');
      final response = await _dio.get(url);
      
      if (response.statusCode == 200 && response.data is List) {
        final subs = <SubtitleTrack>[];
        int idx = 0;
        for (final sub in response.data) {
          subs.add(SubtitleTrack(
            id: idx,
            src: sub['file'] ?? '',
            label: sub['label'] ?? 'Unknown',
            languageCode: (sub['label'] ?? 'en').toString().substring(0, 2).toLowerCase(),
          ));
          idx++;
        }
        print('[SubtitleExtractor] Found ${subs.length} subtitle tracks');
        return subs;
      }
    } catch (e) {
      print('[SubtitleExtractor] Subtitles error: $e');
    }
    return [];
  }
}
