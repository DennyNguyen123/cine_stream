import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/theme/app_colors.dart';

class WebViewPlayerScreen extends StatefulWidget {
  final String playerUrl;
  final String title;

  const WebViewPlayerScreen({
    super.key,
    required this.playerUrl,
    required this.title,
  });

  @override
  State<WebViewPlayerScreen> createState() => _WebViewPlayerScreenState();
}

class _WebViewPlayerScreenState extends State<WebViewPlayerScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  /// Forward D-pad key events to WebView as JavaScript key events
  void _handleKeyEvent(KeyEvent event) {
    if (_controller == null || event is! KeyDownEvent) return;

    String? keyCode;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        keyCode = 'ArrowUp';
        break;
      case LogicalKeyboardKey.arrowDown:
        keyCode = 'ArrowDown';
        break;
      case LogicalKeyboardKey.arrowLeft:
        keyCode = 'ArrowLeft';
        break;
      case LogicalKeyboardKey.arrowRight:
        keyCode = 'ArrowRight';
        break;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.select:
        keyCode = 'Enter';
        break;
      case LogicalKeyboardKey.space:
        keyCode = ' ';
        break;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        Navigator.pop(context);
        return;
      default:
        return;
    }

    // Special handling for Enter/Select: try to click the play button or focused element
    if (keyCode == 'Enter') {
      _controller!.evaluateJavascript(source: '''
        var playBtn = document.getElementById('playbtnx');
        var activeEl = document.activeElement;
        
        // If play button from vidapi is visible
        if (playBtn && window.getComputedStyle(playBtn).display !== 'none' && (!activeEl || activeEl.tagName !== 'BUTTON')) {
          playBtn.click();
        } 
        // If focused on a button (like server selection)
        else if (activeEl && typeof activeEl.click === 'function' && activeEl.tagName !== 'BODY') {
          activeEl.click();
        } 
        // Fallback: Click the exact center of the screen (where the play button usually is on ANY player)
        else {
          var x = window.innerWidth / 2;
          var y = window.innerHeight / 2;
          var centerEl = document.elementFromPoint(x, y);
          if (centerEl && typeof centerEl.click === 'function') {
             centerEl.click();
             console.log('Clicked center element:', centerEl);
          } else {
             // Dispatch normal Enter event
             document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', bubbles: true }));
          }
        }
      ''');
      return;
    }

    // Dispatch other key events to the WebView
    _controller!.evaluateJavascript(source: '''
      document.dispatchEvent(new KeyboardEvent('keydown', {
        key: '$keyCode',
        code: '$keyCode',
        bubbles: true,
        cancelable: true
      }));
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // WebView Player
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.playerUrl),
                headers: {
                  'Referer': 'https://vidapi.xyz/',
                },
              ),
              initialSettings: InAppWebViewSettings(
                userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                mediaPlaybackRequiresUserGesture: false,
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
                domStorageEnabled: true,
                javaScriptCanOpenWindowsAutomatically: false,
                supportMultipleWindows: false,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                allowFileAccess: true,
                allowContentAccess: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                transparentBackground: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                debugPrint('[WebViewPlayer] Loading: $url');
              },
              onLoadStop: (controller, url) async {
                debugPrint('[WebViewPlayer] Loaded: $url');
                if (mounted) setState(() => _isLoading = false);

                // Auto-play script: continuously try to play for 5 seconds
                await controller.evaluateJavascript(source: '''
                  var attempts = 0;
                  var interval = setInterval(function() {
                    attempts++;
                    if (attempts > 10) clearInterval(interval); // Stop after 5 seconds
                    
                    // Strategy 1: Find any video and play it
                    var videos = document.querySelectorAll('video');
                    videos.forEach(function(v) { 
                      try { v.play(); } catch(e) {} 
                    });

                    // Strategy 2: Click the center of the screen (where the play button is)
                    var x = window.innerWidth / 2;
                    var y = window.innerHeight / 2;
                    var centerEl = document.elementFromPoint(x, y);
                    if (centerEl && typeof centerEl.click === 'function' && centerEl.tagName !== 'BODY') {
                      centerEl.click();
                      console.log('AUTOPLAY: Clicked center element', centerEl);
                    }

                    // Strategy 3: Specific player buttons
                    var playBtn = document.getElementById('playbtnx');
                    if (playBtn) playBtn.click();
                    
                    var jwPlay = document.querySelector('.jw-state-idle .jw-display-icon-display');
                    if (jwPlay) jwPlay.click();
                    
                  }, 500); // Check every 500ms
                ''');
              },
              onReceivedError: (controller, request, error) {
                debugPrint('[WebViewPlayer] Error: ${request.url} - ${error.description}');
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('[WebViewPlayer] Console: ${consoleMessage.message}');
              },
              // Block popup windows (ads)
              onCreateWindow: (controller, createWindowAction) async {
                return false;
              },
            ),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),

            // Back button - small, positioned top-left, doesn't block WebView
            Positioned(
              top: 8,
              left: 8,
              child: SafeArea(
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
