import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/stream_info.dart';
import '../../di/injection.dart';

class StreamInfoCache {
  static const String _prefix = 'stream_info_cache_';

  static String _generateKey(String movieId, String episodeId, String? serverId) {
    return '$_prefix${movieId}_${episodeId}_${serverId ?? "default"}';
  }

  static Future<void> saveStreamInfo(String movieId, String episodeId, String? serverId, StreamInfo info) async {
    try {
      final prefs = getIt<SharedPreferences>();
      final key = _generateKey(movieId, episodeId, serverId);
      final jsonString = jsonEncode(info.toJson());
      await prefs.setString(key, jsonString);
      debugPrint('StreamInfoCache: Saved cache for $key');
    } catch (e) {
      debugPrint('StreamInfoCache Error saving cache: $e');
    }
  }

  static StreamInfo? getStreamInfo(String movieId, String episodeId, String? serverId) {
    // Tạm bỏ cơ chế lưu cache m3u8
    return null;
  }

  static Future<void> clearCache(String movieId, String episodeId, String? serverId) async {
    try {
      final prefs = getIt<SharedPreferences>();
      final key = _generateKey(movieId, episodeId, serverId);
      await prefs.remove(key);
      debugPrint('StreamInfoCache: Cleared cache for $key');
    } catch (e) {
      debugPrint('StreamInfoCache Error clearing cache: $e');
    }
  }
}
