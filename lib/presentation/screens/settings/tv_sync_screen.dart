import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/tunnel_service.dart';
import '../../../data/services/webdav_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../di/injection.dart';

class TvSyncScreen extends StatefulWidget {
  const TvSyncScreen({super.key});

  @override
  _TvSyncScreenState createState() => _TvSyncScreenState();
}

class _TvSyncScreenState extends State<TvSyncScreen> {
  final TunnelService _tunnel = TunnelService();
  String? _qrData;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() async {
    _tunnel.onConfigReceived = (data) async {
      final prefs = getIt<SharedPreferences>();
      final url = data['url'] as String? ?? '';
      final user = data['user'] as String? ?? '';
      final pass = data['pass'] as String? ?? '';
      final path = data['path'] as String? ?? '';

      final ttsEngine = data['tts_engine'] as String? ?? 'native';
      final ttsBaseUrl = data['tts_base_url'] as String? ?? '';
      final ttsApiKey = data['tts_api_key'] as String? ?? '';
      final ttsModel = data['tts_model'] as String? ?? 'tts-1';
      final ttsVoice = data['tts_voice'] as String? ?? 'alloy';

      await prefs.setString('cinestream_webdav_url', url);
      await prefs.setString('cinestream_webdav_user', user);
      await prefs.setString('cinestream_webdav_pass', pass);
      await prefs.setString('cinestream_webdav_path', path);

      await prefs.setString('tts_engine', ttsEngine);
      await prefs.setString('tts_base_url', ttsBaseUrl);
      await prefs.setString('tts_api_key', ttsApiKey);
      await prefs.setString('tts_model', ttsModel);
      await prefs.setString('tts_voice', ttsVoice);

      final webdav = getIt<WebDAVService>();
      webdav.init(url, user, pass, folderPath: path);

      if (mounted) {
        setState(() {
          _success = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
      return true;
    };
    final url = await _tunnel.startTunnel();
    if (mounted) {
      if (url != null) {
        setState(() {
          _qrData = url;
        });
      } else {
        setState(() {
          _qrData = 'error';
        });
      }
    }
  }

  @override
  void dispose() {
    _tunnel.stopTunnel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text(
                'Sync Successful!',
                style: TextStyle(fontSize: 40, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_qrData == 'error') {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Connection Error')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 80),
              const SizedBox(height: 20),
              const Text(
                'Cannot connect to Serveo (Tunnel)',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_qrData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Initializing secure connection...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Receive WebDAV Config'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 40,
          runSpacing: 40,
          children: [
            // Thẻ chứa QR bắt buộc phải nền trắng theo chuẩn UI/UX
            Builder(
              builder: (context) {
                bool isFocused = false;
                return StatefulBuilder(
                  builder: (context, setState) => Focus(
                    onFocusChange: (focused) =>
                        setState(() => isFocused = focused),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: isFocused
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 4,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                ),
                              ]
                            : [],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: _qrData!,
                        size: 300,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Open the app on your phone',
                  style: TextStyle(fontSize: 24, color: Colors.white70),
                ),
                SizedBox(height: 10),
                Text(
                  '2. Go to WebDAV Settings > Scan QR',
                  style: TextStyle(fontSize: 24, color: Colors.white70),
                ),
                SizedBox(height: 10),
                Text(
                  '3. Point the camera at the QR code to sync',
                  style: TextStyle(fontSize: 24, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
