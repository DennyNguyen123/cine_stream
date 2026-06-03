import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/history_item.dart';

abstract class HistoryRepository {
  Future<List<HistoryItem>> getHistory();
  Future<void> saveHistory(HistoryItem item);
  Future<void> removeHistory(String movieId, String sourceId);
  Future<void> clearHistory();
  Future<HistoryItem?> getHistoryForMovie(String movieId, String sourceId);
}

class HistoryRepositoryImpl implements HistoryRepository {
  static const String _historyKey = 'watch_history';
  final SharedPreferences _prefs;

  HistoryRepositoryImpl(this._prefs);

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
  }

  @override
  Future<void> removeHistory(String movieId, String sourceId) async {
    final list = await getHistory();
    list.removeWhere((e) => e.movieId == movieId && e.sourceId == sourceId);
    
    final encoded = json.encode(list.map((e) => e.toMap()).toList());
    await _prefs.setString(_historyKey, encoded);
  }

  @override
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
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
}
