import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../domain/entities/stream_info.dart';
import '../../../../domain/entities/subtitle.dart';

class VidsrcmeExtractor {
  static Future<StreamInfo?> extractStream(String serverUrl, List<SubtitleTrack> subtitles) async {
    print('[VidsrcmeExtractor] Loading player: $serverUrl');

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

    headlessWebView = HeadlessInAppWebView(
      initialSize: const Size(1280, 720), // Tránh kích thước 0x0
      initialUrlRequest: URLRequest(url: WebUri(serverUrl)),
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        userAgent: 'Mozilla/5.0 (Linux; Android 13; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.43 Mobile Safari/537.36',
        mediaPlaybackRequiresUserGesture: false,
        javaScriptEnabled: true,
        useShouldInterceptRequest: true,
        useShouldInterceptAjaxRequest: true,
        useShouldInterceptFetchRequest: true,
        
        // Nới lỏng bảo mật & CORS theo yêu cầu
        allowFileAccess: true,
        allowContentAccess: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccessFromFileURLs: true,
        domStorageEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: false, // Bắt buộc giữ luồng trên 1 window
        thirdPartyCookiesEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        // Script chống devtool blockers
        UserScript(
          source: 'window.DisableDevtool = function() {}; window.alert = function(){}; window.confirm = function(){return true;}; window.prompt = function(){return null;};',
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
                if (iframe && iframe.src && iframe.src.indexOf('http') !== -1) {
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
              }, 1000);
              setTimeout(() => clearInterval(clickInterval), 15000);
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
      onReceivedError: (controller, request, error) {
        print('[VidsrcmeExtractor] Error: ${request.url} - ${error.description}');
      },
      shouldInterceptRequest: (controller, request) async {
        final currentUrl = await controller.getUrl();
        return _handleNetworkRequest(request.url.toString(), currentUrl?.toString() ?? 'https://vidsrcme.ru/', completer, timeoutTimer, subtitles);
      },
      shouldInterceptFetchRequest: (controller, request) async {
        final currentUrl = await controller.getUrl();
        _handleNetworkRequest(request.url.toString(), currentUrl?.toString() ?? 'https://vidsrcme.ru/', completer, timeoutTimer, subtitles);
        return request;
      },
      shouldInterceptAjaxRequest: (controller, request) async {
        final currentUrl = await controller.getUrl();
        _handleNetworkRequest(request.url.toString(), currentUrl?.toString() ?? 'https://vidsrcme.ru/', completer, timeoutTimer, subtitles);
        return request;
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async { 
        return NavigationActionPolicy.CANCEL; 
      },
      onConsoleMessage: (controller, consoleMessage) async {
        final msg = consoleMessage.message;
        if (msg.startsWith('VIDEO_SRC:') || msg.startsWith('VIDEO_CURRENT_SRC:')) {
          final videoUrl = msg.split(':').skip(1).join(':');
          if (videoUrl.isNotEmpty && !videoUrl.startsWith('blob:')) {
            final currentUrl = await controller.getUrl();
            _handleNetworkRequest(videoUrl, currentUrl?.toString() ?? 'https://vidsrcme.ru/', completer, timeoutTimer, subtitles);
          }
        }
      },
      onJsAlert: (controller, jsAlertRequest) async => JsAlertResponse(handledByClient: true, action: JsAlertResponseAction.CONFIRM),
      onJsConfirm: (controller, jsConfirmRequest) async => JsConfirmResponse(handledByClient: true, action: JsConfirmResponseAction.CONFIRM),
      onJsPrompt: (controller, jsPromptRequest) async => JsPromptResponse(handledByClient: true, action: JsPromptResponseAction.CONFIRM),
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
      return null;
    }
  }

  // Hàm dùng chung để xử lý và kiểm tra URL request
  static WebResourceResponse? _handleNetworkRequest(
    String reqUrl, 
    String refererUrl,
    Completer<StreamInfo?> completer, 
    Timer timeoutTimer, 
    List<SubtitleTrack> subtitles
  ) {
    if (reqUrl.contains('disable-devtool')) {
      return WebResourceResponse(
        data: Uint8List.fromList([]),
        statusCode: 404,
        headers: {'Access-Control-Allow-Origin': '*'},
      );
    }

    // Biểu thức Regex đánh chặn nghiêm ngặt: Phải là file m3u8 thực sự (chứa .m3u8 hoặc master/playlist/index) hoặc mp4 cụ thể.
    final isValidStream = RegExp(r'\.m3u8$|\.m3u8\?|master\.m3u8|playlist\.m3u8|index\.m3u8|mp4-proxy|\/v\/.*\.mp4', caseSensitive: false).hasMatch(reqUrl);

    if (isValidStream) {
      print('[VidsrcmeExtractor] ✓ Found genuine stream: $reqUrl');
      
      if (!completer.isCompleted) {
        timeoutTimer.cancel();
        
        // Parse the origin from the refererUrl
        final uri = Uri.tryParse(refererUrl);
        final origin = uri != null ? '\${uri.scheme}://\${uri.host}' : 'https://vidsrcme.ru';

        final headers = {
          'Referer': refererUrl,
          'Origin': origin,
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.43 Mobile Safari/537.36',
        };

        // Lấy Cookies
        CookieManager.instance().getCookies(url: WebUri('https://vidsrcme.ru/')).then((iframeCookies) {
          CookieManager.instance().getCookies(url: WebUri(reqUrl)).then((streamCookies) {
            final allCookies = <String, Cookie>{};
            for (var c in iframeCookies) allCookies[c.name] = c;
            for (var c in streamCookies) allCookies[c.name] = c;
            
            if (allCookies.isNotEmpty) {
              headers['Cookie'] = allCookies.values.map((c) => '\${c.name}=\${c.value}').join('; ');
            }
            if (!completer.isCompleted) {
               completer.complete(StreamInfo(videoUrl: reqUrl, subtitles: subtitles, headers: headers));
            }
          });
        }).catchError((_) {
          if (!completer.isCompleted) {
             completer.complete(StreamInfo(videoUrl: reqUrl, subtitles: subtitles, headers: headers));
          }
        });
      }
    }
    return null;
  }
}
