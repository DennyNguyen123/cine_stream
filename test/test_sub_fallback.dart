import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cine_stream/data/repositories/external_subtitle_repository.dart';

void main() async {
  print('--- TESTING SUBTITLE FALLBACK ---');
  final dio = Dio();
  final repo = ExternalSubtitleRepository(dio);
  
  final subs = await repo.getSubtitles('tt13875494', season: 2, episode: 18);
  
  if (subs.isNotEmpty) {
    print('✅ SUCCESS: Fetched ${subs.length} subtitles!');
    for (var sub in subs.take(5)) {
      print(' - ${sub.label} : ${sub.src}');
    }
  } else {
    print('❌ FAILED: No subtitles found from any fallback source.');
  }
}
