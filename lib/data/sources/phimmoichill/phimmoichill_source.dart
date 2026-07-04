import '../../../domain/entities/movie.dart';
import '../../../domain/entities/movie_detail.dart';
import '../../../domain/entities/episode.dart';
import '../../../domain/entities/stream_info.dart';
import '../../../domain/entities/filter.dart';
import '../../../domain/entities/home_section.dart';
import '../../../domain/repositories/movie_source.dart';
import 'package:flutter/foundation.dart';
import 'phimmoichill_api.dart';

class PhimMoiChillSource implements MovieSource {
  final PhimMoiChillApi _api;

  PhimMoiChillSource(this._api);

  @override
  String get sourceName => 'PhimMoiChill';

  @override
  String get sourceIcon => 'assets/images/phimmoichill_icon.png'; // placeholder

  @override
  Future<List<HomeSection>> getHomeSections() async {
    final updated = await _api.filterMovies(sort: 'updated_at', limit: 12);
    final trending = await _api.filterMovies(sort: 'views', limit: 12);
    final favorites = await _api.filterMovies(sort: 'created_at', limit: 12);

    return [
      HomeSection(
        title: 'Mới cập nhật',
        movies:
            updated?.items
                .map(
                  (e) => Movie(
                    id: e.slug,
                    title: e.name,
                    thumbnail: e.thumbUrl,
                    type: e.displayStatus,
                    status: e.status,
                  ),
                )
                .toList() ??
            [],
      ),
      HomeSection(
        title: 'Thịnh hành',
        movies:
            trending?.items
                .map(
                  (e) => Movie(
                    id: e.slug,
                    title: e.name,
                    thumbnail: e.thumbUrl,
                    type: e.displayStatus,
                    status: e.status,
                  ),
                )
                .toList() ??
            [],
      ),
      HomeSection(
        title: 'Mới đăng',
        movies:
            favorites?.items
                .map(
                  (e) => Movie(
                    id: e.slug,
                    title: e.name,
                    thumbnail: e.thumbUrl,
                    type: e.displayStatus,
                    status: e.status,
                  ),
                )
                .toList() ??
            [],
      ),
    ];
  }

  @override
  Future<FilterConfig> getFilterConfig() async {
    return FilterConfig(
      fields: [
        const FilterField(
          key: 'genre',
          title: 'Thể loại',
          defaultValue: '',
          options: [
            FilterOption(label: 'Tất cả', value: ''),
            FilterOption(label: 'Hành Động', value: 'hanh-dong'),
            FilterOption(label: 'Tình Cảm', value: 'tinh-cam'),
            FilterOption(label: 'Hài Hước', value: 'hai-huoc'),
            FilterOption(label: 'Cổ Trang', value: 'co-trang'),
            FilterOption(label: 'Kinh Dị', value: 'kinh-di'),
            FilterOption(label: 'Tâm Lý', value: 'tam-ly'),
            FilterOption(label: 'Viễn Tưởng', value: 'vien-tuong'),
            FilterOption(label: 'Hoạt Hình', value: 'hoat-hinh'),
          ],
        ),
        const FilterField(
          key: 'country',
          title: 'Quốc gia',
          defaultValue: '',
          options: [
            FilterOption(label: 'Tất cả', value: ''),
            FilterOption(label: 'Hàn Quốc', value: 'han-quoc'),
            FilterOption(label: 'Trung Quốc', value: 'trung-quoc'),
            FilterOption(label: 'Âu Mỹ', value: 'au-my'),
            FilterOption(label: 'Việt Nam', value: 'viet-nam'),
            FilterOption(label: 'Nhật Bản', value: 'nhat-ban'),
            FilterOption(label: 'Thái Lan', value: 'thai-lan'),
          ],
        ),
        const FilterField(
          key: 'type',
          title: 'Loại phim',
          defaultValue: '',
          options: [
            FilterOption(label: 'Tất cả', value: ''),
            FilterOption(label: 'Phim Lẻ', value: 'phim-le'),
            FilterOption(label: 'Phim Bộ', value: 'phim-bo'),
            FilterOption(label: 'Hoạt Hình', value: 'hoat-hinh'),
          ],
        ),
        const FilterField(
          key: 'sort',
          title: 'Sắp xếp',
          defaultValue: 'updated_at',
          options: [
            FilterOption(label: 'Mới cập nhật', value: 'updated_at'),
            FilterOption(label: 'Thời gian đăng', value: 'created_at'),
            FilterOption(label: 'Năm sản xuất', value: 'year'),
            FilterOption(label: 'Lượt xem', value: 'views'),
          ],
        ),
      ],
    );
  }

  @override
  Future<List<Movie>> searchMovies(String query) async {
    final result = await _api.searchMovies(keyword: query);
    return result?.items
            .map(
              (e) => Movie(
                id: e.slug,
                title: e.name,
                thumbnail: e.thumbUrl,
                type: e.displayStatus,
                status: e.status,
              ),
            )
            .toList() ??
        [];
  }

  @override
  Future<List<Movie>> advancedSearch(
    Map<String, dynamic> filters, {
    int page = 1,
    String query = '',
  }) async {
    if (query.isNotEmpty) {
      final res = await _api.searchMovies(keyword: query, page: page);
      return res?.items
              .map(
                (e) => Movie(
                  id: e.slug,
                  title: e.name,
                  thumbnail: e.thumbUrl,
                  type: e.displayStatus,
                  status: e.status,
                ),
              )
              .toList() ??
          [];
    }

    final res = await _api.filterMovies(
      genre: filters['genre']?.toString(),
      country: filters['country']?.toString(),
      type: filters['type']?.toString(),
      sort: filters['sort']?.toString() ?? 'updated_at',
      page: page,
    );

    return res?.items
            .map(
              (e) => Movie(
                id: e.slug,
                title: e.name,
                thumbnail: e.thumbUrl,
                type: e.displayStatus,
                status: e.status,
              ),
            )
            .toList() ??
        [];
  }

  @override
  Future<MovieDetail?> getMovieDetail(String id) async {
    final data = await _api.getMovieDetailHTML(id);
    if (data == null) return null;

    List<dynamic> rawEpisodes = data['episodes'] ?? [];
    List<Episode> episodes = [];

    for (int i = 0; i < rawEpisodes.length; i++) {
      String epUrl =
          rawEpisodes[i]['url'] ?? '/xem-phim/$id/${rawEpisodes[i]['slug']}';
      episodes.add(
        Episode(
          id: epUrl,
          number: (i + 1).toDouble(),
          hasSub: false,
          title: rawEpisodes[i]['title'],
        ),
      );
    }

    List<dynamic> rawServers = data['servers'] ?? [];
    List<VideoServer> servers = [];
    for (var s in rawServers) {
      if (s['server'] != null && s['language'] != null) {
        String serverName = '${s['language']['name']} (${s['server']['name']})';
        String serverId = '${s['server']['slug']}|${s['language']['slug']}';
        servers.add(VideoServer(id: serverId, name: serverName));
      }
    }

    String rawTitle = data['title']?.toString() ?? '';
    if (rawTitle.isEmpty) {
      rawTitle = id.replaceAll('-', ' ').toUpperCase();
    }
    String rawDesc = data['description']?.toString() ?? '';

    // Unescape HTML entities simple workaround
    rawDesc = rawDesc
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    rawTitle = rawTitle
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    return MovieDetail(
      id: id,
      title: rawTitle,
      description: rawDesc,
      thumbnail: data['thumbnail'] ?? 'https://phimmoi.cc/favicon.ico',
      type: '',
      episodes: episodes,
      servers: servers,
    );
  }

  @override
  Future<StreamInfo?> getStreamInfo(
    String movieId,
    String episodeId, {
    String? serverId,
  }) async {
    try {
      String finalUrl = episodeId;
      if (serverId != null && serverId.contains('|')) {
        final parts = serverId.split('|');
        final serverSlug = parts[0];
        final langSlug = parts[1];

        finalUrl = '$episodeId/$langSlug?server=$serverSlug';
      }

      final m3u8Url = await _api.getStreamUrl(finalUrl);
      if (m3u8Url == null || m3u8Url.isEmpty) return null;

      final domain = Uri.parse(_api.resolvedBaseUrl).host;
      return StreamInfo(
        videoUrl: m3u8Url,
        subtitles: const [],
        headers: {
          'Referer': 'https://$domain/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );
    } catch (e) {
      debugPrint('PhimMoiChillSource getStreamInfo Error: $e');
      rethrow;
    }
  }
}
