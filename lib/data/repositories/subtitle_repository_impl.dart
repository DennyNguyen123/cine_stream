import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../domain/repositories/subtitle_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class SubtitleRepositoryImpl implements SubtitleRepository {
  final Dio _dio;

  SubtitleRepositoryImpl(this._dio);

  @override
  Future<String?> getSubtitleContent(String url) async {
    try {
      if (url.startsWith('//')) {
        url = 'https:$url';
      }

      final cacheKey = _md5(url);
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/sub_$cacheKey.sub');

      if (await cacheFile.exists()) {
        return await cacheFile.readAsString();
      }

      final headers = <String, dynamic>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
      };

      if (url.contains('kisskh')) {
        headers['Referer'] = 'https://kisskh.co/';
      }

      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
        )
      );
      
      final content = response.data?.toString();
      if (content != null && content.isNotEmpty) {
        await cacheFile.writeAsString(content);
        return content;
      }
      return null;
    } catch (e) {
      debugPrint('SubtitleRepositoryImpl getSubtitleContent Error: $e');
      return null;
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final files = cacheDir.listSync();
      for (var file in files) {
        if (file is File && file.path.contains('/sub_')) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('SubtitleRepositoryImpl clearCache Error: $e');
    }
  }

  String _md5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }
}
