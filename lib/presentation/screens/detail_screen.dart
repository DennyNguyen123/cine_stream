import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_detail.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/stream_info.dart';
import '../../domain/entities/history_item.dart';
import '../../data/repositories/history_repository.dart';
import '../../core/theme/app_colors.dart';
import '../bloc/detail/detail_cubit.dart';
import '../../domain/repositories/movie_source.dart';
import '../../di/injection.dart';
import 'player_screen.dart';
import '../../domain/repositories/source_manager.dart';

class DetailScreen extends StatefulWidget {
  final Movie movie;
  final bool autoPlay;

  const DetailScreen({super.key, required this.movie, this.autoPlay = false});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  static const int _episodesPerPage = 50;
  
  final ScrollController _seasonsScrollController = ScrollController();
  final ScrollController _pagesScrollController = ScrollController();
  final ScrollController _episodesScrollController = ScrollController();
  String? _selectedServerId;
  HistoryItem? _historyItem;
  bool _isHistoryLoaded = false;
  bool _isDescExpanded = false;

  // Pagination State
  int? _selectedSeason;
  int _selectedPage = 0;
  bool _isPaginationInitialized = false;

  late final FocusNode _playButtonNode;
  late final FocusNode _firstServerNode;
  late final FocusNode _firstSeasonNode;
  late final FocusNode _firstPageNode;
  late final FocusNode _firstEpisodeNode;

  @override
  void initState() {
    super.initState();
    _playButtonNode = FocusNode();
    _firstServerNode = FocusNode();
    _firstSeasonNode = FocusNode();
    _firstPageNode = FocusNode();
    _firstEpisodeNode = FocusNode();
    _loadHistory();
  }

  @override
  void dispose() {
    _seasonsScrollController.dispose();
    _pagesScrollController.dispose();
    _episodesScrollController.dispose();
    _playButtonNode.dispose();
    _firstServerNode.dispose();
    _firstSeasonNode.dispose();
    _firstPageNode.dispose();
    _firstEpisodeNode.dispose();
    super.dispose();
  }

  List<FocusNode> _getAvailableRowNodes(MovieDetail detail) {
    List<FocusNode> nodes = [_playButtonNode];
    if (detail.servers.isNotEmpty) nodes.add(_firstServerNode);
    
    final seasons = detail.episodes.map((e) => e.season).toSet().toList();
    if (seasons.length > 1) nodes.add(_firstSeasonNode);
    
    final selectedSeason = _selectedSeason ?? (seasons.isNotEmpty ? seasons.first : null);
    if (selectedSeason != null) {
      final seasonEpisodes = detail.episodes.where((e) => e.season == selectedSeason).toList();
      final int totalPages = (seasonEpisodes.length / _episodesPerPage).ceil();
      if (totalPages > 1) nodes.add(_firstPageNode);
    }
    
    if (detail.episodes.isNotEmpty) nodes.add(_firstEpisodeNode);
    
    return nodes;
  }

  FocusNode? _getNodeBelow(FocusNode currentRowNode, MovieDetail detail) {
    final nodes = _getAvailableRowNodes(detail);
    int index = nodes.indexOf(currentRowNode);
    if (index != -1 && index < nodes.length - 1) {
      return nodes[index + 1];
    }
    return null;
  }

  FocusNode? _getNodeAbove(FocusNode currentRowNode, MovieDetail detail) {
    final nodes = _getAvailableRowNodes(detail);
    int index = nodes.indexOf(currentRowNode);
    if (index > 0) {
      return nodes[index - 1];
    }
    return null;
  }

  KeyEventResult _handleRowFocus(
    FocusNode currentRowNode,
    KeyDownEvent event,
    MovieDetail detail,
    VoidCallback onSelect,
  ) {
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final target = _getNodeBelow(currentRowNode, detail);
      if (target != null) {
        target.requestFocus();
        if (target.context != null) {
          Scrollable.ensureVisible(
            target.context!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final target = _getNodeAbove(currentRowNode, detail);
      if (target != null) {
        target.requestFocus();
        if (target.context != null) {
          Scrollable.ensureVisible(
            target.context!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      onSelect();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadHistory() async {
    final sourceId = getIt<SourceManager>().activeSourceId;
    final history = await getIt<HistoryRepository>().getHistoryForMovie(widget.movie.id, sourceId);
    if (mounted) {
      setState(() {
        _historyItem = history;
        _isHistoryLoaded = true;
      });
    }
  }

  String _formatDuration(int milliseconds) {
    final int seconds = (milliseconds / 1000).truncate();
    final int minutes = (seconds / 60).truncate();
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _getContinueWatchingText(MovieDetail detail) {
    if (_historyItem == null) return 'Play Movie';
    
    String epText = 'Ep ${_historyItem!.episodeNumber.toInt()}';
    try {
      final ep = detail.episodes.firstWhere((e) => e.id == _historyItem!.episodeId);
      final hasMultipleSeasons = detail.episodes.map((e) => e.season).toSet().length > 1;
      epText = ep.title ?? 'Ep ${ep.number.toInt()}';
      if (hasMultipleSeasons && !epText.toUpperCase().startsWith('S${ep.season}')) {
        epText = 'S${ep.season} - $epText';
      }
    } catch (_) {}
    
    if (detail.title == epText || detail.type == 'movie') {
      if (_historyItem!.durationMs > 0) {
        return 'Continue Watching (${_formatDuration(_historyItem!.positionMs)} / ${_formatDuration(_historyItem!.durationMs)})';
      } else if (_historyItem!.positionMs > 0) {
        return 'Continue Watching (${_formatDuration(_historyItem!.positionMs)})';
      }
      return 'Continue Watching';
    }
    
    if (_historyItem!.durationMs > 0) {
      return 'Continue Watching ($epText - ${_formatDuration(_historyItem!.positionMs)} / ${_formatDuration(_historyItem!.durationMs)})';
    } else if (_historyItem!.positionMs > 0) {
      return 'Continue Watching ($epText - ${_formatDuration(_historyItem!.positionMs)})';
    }
    return 'Continue Watching ($epText)';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return BlocProvider(
      create: (context) => getIt<DetailCubit>()..loadDetail(widget.movie.id),
      child: BlocListener<DetailCubit, DetailState>(
        listener: (context, state) {
          // autoPlay has been disabled based on requirements
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: BlocBuilder<DetailCubit, DetailState>(
            builder: (context, state) {
              if (state is DetailLoading || state is DetailInitial || !_isHistoryLoaded) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is DetailError) {
                return Center(
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              } else if (state is DetailLoaded) {
                final detail = state.detail;
                if (_selectedServerId == null && detail.servers.isNotEmpty) {
                  _selectedServerId = detail.servers.first.id;
                }

                // Initialize Pagination
                if (!_isPaginationInitialized && detail.episodes.isNotEmpty) {
                  _isPaginationInitialized = true;
                  
                  final seasons = detail.episodes.map((e) => e.season).toSet().toList()..sort();
                  
                  if (_historyItem != null) {
                    final historyEpIndex = detail.episodes.indexWhere((e) => e.id == _historyItem!.episodeId);
                    if (historyEpIndex != -1) {
                       _selectedSeason = detail.episodes[historyEpIndex].season;
                    }
                  }
                  
                  _selectedSeason ??= seasons.first;
                  
                  final seasonEpisodes = detail.episodes.where((e) => e.season == _selectedSeason).toList()..sort((a, b) => a.number.compareTo(b.number));
                  if (_historyItem != null) {
                    final epIndexInSeason = seasonEpisodes.indexWhere((e) => e.id == _historyItem!.episodeId);
                    if (epIndexInSeason != -1) {
                      _selectedPage = epIndexInSeason ~/ _episodesPerPage;
                    }
                  }
                }
                return Stack(
                  children: [
                    // Background Poster with Fade
                    if (detail.thumbnail != null)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.3,
                          child: CachedNetworkImage(
                            imageUrl: detail.thumbnail!,
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                          ),
                        ),
                      ),

                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColors.background,
                              AppColors.background.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                            stops: const [0.3, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Content
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: isMobile ? 16.0 : 58.0,
                          top: isMobile ? 24.0 : 48.0,
                          right: isMobile ? 16.0 : 48.0,
                          bottom: isMobile ? 24.0 : 48.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back button
                            Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent &&
                                    (event.logicalKey ==
                                            LogicalKeyboardKey.select ||
                                        event.logicalKey ==
                                            LogicalKeyboardKey.enter)) {
                                  Navigator.pop(context);
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: Builder(
                                builder: (context) {
                                  final isFocused = Focus.of(context).hasFocus;
                                  return GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? Colors.white24
                                            : Colors.black45,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isFocused
                                              ? AppColors.focusBorder
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (detail.type ?? 'MOVIE').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              detail.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 28 : 42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: isMobile ? double.infinity : 600,
                              child: Builder(
                                builder: (context) {
                                  bool isFocused = false;
                                  return StatefulBuilder(
                                    builder: (context, setFocusState) {
                                      final rawDesc = detail.description ?? '';
                                      final cleanDesc = rawDesc
                                          .replaceAll('&#x27;', "'")
                                          .replaceAll('&quot;', '"')
                                          .replaceAll('&amp;', '&');
                                          
                                      return Focus(
                                        onFocusChange: (focused) => setFocusState(() => isFocused = focused),
                                        onKeyEvent: (node, event) {
                                          if (event is KeyDownEvent &&
                                              (event.logicalKey == LogicalKeyboardKey.select ||
                                               event.logicalKey == LogicalKeyboardKey.enter)) {
                                            setState(() {
                                              _isDescExpanded = !_isDescExpanded;
                                            });
                                            return KeyEventResult.handled;
                                          }
                                          return KeyEventResult.ignored;
                                        },
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isDescExpanded = !_isDescExpanded;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: EdgeInsets.all(isFocused ? 8 : 0),
                                            decoration: BoxDecoration(
                                              color: isFocused ? Colors.white12 : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isFocused ? Colors.white30 : Colors.transparent,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              cleanDesc,
                                              maxLines: _isDescExpanded ? null : 4,
                                              overflow: _isDescExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isFocused ? Colors.white : Colors.white70,
                                                fontSize: 16,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  );
                                }
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Play Button
                            Builder(
                                builder: (context) {
                                bool isFocused = false;
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return Focus(
                                      focusNode: _playButtonNode,
                                      autofocus: true,
                                      onFocusChange: (focused) =>
                                          setState(() => isFocused = focused),
                                      onKeyEvent: (node, event) {
                                        if (event is KeyDownEvent) {
                                          return _handleRowFocus(
                                            _playButtonNode,
                                            event,
                                            detail,
                                            () => _handlePlayNow(context, detail),
                                          );
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: GestureDetector(
                                        onTap: () {
                                          _handlePlayNow(context, detail);
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          transform: Matrix4.diagonal3Values(
                                            isFocused ? 1.05 : 1.0,
                                            isFocused ? 1.05 : 1.0,
                                            1.0,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isMobile ? 16 : 32,
                                            vertical: isMobile ? 12 : 16,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: isFocused ? const LinearGradient(
                                              colors: [AppColors.primary, Color(0xFFFF5252)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ) : const LinearGradient(
                                              colors: [AppColors.primary, AppColors.primary],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: isFocused ? [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: 0.8),
                                                blurRadius: 20,
                                                spreadRadius: 4,
                                              )
                                            ] : [],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.play_arrow,
                                                size: 28,
                                                color: isFocused
                                                    ? AppColors.background
                                                    : Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  _getContinueWatchingText(detail),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: isMobile ? 16 : 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 48),

                            // Episodes (if any)
                            if (detail.servers.isNotEmpty) ...[
                              const Text(
                                'Servers',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: detail.servers.length,
                                  itemBuilder: (context, index) {
                                    final server = detail.servers[index];
                                    final isSelected =
                                        _selectedServerId == server.id;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 12.0,
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          bool isFocused = false;
                                          return StatefulBuilder(
                                            builder: (context, setFocusState) {
                                              return Focus(
                                                focusNode: index == 0 ? _firstServerNode : null,
                                                onFocusChange: (focused) =>
                                                    setFocusState(
                                                      () => isFocused = focused,
                                                    ),
                                                onKeyEvent: (node, event) {
                                                  if (event is KeyDownEvent) {
                                                    return _handleRowFocus(
                                                      _firstServerNode,
                                                      event,
                                                      detail,
                                                      () {
                                                        setState(() {
                                                          _selectedServerId = server.id;
                                                        });
                                                      },
                                                    );
                                                  }
                                                  return KeyEventResult.ignored;
                                                },
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedServerId =
                                                          server.id;
                                                    });
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 200),
                                                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 6 : 8),
                                                    decoration: BoxDecoration(
                                                      color: isFocused ? Colors.white : (isSelected ? AppColors.primary : AppColors.surface),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(
                                                        color: isFocused ? Colors.white : Colors.transparent,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        server.name,
                                                        style: TextStyle(
                                                          color: isFocused ? AppColors.background : Colors.white,
                                                          fontWeight: isSelected || isFocused ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                            if (detail.episodes.isNotEmpty) ...[
                              const Text(
                                'Episodes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Builder(
                                builder: (context) {
                                  // Find seasons
                                  final seasons = detail.episodes.map((e) => e.season).toSet().toList()..sort();
                                  
                                  // Filter episodes by season
                                  final seasonEpisodes = detail.episodes
                                      .where((e) => e.season == _selectedSeason)
                                      .toList()
                                      ..sort((a, b) => a.number.compareTo(b.number));
                                      
                                  // Pagination
                                  final int totalPages = (seasonEpisodes.length / _episodesPerPage).ceil();
                                  // Fix _selectedPage out of bounds just in case
                                  if (_selectedPage >= totalPages) _selectedPage = totalPages > 0 ? totalPages - 1 : 0;
                                  
                                  final pageEpisodes = seasonEpisodes
                                      .skip(_selectedPage * _episodesPerPage)
                                      .take(_episodesPerPage)
                                      .toList();
                                      
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Season Selector
                                      if (seasons.length > 1) ...[
                                        SizedBox(
                                          height: 48,
                                          child: Scrollbar(
                                            controller: _seasonsScrollController,
                                            thumbVisibility: true,
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: SingleChildScrollView(
                                                controller: _seasonsScrollController,
                                                scrollDirection: Axis.horizontal,
                                                child: Row(
                                                  children: List.generate(seasons.length, (index) {
                                                    final season = seasons[index];
                                                    final isSelected = season == _selectedSeason;
                                                    
                                                    // Initial scroll to selected
                                                    if (isSelected && _firstSeasonNode.context == null) {
                                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                                        if (_firstSeasonNode.context != null && _seasonsScrollController.hasClients) {
                                                          Scrollable.ensureVisible(
                                                            _firstSeasonNode.context!,
                                                            alignment: 0.5,
                                                            duration: const Duration(milliseconds: 300),
                                                          );
                                                        }
                                                      });
                                                    }

                                                    return Padding(
                                                      padding: const EdgeInsets.only(right: 12.0),
                                                      child: _buildFilterChip(
                                                        text: 'Season $season',
                                                        isSelected: isSelected,
                                                        focusNode: isSelected ? _firstSeasonNode : null,
                                                        onKeyEvent: (node, event) {
                                                          if (event is KeyDownEvent) {
                                                            return _handleRowFocus(
                                                              _firstSeasonNode,
                                                              event,
                                                              detail,
                                                              () {
                                                                setState(() {
                                                                  _selectedSeason = season;
                                                                  _selectedPage = 0;
                                                                });
                                                              },
                                                            );
                                                          }
                                                          return KeyEventResult.ignored;
                                                        },
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedSeason = season;
                                                            _selectedPage = 0;
                                                          });
                                                        },
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              ),
                                        ),
                                        ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      
                                      // Page Selector
                                      if (totalPages > 1) ...[
                                        SizedBox(
                                          height: 48,
                                          child: Scrollbar(
                                            controller: _pagesScrollController,
                                            thumbVisibility: true,
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: SingleChildScrollView(
                                                controller: _pagesScrollController,
                                                scrollDirection: Axis.horizontal,
                                                child: Row(
                                                  children: List.generate(totalPages, (index) {
                                                    final startIdx = index * _episodesPerPage;
                                                    final endIdx = (index + 1) * _episodesPerPage;
                                                    final actualEndIdx = endIdx > seasonEpisodes.length ? seasonEpisodes.length : endIdx;
                                                    
                                                    final startEpNum = seasonEpisodes[startIdx].number.toInt();
                                                    final endEpNum = seasonEpisodes[actualEndIdx - 1].number.toInt();
                                                    
                                                    final isSelected = index == _selectedPage;

                                                    // Initial scroll to selected
                                                    if (isSelected && _firstPageNode.context == null) {
                                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                                        if (_firstPageNode.context != null && _pagesScrollController.hasClients) {
                                                          Scrollable.ensureVisible(
                                                            _firstPageNode.context!,
                                                            alignment: 0.5,
                                                            duration: const Duration(milliseconds: 300),
                                                          );
                                                        }
                                                      });
                                                    }

                                                    return Padding(
                                                      padding: const EdgeInsets.only(right: 12.0),
                                                      child: _buildFilterChip(
                                                        text: 'Episodes $startEpNum - $endEpNum',
                                                        isSelected: isSelected,
                                                        focusNode: isSelected ? _firstPageNode : null,
                                                        onKeyEvent: (node, event) {
                                                          if (event is KeyDownEvent) {
                                                            return _handleRowFocus(
                                                              _firstPageNode,
                                                              event,
                                                              detail,
                                                              () {
                                                                setState(() {
                                                                  _selectedPage = index;
                                                                });
                                                              },
                                                            );
                                                          }
                                                          return KeyEventResult.ignored;
                                                        },
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedPage = index;
                                                          });
                                                        },
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              ),
                                        ),
                                        ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      
                                      // Episodes List
                                      SizedBox(
                                        height: 136,
                                        child: Scrollbar(
                                          controller: _episodesScrollController,
                                          thumbVisibility: true,
                                          child: Padding(
                                            padding: const EdgeInsets.only(bottom: 16.0),
                                            child: SingleChildScrollView(
                                              controller: _episodesScrollController,
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: List.generate(pageEpisodes.length, (index) {
                                                  final ep = pageEpisodes[index];
                                                  bool isTarget = false;
                                                  if (_historyItem != null && pageEpisodes.any((e) => e.id == _historyItem!.episodeId)) {
                                                    isTarget = ep.id == _historyItem!.episodeId;
                                                  } else {
                                                    isTarget = index == 0;
                                                  }
                                                  
                                                  // Initial scroll to target when first built
                                                  if (isTarget && _firstEpisodeNode.context == null) {
                                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                                      if (_firstEpisodeNode.context != null && _episodesScrollController.hasClients) {
                                                        Scrollable.ensureVisible(
                                                          _firstEpisodeNode.context!,
                                                          alignment: 0.5,
                                                          duration: const Duration(milliseconds: 300),
                                                        );
                                                      }
                                                    });
                                                  }

                                                  return _buildEpisodeItem(
                                                    ep,
                                                    detail,
                                                    isFirst: isTarget,
                                                  );
                                                }),
                                              ),
                                            ),
                                      ),
                                      ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  void _handlePlayNow(BuildContext context, MovieDetail detail) {
    if (!mounted) return;

    String epId = widget.movie.id;
    double epNumber = 1;
    String epTitle = detail.title;

    if (detail.episodes.isNotEmpty) {
      final ep = detail.episodes.reduce((curr, next) {
        if (curr.season < next.season) return curr;
        if (curr.season > next.season) return next;
        return curr.number < next.number ? curr : next;
      });
      epId = ep.id;
      epNumber = ep.number;
      String titleStr = ep.title ?? 'Episode ${ep.number.toInt()}';
      final hasMultipleSeasons = detail.episodes.map((e) => e.season).toSet().length > 1;
      if (hasMultipleSeasons && !titleStr.toUpperCase().startsWith('S${ep.season}')) {
        titleStr = 'S${ep.season} - $titleStr';
      }
      epTitle = '${detail.title} - $titleStr';
    }

    // Check history for this movie
    final sourceId = getIt<SourceManager>().activeSourceId;
    getIt<HistoryRepository>()
        .getHistoryForMovie(widget.movie.id, sourceId)
        .then((history) {
          if (history != null) {
            if (!context.mounted) return;
            // Resume history
            String historyEpTitle = '${detail.title} - Episode ${history.episodeNumber.toInt()}';
            try {
              if (detail.episodes.isNotEmpty) {
                final ep = detail.episodes.firstWhere((e) => e.id == history.episodeId);
                final hasMultipleSeasons = detail.episodes.map((e) => e.season).toSet().length > 1;
                String titleStr = ep.title ?? 'Episode ${ep.number.toInt()}';
                if (hasMultipleSeasons && !titleStr.toUpperCase().startsWith('S${ep.season}')) {
                  titleStr = 'S${ep.season} - $titleStr';
                }
                historyEpTitle = '${detail.title} - $titleStr';
              } else {
                historyEpTitle = detail.title;
              }
            } catch (_) {}
            
            _playEpisode(
              context: context,
              movieId: widget.movie.id,
              episodeId: history.episodeId,
              title: historyEpTitle,
              episodeNumber: history.episodeNumber,
              allEpisodes: detail.episodes,
              startPositionMs: history.positionMs,
              serverId: history.serverId ?? _selectedServerId,
              servers: detail.servers,
            );
          } else {
            if (!context.mounted) return;
            // Play first episode
            _playEpisode(
              context: context,
              movieId: widget.movie.id,
              episodeId: epId,
              title: epTitle,
              episodeNumber: epNumber,
              allEpisodes: detail.episodes,
              serverId: _selectedServerId,
              servers: detail.servers,
            );
          }
        });
  }

  void _playEpisode({
    required BuildContext context,
    required String movieId,
    required String episodeId,
    required String title,
    required double episodeNumber,
    required List<Episode> allEpisodes,
    int startPositionMs = 0,
    String? serverId,
    List<VideoServer>? servers,
  }) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final source = getIt<MovieSource>();
      final streamInfo = await source.getStreamInfo(
        movieId,
        episodeId,
        serverId: serverId,
      );

      if (!context.mounted) return;

      Navigator.pop(context); // hide loading
      if (streamInfo != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              streamInfo: streamInfo,
              title: title,
              movieId: movieId,
              movieTitle: widget.movie.title,
              thumbnail: widget.movie.thumbnail,
              episodeId: episodeId,
              episodeNumber: episodeNumber,
              startPositionMs: startPositionMs,
              allEpisodes: allEpisodes,
              serverId: serverId,
              servers: servers,
            ),
          ),
        );
      } else {
        _showStreamErrorDialog(
          context: context,
          movieId: movieId,
          episodeId: episodeId,
          title: title,
          episodeNumber: episodeNumber,
          allEpisodes: allEpisodes,
          startPositionMs: startPositionMs,
          serverId: serverId,
          servers: servers,
          error: 'Could not load stream info',
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pop(context);
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      _showStreamErrorDialog(
          context: context,
          movieId: movieId,
          episodeId: episodeId,
          title: title,
          episodeNumber: episodeNumber,
          allEpisodes: allEpisodes,
          startPositionMs: startPositionMs,
          serverId: serverId,
          servers: servers,
          error: errorMsg,
      );
    }
  }

  void _showStreamErrorDialog({
    required BuildContext context,
    required String movieId,
    required String episodeId,
    required String title,
    required double episodeNumber,
    required List<Episode> allEpisodes,
    required int startPositionMs,
    String? serverId,
    List<VideoServer>? servers,
    required String error,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Stream Error', style: TextStyle(color: Colors.white)),
        content: Text('Failed to load video stream.\n$error', style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          if (servers != null && servers.isNotEmpty)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
              onPressed: () {
                Navigator.pop(context);
                _buildServerDialog(
                  context: context,
                  servers: servers,
                  onSelect: (selectedServerId) {
                    _playEpisode(
                      context: context,
                      movieId: movieId,
                      episodeId: episodeId,
                      title: title,
                      episodeNumber: episodeNumber,
                      allEpisodes: allEpisodes,
                      startPositionMs: startPositionMs,
                      serverId: selectedServerId,
                      servers: servers,
                    );
                  },
                );
              },
              child: const Text('Change Server', style: TextStyle(color: Colors.white)),
            ),
          ElevatedButton(
            autofocus: true,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              _playEpisode(
                context: context,
                movieId: movieId,
                episodeId: episodeId,
                title: title,
                episodeNumber: episodeNumber,
                allEpisodes: allEpisodes,
                startPositionMs: startPositionMs,
                serverId: serverId,
                servers: servers,
              );
            },
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _buildServerDialog({
    required BuildContext context,
    required List<VideoServer> servers,
    required Function(String) onSelect,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        child: Container(
          width: 350,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Select Server', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: servers.map((s) {
                      return ListTile(
                        autofocus: s == servers.first,
                        focusColor: Colors.white24,
                        title: Text(s.name, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          onSelect(s.id);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeItem(Episode ep, MovieDetail detail, {bool isFirst = false}) {
    final allEpisodes = detail.episodes;
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Builder(
        builder: (context) {
          bool isFocused = false;
          return StatefulBuilder(
            builder: (context, setState) {
              return Focus(
                focusNode: isFirst ? _firstEpisodeNode : null,
                autofocus: _historyItem == null && isFirst,
                key: ValueKey('episode_${ep.number}'),
                onFocusChange: (focused) => setState(() => isFocused = focused),
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    return _handleRowFocus(
                      _firstEpisodeNode,
                      event,
                      detail,
                      () {
                        final hasMultipleSeasons = allEpisodes.map((e) => e.season).toSet().length > 1;
                        final title = hasMultipleSeasons 
                            ? 'S${ep.season} - ${ep.title ?? 'Episode ${ep.number.toInt()}'}'
                            : (ep.title ?? '${widget.movie.title} - Episode ${ep.number.toInt()}');
                        _playEpisode(
                          context: context,
                          movieId: widget.movie.id,
                          episodeId: ep.id,
                          title: title,
                          episodeNumber: ep.number,
                          allEpisodes: allEpisodes,
                          serverId: _selectedServerId,
                          servers: detail.servers,
                        );
                      },
                    );
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  onTap: () {
                    final hasMultipleSeasons = allEpisodes.map((e) => e.season).toSet().length > 1;
                    String titleStr = ep.title ?? 'Episode ${ep.number.toInt()}';
                    if (hasMultipleSeasons && !titleStr.toUpperCase().startsWith('S${ep.season}')) {
                      titleStr = 'S${ep.season} - $titleStr';
                    }
                    String title = '${widget.movie.title} - $titleStr';
                    if (widget.movie.title == titleStr || widget.movie.type == 'movie') {
                      title = widget.movie.title;
                    }
                    _playEpisode(
                      context: context,
                      movieId: widget.movie.id,
                      episodeId: ep.id,
                      title: title,
                      episodeNumber: ep.number,
                      allEpisodes: allEpisodes,
                      serverId: _selectedServerId,
                      servers: detail.servers,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.diagonal3Values(
                      isFocused ? 1.05 : 1.0,
                      isFocused ? 1.05 : 1.0,
                      1.0,
                    ),
                    transformAlignment: Alignment.center,
                    width: ep.title != null ? 300 : 200,
                    decoration: BoxDecoration(
                      color: isFocused ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFocused ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isFocused
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.6),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Builder(
                            builder: (context) {
                              final hasMultipleSeasons = allEpisodes.map((e) => e.season).toSet().length > 1;
                              String titleStr = ep.title ?? 'Episode ${ep.number.toInt()}';
                              if (hasMultipleSeasons && !titleStr.toUpperCase().startsWith('S${ep.season}')) {
                                titleStr = 'S${ep.season} - $titleStr';
                              }
                              final displayName = titleStr;
                              return Text(
                                displayName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isFocused ? Colors.white : Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                          ),
                          if (ep.hasSub) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'SUB',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    FocusNode? focusNode,
    FocusOnKeyEventCallback? onKeyEvent,
  }) {
    return Builder(
      builder: (context) {
        bool isFocused = false;
        return StatefulBuilder(
          builder: (context, setFocusState) {
            return Focus(
              focusNode: focusNode,
              onFocusChange: (focused) => setFocusState(() => isFocused = focused),
              onKeyEvent: onKeyEvent ?? (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter)) {
                  onTap();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFocused ? Colors.white : (isSelected ? AppColors.primary : AppColors.surface),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFocused ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isFocused ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ] : [],
                  ),
                  child: Center(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isSelected
                            ? (isFocused ? AppColors.background : Colors.white)
                            : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
