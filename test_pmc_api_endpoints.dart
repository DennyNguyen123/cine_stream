import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  final dio = Dio();
  try {
    print('Fetching watch page...');
    final res = await dio.get(
      'https://phimmoichill.click/xem-phim/kieu-so/tap-1/song-ngu',
    );
    final html = res.data.toString();

    final scriptRegex = RegExp(
      r'<script>self\.__next_f\.push\(\[1,"(.*)"\]\)</script>',
      dotAll: true,
    );
    final scriptMatches = scriptRegex.allMatches(html);

    String fullPayload = '';
    for (var m in scriptMatches) {
      String str = m.group(1)!;
      str = str.replaceAll(r'\"', '"');
      str = str.replaceAll(r'\\', r'\');
      fullPayload += str;
    }

    final apiRegex = RegExp(r'/api/v1/[a-zA-Z0-9_/-]+');
    final matches = apiRegex.allMatches(fullPayload);
    final uniqueMatches = matches.map((m) => m.group(0)!).toSet();
    print('Found API endpoints: $uniqueMatches');
  } catch (e) {
    print('Error: $e');
  }
}
