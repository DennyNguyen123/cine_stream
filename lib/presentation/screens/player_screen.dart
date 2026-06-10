import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/tv_controls.dart';
import 'package:dio/dio.dart';
import '../widgets/subtitle_display.dart';
import '../widgets/subtitle_settings.dart';
import '../widgets/tv_controls.dart';
import '../widgets/volume_mixer_dialog.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/subtitle.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/entities/episode.dart';
import '../../core/utils/subtitle_parser.dart';
import '../../data/repositories/translation_service.dart';
import '../../data/repositories/external_subtitle_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../domain/repositories/movie_source.dart';
import '../../domain/repositories/subtitle_repository.dart';
import '../../di/injection.dart';
import '../widgets/player_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/source_manager.dart';
import '../../data/services/log_service.dart';
import '../../core/utils/stream_info_cache.dart';
import '../widgets/debug_overlay.dart';

import '../../domain/services/tts_service.dart';
import './settings/webdav_setup_screen.dart';

class PlayerScreen extends StatefulWidget {
  final StreamInfo streamInfo;
  final String title;
  final String movieId;
  final String movieTitle;
  final String? thumbnail;
  final String episodeId;
  final double episodeNumber;
  final int startPositionMs;
  final List<Episode> allEpisodes;
  final String? serverId;
  final List<VideoServer>? servers;

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
    required this.allEpisodes,
    this.serverId,
    this.servers,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
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
  Timer? _saveHistoryTimer;
  Timer? _hideControlsTimer;
  
  int _seekAccumulator = 0;
  Timer? _seekOverlayTimer;
  
  String? _toastMessage;
  Timer? _toastTimer;

  List<SubtitleCue> _primaryCues = [];
  List<SubtitleCue> _secondaryCues = [];
  SubtitleCue? _currentPrimaryCue;
  SubtitleCue? _currentSecondaryCue;
  SubtitleTrack? _selectedSub;
  SubtitleTrack? _selectedSecondarySub;

  List<SubtitleTrack> _availableSubtitles = [];
  bool _isFetchingExternal = false;
  int _topSubDelayMs = 0;
  int _bottomSubDelayMs = 0;

  int _backPressCount = 0;
  Timer? _backPressTimer;

  bool _isChangingEpisode = false;
  double _playbackSpeed = 1.0;
  bool _autoNext = true;
  bool _showDebugStats = false;
  bool _errorDialogShowing = false;
  
  bool _isVoiceOverEnabled = false;
  SubtitleCue? _lastSpokenCue;
  
  bool _showSubtitlesText = true;
  
  double _videoVolume = 1.0;
  double _ttsVolume = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Warm up TTS engine
    getIt<TtsService>().init();
    
    final prefs = getIt<SharedPreferences>();
    _isVoiceOverEnabled = prefs.getBool('cinestream_tts_enabled') ?? false;
    _showSubtitlesText = prefs.getBool('show_subtitles_text') ?? true;
    _videoVolume = prefs.getDouble('cinestream_video_volume') ?? 1.0;
    _ttsVolume = prefs.getDouble('cinestream_tts_volume') ?? 1.0;
    
    getIt<TtsService>().setVolume(_ttsVolume);
    
      getIt<LogService>().log('[PlayerScreen] Initializing with videoUrl: ${widget.streamInfo.videoUrl}');
      getIt<LogService>().log('[PlayerScreen] Initializing with headers: ${widget.streamInfo.headers}');
      
      // Diagnostic test removed to prevent memory leak and OOM crashes

      if (widget.streamInfo.videoUrl.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.streamInfo.videoUrl),
          formatHint: widget.streamInfo.videoUrl.contains('.mp4') ? VideoFormat.other : VideoFormat.hls,
          httpHeaders: widget.streamInfo.headers ?? {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        );
      } else if (widget.streamInfo.videoUrl.isEmpty) {
        // Mock controller cho testing
        _controller = VideoPlayerController.file(File(''));
      } else {
        _controller = VideoPlayerController.file(
          File(widget.streamInfo.videoUrl),
        );
      }
      
      _controller.initialize().then((_) {
        setState(() {
          _duration = _controller.value.duration;
        });
        if (widget.startPositionMs > 0) {
          _controller.seekTo(Duration(milliseconds: widget.startPositionMs));
        }
        _controller.setPlaybackSpeed(_playbackSpeed);
        _controller.setVolume(_videoVolume);
        _controller.play();
      }).catchError((e, stack) {
        if (!mounted) return;
        getIt<LogService>().error('Player initialization failed', e, stack);
        _showErrorDialog("Player initialization failed:\n${e.toString()}");
      });

    _autoNext = prefs.getBool('auto_next') ?? true;
    _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
    _showDebugStats = prefs.getBool('pref_debug_stats') ?? false;

    _controller.addListener(_videoListener);
    _startControlsTimer();
    
    // Periodically save history every 10 seconds
    _saveHistoryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isPlaying && !_isChangingEpisode) {
        _saveHistory();
      }
    });
    
    _availableSubtitles = List.from(widget.streamInfo.subtitles);
    _fetchExternalSubtitles().then((_) {
      _setupInitialSubtitles();
    });
  }

  Future<void> _fetchExternalSubtitles() async {
    setState(() => _isFetchingExternal = true);
    try {
      final extRepo = getIt<ExternalSubtitleRepository>();
      
      int? season;
      int? episode;
      
      // Only extract season/episode if it is a series.
      // Movies might have a dummy episode with season=1, episode=1 which breaks OpenSubtitles API.
      bool isSeries = widget.movieId.startsWith('series/');
      
      if (isSeries && widget.allEpisodes.isNotEmpty) {
         final ep = widget.allEpisodes.firstWhere((e) => e.id == widget.episodeId, orElse: () => widget.allEpisodes.first);
         season = ep.season;
         episode = ep.number.toInt();
      }
      
      final extraSubs = await extRepo.getSubtitles(widget.movieId, season: season, episode: episode);
      if (mounted) {
        setState(() {
          _availableSubtitles.addAll(extraSubs);
        });
      }
    } catch (e) {
      debugPrint('Error fetch external subs: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingExternal = false);
      }
    }
  }

  String _getBaseLanguage(SubtitleTrack sub) {
    if (sub.src.startsWith('translate_')) {
      return sub.label;
    }
    return sub.label.replaceAll(RegExp(r'\s*\d+$'), '').trim();
  }

  void _applySubtitle(SubtitleTrack sub, bool isTop, {required int trackIndex}) {
     final prefPrefix = isTop ? 'pref_sub_top' : 'pref_sub_bottom';
     final baseLang = _getBaseLanguage(sub);
     
     final prefs = getIt<SharedPreferences>();
     if (sub.src.startsWith('translate_')) {
        prefs.setString('${prefPrefix}_lang', sub.src);
     } else {
        prefs.setString('${prefPrefix}_lang', baseLang.toLowerCase());
     }
     prefs.setInt('${prefPrefix}_track', trackIndex);
     
     if (sub.src.startsWith('translate_')) {
        final target = sub.src.split('_')[1];
        _translateSubtitles(sub, isTop, targetLang: target);
     } else {
        _fetchSubtitles(sub, isTop);
     }
  }

  void _setupInitialSubtitles() {
    if (_availableSubtitles.isEmpty) return;
    final prefs = getIt<SharedPreferences>();
    
    void applyPref(bool isTop) {
      final prefPrefix = isTop ? 'pref_sub_top' : 'pref_sub_bottom';
      final prefLang = prefs.getString('${prefPrefix}_lang') ?? (isTop ? 'english' : 'vietnamese');
      final prefTrack = prefs.getInt('${prefPrefix}_track') ?? 0;
      
      if (prefLang == 'off') return;
      
      if (prefLang.startsWith('translate_')) {
        final target = prefLang.split('_')[1];
        final label = target == 'vi' ? 'Vietnamese (Translate)' : 'English (Translate)';
        final tSub = SubtitleTrack(id: -1, label: label, src: prefLang);
        _translateSubtitles(tSub, isTop, targetLang: target);
      } else {
        final tracks = _availableSubtitles.where((s) => _getBaseLanguage(s).toLowerCase() == prefLang.toLowerCase()).toList();
        if (tracks.isNotEmpty) {
           final trackIdx = prefTrack < tracks.length ? prefTrack : 0;
           _fetchSubtitles(tracks[trackIdx], isTop);
        } else {
           _fetchSubtitles(_availableSubtitles.first, isTop);
        }
      }
    }
    
    applyPref(true);
    applyPref(false);
  }

  Future<void> _fetchSubtitles(SubtitleTrack sub, bool isTop) async {
    try {
      final subRepo = getIt<SubtitleRepository>();
      final content = await subRepo.getSubtitleContent(sub.src);
      
      if (content == null || content.isEmpty) {
        throw Exception("Failed to fetch subtitle content from ${sub.src}");
      }
      
      final parsedCues = SubtitleParser.parse(content);
      
      if (mounted) {
        setState(() {
          if (isTop) {
            _selectedSub = sub;
            _primaryCues = parsedCues;
          } else {
            _selectedSecondarySub = sub;
            _secondaryCues = parsedCues;
          }
          _videoListener();
        });
      }
    } catch (e) {
      debugPrint('Subtitle fetch error for ${sub.src}: $e');
      final baseLang = _getBaseLanguage(sub).toLowerCase();
      final tracks = _availableSubtitles.where((s) => _getBaseLanguage(s).toLowerCase() == baseLang).toList();
      final currentIndex = tracks.indexWhere((s) => s.src == sub.src);
      if (currentIndex != -1 && currentIndex + 1 < tracks.length) {
         debugPrint('Falling back to next subtitle track for $baseLang...');
         _fetchSubtitles(tracks[currentIndex + 1], isTop);
      } else {
         if (mounted) _showToast('Subtitle failed to load.');
      }
    }
  }

  Future<void> _translateSubtitles(SubtitleTrack targetSub, bool isTop, {String targetLang = 'vi'}) async {
    _showToast('Translating... this may take a moment');
    
    try {
      if (_availableSubtitles.isEmpty) {
        throw Exception("No source subtitles available to translate from.");
      }
      
      final prefPrefix = isTop ? 'pref_sub_top' : 'pref_sub_bottom';
      final srcLang = getIt<SharedPreferences>().getString('${prefPrefix}_trans_lang');
      final srcTrackIdx = getIt<SharedPreferences>().getInt('${prefPrefix}_trans_track') ?? 0;
      
      SubtitleTrack sourceSub;
      
      if (srcLang != null) {
         final tracks = _availableSubtitles.where((s) => _getBaseLanguage(s).toLowerCase() == srcLang.toLowerCase()).toList();
         if (tracks.isNotEmpty) {
             sourceSub = tracks[srcTrackIdx < tracks.length ? srcTrackIdx : 0];
         } else {
             sourceSub = _availableSubtitles.first;
         }
      } else {
         sourceSub = _availableSubtitles.firstWhere(
            (s) => s.label.toLowerCase().contains('english'),
            orElse: () => _availableSubtitles.first,
         );
      }
      
      final response = await Dio().get(sourceSub.src);
      final parsedCues = SubtitleParser.parse(response.data.toString());
      
      final translator = getIt<TranslationService>();
      List<SubtitleCue> translatedCues = [];
      
      List<String> currentBatch = [];
      int currentCharCount = 0;
      List<SubtitleCue> currentCueBatch = [];
      
      for (var cue in parsedCues) {
        if (currentCharCount + cue.text.length > 3000) {
          final translatedTexts = await translator.translateBatch(currentBatch, targetLang: targetLang);
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
          final translatedTexts = await translator.translateBatch(currentBatch, targetLang: targetLang);
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
          _videoListener(); // Recalculate cue immediately if paused
        });
        _showToast('Translation applied!');
      }
    } catch (e) {
      debugPrint('Translate error: $e');
      if (mounted) {
        _showToast('Translation failed: $e');
      }
    }
  }

  int _lastPrimaryIndex = 0;
  int _lastSecondaryIndex = 0;
  int _lastTtsIndex = 0;
  final Map<String, String> _ttsTranslationCache = {};

  int _findActiveCueIndex(List<SubtitleCue> cues, int posMs, int lastIndex) {
    if (cues.isEmpty) return -1;
    
    // Fast path: still in the same cue
    if (lastIndex >= 0 && lastIndex < cues.length && 
        posMs >= cues[lastIndex].startMs && 
        posMs <= cues[lastIndex].endMs) {
      return lastIndex;
    }
    
    // Binary search for O(log N) performance
    int low = 0;
    int high = cues.length - 1;
    while (low <= high) {
      int mid = low + ((high - low) >> 1);
      final cue = cues[mid];
      
      if (posMs >= cue.startMs && posMs <= cue.endMs) {
        return mid;
      } else if (posMs < cue.startMs) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    
    // If not found (e.g. during a silence gap), keep the previous valid index 
    // so we can resume fast path later or return -1 to indicate no active subtitle
    return -1;
  }

  void _videoListener() {
    if (!mounted) return;
    
    final posMsTop = _controller.value.position.inMilliseconds - _topSubDelayMs;
    final posMsBottom = _controller.value.position.inMilliseconds - _bottomSubDelayMs;
    
    SubtitleCue? activePrimary;
    SubtitleCue? activeSecondary;
    
    // Fast search primary subtitle
    if (_primaryCues.isNotEmpty) {
      _lastPrimaryIndex = _findActiveCueIndex(_primaryCues, posMsTop, _lastPrimaryIndex);
      if (_lastPrimaryIndex != -1) {
        activePrimary = _primaryCues[_lastPrimaryIndex];
      }
    }

    // Fast search secondary subtitle
    if (_secondaryCues.isNotEmpty) {
      _lastSecondaryIndex = _findActiveCueIndex(_secondaryCues, posMsBottom, _lastSecondaryIndex);
      if (_lastSecondaryIndex != -1) {
        activeSecondary = _secondaryCues[_lastSecondaryIndex];
      }
    }

    bool stateChanged = _isPlaying != _controller.value.isPlaying ||
        _isBuffering != _controller.value.isBuffering ||
        _currentPrimaryCue != activePrimary ||
        _currentSecondaryCue != activeSecondary;
        
    // Update position only if controls are visible and position changed by > 500ms
    bool positionChangedSignificantly = _showControls && (_position.inMilliseconds - _controller.value.position.inMilliseconds).abs() > 500;

    // Trigger TTS Voice-over if enabled
    SubtitleCue? activeTtsCue;
    if (_primaryCues.isNotEmpty) {
      final prefs = getIt<SharedPreferences>();
      final ttsDelayMs = prefs.getDouble('tts_delay_ms') ?? 0.0;
      final posMsTts = _controller.value.position.inMilliseconds - ttsDelayMs.toInt();
      
      _lastTtsIndex = _findActiveCueIndex(_primaryCues, posMsTts, _lastTtsIndex);
      if (_lastTtsIndex != -1) activeTtsCue = _primaryCues[_lastTtsIndex];
    }

    if (_isVoiceOverEnabled && activeTtsCue != null && activeTtsCue != _lastSpokenCue && !_isSeeking && _isPlaying) {
      _lastSpokenCue = activeTtsCue;
      final duration = activeTtsCue.endMs - activeTtsCue.startMs;
      
      final prefs = getIt<SharedPreferences>();
      final targetLang = prefs.getString('tts_target_lang') ?? 'vi';
      final currentSubLang = _selectedSub?.languageCode;

      final originalText = activeTtsCue.text;
      final cleanText = originalText.replaceAll(RegExp(r'\[.*?\]|\(.*?\)', dotAll: true), '').trim();
      
      if (cleanText.isNotEmpty) {
        if (currentSubLang != null && currentSubLang != targetLang) {
          // Need translation
          if (_ttsTranslationCache.containsKey(cleanText)) {
             getIt<TtsService>().speak(
               _ttsTranslationCache[cleanText]!,
               durationMs: duration,
               videoPlaybackSpeed: _playbackSpeed,
               languageCode: targetLang,
             );
          } else {
             getIt<TranslationService>().translate(cleanText, targetLang: targetLang).then((translated) {
                if (mounted) {
                  _ttsTranslationCache[cleanText] = translated;
                  if (_lastSpokenCue == activeTtsCue && _isPlaying) {
                    getIt<TtsService>().speak(
                      translated,
                      durationMs: duration,
                      videoPlaybackSpeed: _playbackSpeed,
                      languageCode: targetLang,
                    );
                  }
                }
             });
          }
        } else {
          // No translation needed
          getIt<TtsService>().speak(
            cleanText,
            durationMs: duration,
            videoPlaybackSpeed: _playbackSpeed,
            languageCode: targetLang,
          );
        }
      }
    } else if (activeTtsCue == null) {
      _lastSpokenCue = null;
    }

    if (stateChanged || positionChangedSignificantly) {
      setState(() {
        _position = _controller.value.position;
        _duration = _controller.value.duration;
        _isPlaying = _controller.value.isPlaying;
        _isBuffering = _controller.value.isBuffering;
        _currentPrimaryCue = activePrimary;
        _currentSecondaryCue = activeSecondary;
      });
    }

    if (_controller.value.hasError && !_errorDialogShowing) {
      _showErrorDialog("Video player error:\n${_controller.value.errorDescription}");
    }

    if (_duration.inMilliseconds > 0 && _controller.value.position >= _duration && _autoNext && !_isChangingEpisode) {
      _playNextEpisode();
    }
  }

  void _playNextEpisode() {
    if (widget.allEpisodes.isEmpty) return;
    
    final sortedEpisodes = widget.allEpisodes.toList()..sort((a, b) {
      int seasonCompare = (a.season ?? 1).compareTo(b.season ?? 1);
      if (seasonCompare != 0) return seasonCompare;
      return a.number.compareTo(b.number);
    });
    final currentIndex = sortedEpisodes.indexWhere((e) => e.id == widget.episodeId);
    if (currentIndex != -1 && currentIndex < sortedEpisodes.length - 1) {
      final nextEp = sortedEpisodes[currentIndex + 1];
      _changeEpisode(nextEp);
    }
  }

  void playPrevEpisode() {
    if (widget.allEpisodes.isEmpty) return;
    
    final sortedEpisodes = widget.allEpisodes.toList()..sort((a, b) {
      int seasonCompare = (a.season ?? 1).compareTo(b.season ?? 1);
      if (seasonCompare != 0) return seasonCompare;
      return a.number.compareTo(b.number);
    });
    final currentIndex = sortedEpisodes.indexWhere((e) => e.id == widget.episodeId);
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

    try {
      final source = getIt<MovieSource>();
      final streamInfo = await source.getStreamInfo(
        widget.movieId, 
        nextEp.id, 
        serverId: widget.serverId,
      );
      
      if (!mounted) return;
      
      if (streamInfo != null) {
        final hasMultipleSeasons = widget.allEpisodes.map((e) => e.season).toSet().length > 1;
        String titleStr = nextEp.title ?? 'Episode ${nextEp.number.toInt()}';
        if (hasMultipleSeasons && !titleStr.toUpperCase().startsWith('S${nextEp.season}')) {
          titleStr = 'S${nextEp.season} - $titleStr';
        }
        String title = '${widget.movieTitle} - $titleStr';
        if (widget.movieTitle == titleStr) { 
          title = widget.movieTitle;
        }
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
            serverId: widget.serverId,
            servers: widget.servers,
          )),
        );
      } else {
        setState(() => _isChangingEpisode = false);
        _showErrorDialog("Could not load stream info for the next episode.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChangingEpisode = false);
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _changeServer(String serverId) async {
    setState(() {
      _isChangingEpisode = true; // Use same flag to prevent auto-next
      _showControls = false;
    });
    
    _controller.pause();

    try {
      final source = getIt<MovieSource>();
      final streamInfo = await source.getStreamInfo(widget.movieId, widget.episodeId, serverId: serverId);
      
      if (!mounted) return;
      
      if (streamInfo != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(
            streamInfo: streamInfo, 
            title: widget.title,
            movieId: widget.movieId,
            movieTitle: widget.movieTitle,
            thumbnail: widget.thumbnail,
            episodeId: widget.episodeId,
            episodeNumber: widget.episodeNumber,
            startPositionMs: _position.inMilliseconds,
            allEpisodes: widget.allEpisodes,
            serverId: serverId,
            servers: widget.servers,
          )),
        );
      } else {
        setState(() => _isChangingEpisode = false);
        _showErrorDialog("Could not load stream info for the selected server.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChangingEpisode = false);
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showErrorDialog(String error) {
    if (_errorDialogShowing || !mounted) return;
    setState(() => _errorDialogShowing = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Stream Error', style: TextStyle(color: Colors.white)),
        content: Text('Failed to load video.\n$error', style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _errorDialogShowing = false);
              _exitPlayer();
            },
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
          if (widget.servers != null && widget.servers!.isNotEmpty)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _errorDialogShowing = false);
                showDialog(
                  context: context,
                  builder: (context) => _buildServerDialog(context),
                );
              },
              child: const Text('Change Server', style: TextStyle(color: Colors.white)),
            ),
          ElevatedButton(
            autofocus: true,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _errorDialogShowing = false);
              
              // Clear cache before retrying
              await StreamInfoCache.clearCache(
                widget.movieId, 
                widget.episodeId, 
                widget.streamInfo.currentServerId ?? widget.serverId
              );

              // Retry current episode on current server
              final ep = widget.allEpisodes.firstWhere((e) => e.id == widget.episodeId, orElse: () => widget.allEpisodes.first);
              _changeEpisode(ep);
            },
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  void toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
      _controlsScopeNode.requestFocus();
    } else {
      _playerFocusNode.requestFocus();
    }
  }

  void _saveHistory({bool syncWebDav = false}) {
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
      sourceId: getIt<SourceManager>().activeSourceId,
      serverId: widget.streamInfo.currentServerId ?? widget.serverId,
    ), syncWebDav: syncWebDav);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Dừng TTS khi ứng dụng đi vào background
      getIt<TtsService>().stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    getIt<TtsService>().dispose();
    _saveHistory(syncWebDav: true);
    _saveHistoryTimer?.cancel();
    _seekDebounceTimer?.cancel();
    _hideControlsTimer?.cancel();
    _backPressTimer?.cancel();
    _seekOverlayTimer?.cancel();
    _toastTimer?.cancel();
    _controlsScopeNode.dispose();
    _playerFocusNode.dispose();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
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
      } else {
         _showToast('Bấm Back lần nữa để thoát');
      }
      _backPressTimer?.cancel();
      _backPressTimer = Timer(const Duration(seconds: 2), () {
        _backPressCount = 0;
      });
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    setState(() => _toastMessage = message);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
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
              if (event.logicalKey == LogicalKeyboardKey.space) {
                if (_isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
                return KeyEventResult.handled;
              }
              
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
                toggleControls();
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
                _seekAccumulator += seekStep;
              } else {
                _targetSeekPosition -= Duration(seconds: seekStep);
                _seekAccumulator -= seekStep;
              }
              
              // Clamp position
              if (_targetSeekPosition < Duration.zero) {
                _targetSeekPosition = Duration.zero;
              } else if (_targetSeekPosition > _duration) {
                _targetSeekPosition = _duration;
              }
              
              setState(() {});
              
              _seekOverlayTimer?.cancel();
              _seekOverlayTimer = Timer(const Duration(seconds: 1), () {
                if (mounted) setState(() => _seekAccumulator = 0);
              });
              
              _seekDebounceTimer?.cancel();
              _seekDebounceTimer = Timer(const Duration(milliseconds: 400), () {
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
              toggleControls();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            toggleControls();
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
              
              // Double tap zones
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onDoubleTap: () {
                          if (!_isSeeking) {
                            _isSeeking = true;
                            _targetSeekPosition = _position;
                            if (_isPlaying) _controller.pause();
                          }
                          _targetSeekPosition -= const Duration(seconds: 10);
                          _seekAccumulator -= 10;
                          if (_targetSeekPosition < Duration.zero) _targetSeekPosition = Duration.zero;
                          setState(() {});
                          
                          _seekOverlayTimer?.cancel();
                          _seekOverlayTimer = Timer(const Duration(seconds: 1), () {
                            if (mounted) setState(() => _seekAccumulator = 0);
                          });
                          
                          _seekDebounceTimer?.cancel();
                          _seekDebounceTimer = Timer(const Duration(milliseconds: 400), () {
                            _controller.seekTo(_targetSeekPosition).then((_) {
                              if (mounted) {
                                setState(() => _isSeeking = false);
                                _controller.play();
                              }
                            });
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onDoubleTap: () {
                          if (!_isSeeking) {
                            _isSeeking = true;
                            _targetSeekPosition = _position;
                            if (_isPlaying) _controller.pause();
                          }
                          _targetSeekPosition += const Duration(seconds: 10);
                          _seekAccumulator += 10;
                          if (_targetSeekPosition > _duration) _targetSeekPosition = _duration;
                          setState(() {});
                          
                          _seekOverlayTimer?.cancel();
                          _seekOverlayTimer = Timer(const Duration(seconds: 1), () {
                            if (mounted) setState(() => _seekAccumulator = 0);
                          });
                          
                          _seekDebounceTimer?.cancel();
                          _seekDebounceTimer = Timer(const Duration(milliseconds: 400), () {
                            _controller.seekTo(_targetSeekPosition).then((_) {
                              if (mounted) {
                                setState(() => _isSeeking = false);
                                _controller.play();
                              }
                            });
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Visual Seek Indicator & Loading Indicator
              if (_isChangingEpisode)
                const Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (_seekAccumulator != 0)
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Text(
                      _seekAccumulator > 0 ? '+${_seekAccumulator}s' : '${_seekAccumulator}s',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // Custom Toast Overlay
              if (_toastMessage != null)
                Positioned(
                  top: 48,
                  left: 24,
                  right: 24,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Text(
                        _toastMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

              // Subtitles Overlay
              if (_showSubtitlesText)
                Positioned.fill(
                  child: DualSubtitleDisplay(
                    topCue: _currentPrimaryCue,
                    bottomCue: _currentSecondaryCue,
                    isDualEnabled: (_selectedSub != null && _selectedSecondarySub != null),
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
                        final sortedEpisodes = widget.allEpisodes.toList()..sort((a, b) {
                          int seasonCompare = (a.season ?? 1).compareTo(b.season ?? 1);
                          if (seasonCompare != 0) return seasonCompare;
                          return a.number.compareTo(b.number);
                        });
                        final currentIndex = sortedEpisodes.indexWhere((e) => e.id == widget.episodeId);
                        
                        VoidCallback? prevEpCallback;
                        if (currentIndex > 0) {
                          prevEpCallback = playPrevEpisode;
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
                          isVoiceOverEnabled: _isVoiceOverEnabled,
                          onVoiceOverToggle: () async {
                            final targetState = !_isVoiceOverEnabled;
                            setState(() {
                              _isVoiceOverEnabled = targetState;
                            });
                            final prefs = getIt<SharedPreferences>();
                            await prefs.setBool('cinestream_tts_enabled', targetState);
                            if (!targetState) {
                              await getIt<TtsService>().stop();
                            }
                          },
                          onVolumeMixer: () {
                            showDialog(
                              context: context,
                              barrierColor: Colors.transparent,
                              builder: (_) => Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 24, bottom: 100),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: VolumeMixerDialog(
                                      initialVideoVolume: _videoVolume,
                                      initialTtsVolume: _ttsVolume,
                                      onVideoVolumeChanged: (val) {
                                        setState(() => _videoVolume = val);
                                        _controller.setVolume(val);
                                      },
                                      onTtsVolumeChanged: (val) {
                                        setState(() => _ttsVolume = val);
                                        getIt<TtsService>().setVolume(val);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
                            
                            // Dừng TTS ngay lập tức khi seek
                            getIt<TtsService>().stop();
                            
                            _targetSeekPosition += Duration(seconds: seconds);
                            _seekAccumulator += seconds;
                            
                            if (_targetSeekPosition < Duration.zero) _targetSeekPosition = Duration.zero;
                            if (_targetSeekPosition > _duration) _targetSeekPosition = _duration;
                            
                            setState(() {});
                            
                            _seekOverlayTimer?.cancel();
                            _seekOverlayTimer = Timer(const Duration(seconds: 1), () {
                              if (mounted) setState(() => _seekAccumulator = 0);
                            });
                            
                            _seekDebounceTimer?.cancel();
                            _seekDebounceTimer = Timer(const Duration(milliseconds: 400), () {
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
                          onDragStart: (val) {
                            setState(() {
                              _isSeeking = true;
                              _targetSeekPosition = Duration(seconds: val.toInt());
                            });
                            if (_isPlaying) _controller.pause();
                            _seekDebounceTimer?.cancel();
                          },
                          onDragUpdate: (val) {
                            setState(() {
                              _targetSeekPosition = Duration(seconds: val.toInt());
                            });
                          },
                          onDragEnd: (val) {
                            final seekPos = Duration(seconds: val.toInt());
                            setState(() {
                              _targetSeekPosition = seekPos;
                            });
                            _controller.seekTo(seekPos).then((_) {
                              if (mounted) {
                                setState(() {
                                  _isSeeking = false;
                                });
                                _controller.play();
                              }
                            });
                          },
                          onPlayPause: () {
                            if (_isSeeking) {
                              _seekDebounceTimer?.cancel();
                              _controller.seekTo(_targetSeekPosition).then((_) {
                                setState(() => _isSeeking = false);
                                _isPlaying ? _controller.pause() : _controller.play();
                                if (_isPlaying) {
                                  getIt<TtsService>().stop();
                                }
                              });
                            } else {
                              _isPlaying ? _controller.pause() : _controller.play();
                              if (_isPlaying) {
                                getIt<TtsService>().stop();
                              }
                            }
                          },
                      onSubtitleToggle: () {
                        _showSidePanel(
                          context,
                          _buildSubtitleSelectionDialog(context),
                        );
                      },
                      onSettings: () {
                        _showSidePanel(
                          context,
                          PlayerSettingsDialog(
                            currentSpeed: _playbackSpeed,
                            autoNext: _autoNext,
                            debugMode: _showDebugStats,
                            onSpeedChanged: (speed) {
                              setState(() => _playbackSpeed = speed);
                              _controller.setPlaybackSpeed(speed);
                              getIt<SharedPreferences>().setDouble('playback_speed', speed);
                            },
                            onAutoNextChanged: (val) {
                              setState(() => _autoNext = val);
                              getIt<SharedPreferences>().setBool('auto_next', val);
                            },
                            onDebugModeChanged: (val) {
                              setState(() => _showDebugStats = val);
                              getIt<SharedPreferences>().setBool('pref_debug_stats', val);
                            },
                            onVoiceOverSettings: () {
                              _controller.pause();
                              Navigator.pop(context); // Close side panel
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WebdavSetupScreen(),
                                ),
                              ).then((_) {
                                // Khi quay lại từ Settings, reload config của player
                                final prefs = getIt<SharedPreferences>();
                                setState(() {
                                  _isVoiceOverEnabled = prefs.getBool('cinestream_tts_enabled') ?? false;
                                });
                              });
                            },
                          ),
                        );
                      },
                      onEpisodes: () {
                        _showSidePanel(
                          context,
                          _buildEpisodesDialog(context),
                        );
                      },
                      onServerToggle: () {
                        _showSidePanel(
                          context,
                          _buildServerDialog(context),
                        );
                      },
                      onBack: () {
                        _exitPlayer();
                      },
                    );
                  }
                  ),
                ),
              ),
              // Debug Overlay
              if (_showDebugStats)
                Positioned(
                  top: 0,
                  left: 0,
                  child: DebugOverlay(controller: _controller),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _showSidePanel(BuildContext context, Widget child) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SidePanel',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.4 > 350 ? 350 : MediaQuery.of(context).size.width * 0.85,
                  height: double.infinity,
                  color: AppColors.surface.withValues(alpha: 0.7),
                  child: SafeArea(child: child),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _buildSubtitleSelectionDialog(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Dual Subtitles Selection', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
                _buildSubtitleRow(
                  context: context,
                  title: 'Top Subtitle',
                  sub: _selectedSub,
                  isTop: true,
                  delayMs: _topSubDelayMs,
                  onDelayChanged: (val) {
                    final newVal = _topSubDelayMs + val;
                    setDialogState(() => _topSubDelayMs = newVal);
                    setState(() {
                      _topSubDelayMs = newVal;
                      _videoListener(); // Recalculate cue immediately
                    });
                  },
                ),
                const Divider(color: Colors.white24, height: 1),
                _buildSubtitleRow(
                  context: context,
                  title: 'Bottom Subtitle',
                  sub: _selectedSecondarySub,
                  isTop: false,
                  delayMs: _bottomSubDelayMs,
                  onDelayChanged: (val) {
                    final newVal = _bottomSubDelayMs + val;
                    setDialogState(() => _bottomSubDelayMs = newVal);
                    setState(() {
                      _bottomSubDelayMs = newVal;
                      _videoListener(); // Recalculate cue immediately
                    });
                  },
                ),
                const Divider(color: Colors.white24, height: 1),
                SwitchListTile(
                  title: const Text('Show Subtitles Text on Screen', style: TextStyle(color: Colors.white)),
                  activeColor: AppColors.primary,
                  value: _showSubtitlesText,
                  onChanged: (val) {
                    setDialogState(() => _showSubtitlesText = val);
                    setState(() => _showSubtitlesText = val);
                    getIt<SharedPreferences>().setBool('show_subtitles_text', val);
                  },
                ),
              ],
            ),
        );
      }
    );
  }

  Widget _buildSubtitleRow({
    required BuildContext context,
    required String title, 
    required SubtitleTrack? sub, 
    required bool isTop,
    required int delayMs, 
    required ValueChanged<int> onDelayChanged
  }) {
    final delayText = delayMs > 0 ? '+$delayMs ms' : (delayMs < 0 ? '$delayMs ms' : '0 ms');
    
    String currentLanguage = 'Off';
    int maxTracks = 0;
    int trackIndex = 0;
    
    bool isTranslating = false;
    String sourceLangStr = '';
    
    if (sub != null) {
       currentLanguage = _getBaseLanguage(sub);
       if (sub.src.startsWith('translate_')) {
          isTranslating = true;
          maxTracks = 1;
          
          final prefPrefix = isTop ? 'pref_sub_top' : 'pref_sub_bottom';
          final srcLang = getIt<SharedPreferences>().getString('${prefPrefix}_trans_lang') ?? 'English';
          final srcTrackIdx = getIt<SharedPreferences>().getInt('${prefPrefix}_trans_track') ?? 0;
          
          sourceLangStr = '${srcLang[0].toUpperCase()}${srcLang.substring(1)} - Track ${srcTrackIdx + 1}';
       } else {
         final tracksForLang = _availableSubtitles.where((s) => _getBaseLanguage(s) == currentLanguage).toList();
         maxTracks = tracksForLang.length;
         trackIndex = tracksForLang.indexWhere((s) => s.id == sub.id);
         if (trackIndex == -1) trackIndex = 0;
       }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                _showLanguageSelector(context, isTop);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(currentLanguage, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: (sub != null && maxTracks > 0) 
              ? InkWell(
                  onTap: (isTranslating || maxTracks > 1) 
                      ? () {
                          Navigator.pop(context);
                          if (isTranslating) {
                             _showTranslateSourceSelector(context, isTop, sub);
                          } else {
                             _showTrackSelector(context, isTop, currentLanguage);
                          }
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isTranslating ? 'Source' : 'Track', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(isTranslating ? sourceLangStr : 'Track ${trackIndex + 1}', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 2),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          ),
            
          if (sub != null)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white),
                  onPressed: () => onDelayChanged(-100),
                  tooltip: '-100ms',
                ),
                Text(delayText, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => onDelayChanged(100),
                  tooltip: '+100ms',
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context, bool isTop) {
    final uniqueLanguages = <String>{};
    for (var s in _availableSubtitles) {
       uniqueLanguages.add(_getBaseLanguage(s));
    }
    
    final langList = uniqueLanguages.toList();
    langList.add('Vietnamese (Translate)');
    langList.add('English (Translate)');
    
    _showSidePanel(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Select Language', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: langList.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      title: const Text('Off', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        final prefPrefix = isTop ? 'pref_sub_top' : 'pref_sub_bottom';
                        getIt<SharedPreferences>().setString('${prefPrefix}_lang', 'off');
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
                  
                  final lang = langList[index - 1];
                  return ListTile(
                    title: Text(lang, style: const TextStyle(color: Colors.white)),
                    onTap: () {
                       Navigator.pop(context);
                       if (lang.contains('(Translate)')) {
                          final target = lang.startsWith('Vietnamese') ? 'vi' : 'en';
                          final tSub = SubtitleTrack(id: -1, label: lang, src: 'translate_$target');
                          _applySubtitle(tSub, isTop, trackIndex: 0);
                       } else {
                          final tracks = _availableSubtitles.where((s) => _getBaseLanguage(s) == lang).toList();
                          if (tracks.isNotEmpty) {
                             _applySubtitle(tracks.first, isTop, trackIndex: 0);
                          }
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

  void _showTrackSelector(BuildContext context, bool isTop, String language) {
    final tracks = _availableSubtitles.where((s) => _getBaseLanguage(s) == language).toList();
    
    _showSidePanel(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Select Track', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final sub = tracks[index];
                  return ListTile(
                    title: Text('Track ${index + 1}', style: const TextStyle(color: Colors.white)),
                    onTap: () {
                       Navigator.pop(context);
                       _applySubtitle(sub, isTop, trackIndex: index);
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

  void _showTranslateSourceSelector(BuildContext context, bool isTop, SubtitleTrack targetSub) {
    _showSidePanel(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Select Translation Source', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableSubtitles.length,
                itemBuilder: (context, index) {
                  final srcSub = _availableSubtitles[index];
                  final baseLang = _getBaseLanguage(srcSub);
                  
                  final peers = _availableSubtitles.where((s) => _getBaseLanguage(s) == baseLang).toList();
                  final localIdx = peers.indexWhere((s) => s.id == srcSub.id);
                  
                  return ListTile(
                    title: Text('$baseLang - Track ${localIdx + 1}', style: const TextStyle(color: Colors.white)),
                    onTap: () {
                       Navigator.pop(context);
                       final prefPrefix = isTop ? 'pref_sub_top' : 'pref_sub_bottom';
                       getIt<SharedPreferences>().setString('${prefPrefix}_trans_lang', baseLang.toLowerCase());
                       getIt<SharedPreferences>().setInt('${prefPrefix}_trans_track', localIdx);
                       
                       final target = targetSub.src.split('_')[1];
                       _translateSubtitles(targetSub, isTop, targetLang: target);
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

  Widget _buildEpisodesDialog(BuildContext context) {
    final sortedEpisodes = widget.allEpisodes.toList()..sort((a, b) {
      int seasonCompare = (a.season ?? 1).compareTo(b.season ?? 1);
      if (seasonCompare != 0) return seasonCompare;
      return a.number.compareTo(b.number);
    });
    
    final currentIndex = sortedEpisodes.indexWhere((e) => e.id == widget.episodeId);
    final scrollController = ScrollController(initialScrollOffset: currentIndex > 0 ? currentIndex * 56.0 : 0);
    
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Episodes', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: sortedEpisodes.length,
              itemBuilder: (context, index) {
                final ep = sortedEpisodes[index];
                final isCurrent = ep.id == widget.episodeId;
                final hasMultipleSeasons = widget.allEpisodes.map((e) => e.season).toSet().length > 1;
                String titleStr = ep.title ?? 'Episode ${ep.number.toInt()}';
                if (hasMultipleSeasons && !titleStr.toUpperCase().startsWith('S${ep.season}')) {
                  titleStr = 'S${ep.season} - $titleStr';
                }
                final displayName = titleStr;
                    
                return ListTile(
                  focusColor: Colors.white24,
                  title: Text(
                    displayName, 
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

  Widget _buildServerDialog(BuildContext context) {
    final servers = widget.servers ?? widget.streamInfo.servers;
    if (servers.isEmpty) {
       return const Padding(
         padding: EdgeInsets.all(24.0),
         child: Text('No other servers available', style: TextStyle(color: Colors.white)),
       );
    }
    
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select Server', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: servers.map((server) {
                String? activeServerId = widget.streamInfo.currentServerId ?? widget.serverId;
                if (activeServerId == null && servers.isNotEmpty) {
                  activeServerId = servers.first.id;
                }
                final isCurrent = server.id == activeServerId;
                return ListTile(
                  autofocus: server == servers.first,
                  focusColor: Colors.white24,
                  title: Text(server.name, style: TextStyle(color: isCurrent ? AppColors.primary : Colors.white)),
                  trailing: isCurrent ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isCurrent) {
                       _changeServer(server.id);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
