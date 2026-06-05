import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import 'marquee_text.dart';

class TvControls extends StatefulWidget {
  final String title;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  final VoidCallback onPlayPause;
  final VoidCallback onSubtitleToggle;
  final VoidCallback onSettings;
  final VoidCallback onEpisodes;
  final VoidCallback onServerToggle;
  final VoidCallback onBack;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
  final ValueChanged<int>? onSeek;

  const TvControls({
    super.key,
    required this.title,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.isBuffering,
    required this.onPlayPause,
    required this.onSubtitleToggle,
    required this.onSettings,
    required this.onEpisodes,
    required this.onServerToggle,
    required this.onBack,
    this.onPrevEpisode,
    this.onNextEpisode,
    this.onSeek,
  });

  @override
  State<TvControls> createState() => _TvControlsState();
}

class _TvControlsState extends State<TvControls> {
  final FocusNode _playPauseNode = FocusNode();

  @override
  void dispose() {
    _playPauseNode.dispose();
    super.dispose();
  }
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Bar
          Padding(
            padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildIconButton(Icons.arrow_back, widget.onBack, downFocusNode: _playPauseNode),
                      const SizedBox(width: 16),
                      Expanded(
                        child: MarqueeText(
                          text: widget.title,
                          isFocused: true,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildIconButton(Icons.list, widget.onEpisodes, downFocusNode: _playPauseNode),
                    const SizedBox(width: 16),
                    _buildIconButton(Icons.dns, widget.onServerToggle, downFocusNode: _playPauseNode),
                    const SizedBox(width: 16),
                    _buildIconButton(Icons.closed_caption, widget.onSubtitleToggle, downFocusNode: _playPauseNode),
                    const SizedBox(width: 16),
                    _buildIconButton(Icons.settings, widget.onSettings, downFocusNode: _playPauseNode),
                  ],
                )
              ],
            ),
          ),

          // Center Controls
          Expanded(
            child: Center(
              child: widget.isBuffering 
                ? const CircularProgressIndicator(color: AppColors.primary)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.onPrevEpisode != null) ...[
                        _buildIconButton(Icons.skip_previous, widget.onPrevEpisode!, size: 48, key: const ValueKey('prev_ep')),
                        const SizedBox(width: 32),
                      ],
                      _buildIconButton(
                        widget.isPlaying ? Icons.pause : Icons.play_arrow,
                        widget.onPlayPause,
                        size: 64,
                        autoFocus: true,
                        key: const ValueKey('play_pause'),
                        focusNode: _playPauseNode,
                      ),
                      if (widget.onNextEpisode != null) ...[
                        const SizedBox(width: 32),
                        _buildIconButton(Icons.skip_next, widget.onNextEpisode!, size: 48, key: const ValueKey('next_ep')),
                      ],
                    ],
                  ),
            ),
          ),

          // Bottom Bar (Progress)
          Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 58, right: 58),
            child: Row(
              children: [
                Text(
                  _formatDuration(widget.position),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TvSlider(
                    position: widget.position,
                    duration: widget.duration,
                    onSeek: widget.onSeek,
                    upFocusNode: _playPauseNode,
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

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {double size = 32, bool autoFocus = false, Key? key, FocusNode? focusNode, FocusNode? downFocusNode}) {
    return _TvControlButton(
      key: key,
      icon: icon,
      onTap: onTap,
      size: size,
      autoFocus: autoFocus,
      focusNode: focusNode,
      downFocusNode: downFocusNode,
    );
  }
}

class _TvControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool autoFocus;
  final FocusNode? focusNode;
  final FocusNode? downFocusNode;

  const _TvControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 32,
    this.autoFocus = false,
    this.focusNode,
    this.downFocusNode,
  });

  @override
  State<_TvControlButton> createState() => _TvControlButtonState();
}

class _TvControlButtonState extends State<_TvControlButton> {
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown && widget.downFocusNode != null) {
            widget.downFocusNode!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.diagonal3Values(_isFocused ? 1.1 : 1.0, _isFocused ? 1.1 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isFocused ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: Icon(
            widget.icon,
            color: _isFocused ? Colors.white : Colors.white70,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

class _TvSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Function(int)? onSeek;
  final FocusNode? upFocusNode;

  const _TvSlider({
    required this.position,
    required this.duration,
    this.onSeek,
    this.upFocusNode,
  });

  @override
  State<_TvSlider> createState() => _TvSliderState();
}

class _TvSliderState extends State<_TvSlider> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp && widget.upFocusNode != null) {
            widget.upFocusNode!.requestFocus();
            return KeyEventResult.handled;
          }
          if (widget.onSeek != null) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              widget.onSeek!(-10);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              widget.onSeek!(10);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _isFocused ? Colors.white : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SliderTheme(
          data: SliderThemeData(
            thumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
          ),
          child: ExcludeFocus(
            child: Slider(
              value: widget.position.inSeconds.toDouble(),
              max: widget.duration.inSeconds.toDouble() > 0 ? widget.duration.inSeconds.toDouble() : 1.0,
              onChanged: (val) {}, // Read-only for TV, seek via buttons
            ),
          ),
        ),
      ),
    );
  }
}
