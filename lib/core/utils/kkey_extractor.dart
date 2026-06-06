import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';


abstract class KkeyExtractor {
  Future<String?> extractStreamKey(int movieId, int episodeId);
  Future<String?> extractSubKey(int movieId, int episodeId);

  static KkeyExtractor getInstance() {
    return _MobileKkeyExtractor();
  }
}

class _MobileKkeyExtractor extends KkeyExtractor {
  Future<String?> _extractKeyFromWebView(int episodeId, String targetApiEndpoint) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;

    headlessWebView = HeadlessInAppWebView(
      initialSize: Size(1280, 720),
      initialUrlRequest: URLRequest(
        url: WebUri('https://kisskh.co/DramaList/Drama/Episode/$episodeId?err=false&ts=null&time=null'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldInterceptFetchRequest: true,
        useShouldInterceptAjaxRequest: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: (controller) {
        debugPrint('DEBUG: Mobile Webview created');
      },
      onLoadStart: (controller, url) {
        debugPrint('DEBUG: URL Loading: $url');
      },
      shouldInterceptFetchRequest: (controller, request) async {
        final url = request.url.toString();
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
      final result = await completer.future.timeout(const Duration(seconds: 15));
      await headlessWebView.dispose();
      return result;
    } catch (e) {
      debugPrint('MobileKkeyExtractor Error: $e');
      await headlessWebView?.dispose();
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


