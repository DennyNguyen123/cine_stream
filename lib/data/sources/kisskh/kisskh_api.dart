import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'kisskh_models.dart';

class KissKhApi {
  final Dio _dio;
  final String baseUrl = 'https://kisskh.co';

  KissKhApi(this._dio);

  Future<List<KissKhMovieJson>> getDramaList({
    int page = 1,
    int type = 0,
    int sub = 0,
    int country = 0,
    int status = 0,
    int order = 2,
    String q = '',
  }) async {
    String url = '$baseUrl/api/DramaList/List?page=$page&type=$type&sub=$sub&country=$country&status=$status&order=$order';
    if (q.isNotEmpty) {
      url = '$baseUrl/api/DramaList/Search?q=$q&type=$type';
    }
    
    final response = await _dio.get(url);
    final data = (q.isNotEmpty ? response.data : response.data['data']) as List;
    return data.map((e) => KissKhMovieJson.fromJson(e)).toList();
  }

  Future<List<KissKhMovieJson>> search(String query) async {
    final response = await _dio.get('$baseUrl/api/DramaList/Search?q=$query&type=0');
    final data = response.data as List;
    return data.map((e) => KissKhMovieJson.fromJson(e)).toList();
  }

  Future<KissKhMovieDetailJson?> getDetail(int id) async {
    final response = await _dio.get('$baseUrl/api/DramaList/Drama/$id?v=1');
    if (response.data == null) return null;
    return KissKhMovieDetailJson.fromJson(response.data);
  }

  Future<String?> getStreamUrl(int episodeId, String streamKey) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/DramaList/Episode/$episodeId.png?err=false&ts=null&time=null&kkey=$streamKey',
        options: Options(
          headers: {
            'Referer': '$baseUrl/',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          responseType: ResponseType.plain,
        ),
      );
      
      final body = response.data.toString().trim();
      String decodedJson = '';
      
      if (body.startsWith('{')) {
        decodedJson = body;
      } else {
        String base64Data = body;
        if (body.startsWith('data:image/png;base64,')) {
          base64Data = body.replaceFirst('data:image/png;base64,', '');
        }
        final bytes = base64Decode(base64Data);
        decodedJson = utf8.decode(bytes);
      }
      
      final Map<String, dynamic> json = jsonDecode(decodedJson);
      return json['Video'] as String? ?? json['video'] as String?;
    } catch (e) {
      debugPrint('KissKhApi getStreamUrl Error: $e');
      return null;
    }
  }

  Future<List<KissKhSubtitleJson>> getSubtitles(int episodeId, String subKey) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/Sub/$episodeId?kkey=$subKey',
        options: Options(
          headers: {
            'Referer': '$baseUrl/',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          }
        ),
      );
      
      if (response.data is List) {
        final data = response.data as List;
        return data.map((e) => KissKhSubtitleJson.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('KissKhApi getSubtitles Error: $e');
      return [];
    }
  }
}
