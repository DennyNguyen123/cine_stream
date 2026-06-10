import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/webdav_service.dart';
import '../../../data/services/log_service.dart';
import '../../../di/injection.dart';
import '../settings/mobile_sync_screen.dart';
import '../settings/tv_sync_screen.dart';
import '../../../domain/services/tts_service.dart';
import '../../../data/services/tts/native_tts_impl.dart';
import '../../widgets/ui_helpers.dart';

class WebdavSetupScreen extends StatefulWidget {
  const WebdavSetupScreen({Key? key}) : super(key: key);

  @override
  State<WebdavSetupScreen> createState() => _WebdavSetupScreenState();
}

class _WebdavSetupScreenState extends State<WebdavSetupScreen> {
  // WebDAV Controllers
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _pathController = TextEditingController();

  // TTS Controllers
  final _ttsUrlController = TextEditingController();
  final _ttsKeyController = TextEditingController();
  final _ttsModelController = TextEditingController();
  final _ttsVoiceController = TextEditingController();

  // WebDAV Focus Nodes
  final _urlFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _pathFocus = FocusNode();

  // TTS Focus Nodes
  final _ttsEngineFocus = FocusNode();
  final _ttsUrlFocus = FocusNode();
  final _ttsKeyFocus = FocusNode();
  final _ttsModelFocus = FocusNode();
  final _ttsVoiceFocus = FocusNode();

  bool _isTesting = false;
  String _ttsEngine = 'native';
  String _ttsVoice = 'alloy';
  List<String> _systemVoices = [];

  // General Settings
  String _ttsTargetLang = 'vi';
  double _ttsDelayMs = 0.0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadSystemVoices();

    _urlFocus.onKeyEvent = _handleKeyEvent;
    _userFocus.onKeyEvent = _handleKeyEvent;
    _passFocus.onKeyEvent = _handleKeyEvent;
    _pathFocus.onKeyEvent = _handleKeyEvent;

    _ttsEngineFocus.onKeyEvent = _handleKeyEvent;
    _ttsUrlFocus.onKeyEvent = _handleKeyEvent;
    _ttsKeyFocus.onKeyEvent = _handleKeyEvent;
    _ttsModelFocus.onKeyEvent = _handleKeyEvent;
    _ttsVoiceFocus.onKeyEvent = _handleKeyEvent;
  }

  void _loadSystemVoices() async {
    try {
      final voices = await getIt<NativeTtsImpl>().getVoices();
      if (mounted) {
        setState(() {
          _systemVoices = voices;
          if (_ttsEngine == 'native' && (_ttsVoice.isEmpty || !_systemVoices.contains(_ttsVoice))) {
            if (_systemVoices.isNotEmpty) {
              _ttsVoice = _systemVoices.first;
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();

    _ttsUrlController.dispose();
    _ttsKeyController.dispose();
    _ttsModelController.dispose();
    _ttsVoiceController.dispose();

    _urlFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _pathFocus.dispose();

    _ttsEngineFocus.dispose();
    _ttsUrlFocus.dispose();
    _ttsKeyFocus.dispose();
    _ttsModelFocus.dispose();
    _ttsVoiceFocus.dispose();
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

    _ttsEngine = prefs.getString('tts_engine') ?? 'native';
    _ttsUrlController.text = prefs.getString('tts_base_url') ?? 'https://api.openai.com/v1';
    _ttsKeyController.text = prefs.getString('tts_api_key') ?? '';
    _ttsModelController.text = prefs.getString('tts_model') ?? 'tts-1';
    _ttsVoice = prefs.getString('tts_voice') ?? '';
    if (prefs.getString('tts_voice') == null) {
      _ttsVoice = _ttsEngine == 'native' ? '' : 'alloy';
    }
    _ttsVoiceController.text = _ttsVoice;

    _ttsTargetLang = prefs.getString('tts_target_lang') ?? 'vi';
    _ttsDelayMs = prefs.getDouble('tts_delay_ms') ?? 0.0;
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isTesting = true);

    final url = _urlController.text.trim();
    final user = _userController.text.trim();
    final pass = _passController.text.trim();
    final path = _pathController.text.trim();

    // 1. Lưu & Kiểm tra WebDAV
    final webdav = getIt<WebDAVService>();
    webdav.init(url, user, pass, folderPath: path);

    final success = await webdav.ping();

    // 2. Lưu cài đặt TTS vào SharedPreferences
    if (_ttsEngine == 'openai') {
      _ttsVoice = _ttsVoiceController.text.trim();
    }
    final prefs = getIt<SharedPreferences>();
    await prefs.setString('tts_engine', _ttsEngine);
    await prefs.setString('tts_base_url', _ttsUrlController.text.trim());
    await prefs.setString('tts_api_key', _ttsKeyController.text.trim());
    await prefs.setString('tts_model', _ttsModelController.text.trim());
    await prefs.setString('tts_voice', _ttsVoice);

    await prefs.setString('tts_target_lang', _ttsTargetLang);
    await prefs.setDouble('tts_delay_ms', _ttsDelayMs);

    setState(() => _isTesting = false);

    if (success) {
      await prefs.setString('cinestream_webdav_url', url);
      await prefs.setString('cinestream_webdav_user', user);
      await prefs.setString('cinestream_webdav_pass', pass);
      await prefs.setString('cinestream_webdav_path', path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved, but WebDAV connection failed.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOpenAiFields = _ttsEngine == 'openai';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION 1: GENERAL SETTINGS
            _buildSectionHeader("General Settings"),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _ttsTargetLang,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'Voice-over Target Language',
                labelStyle: const TextStyle(color: AppColors.textDim),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: 'vi', child: Text('Vietnamese (vi)')),
                DropdownMenuItem(value: 'en', child: Text('English (en)')),
                DropdownMenuItem(value: 'ja', child: Text('Japanese (ja)')),
                DropdownMenuItem(value: 'ko', child: Text('Korean (ko)')),
                DropdownMenuItem(value: 'zh', child: Text('Chinese (zh)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _ttsTargetLang = val);
              },
            ),
            const SizedBox(height: 16),
            Text('Voice-over Delay: ${_ttsDelayMs.toInt()} ms', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _ttsDelayMs,
                    min: -5000,
                    max: 5000,
                    divisions: 100,
                    label: '${_ttsDelayMs.toInt()} ms',
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (val) {
                      setState(() => _ttsDelayMs = val);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.restore, color: AppColors.textDim),
                  tooltip: 'Reset Delay',
                  onPressed: () => setState(() => _ttsDelayMs = 0),
                )
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 4.0),
              child: Text(
                'Adjust delay if voice-over is out of sync with video. Positive value delays voice.',
                style: TextStyle(color: AppColors.textDim, fontSize: 12),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: AppColors.border),
            const SizedBox(height: 24),

            // SECTION 2: QUICK SYNC
            _buildSectionHeader("Quick Sync via QR"),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    autofocus: true,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code, color: AppColors.text),
                    label: const Text("Show QR", style: TextStyle(color: AppColors.text)),
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
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.text),
                    label: const Text("Scan QR", style: TextStyle(color: AppColors.text)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileSyncScreen()));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(color: AppColors.border),
            const SizedBox(height: 24),

            // SECTION 2: WEBDAV CONFIG
            _buildSectionHeader("WebDAV Configuration"),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              focusNode: _urlFocus,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'WebDAV URL',
                hintText: 'E.g.: https://alist.domain.com/dav/',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userController,
              focusNode: _userFocus,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              focusNode: _passFocus,
              textInputAction: TextInputAction.next,
              obscureText: true,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pathController,
              focusNode: _pathFocus,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Remote Sync Folder',
                hintText: 'E.g.: /CineStream',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: AppColors.border),
            const SizedBox(height: 24),

            // SECTION 3: VOICE-OVER CONFIG
            _buildSectionHeader("Voice-over Settings"),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('tts_engine_dropdown'),
              value: _ttsEngine,
              focusNode: _ttsEngineFocus,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.text, fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Voice-over Engine',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
              items: const [
                DropdownMenuItem(value: 'native', child: Text('System Default')),
                DropdownMenuItem(value: 'openai', child: Text('OpenAI Compatible')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _ttsEngine = val;
                    if (val == 'native') {
                      _ttsVoice = _systemVoices.isNotEmpty ? _systemVoices.first : '';
                    } else {
                      _ttsVoice = 'alloy';
                    }
                    _ttsVoiceController.text = _ttsVoice;
                  });
                }
              },
            ),
            if (showOpenAiFields) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _ttsUrlController,
                focusNode: _ttsUrlFocus,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'OpenAI Base URL',
                  hintText: 'E.g.: https://api.openai.com/v1',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ttsKeyController,
                focusNode: _ttsKeyFocus,
                textInputAction: TextInputAction.next,
                obscureText: true,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'OpenAI API Key',
                  hintText: 'Enter API Key',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ttsModelController,
                focusNode: _ttsModelFocus,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'TTS Model',
                  hintText: 'tts-1 or tts-1-hd',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ttsVoiceController,
                focusNode: _ttsVoiceFocus,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'TTS Voice',
                  hintText: 'alloy, echo, or custom (leave empty if not needed)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
            ] else ...[
              // System Default Engine Voice Selection
              if (_systemVoices.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _systemVoices.contains(_ttsVoice) ? _ttsVoice : _systemVoices.first,
                  focusNode: _ttsVoiceFocus,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'System TTS Voice',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                  items: _systemVoices.map((voice) {
                    return DropdownMenuItem(value: voice, child: Text(voice));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() { 
                        _ttsVoice = val; 
                      });
                    }
                  },
                ),
              ],
            ],
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.volume_up, color: AppColors.primary),
                label: const Text("Review Voice", style: TextStyle(color: AppColors.primary)),
                onPressed: () async {
                  // Lưu tạm cấu hình vào SharedPreferences để Engine đọc được ngay
                  if (_ttsEngine == 'openai') {
                    _ttsVoice = _ttsVoiceController.text.trim();
                  }
                  final prefs = getIt<SharedPreferences>();
                  await prefs.setString('tts_engine', _ttsEngine);
                  await prefs.setString('tts_base_url', _ttsUrlController.text.trim());
                  await prefs.setString('tts_api_key', _ttsKeyController.text.trim());
                  await prefs.setString('tts_model', _ttsModelController.text.trim());
                  await prefs.setString('tts_voice', _ttsVoice);

                  // Phát thử giọng đọc
                  String reviewText = "This is a test of Cine Stream voice-over.";
                  if (_ttsTargetLang == 'vi') {
                    reviewText = "Xin chào, đây là giọng đọc thử nghiệm.";
                  } else if (_ttsTargetLang == 'ja') {
                    reviewText = "こんにちは、これは音声テストです。";
                  } else if (_ttsTargetLang == 'ko') {
                    reviewText = "안녕하세요, 이것은 음성 테스트입니다.";
                  } else if (_ttsTargetLang == 'zh') {
                    reviewText = "你好，这是语音测试。";
                  }

                  await getIt<TtsService>().speak(
                    reviewText,
                    durationMs: 0,
                    videoPlaybackSpeed: 1.0,
                    languageCode: _ttsTargetLang,
                  );
                },
              ),
            ),
            const SizedBox(height: 40),

            // BUTTON SAVE
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isTesting ? null : _saveAllSettings,
                child: _isTesting 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Save Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),

            // BUTTON UPLOAD LOGS
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
