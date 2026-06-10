import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  print('--- TESTING SUBTITLE FALLBACK ---');
  final dio = Dio();

  final sources = [
    'https://opensubtitles-v3.strem.io/subtitles/series/tt0773262:2:18.json',
    'https://opensubtitles.strem.io/subtitles/series/tt0773262:2:18.json',
  ];

  for (final url in sources) {
    try {
      print('\\n🔄 Fetching from: $url');
      final response = await dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      print('✅ Status Code: ${response.statusCode}');
      if (response.statusCode == 200 && response.data != null) {
        dynamic data = response.data;
        if (data is String) {
          print('⚠️ Data is a String! Decoding with jsonDecode...');
          data = jsonDecode(data);
        } else {
          print('ℹ️ Data is already a Map.');
        }

        if (data is Map && data['subtitles'] != null) {
          final results = data['subtitles'] as List;
          print(
            '🎉 SUCCESS: Found ${results.length} subtitles from this source!',
          );
          for (var sub in results.take(3)) {
            print(
              ' - Lang: ${sub['lang']} | URL: ${sub['url'].toString().substring(0, 30)}...',
            );
          }
          print('\\n🛑 STOPPING FALLBACK LOOP BECAUSE WE GOT DATA!');
          return; // Stop the fallback loop
        }
      }
    } catch (e) {
      print('❌ ERROR from $url:');
      print(e.toString());
      print('⏳ Moving to next fallback source...');
    }
  }
}
