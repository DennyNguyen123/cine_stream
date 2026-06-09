import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  final dio = Dio();
  
  final sources = [
    'https://msubtitles.strem.io/subtitles/series/tt13875494:2:18.json',
    'https://legion.strem.io/subtitles/series/tt13875494:2:18.json',
    'https://subscene.strem.io/subtitles/series/tt13875494:2:18.json',
    'https://opensubtitles.com/subtitles/series/tt13875494:2:18.json', // Not a stremio addon probably
  ];

  for (final url in sources) {
    print('\\n--- Testing $url ---');
    try {
      final response = await dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      
      print('Status: ${response.statusCode}');
      dynamic data = response.data;
      if (data is String) {
        if (data.trim().startsWith('<')) {
          print('Returned HTML!');
        } else {
          try {
            data = jsonDecode(data);
            print('Parsed JSON.');
          } catch(e) {
            print('Not JSON.');
          }
        }
      }
      
      if (data is Map && data['subtitles'] != null) {
        final subs = data['subtitles'] as List;
        print('SUCCESS: Found ${subs.length} subtitles');
        for (var sub in subs.take(2)) print(sub);
      } else {
        print('No subtitles found.');
      }
    } catch (e) {
      print('ERROR: $e');
    }
  }
}
