import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class TvControls extends StatefulWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekForward;
  final VoidCallback onSeekBackward;
  final VoidCallback onSubtitleToggle;
  final VoidCallback onSettings;
  final VoidCallback onBack;

  const TvControls({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.isBuffering,
    required this.onPlayPause,
    required this.onSeekForward,
    required this.onSeekBackward,
    required this.onSubtitleToggle,
    required this.onSettings,
    required this.onBack,
  });

  @override
  State<TvControls> createState() => _TvControlsState();
}

class _TvControlsState extends State<TvControls> {
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha:0.6),
      child: Stack(
        children: [
          // Top Bar
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildIconButton(Icons.arrow_back, widget.onBack),
                    const SizedBox(width: 16),
                    const Text(
                      'Video Title Here',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildIconButton(Icons.closed_caption, widget.onSubtitleToggle),
                    const SizedBox(width: 16),
                    _buildIconButton(Icons.settings, widget.onSettings),
                  ],
                )
              ],
            ),
          ),

          // Center Controls
          Center(
            child: widget.isBuffering 
              ? const CircularProgressIndicator(color: AppColors.primary)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIconButton(Icons.fast_rewind, widget.onSeekBackward, size: 48),
                    const SizedBox(width: 48),
                    _buildIconButton(
                      widget.isPlaying ? Icons.pause : Icons.play_arrow,
                      widget.onPlayPause,
                      size: 64,
                      autoFocus: true,
                    ),
                    const SizedBox(width: 48),
                    _buildIconButton(Icons.fast_forward, widget.onSeekForward, size: 48),
                  ],
                ),
          ),

          // Bottom Bar (Progress)
          Positioned(
            bottom: 24,
            left: 58,
            right: 58,
            child: Row(
              children: [
                Text(
                  _formatDuration(widget.position),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      thumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white.withValues(alpha:0.3),
                      trackHeight: 4.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    ),
                    child: Slider(
                      value: widget.position.inSeconds.toDouble(),
                      max: widget.duration.inSeconds.toDouble() > 0 ? widget.duration.inSeconds.toDouble() : 1.0,
                      onChanged: (val) {}, // Read-only for TV, seek via buttons
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatDuration(widget.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {double size = 32, bool autoFocus = false}) {
    return Builder(
      builder: (context) {
        bool isFocused = false;
        return StatefulBuilder(
          builder: (context, setBtnState) {
            return Focus(
              autofocus: autoFocus,
              onFocusChange: (focused) => setBtnState(() => isFocused = focused),
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
                  onTap();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFocused ? Colors.white.withValues(alpha:0.2) : Colors.transparent,
                    border: Border.all(
                      color: isFocused ? AppColors.focusBorder : Colors.transparent,
                      width: 2,
                    )
                  ),
                  child: Icon(
                    icon,
                    color: isFocused ? Colors.white : Colors.white70,
                    size: size,
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
