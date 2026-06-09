import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final res = await dio.get('https://94c8cb9f702d-tmdb-addon.baby-beamup.club/meta/series/tt13875494.json');
    final tmdbId = res.data['meta']['tmdb_id'];
    print('TMDB ID: $tmdbId');
    
    if (tmdbId != null) {
      final subUrl = 'https://sub.vdrk.site/v2/tv/$tmdbId/2/18';
      print('Fetching subtitles from VDRK: $subUrl');
      final subResponse = await dio.get(subUrl);
      print('VDRK Status: ${subResponse.statusCode}');
      if (subResponse.data is List) {
        print('SUCCESS: Found ${(subResponse.data as List).length} subtitles');
        for (var sub in subResponse.data) {
           print(' - ${sub['label']} : ${sub['file']}');
        }
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }
}
