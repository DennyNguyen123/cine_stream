import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/webdav_service.dart';
import '../../../data/services/log_service.dart';
import '../../../di/injection.dart';
import '../../bloc/history/history_cubit.dart';
import 'mobile_sync_screen.dart';
import 'tv_sync_screen.dart';

class WebdavSetupScreen extends StatefulWidget {
  const WebdavSetupScreen({Key? key}) : super(key: key);

  @override
  State<WebdavSetupScreen> createState() => _WebdavSetupScreenState();
}

class _WebdavSetupScreenState extends State<WebdavSetupScreen> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _pathController = TextEditingController();
  
  final _urlFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _pathFocus = FocusNode();
  
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    
    _urlFocus.onKeyEvent = _handleKeyEvent;
    _userFocus.onKeyEvent = _handleKeyEvent;
    _passFocus.onKeyEvent = _handleKeyEvent;
    _pathFocus.onKeyEvent = _handleKeyEvent;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();
    _urlFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _pathFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        node.nextFocus();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        node.previousFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _loadConfig() {
    final prefs = getIt<SharedPreferences>();
    _urlController.text = prefs.getString('cinestream_webdav_url') ?? '';
    _userController.text = prefs.getString('cinestream_webdav_user') ?? '';
    _passController.text = prefs.getString('cinestream_webdav_pass') ?? '';
    _pathController.text = prefs.getString('cinestream_webdav_path') ?? '/CineStream';
  }

  Future<void> _saveAndTest() async {
    setState(() => _isTesting = true);
    
    final url = _urlController.text.trim();
    final user = _userController.text.trim();
    final pass = _passController.text.trim();
    final path = _pathController.text.trim();

    final webdav = getIt<WebDAVService>();
    webdav.init(url, user, pass, folderPath: path);
    
    final success = await webdav.ping();
    
    setState(() => _isTesting = false);

    if (success) {
      final prefs = getIt<SharedPreferences>();
      await prefs.setString('cinestream_webdav_url', url);
      await prefs.setString('cinestream_webdav_user', user);
      await prefs.setString('cinestream_webdav_pass', pass);
      await prefs.setString('cinestream_webdav_path', path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WebDAV connected & Saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot connect to WebDAV. Check your credentials!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('WebDAV Configuration'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quick Sync via QR",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    autofocus: true,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code, color: Colors.white),
                    label: const Text("Show QR", style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TvSyncScreen()));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    label: const Text("Scan QR", style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileSyncScreen()));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(color: Colors.white24),
            const SizedBox(height: 24),
            const Text(
              "Enter your WebDAV details (Alist, Nextcloud...) to sync watch history.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _urlController,
              focusNode: _urlFocus,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'WebDAV URL',
                hintText: 'E.g.: https://alist.domain.com/dav/',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userController,
              focusNode: _userFocus,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              focusNode: _passFocus,
              textInputAction: TextInputAction.next,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pathController,
              focusNode: _pathFocus,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Remote Sync Folder',
                hintText: 'E.g.: /CineStream',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isTesting ? null : _saveAndTest,
                child: _isTesting 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Connect & Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final logService = getIt<LogService>();
                  final success = await logService.uploadManual();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Logs uploaded successfully!' : 'Failed to upload logs. Ensure WebDAV is connected.'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                child: const Text("Upload Logs to WebDAV", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
