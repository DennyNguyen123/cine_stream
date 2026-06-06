import 'dart:convert';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart' as webdav;

class WebDAVService {
  webdav.Client? _client;
  String _syncFolder = '/CineStream';

  void init(String url, String username, String password, {String? folderPath}) {
    if (url.isEmpty || username.isEmpty || password.isEmpty) return;
    
    if (folderPath != null && folderPath.isNotEmpty) {
      _syncFolder = folderPath.startsWith('/') ? folderPath : '/$folderPath';
      if (_syncFolder.endsWith('/')) {
        _syncFolder = _syncFolder.substring(0, _syncFolder.length - 1);
      }
    }
    
    _client = webdav.newClient(
      url,
      user: username,
      password: password,
      debug: false,
    );
    _client?.setConnectTimeout(8000);
    _client?.setSendTimeout(8000);
    _client?.setReceiveTimeout(8000);
  }
  
  bool get isConfigured => _client != null;

  Future<bool> ping() async {
    if (_client == null) return false;
    try {
      await _client!.ping();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _ensureFolderExists() async {
    if (_client == null) return;
    try {
      await _client!.mkdir(_syncFolder);
    } catch (e) {
      // Ignored: Folder might already exist
    }
  }

  Future<Map<String, dynamic>?> getHistory() async {
    if (_client == null) return null;
    try {
      final bytes = await _client!.read('$_syncFolder/history.json');
      final str = utf8.decode(bytes);
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (e) {
      // Fallback: try to read old path if exists
      try {
        final bytes = await _client!.read('/cine_stream_history.json');
        final str = utf8.decode(bytes);
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (e2) {
        return null;
      }
    }
  }

  Future<bool> saveHistory(Map<String, dynamic> data) async {
    if (_client == null) return false;
    try {
      await _ensureFolderExists();
      final str = jsonEncode(data);
      final bytes = utf8.encode(str);
      await _client!.write('$_syncFolder/history.json', Uint8List.fromList(bytes));
      return true;
    } catch (e) {
      return false;
    }
  }
}
