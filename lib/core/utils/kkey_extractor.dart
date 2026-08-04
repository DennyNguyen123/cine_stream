import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:collection';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

abstract class KkeyExtractor {
  Future<String?> extractStreamKey(int movieId, int episodeId);
  Future<String?> extractSubKey(int movieId, int episodeId);

  static KkeyExtractor getInstance() {
    return _MobileKkeyExtractor();
  }
}

class _MobileKkeyExtractor extends KkeyExtractor {
  Future<String?> _extractKeyFromWebView(
    int movieId,
    int episodeId,
    String targetApiEndpoint,
  ) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;

    headlessWebView = HeadlessInAppWebView(
      initialSize: Size(1280, 720),
      initialUrlRequest: URLRequest(
        url: WebUri(
          'https://kisskh.co/Drama/Movie/Episode?id=$episodeId&ep=$episodeId&page=0&pageSize=100',
        ),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldInterceptFetchRequest: true,
        useShouldInterceptAjaxRequest: true,
        mediaPlaybackRequiresUserGesture: false,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: '''
            window.addEventListener('flutterInAppWebViewPlatformReady', function() {
              const originalFetch = window.fetch;
              window.fetch = async function(...args) {
                const url = typeof args[0] === 'string' ? args[0] : (args[0] ? args[0].url : '');
                window.flutter_inappwebview.callHandler('kkeyHandler', url);
                return originalFetch.apply(this, args);
              };
              
              const originalXhrOpen = XMLHttpRequest.prototype.open;
              XMLHttpRequest.prototype.open = function(method, url, ...rest) {
                window.flutter_inappwebview.callHandler('kkeyHandler', url);
                return originalXhrOpen.call(this, method, url, ...rest);
              };
            });
          ''',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      onWebViewCreated: (controller) {
        debugPrint('DEBUG: Mobile Webview created');
        controller.addJavaScriptHandler(
          handlerName: 'kkeyHandler',
          callback: (args) {
            final url = args[0].toString();
            debugPrint('DEBUG JS HANDLER URL: $url');
            if (url.contains(targetApiEndpoint) && url.contains('kkey=')) {
              final match = RegExp(r'kkey=([^&]+)').firstMatch(url);
              if (match != null && !completer.isCompleted) {
                completer.complete(match.group(1));
              }
            }
          },
        );
      },
      onLoadStart: (controller, url) {
        debugPrint('DEBUG: URL Loading: $url');
      },
      onLoadStop: (controller, url) {
        debugPrint('DEBUG: URL Load Stop: $url');
      },
      onLoadError: (controller, url, code, message) {
        debugPrint(
          'DEBUG: URL Load Error: $url, code: $code, message: $message',
        );
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('DEBUG: Console message: ${consoleMessage.message}');
      },
      shouldInterceptFetchRequest: (controller, request) async {
        final url = request.url.toString();
        debugPrint('DEBUG FETCH: $url');
        if (url.contains(targetApiEndpoint) && url.contains('kkey=')) {
          final match = RegExp(r'kkey=([^&]+)').firstMatch(url);
          if (match != null && !completer.isCompleted) {
            completer.complete(match.group(1));
          }
        }
        return request;
      },
      shouldInterceptAjaxRequest: (controller, request) async {
        final url = request.url.toString();
        debugPrint('DEBUG AJAX: $url');
        if (url.contains(targetApiEndpoint) && url.contains('kkey=')) {
          final match = RegExp(r'kkey=([^&]+)').firstMatch(url);
          if (match != null && !completer.isCompleted) {
            completer.complete(match.group(1));
          }
        }
        return request;
      },
    );

    try {
      await headlessWebView.run();
      final result = await completer.future.timeout(
        const Duration(seconds: 15),
      );
      await headlessWebView.dispose();
      return result;
    } catch (e) {
      debugPrint('MobileKkeyExtractor Error: $e');
      await headlessWebView.dispose();
      return null;
    }
  }

  @override
  Future<String?> extractStreamKey(int movieId, int episodeId) async {
    return await _extractKeyFromWebView(
      movieId,
      episodeId,
      '/api/DramaList/Episode/',
    );
  }

  @override
  Future<String?> extractSubKey(int movieId, int episodeId) async {
    return await _extractKeyFromWebView(movieId, episodeId, '/api/Sub/');
  }
}
