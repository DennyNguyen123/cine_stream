import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/subtitle.dart';
import '../../../../core/errors/stream_extraction_exception.dart';

class VidplayExtractor {
  static Future<StreamInfo?> extractStream(
    String serverUrl,
    List<SubtitleTrack> subtitles,
  ) async {
    return await _extractMobile(serverUrl, subtitles);
  }

  static Future<StreamInfo?> _extractMobile(
    String serverUrl,
    List<SubtitleTrack> subtitles,
  ) async {
    print('[VidplayExtractor] Loading player: $serverUrl');

    final completer = Completer<StreamInfo?>();
    String? foundStreamUrl;

    // Timeout of 15 seconds for headless extraction
    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        if (foundStreamUrl != null) {
          completer.complete(
            StreamInfo(videoUrl: foundStreamUrl!, subtitles: subtitles),
          );
        } else {
          final uri = Uri.parse(serverUrl);
          final isTv = uri.path.contains('-tv');
          final id = uri.queryParameters['tmdb'] ?? uri.queryParameters['imdb'];
          final s = uri.queryParameters['s'];
          final e = uri.queryParameters['e'];
          final directUrl = isTv
              ? 'https://peachify.top/embed/tv/$id/$s/$e?autostart=true'
              : 'https://peachify.top/embed/movie/$id?autostart=true';

          completer.completeError(
            StreamExtractionException(
              embedUrl: directUrl,
              serverId: 'vpls',
              subtitles: subtitles,
              message: 'Timeout: no stream found after 15s',
            ),
          );
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

    Future<String> resolveRedirect(
      String url,
      Map<String, String> headers,
    ) async {
      print(
        '[VidplayExtractor] resolveRedirect: waiting 1s for WebView to release connection...',
      );
      await Future.delayed(const Duration(seconds: 1));

      final client = HttpClient();
      try {
        var request = await client.getUrl(Uri.parse(url));
        headers.forEach((k, v) => request.headers.set(k, v));
        request.followRedirects = false;
        var response = await request.close();
        print(
          '[VidplayExtractor] resolveRedirect status: ${response.statusCode}',
        );
        if (response.isRedirect) {
          final loc = response.headers.value(HttpHeaders.locationHeader) ?? url;
          print('[VidplayExtractor] resolveRedirect location: $loc');
          return loc;
        }
        return url;
      } catch (e) {
        print('[VidplayExtractor] resolveRedirect error: $e');
        return url;
      } finally {
        client.close();
      }
    }

    final adPatterns = [
      'radiance',
      'hexoic',
      'doubleclick',
      'googlesyndication',
      'popads',
      'adserver',
      'popunder',
    ];

    headlessWebView = HeadlessInAppWebView(
      initialSize: Size(1280, 720),
      initialUrlRequest: URLRequest(url: WebUri(directUrl)),
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        useShouldInterceptRequest: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
        transparentBackground: true,
        thirdPartyCookiesEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        loadsImagesAutomatically: false,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString() ?? '';
        if (navigationAction.isForMainFrame) {
          if (!url.contains('peachify.top') && !url.contains('about:')) {
            print('[VidplayExtractor] 🛑 Blocked main frame redirect: $url');
            controller.stopLoading();
            return NavigationActionPolicy.ALLOW;
          }
        } else {
          if (adPatterns.any((p) => url.contains(p))) {
            print('[VidplayExtractor] 🛑 Blocked iframe redirect: $url');
            return NavigationActionPolicy.ALLOW; // Ignore without deadlocking
          }
        }
        return NavigationActionPolicy.ALLOW;
      },
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: '''
            window.DisableDevtool = function() {}; 
            window.alert = function(){}; 
            window.confirm = function(){return true;}; 
            window.prompt = function(){return null;}; 
            window.addEventListener("beforeunload", function(e) { 
              e.preventDefault(); 
              e.returnValue = "Blocked"; 
              return "Blocked"; 
            });
          ''',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
        UserScript(
          source: '''
            console.log("[MyClicker] Injected into " + window.location.href);
            
            var checkIframe = setInterval(function() {
              var iframes = document.querySelectorAll('iframe');
              for (var i = 0; i < iframes.length; i++) {
                var src = iframes[i].src;
                if (src && src.indexOf('http') !== -1) {
                  if (src.indexOf('radiance') === -1 && src.indexOf('hexoic') === -1 && src.indexOf('ads') === -1 && src.indexOf('cloudflare') === -1) {
                    clearInterval(checkIframe);
                    console.log("[MyClicker] Found player iframe: " + src);
                    try { window.flutter_inappwebview.callHandler('onIframeFound', src); } catch(e) {}
                    break;
                  }
                }
              }
            }, 500);

            var clickInterval = setInterval(function() {
                function simulateInteraction(el) {
                  try {
                    var rect = el.getBoundingClientRect();
                    var x = rect.left + rect.width / 2;
                    var y = rect.top + rect.height / 2;
                    ['mousedown', 'mouseup', 'click', 'pointerdown', 'pointerup'].forEach(function(type) {
                      var evt = new MouseEvent(type, { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y });
                      el.dispatchEvent(evt);
                    });
                    el.click();
                  } catch(e) {}
                }
                
                var elements = document.querySelectorAll('div, a, span, button, i');
                for (var i = 0; i < elements.length; i++) {
                  var el = elements[i];
                  var c = el.className || '';
                  var id = el.id || '';
                  if (typeof c === 'string' && (c.toLowerCase().indexOf('play') !== -1 || c.toLowerCase().indexOf('btn') !== -1 || c.toLowerCase().indexOf('but') !== -1)) {
                    simulateInteraction(el);
                  }
                  if (typeof id === 'string' && (id.toLowerCase().indexOf('play') !== -1 || id.toLowerCase().indexOf('btn') !== -1 || id.toLowerCase().indexOf('but') !== -1)) {
                    simulateInteraction(el);
                  }
                }
                
                var centerEl = document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2);
                if (centerEl) { simulateInteraction(centerEl); }

                document.querySelectorAll('video').forEach(function(v) { try { v.play(); } catch(e) {} });
                
                document.querySelectorAll('video source, video').forEach(function(v) {
                  if(v.src) console.log('VIDEO_SRC:' + v.src);
                  if(v.currentSrc) console.log('VIDEO_CURRENT_SRC:' + v.currentSrc);
                });
              }, 1500);
              setTimeout(() => clearInterval(clickInterval), 14000);
          ''',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      ]),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'onIframeFound',
          callback: (args) async {
            if (args.isNotEmpty) {
              final iframeSrc = args[0].toString();
              print(
                '[VidplayExtractor] ➡ Redirecting via JS Handler to: \$iframeSrc',
              );
              await controller.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri(iframeSrc),
                  headers: {'Referer': 'https://peachify.top/'},
                ),
              );
            }
          },
        );
      },
      onLoadStart: (controller, url) {
        print('[VidplayExtractor] WebView loading: $url');
      },
      onLoadStop: (controller, url) async {
        print('[VidplayExtractor] WebView loaded: $url');
        // Backup evaluateJavascript for main frame
        await controller.evaluateJavascript(
          source: '''
          var clickIntervalMain = setInterval(function() {
            document.querySelectorAll('[class*="play"], [id*="play"], button, .btn').forEach(function(b) { try { b.click(); } catch(e) {} });
            document.querySelectorAll('video').forEach(function(v) { try { v.play(); } catch(e) {} });
          }, 1500);
          setTimeout(() => clearInterval(clickIntervalMain), 14000);
        ''',
        );
      },
      onCreateWindow: (controller, createWindowAction) async {
        print(
          '[VidplayExtractor] ⚠ Blocked popup window: \${createWindowAction.request.url}',
        );
        return false;
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

        final lowercaseUrl = reqUrl.toLowerCase();
        if (lowercaseUrl.endsWith('.png') ||
            lowercaseUrl.endsWith('.jpg') ||
            lowercaseUrl.endsWith('.jpeg') ||
            lowercaseUrl.endsWith('.webp') ||
            lowercaseUrl.endsWith('.gif') ||
            lowercaseUrl.endsWith('.svg') ||
            lowercaseUrl.endsWith('.ico') ||
            lowercaseUrl.endsWith('.woff') ||
            lowercaseUrl.endsWith('.woff2') ||
            lowercaseUrl.endsWith('.ttf')) {
          return WebResourceResponse(
            data: Uint8List.fromList([]),
            statusCode: 200,
            reasonPhrase: 'OK',
            headers: {'Access-Control-Allow-Origin': '*'},
          );
        }

        final adPatterns = [
          'radiance',
          'hexoic',
          'doubleclick',
          'googlesyndication',
          'popads',
          'adserver',
          'popunder',
        ];
        if (adPatterns.any((p) => reqUrl.contains(p))) {
          return WebResourceResponse(
            data: Uint8List.fromList([]),
            statusCode: 204,
            reasonPhrase: 'No Content',
            headers: {'Access-Control-Allow-Origin': '*'},
          );
        }

        // TIK 2 source blocks Dart/ExoPlayer TLS fingerprint, returning 404.
        // We force the WebView's player to fallback to the next source (VID 2) which works in Dart.
        if (reqUrl.contains('tik.1x2.space') ||
            reqUrl.contains('nightspeedster.app') ||
            reqUrl.contains('tiktoks.animanga.fun') ||
            reqUrl.contains('animanga.fun')) {
          print(
            '[VidplayExtractor] ⚠ Blocked known tarpit to force fallback: $reqUrl',
          );
          return WebResourceResponse(
            data: Uint8List.fromList([]),
            statusCode: 404,
            reasonPhrase: 'Not Found',
            headers: {'Access-Control-Allow-Origin': '*'},
          );
        }

        final isValidStream = RegExp(
          r'\.m3u8$|\.m3u8\?|master\.m3u8|playlist\.m3u8|index\.m3u8|mp4-proxy|\/v\/.*\.mp4|\/getm3u8\/|\/stream\/|cf-master.*\.txt',
          caseSensitive: false,
        ).hasMatch(reqUrl);
        if (isValidStream) {
          final capturedUrl = reqUrl;
          if (!completer.isCompleted && foundStreamUrl == null) {
            foundStreamUrl = capturedUrl;
            print('[VidplayExtractor] ✓ Found genuine stream: $capturedUrl');
            timeoutTimer.cancel();

            final headers = <String, String>{};
            if (request.headers != null) {
              request.headers!.forEach((k, v) => headers[k] = v);
            }
            String referer = headers.entries
                .firstWhere(
                  (e) => e.key.toLowerCase() == 'referer',
                  orElse: () => MapEntry('', ''),
                )
                .value;
            if (referer.isEmpty) {
              referer = 'https://vidplay.site/';
              headers['Referer'] = referer;
            }
            if (!headers.keys.any((k) => k.toLowerCase() == 'user-agent')) {
              headers['User-Agent'] =
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
            }
            if (!headers.keys.any((k) => k.toLowerCase() == 'origin')) {
              try {
                final uri = Uri.parse(referer);
                headers['Origin'] = '${uri.scheme}://${uri.host}';
              } catch (_) {}
            }

            try {
              final cookieManager = CookieManager.instance();
              final iframeCookies = await cookieManager
                  .getCookies(url: WebUri(referer))
                  .timeout(const Duration(seconds: 2));
              final streamCookies = await cookieManager
                  .getCookies(url: WebUri(capturedUrl))
                  .timeout(const Duration(seconds: 2));

              final allCookies = <String, Cookie>{};
              for (var c in iframeCookies) {
                allCookies[c.name] = c;
              }
              for (var c in streamCookies) {
                allCookies[c.name] = c;
              }

              if (allCookies.isNotEmpty) {
                headers['Cookie'] = allCookies.values
                    .map((c) => '${c.name}=${c.value}')
                    .join('; ');
              }
            } catch (_) {}

            if (!completer.isCompleted) {
              try {
                controller.evaluateJavascript(
                  source:
                      "document.querySelectorAll('video').forEach(function(v) { v.pause(); v.removeAttribute('src'); v.load(); });",
                );
              } catch (_) {}
              final finalUrl = await resolveRedirect(capturedUrl, headers);
              completer.complete(
                StreamInfo(
                  videoUrl: finalUrl,
                  subtitles: subtitles,
                  headers: headers,
                ),
              );
            }
          }
          // BLOCK the request so the token is not consumed by WebView
          return WebResourceResponse(
            data: Uint8List.fromList([]),
            statusCode: 404,
            reasonPhrase: 'Blocked',
            headers: {'Access-Control-Allow-Origin': '*'},
          );
        }
        return null;
      },

      onConsoleMessage: (controller, consoleMessage) async {
        var msg = consoleMessage.message;
        if (msg.startsWith('"') && msg.endsWith('"')) {
          msg = msg.substring(1, msg.length - 1);
        }
        if (msg.startsWith('VIDEO_SRC:') ||
            msg.startsWith('VIDEO_CURRENT_SRC:') ||
            msg.startsWith('INTERCEPTED_STREAM:')) {
          final videoUrl = msg.split(':').skip(1).join(':');
          if (videoUrl.isNotEmpty &&
              !videoUrl.startsWith('blob:') &&
              foundStreamUrl == null) {
            foundStreamUrl = videoUrl;
            print(
              '[VidplayExtractor] ✓ Found genuine stream (console): $videoUrl',
            );
            timeoutTimer.cancel();

            final headers = {
              'Referer': 'https://peachify.top/',
              'Origin': 'https://peachify.top',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            };
            try {
              final cookieManager = CookieManager.instance();
              final iframeCookies = await cookieManager
                  .getCookies(url: WebUri('https://vidplay.online/'))
                  .timeout(const Duration(seconds: 2));
              final streamCookies = await cookieManager
                  .getCookies(url: WebUri(foundStreamUrl!))
                  .timeout(const Duration(seconds: 2));

              final allCookies = <String, Cookie>{};
              for (var c in iframeCookies) {
                allCookies[c.name] = c;
              }
              for (var c in streamCookies) {
                allCookies[c.name] = c;
              }

              if (allCookies.isNotEmpty) {
                headers['Cookie'] = allCookies.values
                    .map((c) => '${c.name}=${c.value}')
                    .join('; ');
              }
            } catch (_) {}

            if (!completer.isCompleted) {
              try {
                controller.evaluateJavascript(
                  source:
                      "document.querySelectorAll('video').forEach(function(v) { v.pause(); v.removeAttribute('src'); v.load(); });",
                );
              } catch (_) {}
              final finalUrl = await resolveRedirect(foundStreamUrl!, headers);
              completer.complete(
                StreamInfo(
                  videoUrl: finalUrl,
                  subtitles: subtitles,
                  headers: headers,
                ),
              );
            }
          }
        }
      },
      onJsAlert: (controller, jsAlertRequest) async {
        return JsAlertResponse(
          handledByClient: true,
          action: JsAlertResponseAction.CONFIRM,
        );
      },
      onJsConfirm: (controller, jsConfirmRequest) async {
        return JsConfirmResponse(
          handledByClient: true,
          action: JsConfirmResponseAction.CONFIRM,
        );
      },
      onJsPrompt: (controller, jsPromptRequest) async {
        return JsPromptResponse(
          handledByClient: true,
          action: JsPromptResponseAction.CONFIRM,
        );
      },
      onJsBeforeUnload: (controller, jsBeforeUnloadRequest) async {
        print(
          '[VidplayExtractor] ⚠ Blocked main frame redirect (beforeunload): \${jsBeforeUnloadRequest.url}',
        );
        return JsBeforeUnloadResponse(
          handledByClient: true,
          action: JsBeforeUnloadResponseAction.CANCEL,
        );
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

      if (e is StreamExtractionException) {
        rethrow;
      }

      final uri = Uri.parse(serverUrl);
      final isTv = uri.path.contains('-tv');
      final id = uri.queryParameters['tmdb'] ?? uri.queryParameters['imdb'];
      final s = uri.queryParameters['s'];
      final eParam = uri.queryParameters['e'];
      final directUrl = isTv
          ? 'https://peachify.top/embed/tv/$id/$s/$eParam?autostart=true'
          : 'https://peachify.top/embed/movie/$id?autostart=true';

      throw StreamExtractionException(
        embedUrl: directUrl,
        serverId: 'vpls',
        subtitles: subtitles,
        message: e.toString(),
      );
    }
  }
}
