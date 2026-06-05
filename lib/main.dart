import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'core/theme/app_theme.dart';
import 'di/injection.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await setupInjection();
  
  // Tối ưu cho TV: Landscape
  SystemChrome.setPreferredOrientations([
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
      home: const HomeScreen(),
    );
  }
}
