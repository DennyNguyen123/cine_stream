import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/tunnel_service.dart';
import '../../../data/services/webdav_service.dart';
import '../../../di/injection.dart';
import '../../bloc/history/history_cubit.dart';

class TvSyncScreen extends StatefulWidget {
  const TvSyncScreen({Key? key}) : super(key: key);

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

      await prefs.setString('cinestream_webdav_url', url);
      await prefs.setString('cinestream_webdav_user', user);
      await prefs.setString('cinestream_webdav_pass', pass);
      await prefs.setString('cinestream_webdav_path', path);

      final webdav = getIt<WebDAVService>();
      webdav.init(url, user, pass, folderPath: path);
      
      if (mounted) {
        setState(() { _success = true; });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
      return true;
    };
    final url = await _tunnel.startTunnel();
    if (mounted) {
      if (url != null) {
        setState(() { _qrData = url; });
      } else {
        setState(() { _qrData = "error"; });
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
              const Text("Sync Successful!", style: TextStyle(fontSize: 40, color: Colors.white)),
            ],
          ),
        ),
      );
    }
    
    if (_qrData == "error") {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text("Connection Error")),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 80),
              const SizedBox(height: 20),
              const Text("Cannot connect to Serveo (Tunnel)", style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Go Back"),
              )
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
              Text("Initializing secure connection...", style: TextStyle(color: Colors.white, fontSize: 18))
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Receive WebDAV Config"),
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
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: _qrData!, 
                size: 300,
                backgroundColor: Colors.white,
              ),
            ),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "1. Open the app on your phone", 
                  style: TextStyle(fontSize: 24, color: Colors.white70)
                ),
                SizedBox(height: 10),
                Text(
                  "2. Go to WebDAV Settings > Scan QR", 
                  style: TextStyle(fontSize: 24, color: Colors.white70)
                ),
                SizedBox(height: 10),
                Text(
                  "3. Point the camera at the QR code to sync", 
                  style: TextStyle(fontSize: 24, color: Colors.white70)
                ),
              ],
            )
          ],
        ),
      )
    );
  }
}
