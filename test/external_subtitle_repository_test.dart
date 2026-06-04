import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:cine_stream/data/repositories/external_subtitle_repository.dart';

void main() {
  group('ExternalSubtitleRepository', () {
    late Dio dio;
    late ExternalSubtitleRepository repository;

    setUp(() {
      dio = Dio();
      repository = ExternalSubtitleRepository(dio);
    });

    test('getSubtitles returns subtitle tracks for valid IMDb movie ID', () async {
      // tt1375666 is Inception (2010)
      final tracks = await repository.getSubtitles('tt1375666');
      
      // We expect the Stremio Addon to have subtitles for a popular movie like Inception
      expect(tracks, isNotEmpty);
      expect(tracks.first.src, isNotEmpty);
      expect(tracks.first.label, isNotEmpty);
    });

    test('getSubtitles returns subtitle tracks for valid IMDb series ID', () async {
      // tt0903747 is Breaking Bad, Season 1 Episode 1
      final tracks = await repository.getSubtitles('tt0903747', season: 1, episode: 1);
      
      // We expect the Stremio Addon to have subtitles for a popular TV show like Breaking Bad
      expect(tracks, isNotEmpty);
      expect(tracks.first.src, isNotEmpty);
      expect(tracks.first.label, isNotEmpty);
    });
    
    test('getSubtitles returns empty list for invalid ID format', () async {
      final tracks = await repository.getSubtitles('invalid_id');
      
      expect(tracks, isEmpty);
    });
  });
}
