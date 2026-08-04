import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'movie_source.dart';

class SourceManager extends ChangeNotifier {
  final SharedPreferences _prefs;
  final Map<String, MovieSource> _sources;
  late String _activeSourceId;

  static const String _activeSourceKey = 'active_source_id';

  SourceManager({
    required SharedPreferences prefs,
    required Map<String, MovieSource> sources,
    required String defaultSourceId,
  }) : _prefs = prefs,
       _sources = sources {
    _activeSourceId = _prefs.getString(_activeSourceKey) ?? defaultSourceId;

    // Fallback if saved source doesn't exist
    if (!_sources.containsKey(_activeSourceId)) {
      _activeSourceId = defaultSourceId;
    }
  }

  MovieSource get activeSource => _sources[_activeSourceId]!;
  String get activeSourceId => _activeSourceId;

  List<Map<String, String>> getAvailableSources() {
    return _sources.entries
        .map(
          (e) => {
            'id': e.key,
            'name': e.value.sourceName,
            'icon': e.value.sourceIcon,
          },
        )
        .toList();
  }

  Future<void> setActiveSource(String id) async {
    if (!_sources.containsKey(id) || id == _activeSourceId) return;

    _activeSourceId = id;
    await _prefs.setString(_activeSourceKey, id);
    notifyListeners();
  }
}
