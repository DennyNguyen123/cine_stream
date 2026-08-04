import 'package:dio/dio.dart';
import 'dart:convert';

void main() async {
  final dio = Dio();
  try {
    print('Fetching phimmoichill.click...');
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

    // find "current_episode" or "episode_sources"
    final objRegex = RegExp(
      r'"current_episode":(\{.*?"episode_sources".*?\]})',
    );
    final objMatch = objRegex.firstMatch(fullPayload);
    if (objMatch != null) {
      print('current_episode: ${objMatch.group(1)}');
    } else {
      print('Not found. Payload: ${fullPayload.substring(0, 500)}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
