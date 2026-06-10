import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final urls = [
    'https://opensubtitles.addon.strem.io/subtitles/series/tt0816696:3:10.json',
    'https://opensubtitles-v2.strem.io/subtitles/series/tt0816696:3:10.json',
  ];
  for (var u in urls) {
    try {
      print('Testing: $u');
      final r = await dio.get(
        u,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      print('Status: ${r.statusCode}');
      if (r.data is Map) {
        print('Found: ${(r.data['subtitles'] as List?)?.length} subs');
      } else {
        print('Not map: ${r.data.toString().substring(0, 30)}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
