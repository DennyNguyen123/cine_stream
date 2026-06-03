import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_detail.dart';
import '../../domain/entities/episode.dart';
import '../../data/repositories/history_repository.dart';
import '../../core/theme/app_colors.dart';
import '../bloc/detail/detail_cubit.dart';
import '../../domain/repositories/movie_source.dart';
import '../../di/injection.dart';
import 'player_screen.dart';
import 'webview_player_screen.dart';
import '../../domain/repositories/source_manager.dart';

class DetailScreen extends StatefulWidget {
  final Movie movie;
  final bool autoPlay;

  const DetailScreen({super.key, required this.movie, this.autoPlay = false});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<DetailCubit>()..loadDetail(widget.movie.id),
      child: BlocListener<DetailCubit, DetailState>(
        listener: (context, state) {
          if (widget.autoPlay && state is DetailLoaded) {
            if (state.detail.episodes.isNotEmpty) {
              _handlePlayNow(context, state.detail);
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: BlocBuilder<DetailCubit, DetailState>(
            builder: (context, state) {
              if (state is DetailLoading || state is DetailInitial) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is DetailError) {
                return Center(child: Text(state.message, style: const TextStyle(color: Colors.white)));
              } else if (state is DetailLoaded) {
                final detail = state.detail;
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
                        padding: const EdgeInsets.only(left: 58.0, top: 48.0, right: 48.0, bottom: 48.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back button
                            Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
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
                                        color: isFocused ? Colors.white24 : Colors.black45,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isFocused ? AppColors.focusBorder : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                                    ),
                                  );
                                }
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (detail.type ?? 'MOVIE').toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            detail.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 600,
                            child: Text(
                              detail.description ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.5,
                              ),
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
                                    autofocus: true,
                                    onFocusChange: (focused) => setState(() => isFocused = focused),
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
                                        if (detail.episodes.isNotEmpty) {
                                          _handlePlayNow(context, detail);
                                        }
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: GestureDetector(
                                      onTap: () {
                                        if (detail.episodes.isNotEmpty) {
                                          _handlePlayNow(context, detail);
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        transform: Matrix4.diagonal3Values(isFocused ? 1.05 : 1.0, isFocused ? 1.05 : 1.0, 1.0),
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        decoration: BoxDecoration(
                                          color: isFocused ? Colors.white : AppColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: isFocused ? [
                                            BoxShadow(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            )
                                          ] : [],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_arrow, size: 28, color: isFocused ? AppColors.background : Colors.white),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Play Movie',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isFocused ? AppColors.background : Colors.white,
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
                          if (detail.episodes.isNotEmpty) ...[
                            const Text(
                              'Episodes',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final sortedEpisodes = detail.episodes.toList()
                                  ..sort((a, b) {
                                    int sComp = a.season.compareTo(b.season);
                                    if (sComp != 0) return sComp;
                                    return a.number.compareTo(b.number);
                                  });
                                return SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: sortedEpisodes.length,
                                    itemBuilder: (context, index) {
                                      final ep = sortedEpisodes[index];
                                      return _buildEpisodeItem(ep, detail.episodes);
                                    },
                                  ),
                                );
                              }
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
    final ep = detail.episodes.reduce((curr, next) {
      if (curr.season < next.season) return curr;
      if (curr.season > next.season) return next;
      return curr.number < next.number ? curr : next;
    });
    final title = ep.title ?? '${detail.title} - Tập ${ep.number.toInt()}';
    // Check history for this movie
    final sourceId = getIt<SourceManager>().activeSourceId;
    getIt<HistoryRepository>().getHistoryForMovie(widget.movie.id, sourceId).then((history) {
      if (history != null) {
        if (!context.mounted) return;
        // Resume history
        final epTitle = '${detail.title} - Tập ${history.episodeNumber.toInt()}';
        _playEpisode(
          context: context, 
          movieId: widget.movie.id, 
          episodeId: history.episodeId, 
          title: epTitle,
          episodeNumber: history.episodeNumber,
          allEpisodes: detail.episodes,
          startPositionMs: history.positionMs,
        );
      } else {
        if (!context.mounted) return;
        // Play first episode
        _playEpisode(
          context: context, 
          movieId: widget.movie.id, 
          episodeId: ep.id, 
          title: title,
          episodeNumber: ep.number,
          allEpisodes: detail.episodes,
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
  }) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final source = getIt<MovieSource>();
      final streamInfo = await source.getStreamInfo(movieId, episodeId);
      
      if (!context.mounted) return;
      
      Navigator.pop(context); // hide loading
      if (streamInfo != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(
            streamInfo: streamInfo, 
            title: title,
            movieId: movieId,
            movieTitle: widget.movie.title,
            thumbnail: widget.movie.thumbnail,
            episodeId: episodeId,
            episodeNumber: episodeNumber,
            startPositionMs: startPositionMs,
            allEpisodes: allEpisodes,
          )),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load stream info')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      
      Navigator.pop(context);
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  Widget _buildEpisodeItem(Episode ep, List<Episode> allEpisodes) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Builder(
        builder: (context) {
          bool isFocused = false;
          return StatefulBuilder(
            builder: (context, setState) {
              return Focus(
                key: ValueKey('episode_${ep.number}'),
                onFocusChange: (focused) => setState(() => isFocused = focused),
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                       event.logicalKey == LogicalKeyboardKey.enter)) {
                    final title = ep.title ?? '${widget.movie.title} - Tập ${ep.number.toInt()}';
                    _playEpisode(
                      context: context, 
                      movieId: widget.movie.id, 
                      episodeId: ep.id, 
                      title: title,
                      episodeNumber: ep.number,
                      allEpisodes: allEpisodes,
                    );
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  onTap: () {
                    final title = ep.title ?? '${widget.movie.title} - Tập ${ep.number.toInt()}';
                    _playEpisode(
                      context: context, 
                      movieId: widget.movie.id, 
                      episodeId: ep.id, 
                      title: title,
                      episodeNumber: ep.number,
                      allEpisodes: allEpisodes,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.diagonal3Values(isFocused ? 1.05 : 1.0, isFocused ? 1.05 : 1.0, 1.0),
                    transformAlignment: Alignment.center,
                    width: ep.title != null ? 300 : 200,
                    decoration: BoxDecoration(
                      color: isFocused ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFocused ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isFocused ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ] : [],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ep.title ?? 'Episode ${ep.number.toInt()}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isFocused ? Colors.white : Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
          );
        }
      ),
    );
  }
}
