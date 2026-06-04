import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';

abstract class KkeyExtractor {
  Future<String?> extractStreamKey(int movieId, int episodeId);
  Future<String?> extractSubKey(int movieId, int episodeId);

  static KkeyExtractor getInstance() {
    if (Platform.isWindows) {
      return _WindowsKkeyExtractor();
    } else {
      return _AndroidKkeyExtractor();
    }
  }
}

class _AndroidKkeyExtractor extends KkeyExtractor {
  final MethodChannel _channel = const MethodChannel('cine_stream/kkey');

  int? _lastEpisodeId;
  Map<String, String?>? _cachedKeys;

  Future<void> _fetchKeysIfNeeded(int movieId, int episodeId) async {
    if (_lastEpisodeId == episodeId && _cachedKeys != null) return;
    
    final keys = await _channel.invokeMapMethod<String, dynamic>('extractKkey', {
      'dramaId': movieId,
      'episodeId': episodeId
    });
    
    _cachedKeys = keys?.cast<String, String?>();
    _lastEpisodeId = episodeId;
  }

  @override
  Future<String?> extractStreamKey(int movieId, int episodeId) async {
    try {
      await _fetchKeysIfNeeded(movieId, episodeId);
      return _cachedKeys?['streamKkey'];
    } catch (e) {
      debugPrint('AndroidKkeyExtractor Stream Error: $e');
      return null;
    }
  }

  @override
  Future<String?> extractSubKey(int movieId, int episodeId) async {
    try {
      await _fetchKeysIfNeeded(movieId, episodeId);
      return _cachedKeys?['subKkey'];
    } catch (e) {
      debugPrint('AndroidKkeyExtractor Sub Error: $e');
      return null;
    }
  }
}

class _WindowsKkeyExtractor extends KkeyExtractor {
  Future<String?> _extractKeyFromWebView(int episodeId, String targetApiEndpoint) async {
    final controller = WebviewController();
    try {
      debugPrint('DEBUG: Initializing Windows Webview...');
      await controller.initialize();
      debugPrint('DEBUG: Webview initialized');
      final completer = Completer<String?>();
      
      // webview_windows doesn't directly expose network interceptors easily like Android's shouldInterceptRequest.
      // However, we can inject JS to patch fetch/XMLHttpRequest to grab the token.
      
      bool completed = false;

      // We will inject a script that overrides window.fetch and XHR to catch the token
      final String injectionScript = '''
        (function() {
          const originalFetch = window.fetch;
          window.fetch = async function() {
            const url = arguments[0];
            if (url && typeof url === 'string' && url.includes('$targetApiEndpoint') && url.includes('kkey=')) {
               const match = url.match(/kkey=([^&]+)/);
               if(match && match[1]) {
                  window.chrome.webview.postMessage("KKEY:" + match[1]);
               }
            }
            return originalFetch.apply(this, arguments);
          };
          
          const origOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url) {
            if (url && typeof url === 'string' && url.includes('$targetApiEndpoint') && url.includes('kkey=')) {
               const match = url.match(/kkey=([^&]+)/);
               if(match && match[1]) {
                  window.chrome.webview.postMessage("KKEY:" + match[1]);
               }
            }
            origOpen.apply(this, arguments);
          };
        })();
      ''';

      controller.webMessage.listen((event) {
        if (!completed && event is String && event.startsWith('KKEY:')) {
          completed = true;
          completer.complete(event.substring(5));
        }
      });

      debugPrint('DEBUG: Loading URL...');
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await controller.loadUrl('https://kisskh.co/DramaList/Drama/Episode/$episodeId?err=false&ts=null&time=null');
      debugPrint('DEBUG: URL Loaded, waiting for KKEY...');
      
      // Keep injecting script
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (completed) {
          timer.cancel();
          return;
        }
        controller.executeScript(injectionScript);
      });

      // Timeout after 15 seconds
      Future.delayed(const Duration(seconds: 15), () {
        if (!completed) {
          debugPrint('DEBUG: Timeout reached 15s');
          completed = true;
          completer.complete(null);
        }
      });

      final result = await completer.future;
      await controller.dispose();
      return result;

    } catch (e) {
      debugPrint('WindowsKkeyExtractor Error: $e');
      await controller.dispose();
      return null;
    }
  }

  @override
  Future<String?> extractStreamKey(int movieId, int episodeId) async {
    return await _extractKeyFromWebView(episodeId, '/api/DramaList/Episode/');
  }

  @override
  Future<String?> extractSubKey(int movieId, int episodeId) async {
    return await _extractKeyFromWebView(episodeId, '/api/Sub/');
  }
}

