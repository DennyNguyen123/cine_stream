import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/subtitle.dart';

class VidplayExtractor {
  static Future<StreamInfo?> extractStream(String serverUrl, List<SubtitleTrack> subtitles) async {
    print('[VidplayExtractor] Loading player: $serverUrl');

    final completer = Completer<StreamInfo?>();
    String? foundStreamUrl;

    // Global timeout of 30 seconds
    final timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        if (foundStreamUrl != null) {
          completer.complete(StreamInfo(videoUrl: foundStreamUrl!, subtitles: subtitles));
        } else {
          completer.completeError(Exception('Timeout: no stream found after 30s'));
        }
      }
    });

    HeadlessInAppWebView? headlessWebView;
    final uri = Uri.parse(serverUrl);
    final isTv = uri.path.contains('-tv');
    final id = uri.queryParameters['tmdb'] ?? uri.queryParameters['imdb'];
    final s = uri.queryParameters['s'];
    final e = uri.queryParameters['e'];
    
    final directUrl = isTv 
        ? 'https://peachify.top/embed/tv/$id/$s/$e?autostart=true'
        : 'https://peachify.top/embed/movie/$id?autostart=true';

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(directUrl)),
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        mediaPlaybackRequiresUserGesture: false,
        javaScriptEnabled: true,
        useShouldInterceptRequest: true,
        useShouldInterceptAjaxRequest: true,
        useShouldInterceptFetchRequest: true,
        allowFileAccess: true,
        allowContentAccess: true,
        domStorageEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: false,
        thirdPartyCookiesEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: 'window.DisableDevtool = function() { console.log("Blocked disable-devtool execution"); }; window.alert = function(){}; window.confirm = function(){return true;}; window.prompt = function(){return null;};',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
        UserScript(
          source: '''
            var clickInterval = setInterval(function() {
              document.querySelectorAll('[class*="play"], [id*="play"], button, .btn').forEach(function(b) { try { b.click(); } catch(e) {} });
              document.querySelectorAll('video').forEach(function(v) { try { v.play(); } catch(e) {} });
              document.querySelectorAll('video source, video').forEach(function(v) {
                if(v.src) console.log('VIDEO_SRC:' + v.src);
                if(v.currentSrc) console.log('VIDEO_CURRENT_SRC:' + v.currentSrc);
              });
            }, 1000);
            setTimeout(() => clearInterval(clickInterval), 15000);
          ''',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
          forMainFrameOnly: false,
        )
      ]),
      onLoadStart: (controller, url) {
        print('[VidplayExtractor] WebView loading: $url');
      },
      onLoadStop: (controller, url) async {
        print('[VidplayExtractor] WebView loaded: $url');
        // Backup evaluateJavascript for main frame
        await controller.evaluateJavascript(source: '''
          var clickIntervalMain = setInterval(function() {
            document.querySelectorAll('[class*="play"], [id*="play"], button, .btn').forEach(function(b) { try { b.click(); } catch(e) {} });
            document.querySelectorAll('video').forEach(function(v) { try { v.play(); } catch(e) {} });
          }, 1000);
          setTimeout(() => clearInterval(clickIntervalMain), 15000);
        ''');
      },
      shouldInterceptRequest: (controller, request) async {
        final reqUrl = request.url.toString();

        if (reqUrl.contains('disable-devtool')) {
          return WebResourceResponse(
            data: Uint8List.fromList([]),
            statusCode: 404,
            reasonPhrase: 'Not Found',
            headers: {'Access-Control-Allow-Origin': '*'},
          );
        }

        // TIK 2 source blocks Dart/ExoPlayer TLS fingerprint, returning 404.
        // We force the WebView's player to fallback to the next source (VID 2) which works in Dart.
        if (reqUrl.contains('tik.1x2.space') || reqUrl.contains('nightspeedster.app')) {
          print('[VidplayExtractor] ⚠ Blocked known tarpit to force fallback: $reqUrl');
          return WebResourceResponse(
            data: Uint8List.fromList([]),
            statusCode: 404,
            reasonPhrase: 'Not Found',
            headers: {'Access-Control-Allow-Origin': '*'},
          );
        }

        if (reqUrl.contains('.m3u8') || reqUrl.contains('mp4-proxy') || reqUrl.contains('.mp4')) {
          foundStreamUrl = reqUrl;
          print('[VidplayExtractor] ✓ Found genuine stream: $reqUrl');
          
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            final headers = {
              'Referer': 'https://peachify.top/',
              'Origin': 'https://peachify.top',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            };
            
            try {
              final cookieManager = CookieManager.instance();
              final iframeCookies = await cookieManager.getCookies(url: WebUri('https://peachify.top/'));
              final streamCookies = await cookieManager.getCookies(url: WebUri(reqUrl));
              
              final allCookies = <String, Cookie>{};
              for (var c in iframeCookies) {
                allCookies[c.name] = c;
              }
              for (var c in streamCookies) {
                allCookies[c.name] = c;
              }
              
              if (allCookies.isNotEmpty) {
                headers['Cookie'] = allCookies.values.map((c) => '${c.name}=${c.value}').join('; ');
              }
            } catch (_) {}

            completer.complete(StreamInfo(videoUrl: foundStreamUrl!, subtitles: subtitles, headers: headers));
          }
        }
        return null;
      },
      shouldInterceptFetchRequest: (controller, request) async {
        final reqUrl = request.url.toString();
        
        if (reqUrl.contains('disable-devtool')) return null;
        
        if (reqUrl.contains('.m3u8') || reqUrl.contains('mp4-proxy') || reqUrl.contains('.mp4')) {
          if (reqUrl.contains('tik.1x2.space') || reqUrl.contains('nightspeedster.app')) return request;
          
          foundStreamUrl = reqUrl;
          print('[VidplayExtractor] ✓ Found genuine stream: $reqUrl');
          
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            final headers = {
              'Referer': 'https://peachify.top/',
              'Origin': 'https://peachify.top',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            };
            completer.complete(StreamInfo(videoUrl: foundStreamUrl!, subtitles: subtitles, headers: headers));
          }
        }
        return request;
      },
      shouldInterceptAjaxRequest: (controller, request) async {
        final reqUrl = request.url.toString();
        
        if (reqUrl.contains('disable-devtool')) return null;

        if (reqUrl.contains('.m3u8') || reqUrl.contains('mp4-proxy') || reqUrl.contains('.mp4')) {
          if (reqUrl.contains('tik.1x2.space') || reqUrl.contains('eat-peach.sbs') || reqUrl.contains('nightspeedster.app')) return request;
          
          foundStreamUrl = reqUrl;
          print('[VidplayExtractor] ✓ Found genuine stream: $reqUrl');
          if (!completer.isCompleted) {
            timeoutTimer.cancel();
            final headers = {
              'Referer': 'https://peachify.top/',
              'Origin': 'https://peachify.top',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            };
            completer.complete(StreamInfo(videoUrl: foundStreamUrl!, subtitles: subtitles, headers: headers));
          }
        }
        return request;
      },
      onConsoleMessage: (controller, consoleMessage) {
        final msg = consoleMessage.message;
        if (msg.startsWith('VIDEO_SRC:') || msg.startsWith('VIDEO_CURRENT_SRC:')) {
          final videoUrl = msg.split(':').skip(1).join(':');
          if (videoUrl.isNotEmpty && !videoUrl.startsWith('blob:') && !completer.isCompleted) {
            foundStreamUrl = videoUrl;
            print('[VidplayExtractor] ✓ Found genuine stream (console): $videoUrl');
            timeoutTimer.cancel();
            
            final headers = {
              'Referer': 'https://peachify.top/',
              'Origin': 'https://peachify.top',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            };
            completer.complete(StreamInfo(videoUrl: foundStreamUrl!, subtitles: subtitles, headers: headers));
          }
        }
      },
      onJsAlert: (controller, jsAlertRequest) async {
        return JsAlertResponse(handledByClient: true, action: JsAlertResponseAction.CONFIRM);
      },
      onJsConfirm: (controller, jsConfirmRequest) async {
        return JsConfirmResponse(handledByClient: true, action: JsConfirmResponseAction.CONFIRM);
      },
      onJsPrompt: (controller, jsPromptRequest) async {
        return JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM);
      },
    );

    try {
      await headlessWebView.run();
      final result = await completer.future;
      timeoutTimer.cancel();
      await headlessWebView.dispose();
      return result;
    } catch (e) {
      print('[VidplayExtractor] Error: $e');
      timeoutTimer.cancel();
      await headlessWebView.dispose();
      return null;
    }
  }
}
