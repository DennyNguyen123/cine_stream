import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../di/injection.dart';

class MobileSyncScreen extends StatefulWidget {
  const MobileSyncScreen({Key? key}) : super(key: key);

  @override
  _MobileSyncScreenState createState() => _MobileSyncScreenState();
}

class _MobileSyncScreenState extends State<MobileSyncScreen> {
  String? _scannedUrl;
  bool _isLoading = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scannedUrl != null) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.startsWith('http')) {
        HapticFeedback.lightImpact();
        setState(() { _scannedUrl = barcode.rawValue; });
        _sendConfig();
        break;
      }
    }
  }

  void _sendConfig() async {
    setState(() => _isLoading = true);
    
    final prefs = getIt<SharedPreferences>();
    final payload = jsonEncode({
      "url": prefs.getString('cinestream_webdav_url') ?? "", 
      "user": prefs.getString('cinestream_webdav_user') ?? "", 
      "pass": prefs.getString('cinestream_webdav_pass') ?? "",
      "path": prefs.getString('cinestream_webdav_path') ?? "/CineStream",
    }); 
    
    try {
      final response = await http.post(
        Uri.parse(_scannedUrl!), 
        body: payload,
        headers: {'Content-Type': 'application/json'}
      );
      
      if (response.statusCode == 200) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.pop(context); // close scanner
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sync Successful!'), backgroundColor: Colors.green)
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An error occurred, please try again'), backgroundColor: Colors.red)
          );
          setState(() { 
            _isLoading = false; 
            _scannedUrl = null; // Reset để quét lại
          });
        }
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot connect to TV'), backgroundColor: Colors.red)
        );
        setState(() { 
          _isLoading = false; 
          _scannedUrl = null; // Reset để quét lại
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan TV QR Code"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          // Viewfinder Overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.red, // This color doesn't matter because of BlendMode.srcOut
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              "Place QR Code inside the frame",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          )
        ],
      ),
    );
  }
}
