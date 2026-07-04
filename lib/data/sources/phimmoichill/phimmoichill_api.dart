import 'dart:convert';
import 'dart:io';
import 'package:cine_stream/data/sources/phimmoichill/phimmoichill_crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'phimmoichill_models.dart';

class PhimMoiChillApi {
  final Dio _dio;
  String? _resolvedBaseUrl;
  String? _resolvedApiUrl;

  String get resolvedBaseUrl => _resolvedBaseUrl ?? 'https://phimmoi.date';

  PhimMoiChillApi(this._dio);

  Future<void> _ensureInitialized() async {
    if (_resolvedBaseUrl != null) return;
    try {
      final response = await _dio.get(
        'https://phimmoichill.live/',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      String targetUrl = '';
      final realUri = response.realUri;
      if (realUri.host != 'phimmoichill.live' && realUri.host.isNotEmpty) {
        targetUrl = '${realUri.scheme}://${realUri.host}';
      } else {
        final html = response.data.toString();
        final canonicalRegex = RegExp(r'<link[^>]*rel="canonical"[^>]*href="([^"]+)"');
        final canonicalMatch = canonicalRegex.firstMatch(html);
        if (canonicalMatch != null) {
          targetUrl = canonicalMatch.group(1) ?? '';
        }

        if (targetUrl.isEmpty) {
          final ogUrlRegex = RegExp(r'<meta[^>]*property="og:url"[^>]*content="([^"]+)"');
          final ogUrlMatch = ogUrlRegex.firstMatch(html);
          if (ogUrlMatch != null) {
            targetUrl = ogUrlMatch.group(1) ?? '';
          }
        }

        if (targetUrl.isEmpty) {
          final cdnRegex = RegExp(r'https://cdn\.([^/"]+)');
          final cdnMatch = cdnRegex.firstMatch(html);
          if (cdnMatch != null) {
            targetUrl = 'https://${cdnMatch.group(1)}';
          }
        }
      }

      if (targetUrl.isNotEmpty) {
        if (targetUrl.endsWith('/')) {
          targetUrl = targetUrl.substring(0, targetUrl.length - 1);
        }
        final uri = Uri.parse(targetUrl);
        final host = uri.host;
        _resolvedBaseUrl = 'https://$host';
        _resolvedApiUrl = 'https://cdn.$host/api/v1';
        debugPrint('PhimMoiChillApi: Resolved baseUrl=$_resolvedBaseUrl, apiUrl=$_resolvedApiUrl');
        return;
      }
    } catch (e) {
      debugPrint('PhimMoiChillApi _ensureInitialized Error: $e');
    }

    _resolvedBaseUrl = 'https://phimmoi.date';
    _resolvedApiUrl = 'https://cdn.phimmoi.date/api/v1';
  }

  Future<PhimMoiSearchResponse?> searchMovies({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      await _ensureInitialized();
      final res = await _dio.get(
        '$_resolvedApiUrl/search',
        queryParameters: {'keyword': keyword, 'page': page, 'limit': limit},
      );
      return PhimMoiSearchResponse.fromJson(res.data);
    } catch (e) {
      debugPrint('PhimMoiChillApi searchMovies Error: $e');
      return null;
    }
  }

  Future<PhimMoiSearchResponse?> filterMovies({
    String? genre,
    String? country,
    String? type,
    String? year,
    String? status,
    String? topic,
    String sort = 'updated_at',
    String order = 'desc',
    int page = 1,
    int limit = 21,
  }) async {
    try {
      await _ensureInitialized();
      final queryParams = <String, dynamic>{
        'sort': sort,
        'order': order,
        'page': page,
        'limit': limit,
      };
      if (genre != null && genre.isNotEmpty && genre != 'tat-ca') {
        queryParams['genre'] = genre;
      }
      if (country != null && country.isNotEmpty && country != 'tat-ca') {
        queryParams['country'] = country;
      }
      if (type != null && type.isNotEmpty && type != 'tat-ca') {
        queryParams['type'] = type;
      }
      if (year != null && year.isNotEmpty && year != 'tat-ca') {
        queryParams['year'] = year;
      }
      if (status != null && status.isNotEmpty && status != 'tat-ca') {
        queryParams['status'] = status;
      }
      if (topic != null && topic.isNotEmpty && topic != 'tat-ca') {
        queryParams['topic'] = topic;
      }

      final res = await _dio.get(
        '$_resolvedApiUrl/filter/movies',
        queryParameters: queryParams,
      );
      return PhimMoiSearchResponse.fromJson(res.data);
    } catch (e) {
      debugPrint('PhimMoiChillApi filterMovies Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMovieDetailHTML(String slug) async {
    try {
      await _ensureInitialized();
      final res = await _dio.get('$_resolvedBaseUrl/phim/$slug');
      final html = res.data.toString();

      String title = '';
      final titleRegex = RegExp(
        r'''<meta[^>]*property=["']og:title["'][^>]*content=["']([^"']+)["']''',
      );
      final titleMatch = titleRegex.firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1) ?? '';
      }

      String description = '';
      final descRegex = RegExp(
        r'''<meta[^>]*property=["']og:description["'][^>]*content=["']([^"']+)["']''',
      );
      final match = descRegex.firstMatch(html);
      if (match != null) {
        description = match.group(1) ?? '';
      }

      String thumbnail = '';
      final imgRegex = RegExp(
        r'''<meta[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']''',
      );
      final imgMatch = imgRegex.firstMatch(html);
      if (imgMatch != null) {
        thumbnail = imgMatch.group(1) ?? '';
      }

      // Parse episodes

      List<Map<String, String>> episodes = [];
      List<Map<String, dynamic>> servers = [];

      // Fetch Next.js watch page to get episodes & servers
      try {
        final watchRes = await _dio.get(
          '$_resolvedBaseUrl/xem-phim/$slug/tap-1/vietsub',
        );
        final watchHtml = watchRes.data.toString();

        final scriptRegex = RegExp(
          r'<script>self\.__next_f\.push\(\[1,"(.*)"\]\)</script>',
          dotAll: true,
        );
        final scriptMatches = scriptRegex.allMatches(watchHtml);

        String fullPayload = '';
        for (var m in scriptMatches) {
          String str = m.group(1)!;
          str = str.replaceAll(r'\"', '"');
          str = str.replaceAll(r'\\', r'\');
          fullPayload += str;
        }

        final epSourceRegex = RegExp(r'"episode_sources":(\[.*?\])');
        final sourceMatch = epSourceRegex.firstMatch(fullPayload);
        if (sourceMatch != null) {
          final sourcesList = jsonDecode(sourceMatch.group(1)!) as List;
          for (var src in sourcesList) {
            servers.add(src);
          }
        }

        final epListRegex = RegExp(r'"episodes":(\[.*?\])');
        final listMatch = epListRegex.firstMatch(fullPayload);
        if (listMatch != null) {
          final epsList = jsonDecode(listMatch.group(1)!) as List;
          for (var ep in epsList) {
            episodes.add({
              'title': ep['name'].toString(),
              'slug': ep['slug'].toString(),
              'episode_type': ep['episode_type']?.toString() ?? '',
            });
          }
        }
      } catch (e) {
        debugPrint('PhimMoiChillApi Next.js parse error: $e');
      }

      // Nếu không parse được từ Next.js JSON thì fallback cào HTML cũ
      if (episodes.isEmpty) {
        final epRegex = RegExp(
          r'''<a[^>]*title=["']([^"']+)["'][^>]*href=["'](/xem-phim/[^"']+)["']|<a[^>]*href=["'](/xem-phim/[^"']+)["'][^>]*title=["']([^"']+)["']''',
        );
        final matches = epRegex.allMatches(html);
        Set<String> seenUrls = {};
        for (final m in matches) {
          String title = m.group(1) ?? m.group(4) ?? '';
          String href = m.group(2) ?? m.group(3) ?? '';
          if (href.isNotEmpty) {
            href = href.split('?').first;
            if (href.endsWith('/vietsub')) href = href.substring(0, href.length - 8);
            if (href.endsWith('/thuyet-minh')) href = href.substring(0, href.length - 12);
            
            if (!seenUrls.contains(href)) {
              seenUrls.add(href);
              if (title.contains('-')) {
              title = title.split('-').first.trim();
            }
            if (title.isEmpty) {
              final uri = Uri.tryParse(href);
              if (uri != null && uri.pathSegments.length >= 3) {
                title = uri.pathSegments[2].replaceAll('-', ' ').toUpperCase();
              }
            }
              episodes.add({'title': title, 'url': href});
            }
          }
        }
      }

      return {
        'title': title,
        'description': description,
        'thumbnail': thumbnail,
        'episodes': episodes,
        'servers': servers,
      };
    } catch (e) {
      debugPrint('PhimMoiChillApi getMovieDetailHTML Error: $e');
      return null;
    }
  }

  Future<String?> getStreamUrl(String episodePath) async {
    try {
      await _ensureInitialized();

      // Đảm bảo episodePath luôn chứa hậu tố ngôn ngữ để tránh lỗi 404 trên domain mới
      String path = episodePath;
      if (!path.contains('/vietsub') &&
          !path.contains('/thuyet-minh') &&
          !path.contains('/song-ngu')) {
        final uri = Uri.parse(path);
        var newPath = uri.path;
        if (!newPath.endsWith('/vietsub') &&
            !newPath.endsWith('/thuyet-minh') &&
            !newPath.endsWith('/song-ngu')) {
          newPath = '$newPath/vietsub';
        }
        path = uri.hasQuery ? '$newPath?${uri.query}' : newPath;
      }

      debugPrint('PhimMoiChillApi getStreamUrl: episodePath=$path');
      final res = await _dio.get('$_resolvedBaseUrl$path');
      final html = res.data.toString();

      String? serverSlug;
      if (path.contains('?server=')) {
        serverSlug = path.split('?server=').last;
      }

      String? matchedEmbedUrl;
      try {
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
        final epSourceRegex = RegExp(r'"episode_sources":(\[.*?\])');
        final sourceMatch = epSourceRegex.firstMatch(fullPayload);
        if (sourceMatch != null) {
          final sourcesList = jsonDecode(sourceMatch.group(1)!) as List;
          if (serverSlug != null) {
            for (var src in sourcesList) {
              if (src['server'] != null && src['server']['slug'] == serverSlug) {
                matchedEmbedUrl = src['link']?.toString();
                break;
              }
            }
          }
          // Fallback to first if not found
          if (matchedEmbedUrl == null && sourcesList.isNotEmpty) {
            matchedEmbedUrl = sourcesList[0]['link']?.toString();
          }
        }
      } catch (e) {
        debugPrint('NextJS JSON extraction error in getStreamUrl: $e');
      }

      if (matchedEmbedUrl != null && matchedEmbedUrl.isNotEmpty) {
        String embedUrl = matchedEmbedUrl;
        final realUrl = embedUrl.startsWith('//')
            ? 'https:$embedUrl'
            : embedUrl;
        debugPrint('PhimMoiChillApi getStreamUrl (JSON): realUrl=$realUrl');
        return realUrl;
      }

      final m3u8Regex = RegExp(r'link_m3u8[\\":]+(https?[^"\\]+m3u8)');
      final match = m3u8Regex.firstMatch(html);
      if (match != null) {
        return match.group(1)!.replaceAll(r'\/', '/');
      }

      if (matchedEmbedUrl == null) {
        final embedUrlRegex = RegExp(r'https?[^"\\]+embed[^"\\]+');
        final embedUrlMatch = embedUrlRegex.firstMatch(html);
        if (embedUrlMatch != null) {
          matchedEmbedUrl = embedUrlMatch.group(0)!.replaceAll(r'\/', '/');
        }
      }

      if (matchedEmbedUrl != null) {
        String embedUrl = matchedEmbedUrl;
        final realUrl = embedUrl.startsWith('//')
            ? 'https:$embedUrl'
            : embedUrl;
        debugPrint('PhimMoiChillApi getStreamUrl: realUrl=$realUrl');

        final embedRes = await _dio.get(
          realUrl,
          options: Options(headers: {'Referer': '$_resolvedBaseUrl/'}),
        );
        final embedHtml = embedRes.data.toString();
        final vDataRegex = RegExp(r'window\.__V_DATA__\s*=\s*"([^"]+)"');
        final keyRegex = RegExp(r'window\.__TRANSPORT_KEY_HEX\s*=\s*"([^"]+)"');

        final vDataMatch = vDataRegex.firstMatch(embedHtml);
        final keyMatch = keyRegex.firstMatch(embedHtml);

        debugPrint(
          'PhimMoiChillApi getStreamUrl: vDataMatch=${vDataMatch != null}',
        );

        if (vDataMatch != null) {
          final vData = vDataMatch.group(1)!;
          final keyHex =
              keyMatch?.group(1) ?? 'c2ef86fd3ed02231d8f62ad32b0a1386';

          var base64Data = vData.replaceAll('-', '+').replaceAll('_', '/');
          switch (base64Data.length % 4) {
            case 2:
              base64Data += '==';
              break;
            case 3:
              base64Data += '=';
              break;
          }
          final jsonStr = utf8.decode(base64Decode(base64Data));
          final jsonMap = jsonDecode(jsonStr);

          debugPrint('PhimMoiChillApi getStreamUrl: jsonMap=$jsonMap');

          if (jsonMap['m'] != null) {
            final mDecoded = utf8.decode(base64Decode(jsonMap['m']));
            debugPrint('PhimMoiChillApi getStreamUrl: mDecoded=$mDecoded');

            if (mDecoded.endsWith('.m3u8') && mDecoded.startsWith('http')) {
              return mDecoded;
            } else if (mDecoded.startsWith('/api/v1/media-proxy')) {
              final cdnHost = 'cdn.${Uri.parse(_resolvedBaseUrl!).host}';
              final proxyUrl = 'https://$cdnHost$mDecoded';
              debugPrint(
                'PhimMoiChillApi getStreamUrl: fetching proxy data from $proxyUrl',
              );
              final proxyRes = await _dio.get<List<int>>(
                proxyUrl,
                options: Options(
                  responseType: ResponseType.bytes,
                  headers: {
                    'Referer': realUrl,
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  },
                ),
              );
              final bytes = Uint8List.fromList(proxyRes.data!);
              final decryptedBytes = PhimmoichillCrypto.decrypt(bytes, keyHex);

              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/temp_stream.m3u8');
              await file.writeAsBytes(decryptedBytes);
              debugPrint(
                'PhimMoiChillApi getStreamUrl: Decrypted proxy data saved to ${file.path}',
              );
              return file.path;
            }
          }
        }
      }
      return null;
    } catch (e, stacktrace) {
      debugPrint('PhimMoiChillApi getStreamUrl Error: $e\n$stacktrace');
      return null;
    }
  }
}
