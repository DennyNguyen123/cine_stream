import 'package:dio/dio.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/entities/movie_detail.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../domain/entities/home_section.dart';
import '../../../domain/entities/filter.dart';
import '../../../domain/repositories/movie_source.dart';
import '../../../domain/entities/episode.dart';
import 'extractors/vidnest_extractor.dart';
import 'extractors/vidplay_extractor.dart';
import 'extractors/vdrk_subtitle_extractor.dart';
import 'extractors/vidsrcme_extractor.dart';
import '../../../domain/entities/subtitle.dart';

class CinemetaSource implements MovieSource {
  final Dio _dio;
  final String _baseUrl = 'https://v3-cinemeta.strem.io';

  CinemetaSource(this._dio);

  @override
  String get sourceName => 'Cinemeta';

  @override
  String get sourceIcon => 'https://www.stremio.com/website/stremio-logo-small.png';

  @override
  Future<List<HomeSection>> getHomeSections() async {
    final sections = <HomeSection>[];
    try {
      final movieRes = await _dio.get('$_baseUrl/catalog/movie/top.json');
      if (movieRes.data['metas'] != null) {
        final movies = (movieRes.data['metas'] as List).map((m) => _parseMovie(m, isTv: false)).toList();
        sections.add(HomeSection(title: 'Top Movies', movies: movies));
      }

      final seriesRes = await _dio.get('$_baseUrl/catalog/series/top.json');
      if (seriesRes.data['metas'] != null) {
        final series = (seriesRes.data['metas'] as List).map((m) => _parseMovie(m, isTv: true)).toList();
        sections.add(HomeSection(title: 'Top Series', movies: series));
      }
    } catch (e) {
      print('Cinemeta getHomeSections Error: $e');
    }
    return sections;
  }

  @override
  Future<List<Movie>> searchMovies(String query) async {
    final results = <Movie>[];
    try {
      final encodedQuery = Uri.encodeComponent(query);
      
      final movieRes = await _dio.get('$_baseUrl/catalog/movie/top/search=$encodedQuery.json');
      if (movieRes.data['metas'] != null) {
        results.addAll((movieRes.data['metas'] as List).map((m) => _parseMovie(m, isTv: false)));
      }

      final seriesRes = await _dio.get('$_baseUrl/catalog/series/top/search=$encodedQuery.json');
      if (seriesRes.data['metas'] != null) {
        results.addAll((seriesRes.data['metas'] as List).map((m) => _parseMovie(m, isTv: true)));
      }
    } catch (e) {
      print('Cinemeta searchMovies Error: $e');
    }
    return results;
  }

  @override
  Future<List<Movie>> advancedSearch(Map<String, dynamic> filters, {int page = 1, String query = ''}) async {
    if (query.isNotEmpty) {
      return searchMovies(query);
    }
    
    // When query is empty, return popular/top movies like KissKH does
    final results = <Movie>[];
    try {
      final type = filters['type'] ?? 'movie';
      final genre = filters['genre'] ?? '';
      
      final skip = (page - 1) * 20; // Assuming 20 items per page
      
      List<String> extraParams = [];
      if (genre.isNotEmpty) extraParams.add('genre=$genre');
      if (skip > 0) extraParams.add('skip=$skip');
      
      final paramsString = extraParams.isNotEmpty ? '/${extraParams.join('&')}' : '';
      
      final url = '$_baseUrl/catalog/$type/top$paramsString.json';
          
      final res = await _dio.get(url);
      if (res.data['metas'] != null) {
        results.addAll((res.data['metas'] as List).map((m) => _parseMovie(m, isTv: type == 'series')));
      }
    } catch (e) {
      print('Cinemeta advancedSearch empty Error: $e');
    }
    return results;
  }

  @override
  Future<FilterConfig> getFilterConfig() async {
    return FilterConfig(
      fields: [
        FilterField(
          key: 'type',
          title: 'Type',
          defaultValue: 'movie',
          options: [
            FilterOption(value: 'movie', label: 'Movie'),
            FilterOption(value: 'series', label: 'Series'),
          ],
        ),
        FilterField(
          key: 'genre',
          title: 'Genre',
          defaultValue: '',
          options: [
            FilterOption(value: '', label: 'All Genres'),
            FilterOption(value: 'Action', label: 'Action'),
            FilterOption(value: 'Adventure', label: 'Adventure'),
            FilterOption(value: 'Animation', label: 'Animation'),
            FilterOption(value: 'Comedy', label: 'Comedy'),
            FilterOption(value: 'Crime', label: 'Crime'),
            FilterOption(value: 'Documentary', label: 'Documentary'),
            FilterOption(value: 'Drama', label: 'Drama'),
            FilterOption(value: 'Family', label: 'Family'),
            FilterOption(value: 'Fantasy', label: 'Fantasy'),
            FilterOption(value: 'History', label: 'History'),
            FilterOption(value: 'Horror', label: 'Horror'),
            FilterOption(value: 'Music', label: 'Music'),
            FilterOption(value: 'Mystery', label: 'Mystery'),
            FilterOption(value: 'Romance', label: 'Romance'),
            FilterOption(value: 'Science Fiction', label: 'Sci-Fi'),
            FilterOption(value: 'Thriller', label: 'Thriller'),
            FilterOption(value: 'War', label: 'War'),
            FilterOption(value: 'Western', label: 'Western'),
          ],
        )
      ],
    );
  }

  @override
  Future<MovieDetail?> getMovieDetail(String movieId) async {
    try {
      final parts = movieId.split('/');
      if (parts.length != 2) return null;
      final type = parts[0];
      final imdbId = parts[1];

      final res = await _dio.get('$_baseUrl/meta/$type/$imdbId.json');
      final meta = res.data['meta'];
      if (meta == null) return null;

      final isTv = type == 'series';
      final episodes = <Episode>[];

      if (isTv && meta['videos'] != null) {
        for (var v in meta['videos']) {
          final season = v['season'];
          final episode = v['episode'];
          episodes.add(Episode(
            id: 'tv/$imdbId/$season/$episode',
            number: double.parse(episode.toString()),
            season: int.parse(season.toString()),
            title: v['title'] ?? 'S${season}E$episode',
          ));
        }
      } else if (!isTv) {
        // Add a single episode for movies so the play button works
        episodes.add(Episode(
          id: 'movie/$imdbId',
          number: 1,
          title: meta['name'] ?? 'Movie',
        ));
      }

      episodes.sort((a, b) {
        int seasonCompare = (a.season ?? 1).compareTo(b.season ?? 1);
        if (seasonCompare != 0) return seasonCompare;
        return a.number.compareTo(b.number);
      });

      return MovieDetail(
        id: movieId,
        title: meta['name'] ?? '',
        description: meta['description'] ?? '',
        thumbnail: meta['poster'] ?? meta['background'] ?? '',
        type: isTv ? 'series' : 'movie',
        episodes: episodes,
        servers: [
          VideoServer(id: 'vnest', name: 'Vidnest'),
          VideoServer(id: 'vpls', name: 'Vidplay'),
          VideoServer(id: 'vidsrcme', name: 'Vidsrcme')
        ],
      );
    } catch (e) {
      print('Cinemeta getMovieDetail Error: $e');
      return null;
    }
  }

  static String? extractTmdbId(String html) {
    var regex = RegExp(r'https://sub\.vdrk\.site/(?:v2/)?(?:movie|tv)/([^/"]+)');
    var match = regex.firstMatch(html);
    if (match != null) return match.group(1);
    
    // Fallback: extract from iframe params
    regex = RegExp(r'tmdb=(\d+)');
    match = regex.firstMatch(html);
    return match?.group(1);
  }

  @override
  Future<StreamInfo?> getStreamInfo(String movieId, String episodeId, {String? serverId}) async {
    try {
      final parts = movieId.split('/');
      final type = parts[0];
      final imdbId = parts[1];

      // Step 1: Get the embed page URL
      final isTv = type == 'series';
      final embedUrl = isTv
          ? 'https://vidapi.xyz/embed/tv/$imdbId/${episodeId.split('/')[2]}/${episodeId.split('/')[3]}'
          : 'https://vidapi.xyz/embed/movie/$imdbId';

      // Step 2: Fetch embed page and extract all servers
      String? tmdbId;
      List<VideoServer> servers = [];
      String? targetServerUrl;

      try {
        final response = await _dio.get(embedUrl);
        final html = response.data.toString();
        
        tmdbId = extractTmdbId(html);

        final iframeSrcRegex = RegExp(r'data-src="(https?://[^"]+)"');
        final matches = iframeSrcRegex.allMatches(html).toList();
        
        final preferredDomains = ['vnest', 'vpls'];
        
        for (final match in matches) {
          final src = match.group(1)!.replaceAll('&amp;', '&');
          String serverName = 'Unknown';
          
          if (src.contains('vnest')) {
            serverName = 'Vidnest';
          } else if (src.contains('vpls')) serverName = 'Vidplay';
          else continue; // Bỏ qua các server không thuộc Vidnest hoặc Vidplay
          
          // Only add if not already in list to avoid duplicates
          if (!servers.any((s) => s.name == serverName || s.id == src)) {
            servers.add(VideoServer(id: src, name: serverName));
          }
        }
        
        servers.add(VideoServer(id: 'vidsrcme', name: 'Vidsrcme'));

        // Determine target server URL
        if (serverId != null && serverId.isNotEmpty) {
          if (serverId == 'vidsrcme') {
            targetServerUrl = 'vidsrcme';
          } else {
            final found = servers.where((s) => s.id.contains(serverId)).toList();
            if (found.isNotEmpty) {
              targetServerUrl = found.first.id;
            }
          }
        } 
        
        if (targetServerUrl == null) {
          // Select preferred
          for (final domain in preferredDomains) {
            final found = servers.where((s) => s.id.contains(domain)).toList();
            if (found.isNotEmpty) {
              targetServerUrl = found.first.id;
              break;
            }
          }
          if (targetServerUrl == null && servers.isNotEmpty) {
            targetServerUrl = servers.first.id;
          }
        }
      } catch (e) {
        print('[Cinemeta] Error extracting iframe: $e');
      }

      targetServerUrl ??= embedUrl;
      print('[Cinemeta] Selected Server URL: $targetServerUrl');

      // Step 3: Run headless extractor to get the raw .m3u8 link
      int? s;
      int? e;
      if (isTv) {
        s = int.tryParse(episodeId.split('/')[2]);
        e = int.tryParse(episodeId.split('/')[3]);
      }

      // Fetch subtitles first
      final subtitles = tmdbId != null 
          ? await VdrkSubtitleExtractor.fetchSubtitles(tmdbId, isTv: isTv, s: s, e: e) 
          : <SubtitleTrack>[];

      StreamInfo? streamInfo;
      
      if (targetServerUrl == 'vidsrcme') {
        String vidsrcUrl;
        if (isTv) {
          vidsrcUrl = 'https://vidsrcme.ru/embed/tv?imdb=$imdbId&season=${episodeId.split('/')[2]}&episode=${episodeId.split('/')[3]}&autoplay=1';
        } else {
          vidsrcUrl = 'https://vidsrcme.ru/embed/movie?imdb=$imdbId&autoplay=1';
        }
        streamInfo = await VidsrcmeExtractor.extractStream(vidsrcUrl, subtitles);
      } else if (targetServerUrl.contains('vnest')) {
        streamInfo = await VidnestExtractor.extractStream(targetServerUrl, subtitles);
      } else if (targetServerUrl.contains('vpls')) {
        streamInfo = await VidplayExtractor.extractStream(targetServerUrl, subtitles);
      }

      String? resolvedServerId = serverId;
      if (resolvedServerId == null || resolvedServerId.isEmpty) {
        if (targetServerUrl.contains('vnest')) {
          resolvedServerId = 'vnest';
        } else if (targetServerUrl.contains('vpls')) {
          resolvedServerId = 'vpls';
        } else if (targetServerUrl == 'vidsrcme') {
          resolvedServerId = 'vidsrcme';
        }
      }

      if (streamInfo != null) {
        return StreamInfo(
          videoUrl: streamInfo.videoUrl,
          subtitles: streamInfo.subtitles,
          servers: servers,
          currentServerId: resolvedServerId,
          headers: streamInfo.headers,
        );
      }

      return null;
    } catch (e) {
      print('Cinemeta getStreamInfo Error: $e');
      return null;
    }
  }

  Movie _parseMovie(Map<String, dynamic> data, {required bool isTv}) {
    final type = isTv ? 'series' : 'movie';
    String? yearStr;
    final releaseInfo = data['releaseInfo']?.toString() ?? data['year']?.toString();
    if (releaseInfo != null) {
      if (releaseInfo.length >= 4) {
        yearStr = releaseInfo.substring(0, 4);
      } else {
        yearStr = releaseInfo;
      }
    }
    return Movie(
      id: '$type/${data['id']}',
      title: data['name'] ?? '',
      thumbnail: data['poster'] ?? '',
      type: type,
      year: yearStr,
    );
  }
}
