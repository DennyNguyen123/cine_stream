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
  final FocusNode _topNode = FocusNode();
  final FocusNode _bottomNode = FocusNode();

  @override
  void dispose() {
    _topNode.dispose();
    _bottomNode.dispose();
    super.dispose();
  }

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
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _bottomNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: _buildFocusableTile(
              focusNode: _topNode,
              title: 'Auto Next Episode',
              subtitle: _autoNext ? 'On' : 'Off',
              onTap: () {
                setState(() {
                  _autoNext = !_autoNext;
                });
                widget.onAutoNextChanged(_autoNext);
              },
            ),
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
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Voice-over Delay', style: TextStyle(color: Colors.white70, fontSize: 16)),
              Row(
                children: [
                  _buildDelayButton(Icons.remove, () {
                    setState(() {
                      _ttsDelayMs -= 100;
                      if (_ttsDelayMs < -5000) _ttsDelayMs = -5000;
                    });
                    getIt<SharedPreferences>().setDouble('tts_delay_ms', _ttsDelayMs);
                  }),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${_ttsDelayMs.toInt()} ms', 
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDelayButton(Icons.add, () {
                    setState(() {
                      _ttsDelayMs += 100;
                      if (_ttsDelayMs > 5000) _ttsDelayMs = 5000;
                    });
                    getIt<SharedPreferences>().setDouble('tts_delay_ms', _ttsDelayMs);
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
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
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _topNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _speeds.length,
                itemBuilder: (context, index) {
                  final s = _speeds[index];
                  final isSelected = s == _speed;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: _buildSpeedItem(s, isSelected, index == 0 ? _bottomNode : null),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusableTile({FocusNode? focusNode, required String title, required String subtitle, required VoidCallback onTap}) {
    return Builder(
      builder: (context) {
        bool isFocused = false;
        return StatefulBuilder(
          builder: (context, setTileState) {
            return Focus(
              focusNode: focusNode,
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
                    color: isFocused ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFocused ? AppColors.primary : Colors.white24,
                      width: isFocused ? 2 : 1,
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

  Widget _buildSpeedItem(double speed, bool isSelected, FocusNode? focusNode) {
    return Builder(
      builder: (context) {
        bool isFocused = false;
        return StatefulBuilder(
          builder: (context, setBtnState) {
            return Focus(
              focusNode: focusNode,
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
                    color: isSelected ? AppColors.primary : (isFocused ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFocused ? AppColors.primary : Colors.transparent,
                      width: isFocused ? 2 : 1,
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
  Widget _buildDelayButton(IconData icon, VoidCallback onTap) {
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
                  onTap();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFocused ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFocused ? AppColors.primary : Colors.white24,
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: Icon(icon, color: isFocused ? AppColors.primary : Colors.white, size: 20),
                ),
              ),
            );
          }
        );
      }
    );
  }
}
