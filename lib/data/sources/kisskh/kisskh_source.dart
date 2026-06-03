import '../../../domain/entities/movie.dart';
import '../../../domain/entities/movie_detail.dart';
import '../../../core/utils/kkey_extractor.dart';
import '../../../domain/entities/episode.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../domain/entities/subtitle.dart';
import '../../../domain/entities/filter.dart';
import '../../../domain/entities/home_section.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/repositories/movie_source.dart';
import 'kisskh_api.dart';

class KissKhSource implements MovieSource {
  final KissKhApi _api;
  final KkeyExtractor _kkeyExtractor = KkeyExtractor.getInstance();

  KissKhSource(this._api);

  @override
  String get sourceName => 'KissKH';

  @override
  String get sourceIcon => 'assets/images/kisskh_icon.png'; // placeholder

  @override
  Future<List<HomeSection>> getHomeSections() async {
    final trending = await _api.getDramaList(page: 1, type: 1, order: 1); // TV Series
    final popularMovie = await _api.getDramaList(page: 1, type: 2, order: 1); // Movie
    final recentlyUpdated = await _api.getDramaList(page: 1, type: 0, order: 2); // Last update
    
    return [
      HomeSection(
        title: 'Trending TV Series',
        movies: trending.map((e) => Movie(id: e.id.toString(), title: e.title, thumbnail: e.thumbnail, type: e.type, status: e.status)).toList(),
      ),
      HomeSection(
        title: 'Popular Movies',
        movies: popularMovie.map((e) => Movie(id: e.id.toString(), title: e.title, thumbnail: e.thumbnail, type: e.type, status: e.status)).toList(),
      ),
      HomeSection(
        title: 'Recently Updated',
        movies: recentlyUpdated.map((e) => Movie(id: e.id.toString(), title: e.title, thumbnail: e.thumbnail, type: e.type, status: e.status)).toList(),
      ),
    ];
  }

  @override
  Future<FilterConfig> getFilterConfig() async {
    return FilterConfig(fields: [
      const FilterField(
        key: 'type',
        title: 'Type',
        defaultValue: 0,
        options: [
          FilterOption(label: 'All', value: 0),
          FilterOption(label: 'TVSeries', value: 1),
          FilterOption(label: 'Movie', value: 2),
          FilterOption(label: 'Anime', value: 3),
          FilterOption(label: 'Hollywood', value: 4),
        ]
      ),
      const FilterField(
        key: 'sub',
        title: 'Subtitles',
        defaultValue: 0,
        options: [
          FilterOption(label: 'All Subtitles', value: 0),
          FilterOption(label: 'English', value: 1),
          // More subs can be added here
        ]
      ),
      const FilterField(
        key: 'country',
        title: 'Regions',
        defaultValue: 0,
        options: [
          FilterOption(label: 'All Regions', value: 0),
          FilterOption(label: 'Chinese', value: 1),
          FilterOption(label: 'South Korea', value: 2),
          FilterOption(label: 'Japanese', value: 3),
          FilterOption(label: 'Hong Kong', value: 4),
          FilterOption(label: 'Thailand', value: 5),
          FilterOption(label: 'United States', value: 6),
          FilterOption(label: 'Taiwan', value: 7),
          FilterOption(label: 'Philippine', value: 8),
        ]
      ),
      const FilterField(
        key: 'status',
        title: 'Status',
        defaultValue: 0,
        options: [
          FilterOption(label: 'All', value: 0),
          FilterOption(label: 'Ongoing', value: 1),
          FilterOption(label: 'Completed', value: 2),
          FilterOption(label: 'Upcoming', value: 3),
        ]
      ),
      const FilterField(
        key: 'order',
        title: 'Order',
        defaultValue: 2,
        options: [
          FilterOption(label: 'Popular', value: 1),
          FilterOption(label: 'Last Update', value: 2),
          FilterOption(label: 'Release Date', value: 3),
        ]
      ),
    ]);
  }

  @override
  Future<List<Movie>> searchMovies(String query) async {
    return advancedSearch({}, query: query);
  }

  @override
  Future<List<Movie>> advancedSearch(Map<String, dynamic> filters, {int page = 1, String query = ''}) async {
    final list = await _api.getDramaList(
      page: page,
      q: query,
      type: filters['type'] as int? ?? 0,
      sub: filters['sub'] as int? ?? 0,
      country: filters['country'] as int? ?? 0,
      status: filters['status'] as int? ?? 0,
      order: filters['order'] as int? ?? 2,
    );
    
    return list.map((e) => Movie(
      id: e.id.toString(),
      title: e.title,
      thumbnail: e.thumbnail,
      type: e.type,
      status: e.status,
    )).toList();
  }

  @override
  Future<MovieDetail?> getMovieDetail(String id) async {
    final detail = await _api.getDetail(int.parse(id));
    if (detail == null) return null;
    
    return MovieDetail(
      id: detail.id.toString(),
      title: detail.title,
      description: detail.description,
      thumbnail: detail.thumbnail,
      type: detail.type,
      episodes: detail.episodes.map((e) => Episode(
        id: e.id.toString(),
        number: e.number,
        hasSub: e.sub == 1,
      )).toList(),
    );
  }

  @override
  Future<StreamInfo?> getStreamInfo(String movieId, String episodeId, {String? serverId}) async {
    try {
      int parsedMovieId = int.parse(movieId);
      int parsedEpisodeId = int.parse(episodeId);

      // 1. Get Stream kkey natively via extractor
      final String? streamKkey = await _kkeyExtractor.extractStreamKey(parsedMovieId, parsedEpisodeId);
      if (streamKkey == null) return null;

      // 2. Fetch video url
      String? videoUrl = await _api.getStreamUrl(parsedEpisodeId, streamKkey);
      debugPrint('KissKH Stream URL: $videoUrl');
      if (videoUrl == null || videoUrl.isEmpty) return null;
      
      if (videoUrl.contains('tickcounter.com')) {
        throw Exception('Tập phim này chưa tới giờ công chiếu!');
      }

      if (videoUrl.startsWith('//')) {
        videoUrl = 'https:$videoUrl';
      }

      // 3. Get Subtitle kkey via extractor
      final String? subKkey = await _kkeyExtractor.extractSubKey(parsedMovieId, parsedEpisodeId);
      List<SubtitleTrack> tracks = [];
      if (subKkey != null) {
        final subs = await _api.getSubtitles(parsedEpisodeId, subKkey);
        for (int i = 0; i < subs.length; i++) {
          tracks.add(SubtitleTrack(
            id: i + 1,
            src: subs[i].src,
            label: subs[i].label,
            languageCode: subs[i].land,
          ));
        }
      }

      return StreamInfo(
        videoUrl: videoUrl,
        subtitles: tracks,
      );
    } catch (e) {
      debugPrint('KissKhSource getStreamInfo Error: $e');
      rethrow;
    }
  }
}
