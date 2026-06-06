import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/history_item.dart';

import '../services/webdav_service.dart';

abstract class HistoryRepository {
  Future<List<HistoryItem>> getHistory();
  Future<void> saveHistory(HistoryItem item);
  Future<void> removeHistory(String movieId, String sourceId);
  Future<void> clearHistory();
  Future<HistoryItem?> getHistoryForMovie(String movieId, String sourceId);
  Future<void> syncWithWebDAV();
}

class HistoryRepositoryImpl implements HistoryRepository {
  static const String _historyKey = 'watch_history';
  final SharedPreferences _prefs;
  final WebDAVService _webdav;

  HistoryRepositoryImpl(this._prefs, this._webdav);

  @override
  Future<List<HistoryItem>> getHistory() async {
    final String? historyJson = _prefs.getString(_historyKey);
    if (historyJson == null) return [];

    try {
      final List<dynamic> decoded = json.decode(historyJson);
      final list = decoded.map((e) => HistoryItem.fromMap(e)).toList();
      // Sort by timestamp descending (newest first)
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> saveHistory(HistoryItem item) async {
    final list = await getHistory();
    
    // Remove if already exists for this movie and source
    list.removeWhere((e) => e.movieId == item.movieId && e.sourceId == item.sourceId);
    
    // Add new at the beginning
    list.insert(0, item);
    
    // Keep max 100 items
    if (list.length > 100) {
      list.removeLast();
    }

    final encoded = json.encode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_historyKey, encoded);
    
    // Background sync
    if (_webdav.isConfigured) {
      _syncToWebDavBackground();
    }
  }

  @override
  Future<void> removeHistory(String movieId, String sourceId) async {
    final list = await getHistory();
    list.removeWhere((e) => e.movieId == movieId && e.sourceId == sourceId);
    
    final encoded = json.encode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_historyKey, encoded);

    // Background sync
    if (_webdav.isConfigured) {
      _syncToWebDavBackground();
    }
  }

  @override
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
    // Background sync
    if (_webdav.isConfigured) {
      _syncToWebDavBackground();
    }
  }

  @override
  Future<HistoryItem?> getHistoryForMovie(String movieId, String sourceId) async {
    final list = await getHistory();
    try {
      return list.firstWhere((e) => e.movieId == movieId && e.sourceId == sourceId);
    } catch (e) {
      return null;
    }
  }
  
  void _syncToWebDavBackground() async {
    try {
      final list = await getHistory();
      final mapData = {'history': list.map((e) => e.toMap()).toList()};
      await _webdav.saveHistory(mapData);
    } catch (e) {
      // Ignore
    }
  }

  @override
  Future<void> syncWithWebDAV() async {
    if (!_webdav.isConfigured) return;
    try {
      final remoteData = await _webdav.getHistory();
      if (remoteData != null && remoteData['history'] != null) {
        final remoteListRaw = List<dynamic>.from(remoteData['history']);
        final remoteList = remoteListRaw.map((e) => HistoryItem.fromMap(e)).toList();
        
        final localList = await getHistory();
        final Map<String, HistoryItem> mergedMap = {};
        
        // Add all local
        for (var item in localList) {
          mergedMap['${item.sourceId}_${item.movieId}'] = item;
        }
        
        // Merge with remote
        for (var item in remoteList) {
          final key = '${item.sourceId}_${item.movieId}';
          if (mergedMap.containsKey(key)) {
            // Pick newest
            if (item.timestamp > mergedMap[key]!.timestamp) {
              mergedMap[key] = item;
            }
          } else {
            mergedMap[key] = item;
          }
        }
        
        final mergedList = mergedMap.values.toList();
        mergedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        if (mergedList.length > 100) {
          mergedList.removeRange(100, mergedList.length);
        }
        
        final encoded = json.encode(mergedList.map((e) => e.toMap()).toList());
        await _prefs.setString(_historyKey, encoded);
        
        // Update WebDAV with merged list
        _syncToWebDavBackground();
      }
    } catch (e) {
      // Ignore
    }
  }
}
