import 'package:cine_stream/data/sources/cinemeta/cinemeta_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CinemetaSource', () {
    late CinemetaSource source;
    late Dio dio;

    setUp(() {
      dio = Dio();
      source = CinemetaSource(dio);
    });

    test('getHomeSections returns Top Movies and Top Series', () async {
      final sections = await source.getHomeSections();
      expect(sections, isNotEmpty);
      expect(sections.any((s) => s.title == 'Top Movies'), isTrue);
      expect(sections.any((s) => s.title == 'Top Series'), isTrue);
    });

    test('searchMovies returns results for Inception', () async {
      final movies = await source.searchMovies('Inception');
      expect(movies, isNotEmpty);
      expect(movies.first.title.toLowerCase(), contains('inception'));
    });

    test(
      'getMovieDetail returns details and episodes for Game of Thrones',
      () async {
        final detail = await source.getMovieDetail('series/tt0944947');
        expect(detail, isNotNull);
        expect(detail!.title, 'Game of Thrones');
        expect(detail.type, 'series');
        expect(detail.episodes, isNotEmpty);
        expect(detail.episodes.first.id, contains('tv/tt0944947'));
      },
    );
  });
}
