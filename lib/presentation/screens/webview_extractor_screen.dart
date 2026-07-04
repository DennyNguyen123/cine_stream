import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/subtitle.dart';

class WebViewExtractorScreen extends StatefulWidget {
  final String embedUrl;
  final String serverId;
  final List<SubtitleTrack> subtitles;

  const WebViewExtractorScreen({
    Key? key,
    required this.embedUrl,
    required this.serverId,
    required this.subtitles,
  }) : super(key: key);

  @override
  State<WebViewExtractorScreen> createState() => _WebViewExtractorScreenState();
}

class _WebViewExtractorScreenState extends State<WebViewExtractorScreen> {
  InAppWebViewController? _webViewController;
  
  double _cursorX = 0;
  double _cursorY = 0;
  final double _cursorSpeed = 25.0;
  
  bool _isInit = false;
  bool _isExtracted = false;

  final FocusNode _focusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _cursorX = size.width / 2;
        _cursorY = size.height / 2;
        _isInit = true;
      });
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<String> resolveRedirect(String url, Map<String, String> headers) async {
    print('[WebViewExtractor UI] resolveRedirect: waiting 1s for WebView to release connection...');
    await Future.delayed(const Duration(seconds: 1));
    
    final client = HttpClient();
    try {
      var request = await client.getUrl(Uri.parse(url));
      headers.forEach((k, v) => request.headers.set(k, v));
      request.followRedirects = false;
      var response = await request.close();
      print('[WebViewExtractor UI] resolveRedirect status: ${response.statusCode}');
      if (response.isRedirect) {
        final loc = response.headers.value(HttpHeaders.locationHeader) ?? url;
        print('[WebViewExtractor UI] resolveRedirect location: $loc');
        return loc;
      }
      return url;
    } catch (e) {
      print('[WebViewExtractor UI] resolveRedirect error: $e');
      return url;
    } finally {
      client.close();
    }
  }

  void _onStreamFound(String capturedUrl) async {
    if (_isExtracted) return;
    _isExtracted = true;
    print('[WebViewExtractor UI] ✓ Found genuine stream: $capturedUrl');
    
    // Attempt to parse domain from current URL or embed URL
    String currentUrl = widget.embedUrl;
    try {
      final u = await _webViewController?.getUrl();
      if (u != null) currentUrl = u.toString();
    } catch (_) {}

    final uri = Uri.tryParse(currentUrl);
    final origin = uri != null ? '${uri.scheme}://${uri.host}' : 'https://vidsrcme.ru';

    final headers = {
      'Referer': currentUrl,
      'Origin': origin,
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    try {
      final cookieManager = CookieManager.instance();
      final iframeCookies = await cookieManager.getCookies(url: WebUri(currentUrl)).timeout(const Duration(seconds: 2));
      final streamCookies = await cookieManager.getCookies(url: WebUri(capturedUrl)).timeout(const Duration(seconds: 2));
      
      final allCookies = <String, Cookie>{};
      for (var c in iframeCookies) allCookies[c.name] = c;
      for (var c in streamCookies) allCookies[c.name] = c;
      
      if (allCookies.isNotEmpty) {
        headers['Cookie'] = allCookies.values.map((c) => '${c.name}=${c.value}').join('; ');
      }
    } catch (_) {}

    try {
      _webViewController?.evaluateJavascript(source: "document.querySelectorAll('video').forEach(function(v) { v.pause(); v.removeAttribute('src'); v.load(); });");
    } catch (_) {}

    final finalUrl = await resolveRedirect(capturedUrl, headers);
    
    if (mounted) {
      Navigator.pop(context, StreamInfo(videoUrl: finalUrl, subtitles: widget.subtitles, headers: headers, currentServerId: widget.serverId));
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final size = MediaQuery.of(context).size;
      
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() => _cursorY = (_cursorY - _cursorSpeed).clamp(0, size.height));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() => _cursorY = (_cursorY + _cursorSpeed).clamp(0, size.height));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() => _cursorX = (_cursorX - _cursorSpeed).clamp(0, size.width));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() => _cursorX = (_cursorX + _cursorSpeed).clamp(0, size.width));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space) {
        // Trigger click at cursor position
        _webViewController?.evaluateJavascript(source: '''
          (function() {
            var el = document.elementFromPoint($_cursorX, $_cursorY);
            if (el) {
              var rect = el.getBoundingClientRect();
              var x = rect.left + rect.width / 2;
              var y = rect.top + rect.height / 2;
              ['mousedown', 'mouseup', 'click', 'pointerdown', 'pointerup'].forEach(function(type) {
                var evt = new MouseEvent(type, { bubbles: true, cancelable: true, view: window, clientX: x, clientY: y });
                el.dispatchEvent(evt);
              });
              el.click();
              console.log("[MyClicker] Clicked element at $_cursorX, $_cursorY");
            }
          })();
        ''');
        
        // Show click animation (optional visual feedback)
        setState(() {}); 
        return KeyEventResult.handled;
      }
      
      // Escape or Back to close
      if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack) {
        Navigator.pop(context);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) return const Scaffold(backgroundColor: Colors.black);

    final adPatterns = ['radiance', 'hexoic', 'doubleclick', 'googlesyndication', 'popads', 'adserver', 'popunder', 'propellerads', 'exdynsrv', 'onclick', 'bet365', '1xbet'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.embedUrl)),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              javaScriptEnabled: true,
              useShouldInterceptRequest: true,
              allowFileAccess: true,
              allowContentAccess: true,
              domStorageEnabled: true,
              javaScriptCanOpenWindowsAutomatically: false, // Strict block popups
              supportMultipleWindows: true,
              thirdPartyCookiesEnabled: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              transparentBackground: true,
            ),
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: '''
                  window.DisableDevtool = function() {}; 
                  window.alert = function(){}; 
                  window.confirm = function(){return true;}; 
                  window.prompt = function(){return null;}; 
                  
                  // Tự động tìm và click play button nếu có, giảm tải cho user
                  var clickInterval = setInterval(function() {
                    document.querySelectorAll('[class*="play"], [id*="play"], button, .btn').forEach(function(b) { try { b.click(); } catch(e) {} });
                    document.querySelectorAll('video').forEach(function(v) { try { v.play(); } catch(e) {} });
                    
                    document.querySelectorAll('video source, video').forEach(function(v) {
                      if(v.src) console.log('VIDEO_SRC:' + v.src);
                      if(v.currentSrc) console.log('VIDEO_CURRENT_SRC:' + v.currentSrc);
                    });
                  }, 2000);
                  setTimeout(() => clearInterval(clickInterval), 15000);
                ''',
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                forMainFrameOnly: false,
              )
            ]),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onCreateWindow: (controller, createWindowAction) async {
              print('[WebViewExtractor UI] ⚠ Blocked popup window: \${createWindowAction.request.url}');
              return false; // Chặn cứng toàn bộ popup
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              
              if (navigationAction.isForMainFrame) {
                // Rất khắt khe: chỉ cho phép ở lại miền chiếu phim
                if (!url.contains('vidnest.fun') && !url.contains('peachify.top') && !url.contains('vidsrcme.ru') && !url.contains('about:')) {
                  print('[WebViewExtractor UI] 🛑 Blocked main frame redirect: $url');
                  controller.stopLoading();
                  return NavigationActionPolicy.ALLOW; // Hoặc CANCEL tùy phiên bản InAppWebView
                }
              } else {
                if (adPatterns.any((p) => url.contains(p))) {
                  print('[WebViewExtractor UI] 🛑 Blocked iframe redirect: $url');
                  return NavigationActionPolicy.ALLOW; // Bỏ qua không load
                }
              }
              return NavigationActionPolicy.ALLOW;
            },
            shouldInterceptRequest: (controller, request) async {
              final reqUrl = request.url.toString();

              if (reqUrl.contains('disable-devtool')) {
                return WebResourceResponse(data: Uint8List.fromList([]), statusCode: 404, headers: {'Access-Control-Allow-Origin': '*'});
              }

              if (adPatterns.any((p) => reqUrl.contains(p))) {
                return WebResourceResponse(data: Uint8List.fromList([]), statusCode: 204, reasonPhrase: 'No Content', headers: {'Access-Control-Allow-Origin': '*'});
              }

              final isValidStream = RegExp(r'\.m3u8$|\.m3u8\?|master\.m3u8|playlist\.m3u8|index\.m3u8|mp4-proxy|\/v\/.*\.mp4|\/getm3u8\/|\/stream\/|cf-master.*\.txt', caseSensitive: false).hasMatch(reqUrl);
              if (isValidStream) {
                _onStreamFound(reqUrl);
                return WebResourceResponse(data: Uint8List.fromList([]), statusCode: 404, reasonPhrase: 'Blocked', headers: {'Access-Control-Allow-Origin': '*'});
              }
              return null;
            },
            onConsoleMessage: (controller, consoleMessage) async {
              var msg = consoleMessage.message;
              if (msg.startsWith('"') && msg.endsWith('"')) msg = msg.substring(1, msg.length - 1);
              
              if (msg.startsWith('VIDEO_SRC:') || msg.startsWith('VIDEO_CURRENT_SRC:') || msg.startsWith('INTERCEPTED_STREAM:')) {
                final videoUrl = msg.split(':').skip(1).join(':');
                if (videoUrl.isNotEmpty && !videoUrl.startsWith('blob:')) {
                  _onStreamFound(videoUrl);
                }
              }
            },
          ),
          
          // Virtual Cursor Layer
          Positioned.fill(
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _handleKeyEvent,
              child: Stack(
                children: [
                  Positioned(
                    left: _cursorX - 12, // Center the icon
                    top: _cursorY - 12,
                    child: const IgnorePointer(
                      child: Icon(
                        Icons.mouse,
                        color: Colors.amber,
                        size: 30,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Instruction Overlay (Top Left)
          Positioned(
            top: 20,
            left: 20,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xác minh Captcha',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dùng D-Pad trên Remote để di chuyển trỏ chuột\nvà bấm OK để xác minh.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
