// Force IDE cache refresh
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/history_item.dart';
import '../bloc/history/history_cubit.dart';
import '../bloc/home/home_cubit.dart';
import '../../di/injection.dart';
import '../../domain/repositories/source_manager.dart';
import '../../core/theme/app_colors.dart';
import 'detail_screen.dart';
import 'search_screen.dart';
import '../widgets/marquee_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<HomeCubit>()..loadData()),
        BlocProvider(create: (context) => getIt<HistoryCubit>()..loadHistory()),
      ],
      child: Builder(
        builder: (context) {
          _pollingTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
            if (context.mounted) context.read<HistoryCubit>().loadHistory();
          });
          return Scaffold(
            backgroundColor: AppColors.background,
            body: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading || state is HomeInitial) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is HomeError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.white)));
            } else if (state is HomeLoaded) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Button and Source Selection at the top right
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, right: 48.0, left: 48.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Source Selection Button
                          Builder(
                            builder: (context) {
                              bool isFocused = false;
                              final sourceManager = getIt<SourceManager>();
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return Focus(
                                    onFocusChange: (focused) => setState(() => isFocused = focused),
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent &&
                                          (event.logicalKey == LogicalKeyboardKey.select ||
                                           event.logicalKey == LogicalKeyboardKey.enter)) {
                                        _showSourceSelectionDialog(context);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: GestureDetector(
                                      onTap: () => _showSourceSelectionDialog(context),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        transform: Matrix4.diagonal3Values(isFocused ? 1.05 : 1.0, isFocused ? 1.05 : 1.0, 1.0),
                                        transformAlignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isFocused ? AppColors.primary : Colors.black45,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isFocused ? Colors.white : Colors.transparent,
                                            width: 2,
                                          ),
                                          boxShadow: isFocused ? [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.6),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            )
                                          ] : [],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.source, color: Colors.white, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              sourceManager.activeSource.sourceName,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              );
                            }
                          ),
                          // Search Button
                          Builder(
                          builder: (context) {
                            bool isFocused = false;
                            return StatefulBuilder(
                              builder: (context, setState) {
                                return Focus(
                                  onFocusChange: (focused) => setState(() => isFocused = focused),
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        (event.logicalKey == LogicalKeyboardKey.select ||
                                         event.logicalKey == LogicalKeyboardKey.enter)) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                                      );
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  transform: Matrix4.diagonal3Values(isFocused ? 1.1 : 1.0, isFocused ? 1.1 : 1.0, 1.0),
                                  transformAlignment: Alignment.center,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isFocused ? AppColors.primary : Colors.black45,
                                    shape: BoxShape.circle,
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
                                  child: const Icon(Icons.search, color: Colors.white, size: 28),
                                ),
                              ),
                                );
                              }
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                    
                    BlocBuilder<HistoryCubit, HistoryState>(
                      builder: (context, historyState) {
                        if (historyState is HistoryLoaded) {
                          final activeSourceId = getIt<SourceManager>().activeSourceId;
                          final filteredItems = historyState.items.where((i) => i.sourceId == activeSourceId).toList();
                          
                          if (filteredItems.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: _buildHistoryRow(context, filteredItems),
                            );
                          }
                        }
                        return const Padding(
                          padding: EdgeInsets.all(58.0),
                          child: Text('You haven\'t watched any movies yet. Use the Search button above!', style: TextStyle(color: Colors.white54, fontSize: 18)),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 48),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }
    ),
    );
  }

  Widget _buildHistoryRow(BuildContext context, List<HistoryItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 58.0),
          child: Text(
            'Continue Watching',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final scrollController = ScrollController();
            return SizedBox(
              height: 180, // Increased to accommodate scaling and shadow
              child: ListView.builder(
                controller: scrollController,
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 10.0),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _HistoryCard(
                      key: ValueKey('history_${item.movieId}'),
                      item: item,
                      autoFocus: index == 0,
                      onFocus: () {
                        if (index == 0) {
                          scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        } else if (index == items.length - 1) {
                          scrollController.animateTo(
                            scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            );
          }
        ),
      ],
    );
  }

  void _showSourceSelectionDialog(BuildContext context) {
    final sourceManager = getIt<SourceManager>();
    final sources = sourceManager.getAvailableSources();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Select Source', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sources.length,
            itemBuilder: (dialogCtx, index) {
              final source = sources[index];
              final isSelected = sourceManager.activeSourceId == source['id'];
              return ListTile(
                autofocus: isSelected,
                focusColor: Colors.white24,
                title: Text(source['name'] ?? '', style: const TextStyle(color: Colors.white)),
                trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                tileColor: isSelected ? Colors.white12 : Colors.transparent,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!isSelected) {
                    await sourceManager.setActiveSource(source['id']!);
                    // Reload Data
                    if (!context.mounted) return; {
                      context.read<HomeCubit>().loadData();
                      context.read<HistoryCubit>().loadHistory();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Changed source to: ${source['name']}')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final HistoryItem item;
  final bool autoFocus;
  final VoidCallback? onFocus;

  const _HistoryCard({super.key, required this.item, this.autoFocus = false, this.onFocus});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _isFocused = false;
  Timer? _longPressTimer;
  bool _isDialogShowing = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autoFocus,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused && widget.onFocus != null) {
          widget.onFocus!();
        }
      },
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
          if (event is KeyDownEvent) {
            _longPressTimer ??= Timer(const Duration(milliseconds: 800), () {
              _longPressTimer = null;
              _showDeleteDialog(context);
            });
          } else if (event is KeyUpEvent) {
            if (_longPressTimer != null) {
              _longPressTimer?.cancel();
              _longPressTimer = null;
              _playHistoryItem(context);
            }
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _playHistoryItem(context),
        onLongPress: () => _showDeleteDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.diagonal3Values(_isFocused ? 1.05 : 1.0, _isFocused ? 1.05 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          width: 250,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: _isFocused ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ] : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.item.thumbnail != null)
                      Image.network(
                        widget.item.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Colors.black26),
                      )
                    else
                      const ColoredBox(color: Colors.black26),
                    
                    // Play icon overlay
                    if (_isFocused)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                        ),
                      ),
                  ],
                ),
              ),
              // Progress Bar
              if (widget.item.durationMs > 0)
                LinearProgressIndicator(
                  value: widget.item.positionMs / widget.item.durationMs,
                  backgroundColor: Colors.grey.shade900,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
                ),
              // Info
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      text: widget.item.movieTitle,
                      isFocused: _isFocused,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Episode ${widget.item.episodeNumber.toInt()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playHistoryItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(movie: Movie(
        id: widget.item.movieId,
        title: widget.item.movieTitle,
        thumbnail: widget.item.thumbnail,
      ), autoPlay: true)),
    ).then((_) {
      if (context.mounted) {
        context.read<HistoryCubit>().loadHistory();
      }
    });
  }

  void _showDeleteDialog(BuildContext context) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    
    bool canDismiss = false;
    Timer(const Duration(milliseconds: 500), () => canDismiss = true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete History?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to remove "${widget.item.movieTitle} - Episode ${widget.item.episodeNumber.toInt()}" from your watch history?', style: const TextStyle(color: Colors.white70)),
        actions: [
          _TvDialogButton(
            text: 'Cancel',
            autoFocus: true,
            onPressed: () {
              if (!canDismiss) return;
              Navigator.pop(ctx);
            },
            isPrimary: false,
          ),
          const SizedBox(width: 16),
          _TvDialogButton(
            text: 'Delete',
            onPressed: () {
              if (!canDismiss) return;
              final cubit = context.read<HistoryCubit>();
              Navigator.pop(ctx);
              cubit.removeHistory(widget.item.movieId, widget.item.sourceId);
            },
            isPrimary: true,
          ),
        ],
      ),
    ).then((_) => _isDialogShowing = false);
  }
}

class _TvDialogButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool autoFocus;

  const _TvDialogButton({
    required this.text,
    required this.onPressed,
    this.isPrimary = false,
    this.autoFocus = false,
  });

  @override
  State<_TvDialogButton> createState() => _TvDialogButtonState();
}

class _TvDialogButtonState extends State<_TvDialogButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autoFocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.diagonal3Values(_isFocused ? 1.05 : 1.0, _isFocused ? 1.05 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isPrimary ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused ? [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: Text(
            widget.text,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
