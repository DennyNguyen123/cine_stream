import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/history_item.dart';

import '../services/webdav_service.dart';

abstract class HistoryRepository {
  Future<List<HistoryItem>> getHistory();
  Future<void> saveHistory(HistoryItem item, {bool syncWebDav = true});
  Future<void> removeHistory(String movieId, String sourceId);
  Future<void> clearHistory();
  Future<HistoryItem?> getHistoryForMovie(String movieId, String sourceId);
  Future<void> syncWithWebDAV();
}

class HistoryRepositoryImpl implements HistoryRepository {
  static const String _historyKey = 'watch_history';
  final SharedPreferences _prefs;
  final WebDAVService _webdav;
  bool _isSyncing = false;

  HistoryRepositoryImpl(this._prefs, this._webdav);

  Future<List<HistoryItem>> _getRawHistory() async {
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
  Future<List<HistoryItem>> getHistory() async {
    final list = await _getRawHistory();
    return list.where((e) => e.isDeleted != true).toList();
  }

  @override
  Future<void> saveHistory(HistoryItem item, {bool syncWebDav = true}) async {
    final list = await _getRawHistory();
    
    // Remove if already exists for this movie and source
    list.removeWhere((e) => e.movieId == item.movieId && e.sourceId == item.sourceId);
    
    final newItem = item.isDeleted ? item.copyWith(isDeleted: false, timestamp: DateTime.now().millisecondsSinceEpoch) : item;
    
    // Add new at the beginning
    list.insert(0, newItem);
    
    // Keep max 200 items (to allow space for tombstones)
    if (list.length > 200) {
      list.removeLast();
    }

    final encoded = json.encode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_historyKey, encoded);
    
    // Background sync
    if (syncWebDav && _webdav.isConfigured) {
      _syncToWebDavBackground();
    }
  }

  @override
  Future<void> removeHistory(String movieId, String sourceId) async {
    final list = await _getRawHistory();
    final index = list.indexWhere((e) => e.movieId == movieId && e.sourceId == sourceId);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (index != -1) {
      list[index] = list[index].copyWith(isDeleted: true, timestamp: now);
    } else {
      list.insert(0, HistoryItem(
        movieId: movieId,
        movieTitle: '',
        episodeId: '',
        episodeNumber: 0,
        positionMs: 0,
        durationMs: 0,
        timestamp: now,
        sourceId: sourceId,
        isDeleted: true,
      ));
    }
    
    if (list.length > 200) {
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
  Future<void> clearHistory() async {
    final list = await _getRawHistory();
    final now = DateTime.now().millisecondsSinceEpoch;
    final clearedList = list.map((e) => e.copyWith(isDeleted: true, timestamp: now)).toList();

    final encoded = json.encode(clearedList.map((e) => e.toMap()).toList());
    await _prefs.setString(_historyKey, encoded);

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
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final list = await _getRawHistory();
      final mapData = {'history': list.map((e) => e.toMap()).toList()};
      await _webdav.saveHistory(mapData);
    } catch (e) {
      // Ignore
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Future<void> syncWithWebDAV() async {
    if (!_webdav.isConfigured || _isSyncing) return;
    _isSyncing = true;
    try {
      final remoteData = await _webdav.getHistory();
      if (remoteData != null && remoteData['history'] != null) {
        final remoteListRaw = List<dynamic>.from(remoteData['history']);
        final remoteList = remoteListRaw.map((e) => HistoryItem.fromMap(e)).toList();
        
        final localList = await _getRawHistory();
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
        
        if (mergedList.length > 200) {
          mergedList.removeRange(200, mergedList.length);
        }
        
        final encoded = json.encode(mergedList.map((e) => e.toMap()).toList());
        await _prefs.setString(_historyKey, encoded);
        
        // Update WebDAV with merged list directly without trigger another sync background function since we're in one
        final mapData = {'history': mergedList.map((e) => e.toMap()).toList()};
        await _webdav.saveHistory(mapData);
      }
    } catch (e) {
      // Ignore
    } finally {
      _isSyncing = false;
    }
  }
}
