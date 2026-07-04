import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/subtitle.dart';
import '../../../../core/errors/stream_extraction_exception.dart';

class VidsrcmeExtractor {
  static Future<StreamInfo?> extractStream(String serverUrl, List<SubtitleTrack> subtitles) async {
    print('[VidsrcmeExtractor] Loading player: $serverUrl');

    final completer = Completer<StreamInfo?>();
    String? foundStreamUrl;

    // Timeout of 15 seconds for headless extraction
    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        if (foundStreamUrl != null) {
          completer.complete(StreamInfo(videoUrl: foundStreamUrl!, subtitles: subtitles));
        } else {
          completer.completeError(StreamExtractionException(
            embedUrl: serverUrl,
            serverId: 'vidsrcme',
            subtitles: subtitles,
            message: 'Timeout: no stream found after 15s',
          ));
        }
      }
    });

    HeadlessInAppWebView? headlessWebView;

    Future<String?> resolveRedirect(String url, Map<String, String> headers) async {
      print('[VidsrcmeExtractor] resolveRedirect: waiting 1s for WebView to release connection...');
      await Future.delayed(const Duration(seconds: 1));
      
      final client = HttpClient();
      try {
        var request = await client.getUrl(Uri.parse(url));
        headers.forEach((k, v) => request.headers.set(k, v));
        request.followRedirects = false;
        var response = await request.close();
        print('[VidsrcmeExtractor] resolveRedirect status: ${response.statusCode}');
        
        if (response.statusCode >= 400) {
          print('[VidsrcmeExtractor] 🛑 Invalid status code: ${response.statusCode}');
          return null;
        }
        
        if (response.isRedirect) {
          final loc = response.headers.value(HttpHeaders.locationHeader) ?? url;
          print('[VidsrcmeExtractor] resolveRedirect location: $loc');
          return loc;
        }
        
        final contentType = response.headers.value(HttpHeaders.contentTypeHeader)?.toLowerCase() ?? '';
        if (contentType.contains('text/html')) {
          print('[VidsrcmeExtractor] 🛑 Invalid stream: Content-Type is HTML');
          return null;
        }
        
        return url;
      } catch (e) {
        print('[VidsrcmeExtractor] resolveRedirect error: $e');
        return null;
      } finally {
        client.close();
      }
    }

    headlessWebView = HeadlessInAppWebView(
      initialSize: const Size(1280, 720), // Tránh kích thước 0x0
      initialUrlRequest: URLRequest(url: WebUri(serverUrl)),
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        javaScriptEnabled: true,
        useShouldInterceptRequest: true,
        
        // Nới lỏng bảo mật & CORS theo yêu cầu
        allowFileAccess: true,
        allowContentAccess: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccessFromFileURLs: true,
        domStorageEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
        thirdPartyCookiesEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        transparentBackground: true,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url?.toString() ?? '';
        final adPatterns = ['doubleclick.net', 'google-analytics.com', 'popads.net', 'adserver', 'popunder'];
        if (navigationAction.isForMainFrame) {
          if (!url.contains('vidsrcme.ru') && !url.contains('about:') && !url.contains('cloudorchestranova.com') && !url.contains('vidsrc')) {
            print('[VidsrcmeExtractor] 🛑 Blocked main frame redirect: $url');
            controller.stopLoading();
            return NavigationActionPolicy.ALLOW;
          }
        } else {
          if (adPatterns.any((p) => url.contains(p))) {
            print('[VidsrcmeExtractor] 🛑 Blocked iframe redirect: $url');
            return NavigationActionPolicy.ALLOW;
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
        // Frame-Independent Clicker Script
        UserScript(
          source: '''
            console.log("[MyClicker] Injected into " + window.location.href);
            
            // 1. Logic chuyển hướng: Nếu đang ở trang vỏ vidsrcme, gửi iframe URL về Flutter
            if (window.location.href.indexOf('vidsrcme.ru') !== -1) {
              var checkIframe = setInterval(function() {
                var iframe = document.querySelector('iframe');
                if (iframe && iframe.src && iframe.src.indexOf('http') !== -1 && iframe.src.indexOf('cloudflare') === -1) {
                  clearInterval(checkIframe);
                  console.log("[MyClicker] Found iframe, sending to Flutter: " + iframe.src);
                  // Gửi URL qua JS Handler
                  window.flutter_inappwebview.callHandler('onIframeFound', iframe.src);
                }
              }, 500);
            } 
            // 2. Logic click tự động: Nếu đã ở trang player (cloudnestra)
            else {
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
              }, 1500);
              setTimeout(() => clearInterval(clickInterval), 14000);
            }
          ''',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START, // Inject sớm nhất có thể
          forMainFrameOnly: false, // Bơm độc lập vào mọi frame
        )
      ]),
      onWebViewCreated: (controller) {
        // Lắng nghe JS Handler từ trang vỏ
        controller.addJavaScriptHandler(
          handlerName: 'onIframeFound',
          callback: (args) async {
            if (args.isNotEmpty) {
              final iframeSrc = args[0].toString();
              print('[VidsrcmeExtractor] ➡ Redirecting via JS Handler to: $iframeSrc');
              await controller.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri(iframeSrc),
                  headers: {'Referer': 'https://vidsrcme.ru/'},
                ),
              );
            }
          },
        );
      },
      onLoadStart: (controller, url) {
        print('[VidsrcmeExtractor] WebView loading: $url');
      },
      onLoadStop: (controller, url) async {
        print('[VidsrcmeExtractor] WebView loaded: $url');
      },
      onCreateWindow: (controller, createWindowAction) async {
        print('[VidsrcmeExtractor] ⚠ Blocked popup window: \${createWindowAction.request.url}');
        return false;
      },
      onReceivedError: (controller, request, error) {
        print('[VidsrcmeExtractor] Error: ${request.url} - ${error.description}');
      },
      shouldInterceptRequest: (controller, request) async {
        final currentUrl = await controller.getUrl();
        return _handleNetworkRequest(controller, request.url.toString(), currentUrl?.toString() ?? 'https://vidsrcme.ru/', completer, timeoutTimer, subtitles, resolveRedirect);
      },


      onConsoleMessage: (controller, consoleMessage) async {
        var msg = consoleMessage.message;
        if (msg.startsWith('"') && msg.endsWith('"')) {
          msg = msg.substring(1, msg.length - 1);
        }
        if (msg.startsWith('VIDEO_SRC:') || msg.startsWith('VIDEO_CURRENT_SRC:') || msg.startsWith('INTERCEPTED_STREAM:')) {
          final videoUrl = msg.split(':').skip(1).join(':');
          if (videoUrl.isNotEmpty && !videoUrl.startsWith('blob:') && foundStreamUrl == null) {
            foundStreamUrl = videoUrl;
            final currentUrl = await controller.getUrl();
            _handleNetworkRequest(controller, videoUrl, currentUrl?.toString() ?? 'https://vidsrcme.ru/', completer, timeoutTimer, subtitles, resolveRedirect);
          }
        }
      },
      onJsAlert: (controller, jsAlertRequest) async => JsAlertResponse(handledByClient: true, action: JsAlertResponseAction.CONFIRM),
      onJsConfirm: (controller, jsConfirmRequest) async => JsConfirmResponse(handledByClient: true, action: JsConfirmResponseAction.CONFIRM),
      onJsPrompt: (controller, jsPromptRequest) async => JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM),
      onJsBeforeUnload: (controller, jsBeforeUnloadRequest) async {
        print('[VidsrcmeExtractor] ⚠ Blocked main frame redirect (beforeunload): \${jsBeforeUnloadRequest.url}');
        return JsBeforeUnloadResponse(handledByClient: true, action: JsBeforeUnloadResponseAction.CANCEL);
      },
    );

    try {
      await headlessWebView.run();
      final result = await completer.future;
      timeoutTimer.cancel();
      await headlessWebView.dispose();
      return result;
    } catch (e) {
      print('[VidsrcmeExtractor] Error: $e');
      timeoutTimer.cancel();
      await headlessWebView.dispose();
      
      if (e is StreamExtractionException) {
        throw e;
      }
      
      throw StreamExtractionException(
        embedUrl: serverUrl,
        serverId: 'vidsrcme',
        subtitles: subtitles,
        message: e.toString(),
      );
    }
  }

  // Hàm dùng chung để xử lý và kiểm tra URL request
  static WebResourceResponse? _handleNetworkRequest(
    InAppWebViewController controller,
    String reqUrl, 
    String refererUrl,
    Completer<StreamInfo?> completer, 
    Timer timeoutTimer, 
    List<SubtitleTrack> subtitles,
    Future<String?> Function(String, Map<String, String>) resolveRedirect
  ) {
    if (reqUrl.contains('disable-devtool')) {
      return WebResourceResponse(
        data: Uint8List.fromList([]),
        statusCode: 404,
        headers: {'Access-Control-Allow-Origin': '*'},
      );
    }

    // Biểu thức Regex đánh chặn nghiêm ngặt: Phải là file m3u8 thực sự (chứa .m3u8 hoặc master/playlist/index) hoặc mp4 cụ thể.
    final isValidStream = RegExp(r'\.m3u8$|\.m3u8\?|master\.m3u8|playlist\.m3u8|index\.m3u8|mp4-proxy|\/v\/.*\.mp4|\/getm3u8\/|\/stream\/|cf-master.*\.txt', caseSensitive: false).hasMatch(reqUrl);

    if (isValidStream) {
      print('[VidsrcmeExtractor] ✓ Found genuine stream: $reqUrl');
      
      if (!completer.isCompleted) {
        timeoutTimer.cancel();
        
        // Parse the origin from the refererUrl
        final uri = Uri.tryParse(refererUrl);
        final origin = uri != null ? '${uri.scheme}://${uri.host}' : 'https://vidsrcme.ru';

        final headers = {
          'Referer': refererUrl,
          'Origin': origin,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        };

        // Lấy Cookies
        CookieManager.instance().getCookies(url: WebUri('https://vidsrcme.ru/')).timeout(const Duration(seconds: 2)).then((iframeCookies) {
          CookieManager.instance().getCookies(url: WebUri(reqUrl)).timeout(const Duration(seconds: 2)).then((streamCookies) {
            final allCookies = <String, Cookie>{};
            for (var c in iframeCookies) allCookies[c.name] = c;
            for (var c in streamCookies) allCookies[c.name] = c;
            
            if (allCookies.isNotEmpty) {
              headers['Cookie'] = allCookies.values.map((c) => '${c.name}=${c.value}').join('; ');
            }
            if (!completer.isCompleted) {
               try {
                 controller.evaluateJavascript(source: "document.querySelectorAll('video').forEach(function(v) { v.pause(); v.removeAttribute('src'); v.load(); });");
               } catch (_) {}
               resolveRedirect(reqUrl, headers).then((finalUrl) {
                 if (finalUrl != null && !completer.isCompleted) completer.complete(StreamInfo(videoUrl: finalUrl, subtitles: subtitles, headers: headers));
               });
            }
          });
        }).catchError((_) {
          if (!completer.isCompleted) {
             try {
               controller.evaluateJavascript(source: "document.querySelectorAll('video').forEach(function(v) { v.pause(); v.removeAttribute('src'); v.load(); });");
             } catch (_) {}
             resolveRedirect(reqUrl, headers).then((finalUrl) {
               if (finalUrl != null && !completer.isCompleted) completer.complete(StreamInfo(videoUrl: finalUrl, subtitles: subtitles, headers: headers));
             });
          }
        });
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
  }
}
