import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/tv_controls.dart';
import 'package:dio/dio.dart';
import '../widgets/subtitle_display.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/subtitle.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/entities/episode.dart';
import '../../core/utils/subtitle_parser.dart';
import '../../data/repositories/translation_service.dart';
import '../../data/repositories/history_repository.dart';
import '../../domain/repositories/movie_source.dart';
import '../../di/injection.dart';
import '../widgets/player_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerScreen extends StatefulWidget {
  final StreamInfo streamInfo;
  final String title;
  final int movieId;
  final String movieTitle;
  final String? thumbnail;
  final int episodeId;
  final double episodeNumber;
  final int startPositionMs;
  final List<Episode> allEpisodes;

  const PlayerScreen({
    super.key,
    required this.streamInfo,
    required this.title,
    required this.movieId,
    required this.movieTitle,
    this.thumbnail,
    required this.episodeId,
    required this.episodeNumber,
    this.startPositionMs = 0,
    this.allEpisodes = const [],
  });

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
  final FocusNode _playerFocusNode = FocusNode();
  final FocusScopeNode _controlsScopeNode = FocusScopeNode();
  
  bool _isSeeking = false;
  bool _isPopping = false;
  Duration _targetSeekPosition = Duration.zero;
  Timer? _seekDebounceTimer;
  Timer? _hideControlsTimer;

  List<SubtitleCue> _primaryCues = [];
  List<SubtitleCue> _secondaryCues = [];
  SubtitleCue? _currentPrimaryCue;
  SubtitleCue? _currentSecondaryCue;
  SubtitleTrack? _selectedSub;
  SubtitleTrack? _selectedSecondarySub;

  int _backPressCount = 0;
  Timer? _backPressTimer;

  bool _autoNext = true;
  double _playbackSpeed = 1.0;
  bool _isChangingEpisode = false;

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
        if (widget.startPositionMs > 0) {
          _controller.seekTo(Duration(milliseconds: widget.startPositionMs));
        }
        _controller.setPlaybackSpeed(_playbackSpeed);
        _controller.play();
      });

    final prefs = getIt<SharedPreferences>();
    _autoNext = prefs.getBool('auto_next') ?? true;
    _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;

    _controller.addListener(_videoListener);
    _startControlsTimer();
    
    // Periodically save history every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _saveHistory();
    });
    
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

  Future<void> _translateSubtitles(SubtitleTrack targetSub, bool isTop) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Translating... this may take a moment')));
    
    try {
      if (widget.streamInfo.subtitles.isEmpty) {
        throw Exception("No source subtitles available to translate from.");
      }
      
      final engSub = widget.streamInfo.subtitles.firstWhere(
        (s) => s.label.toLowerCase().contains('english'),
        orElse: () => widget.streamInfo.subtitles.first,
      );
      
      final response = await Dio().get(engSub.src);
      final parsedCues = SubtitleParser.parse(response.data.toString());
      
      final translator = getIt<TranslationService>();
      List<SubtitleCue> translatedCues = [];
      
      List<String> currentBatch = [];
      int currentCharCount = 0;
      List<SubtitleCue> currentCueBatch = [];
      
      for (var cue in parsedCues) {
        if (currentCharCount + cue.text.length > 3000) {
          final translatedTexts = await translator.translateBatch(currentBatch, targetLang: 'vi');
          for (int i = 0; i < currentCueBatch.length; i++) {
            translatedCues.add(SubtitleCue(
              startMs: currentCueBatch[i].startMs,
              endMs: currentCueBatch[i].endMs,
              text: i < translatedTexts.length ? translatedTexts[i] : currentCueBatch[i].text,
            ));
          }
          currentBatch.clear();
          currentCueBatch.clear();
          currentCharCount = 0;
        }
        currentBatch.add(cue.text);
        currentCueBatch.add(cue);
        currentCharCount += cue.text.length + 3;
      }
      
      if (currentBatch.isNotEmpty) {
          final translatedTexts = await translator.translateBatch(currentBatch, targetLang: 'vi');
          for (int i = 0; i < currentCueBatch.length; i++) {
            translatedCues.add(SubtitleCue(
              startMs: currentCueBatch[i].startMs,
              endMs: currentCueBatch[i].endMs,
              text: i < translatedTexts.length ? translatedTexts[i] : currentCueBatch[i].text,
            ));
          }
      }
      
      if (mounted) {
        setState(() {
          if (isTop) {
            _selectedSub = targetSub;
            _primaryCues = translatedCues;
          } else {
            _selectedSecondarySub = targetSub;
            _secondaryCues = translatedCues;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Translation applied!')));
      }
    } catch (e) {
      debugPrint('Translate error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Translation failed: $e')));
      }
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

    if (_duration.inMilliseconds > 0 && _position >= _duration && _autoNext && !_isChangingEpisode) {
      _playNextEpisode();
    }
  }

  void _playNextEpisode() {
    if (widget.allEpisodes.isEmpty) return;
    
    final sortedEpisodes = widget.allEpisodes.toList()..sort((a, b) => a.number.compareTo(b.number));
    final currentIndex = sortedEpisodes.indexWhere((e) => e.number == widget.episodeNumber);
    if (currentIndex != -1 && currentIndex < sortedEpisodes.length - 1) {
      final nextEp = sortedEpisodes[currentIndex + 1];
      _changeEpisode(nextEp);
    }
  }

  void _playPrevEpisode() {
    if (widget.allEpisodes.isEmpty) return;
    
    final sortedEpisodes = widget.allEpisodes.toList()..sort((a, b) => a.number.compareTo(b.number));
    final currentIndex = sortedEpisodes.indexWhere((e) => e.number == widget.episodeNumber);
    if (currentIndex > 0) {
      final prevEp = sortedEpisodes[currentIndex - 1];
      _changeEpisode(prevEp);
    }
  }

  void _changeEpisode(Episode nextEp) async {
    setState(() {
      _isChangingEpisode = true;
      _showControls = false;
    });
    
    _controller.pause();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final source = getIt<MovieSource>();
      final streamInfo = await source.getStreamInfo(widget.movieId, nextEp.id);
      
      if (!mounted) return;
      
      Navigator.pop(context); // hide loading
      
      if (streamInfo != null) {
        final title = '${widget.movieTitle} - Tập ${nextEp.number.toInt()}';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(
            streamInfo: streamInfo, 
            title: title,
            movieId: widget.movieId,
            movieTitle: widget.movieTitle,
            thumbnail: widget.thumbnail,
            episodeId: nextEp.id,
            episodeNumber: nextEp.number,
            startPositionMs: 0,
            allEpisodes: widget.allEpisodes,
          )),
        );
      } else {
        setState(() => _isChangingEpisode = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load next episode')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isChangingEpisode = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _startControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isPlaying && ModalRoute.of(context)?.isCurrent == true) {
        setState(() => _showControls = false);
        _playerFocusNode.requestFocus();
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
      _controlsScopeNode.requestFocus();
    } else {
      _playerFocusNode.requestFocus();
    }
  }

  void _saveHistory() {
    if (!mounted || _duration.inMilliseconds == 0) return;
    
    final historyRepo = getIt<HistoryRepository>();
    historyRepo.saveHistory(HistoryItem(
      movieId: widget.movieId,
      movieTitle: widget.movieTitle,
      thumbnail: widget.thumbnail,
      episodeId: widget.episodeId,
      episodeNumber: widget.episodeNumber,
      positionMs: _position.inMilliseconds,
      durationMs: _duration.inMilliseconds,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      sourceId: 'kisskh',
    ));
  }

  @override
  void dispose() {
    _saveHistory();
    _seekDebounceTimer?.cancel();
    _hideControlsTimer?.cancel();
    _backPressTimer?.cancel();
    _controlsScopeNode.dispose();
    _playerFocusNode.dispose();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  void _handleBackPress() {
    if (_isPopping) return;

    if (!_isPlaying) {
       _exitPlayer();
       return;
    }

    _backPressCount++;
    if (_backPressCount >= 2) {
      _exitPlayer();
    } else {
      if (_showControls) {
         setState(() => _showControls = false);
         _playerFocusNode.requestFocus();
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bấm Back lần nữa để thoát'), duration: Duration(seconds: 2)),
      );
      _backPressTimer?.cancel();
      _backPressTimer = Timer(const Duration(seconds: 2), () {
        _backPressCount = 0;
      });
    }
  }

  void _exitPlayer() {
    if (_isPopping) return;
    setState(() => _isPopping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isPopping,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _playerFocusNode,
          onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            bool isSeekKey = event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight;
            
            // Allow focus traversal if controls are shown, unless we are already seeking
            if (isSeekKey) {
              if (_showControls && !_isSeeking) {
                 // We are showing controls, and not currently seeking.
                 // We should only intercept seek if the user is NOT focused on the Top Bar.
                 // A simple heuristic: if they press Left/Right, we let the Focus system try to handle it.
                 // BUT we can't easily do that. Let's just only seek if controls are hidden or already seeking.
                 // To allow them to seek while controls are shown, they can use D-pad.
                 // Actually, let's just intercept it ALWAYS, EXCEPT when focus is on the top bar?
                 // Let's just pass the seek logic down, or simpler: if controls are shown, Left/Right navigates. 
                 // If they want to seek, they wait for controls to hide, or we just allow it to bubble.
                 // Since they complained about focus, let's prioritize Focus Traversal!
                 return KeyEventResult.ignored;
              }
              
              if (!_showControls) {
                _toggleControls();
              }
              
              if (!_isSeeking) {
                _isSeeking = true;
                _targetSeekPosition = _position;
                if (_isPlaying) {
                  _controller.pause();
                }
              }
              
              final int seekStep = 10; // 10 seconds step
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _targetSeekPosition += Duration(seconds: seekStep);
              } else {
                _targetSeekPosition -= Duration(seconds: seekStep);
              }
              
              // Clamp position
              if (_targetSeekPosition < Duration.zero) {
                _targetSeekPosition = Duration.zero;
              } else if (_targetSeekPosition > _duration) {
                _targetSeekPosition = _duration;
              }
              
              setState(() {});
              
              _seekDebounceTimer?.cancel();
              _seekDebounceTimer = Timer(const Duration(seconds: 1), () {
                _controller.seekTo(_targetSeekPosition).then((_) {
                  if (mounted) {
                    setState(() {
                      _isSeeking = false;
                    });
                    _controller.play();
                  }
                });
              });
              
              return KeyEventResult.handled;
            }

            // Wake up controls on other keys
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
                  child: FocusScope(
                    node: _controlsScopeNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        _startControlsTimer();
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(
                      builder: (context) {
                        final sortedEpisodes = widget.allEpisodes.toList()..sort((a, b) => a.number.compareTo(b.number));
                        final currentIndex = sortedEpisodes.indexWhere((e) => e.number == widget.episodeNumber);
                        
                        VoidCallback? prevEpCallback;
                        if (currentIndex > 0) {
                          prevEpCallback = _playPrevEpisode;
                        }
                        
                        VoidCallback? nextEpCallback;
                        if (currentIndex != -1 && currentIndex < sortedEpisodes.length - 1) {
                          nextEpCallback = _playNextEpisode;
                        }

                        return TvControls(
                          title: widget.title,
                          isPlaying: _isPlaying,
                          position: _isSeeking ? _targetSeekPosition : _position,
                          duration: _duration,
                          isBuffering: _isBuffering,
                          onPrevEpisode: prevEpCallback,
                          onNextEpisode: nextEpCallback,
                          onSeek: (seconds) {
                            if (!_isSeeking) {
                              _isSeeking = true;
                              _targetSeekPosition = _position;
                              if (_isPlaying) {
                                _controller.pause();
                              }
                            }
                            
                            _targetSeekPosition += Duration(seconds: seconds);
                            if (_targetSeekPosition < Duration.zero) _targetSeekPosition = Duration.zero;
                            if (_targetSeekPosition > _duration) _targetSeekPosition = _duration;
                            
                            setState(() {});
                            
                            _seekDebounceTimer?.cancel();
                            _seekDebounceTimer = Timer(const Duration(seconds: 1), () {
                              _controller.seekTo(_targetSeekPosition).then((_) {
                                if (mounted) {
                                  setState(() {
                                    _isSeeking = false;
                                  });
                                  _controller.play();
                                }
                              });
                            });
                          },
                          onPlayPause: () {
                            if (_isSeeking) {
                              _seekDebounceTimer?.cancel();
                              _controller.seekTo(_targetSeekPosition).then((_) {
                                setState(() => _isSeeking = false);
                                _isPlaying ? _controller.pause() : _controller.play();
                              });
                            } else {
                              _isPlaying ? _controller.pause() : _controller.play();
                            }
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
                            child: PlayerSettingsDialog(
                              currentSpeed: _playbackSpeed,
                              autoNext: _autoNext,
                              onSpeedChanged: (speed) {
                                setState(() => _playbackSpeed = speed);
                                _controller.setPlaybackSpeed(speed);
                                getIt<SharedPreferences>().setDouble('playback_speed', speed);
                              },
                              onAutoNextChanged: (val) {
                                setState(() => _autoNext = val);
                                getIt<SharedPreferences>().setBool('auto_next', val);
                              },
                            ),
                          ),
                        );
                      },
                      onEpisodes: () {
                        showDialog(
                          context: context,
                          builder: (context) => _buildEpisodesDialog(context),
                        );
                      },
                      onBack: () {
                        _handleBackPress();
                      },
                    );
                  }
                  ),
                ),
              ),
            ],
          ),
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
                    _translateSubtitles(sub, isTop);
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

  Widget _buildEpisodesDialog(BuildContext context) {
    final sortedEpisodes = widget.allEpisodes.toList()..sort((a, b) => a.number.compareTo(b.number));
    
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Container(
        width: 350,
        height: 500,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Episodes', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sortedEpisodes.length,
                itemBuilder: (context, index) {
                  final ep = sortedEpisodes[index];
                  final isCurrent = ep.number == widget.episodeNumber;
                  return ListTile(
                    title: Text(
                      'Tập ${ep.number.toInt()}', 
                      style: TextStyle(
                        color: isCurrent ? AppColors.primary : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      )
                    ),
                    tileColor: isCurrent ? Colors.white12 : Colors.transparent,
                    onTap: () {
                      Navigator.pop(context);
                      if (!isCurrent) {
                        _changeEpisode(ep);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
