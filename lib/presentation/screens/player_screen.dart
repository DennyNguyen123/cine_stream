import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/tv_controls.dart';
import 'package:dio/dio.dart';
import '../widgets/subtitle_display.dart';
import '../widgets/subtitle_settings.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/subtitle.dart';
import '../../core/utils/subtitle_parser.dart';

class PlayerScreen extends StatefulWidget {
  final StreamInfo streamInfo;

  const PlayerScreen({super.key, required this.streamInfo});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = true;
  bool _isBuffering = true;

  List<SubtitleCue> _primaryCues = [];
  List<SubtitleCue> _secondaryCues = [];
  SubtitleCue? _currentPrimaryCue;
  SubtitleCue? _currentSecondaryCue;
  SubtitleTrack? _selectedSub;
  SubtitleTrack? _selectedSecondarySub;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamInfo.videoUrl),
      httpHeaders: {
        'Referer': 'https://kisskh.co/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    )..initialize().then((_) {
        setState(() {
          _duration = _controller.value.duration;
        });
        _controller.play();
      });

    _controller.addListener(_videoListener);
    _startControlsTimer();
    
    if (widget.streamInfo.subtitles.isNotEmpty) {
      final defaultSub = widget.streamInfo.subtitles.firstWhere(
        (s) => s.label.toLowerCase().contains('english'),
        orElse: () => widget.streamInfo.subtitles.first,
      );
      _fetchSubtitles(defaultSub, true);
      
      try {
        final vnSub = widget.streamInfo.subtitles.firstWhere(
          (s) => s.label.toLowerCase().contains('viet') || s.label.toLowerCase().contains('việt'),
        );
        _fetchSubtitles(vnSub, false);
      } catch (e) {
        debugPrint('Auto-fetch vietnamese subtitle error: $e');
      }
    }
  }

  Future<void> _fetchSubtitles(SubtitleTrack sub, bool isTop) async {
    try {
      final response = await Dio().get(sub.src);
      final parsedCues = SubtitleParser.parse(response.data.toString());
      
      if (mounted) {
        setState(() {
          if (isTop) {
            _selectedSub = sub;
            _primaryCues = parsedCues;
          } else {
            _selectedSecondarySub = sub;
            _secondaryCues = parsedCues;
          }
        });
      }
    } catch (e) {
      debugPrint('Subtitle fetch error: $e');
    }
  }

  void _videoListener() {
    if (!mounted) return;
    
    final posMs = _controller.value.position.inMilliseconds;
    SubtitleCue? activePrimary;
    SubtitleCue? activeSecondary;
    
    // Quick search for current primary subtitle cue
    for (var cue in _primaryCues) {
      if (posMs >= cue.startMs && posMs <= cue.endMs) {
        activePrimary = cue;
        break;
      }
    }

    // Quick search for current secondary subtitle cue
    for (var cue in _secondaryCues) {
      if (posMs >= cue.startMs && posMs <= cue.endMs) {
        activeSecondary = cue;
        break;
      }
    }

    setState(() {
      _position = _controller.value.position;
      _duration = _controller.value.duration;
      _isPlaying = _controller.value.isPlaying;
      _isBuffering = _controller.value.isBuffering;
      _currentPrimaryCue = activePrimary;
      _currentSecondaryCue = activeSecondary;
    });
  }

  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            // Wake up controls
            if (!_showControls) {
              _toggleControls();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_showControls) {
              _toggleControls();
            }
          },
          child: Stack(
            children: [
              // Video Player
              Center(
                child: _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const CircularProgressIndicator(color: AppColors.primary),
              ),
              
              // Subtitles Overlay
              Positioned.fill(
                child: DualSubtitleDisplay(
                  topCue: _currentPrimaryCue,
                  bottomCue: _currentSecondaryCue,
                  isDualEnabled: (_currentPrimaryCue != null && _currentSecondaryCue != null),
                ),
              ),

              // Controls Overlay
              if (_showControls)
                Positioned.fill(
                  child: TvControls(
                    isPlaying: _isPlaying,
                    position: _position,
                    duration: _duration,
                    isBuffering: _isBuffering,
                    onPlayPause: () {
                      _isPlaying ? _controller.pause() : _controller.play();
                    },
                    onSeekForward: () {
                      final newPos = _position + const Duration(seconds: 10);
                      _controller.seekTo(newPos);
                    },
                    onSeekBackward: () {
                      final newPos = _position - const Duration(seconds: 10);
                      _controller.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
                    },
                    onSubtitleToggle: () {
                      showDialog(
                        context: context,
                        builder: (context) => _buildSubtitleSelectionDialog(context),
                      );
                    },
                    onSettings: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: const SubtitleSettingsDialog(),
                        ),
                      );
                    },
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleSelectionDialog(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Container(
        width: 400,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Dual Subtitles Selection', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text('Top Subtitle', style: TextStyle(color: Colors.white)),
              subtitle: Text(_selectedSub?.label ?? 'Off', style: const TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showLanguageListDialog(context, true);
              },
            ),
            ListTile(
              title: const Text('Bottom Subtitle', style: TextStyle(color: Colors.white)),
              subtitle: Text(_selectedSecondarySub?.label ?? 'Off', style: const TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showLanguageListDialog(context, false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageListDialog(BuildContext context, bool isTop) {
    // Determine available subtitles and inject "Vietnamese (Translate)" if missing
    List<SubtitleTrack> availableSubs = List.from(widget.streamInfo.subtitles);
    bool hasViet = availableSubs.any((s) => s.label.toLowerCase().contains('viet') || s.label.toLowerCase().contains('việt'));
    
    if (!hasViet) {
      availableSubs.add(const SubtitleTrack(
        id: -1, 
        label: 'Vietnamese (Translate)', 
        src: 'translate_vi'
      ));
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableSubs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: const Text('Off', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() {
                      if (isTop) {
                        _selectedSub = null;
                        _primaryCues = [];
                      } else {
                        _selectedSecondarySub = null;
                        _secondaryCues = [];
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }
              
              final sub = availableSubs[index - 1];
              return ListTile(
                title: Text(sub.label, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  if (sub.src == 'translate_vi') {
                    // Translation logic to be implemented
                    debugPrint("Translate to Vietnamese selected");
                  } else {
                    _fetchSubtitles(sub, isTop);
                  }
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
