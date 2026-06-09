import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  final dio = Dio();
  
  final sources = [
    'https://opensubtitles-v3.strem.io/subtitles/series/tt13875494:2:18.json',
    'https://opensubtitles.strem.io/subtitles/series/tt13875494:2:18.json',
    'https://stremio-opensubtitles.strem.io/subtitles/series/tt13875494:2:18.json',
  ];

  for (final url in sources) {
    print('\\n--- Testing $url ---');
    try {
      final response = await dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      
      print('Status: ${response.statusCode}');
      dynamic data = response.data;
      if (data is String) {
        if (data.trim().startsWith('<')) {
          print('Returned HTML!');
        } else {
          data = jsonDecode(data);
          print('Parsed JSON from String.');
        }
      }
      
      if (data is Map && data['subtitles'] != null) {
        final subs = data['subtitles'] as List;
        print('SUCCESS: Found ${subs.length} subtitles');
      } else {
        print('No subtitles found in response.');
      }
    } catch (e) {
      print('ERROR: $e');
    }
  }
}
