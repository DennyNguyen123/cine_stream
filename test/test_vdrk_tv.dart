import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final subUrl = 'https://sub.vdrk.site/v2/tv/211288/2/18';
    print('Fetching subtitles from VDRK: $subUrl');
    final subResponse = await dio.get(subUrl);
    print('VDRK Status: ${subResponse.statusCode}');
    if (subResponse.data is List) {
      print('SUCCESS: Found ${(subResponse.data as List).length} subtitles');
      for (var sub in subResponse.data) {
         print(' - ${sub['label']}');
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }
}
