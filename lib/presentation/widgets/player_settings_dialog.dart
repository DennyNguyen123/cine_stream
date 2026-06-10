import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../di/injection.dart';
import '../../../core/theme/app_colors.dart';

class PlayerSettingsDialog extends StatefulWidget {
  final double currentSpeed;
  final bool autoNext;
  final bool debugMode;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onAutoNextChanged;
  final ValueChanged<bool> onDebugModeChanged;
  final VoidCallback onVoiceOverSettings;

  const PlayerSettingsDialog({
    super.key,
    required this.currentSpeed,
    required this.autoNext,
    required this.debugMode,
    required this.onSpeedChanged,
    required this.onAutoNextChanged,
    required this.onDebugModeChanged,
    required this.onVoiceOverSettings,
  });

  @override
  State<PlayerSettingsDialog> createState() => _PlayerSettingsDialogState();
}

class _PlayerSettingsDialogState extends State<PlayerSettingsDialog> {
  late double _speed;
  late bool _autoNext;
  late bool _debugMode;
  String _ttsTargetLang = 'vi';
  double _ttsDelayMs = 0.0;

  final List<double> _speeds = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _speed = widget.currentSpeed;
    _autoNext = widget.autoNext;
    _debugMode = widget.debugMode;
    final prefs = getIt<SharedPreferences>();
    _ttsTargetLang = prefs.getString('tts_target_lang') ?? 'vi';
    _ttsDelayMs = prefs.getDouble('tts_delay_ms') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Player Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Auto Next Toggle
          _buildFocusableTile(
            title: 'Auto Next Episode',
            subtitle: _autoNext ? 'On' : 'Off',
            onTap: () {
              setState(() {
                _autoNext = !_autoNext;
              });
              widget.onAutoNextChanged(_autoNext);
            },
          ),
          const SizedBox(height: 16),
          
          // Debug Stats Toggle
          _buildFocusableTile(
            title: 'Debug Stats',
            subtitle: _debugMode ? 'On' : 'Off',
            onTap: () {
              setState(() {
                _debugMode = !_debugMode;
              });
              widget.onDebugModeChanged(_debugMode);
            },
          ),
          const SizedBox(height: 16),
          
          // Voice-over Target Language
          const Text('Voice-over Language', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _ttsTargetLang,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white12,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(value: 'vi', child: Text('Vietnamese (vi)')),
              DropdownMenuItem(value: 'en', child: Text('English (en)')),
              DropdownMenuItem(value: 'ja', child: Text('Japanese (ja)')),
              DropdownMenuItem(value: 'ko', child: Text('Korean (ko)')),
              DropdownMenuItem(value: 'zh', child: Text('Chinese (zh)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _ttsTargetLang = val);
                getIt<SharedPreferences>().setString('tts_target_lang', val);
              }
            },
          ),
          const SizedBox(height: 16),

          // Voice-over Delay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Voice-over Delay', style: TextStyle(color: Colors.white70, fontSize: 16)),
              Text('${_ttsDelayMs.toInt()} ms', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Slider(
            value: _ttsDelayMs,
            min: -5000,
            max: 5000,
            divisions: 20,
            activeColor: AppColors.primary,
            inactiveColor: Colors.white24,
            onChanged: (val) {
              setState(() => _ttsDelayMs = val);
            },
            onChangeEnd: (val) {
              getIt<SharedPreferences>().setDouble('tts_delay_ms', val);
            },
          ),
          const SizedBox(height: 4),
          
          // Voice-over Advanced Settings Button
          _buildFocusableTile(
            title: 'TTS Advanced Settings',
            subtitle: 'Engine & API',
            onTap: widget.onVoiceOverSettings,
          ),
          const SizedBox(height: 16),
          
          // Speed Selection
          const Text(
            'Playback Speed',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _speeds.length,
              itemBuilder: (context, index) {
                final s = _speeds[index];
                final isSelected = s == _speed;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: _buildSpeedItem(s, isSelected),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusableTile({required String title, required String subtitle, required VoidCallback onTap}) {
    return Builder(
      builder: (context) {
        bool isFocused = false;
        return StatefulBuilder(
          builder: (context, setTileState) {
            return Focus(
              onFocusChange: (focused) => setTileState(() => isFocused = focused),
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && 
                   (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
                  onTap();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isFocused ? Colors.white12 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFocused ? AppColors.primary : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subtitle, 
                          style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSpeedItem(double speed, bool isSelected) {
    return Builder(
      builder: (context) {
        bool isFocused = false;
        return StatefulBuilder(
          builder: (context, setBtnState) {
            return Focus(
              onFocusChange: (focused) => setBtnState(() => isFocused = focused),
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && 
                   (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
                  setState(() => _speed = speed);
                  widget.onSpeedChanged(speed);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () {
                  setState(() => _speed = speed);
                  widget.onSpeedChanged(speed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : (isFocused ? Colors.white24 : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFocused && !isSelected ? Colors.white : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }
}
