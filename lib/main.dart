import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'core/theme/app_theme.dart';
import 'di/injection.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows) {
    try {
      final availableVersion = await WebViewEnvironment.getAvailableVersion();
      if (availableVersion != null) {
        await WebViewEnvironment.create();
      } else {
        debugPrint('WebView2 Runtime is not installed on this system.');
      }
    } catch (e) {
      debugPrint('Failed to initialize WebViewEnvironment: $e');
    }
  }

  MediaKit.ensureInitialized();
  VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);
  await setupInjection();
  
  // Cho phép cả màn hình dọc và ngang
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  // Tối ưu RAM cho Android TV (giảm cache ảnh để tránh OOM)
  PaintingBinding.instance.imageCache.maximumSize = 200; // Mặc định là 1000 ảnh
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB (Mặc định là 100 MB)

  runApp(const CineStreamApp());
}

class CineStreamApp extends StatelessWidget {
  const CineStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineStream',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      home: const HomeScreen(),
    );
  }
}
