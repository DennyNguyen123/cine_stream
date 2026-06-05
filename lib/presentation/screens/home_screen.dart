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
import '../widgets/movie_row.dart';
import '../widgets/marquee_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _pollingTimer;
  final List<GlobalKey<MovieRowState>> _rowKeys = [];
  GlobalKey<_HistoryRowState>? _historyRowKey;

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
                  return Center(
                      child: Text(state.message,
                          style: const TextStyle(color: Colors.white)));
                } else if (state is HomeLoaded) {
                  _rowKeys.clear();
                  _historyRowKey = GlobalKey<_HistoryRowState>();
                  for (int i = 0; i < state.sections.length; i++) {
                    _rowKeys.add(GlobalKey<MovieRowState>());
                  }

                  return FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 0: Top bar
                          FocusTraversalOrder(
                            order: NumericFocusOrder(0),
                            child: _TopBar(key: UniqueKey()),
                          ),
                          // Row 1: History
                          FocusTraversalOrder(
                            order: NumericFocusOrder(1),
                            child: _FocusableHistoryRow(
                              key: _historyRowKey,
                              pollingTimer: _pollingTimer,
                              onMoviePressed: (item) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(
                                      movie: Movie(
                                        id: item.movieId,
                                        title: item.movieTitle,
                                        thumbnail: item.thumbnail,
                                      ),
                                      autoPlay: true,
                                    ),
                                  ),
                                ).then((_) {
                                  if (context.mounted) {
                                    context
                                        .read<HistoryCubit>()
                                        .loadHistory();
                                  }
                                });
                              },
                              onDeleteItem: (item) {
                                context
                                    .read<HistoryCubit>()
                                    .removeHistory(
                                        item.movieId, item.sourceId);
                              },
                            ),
                          ),
                          // Row 2+: Content sections
                          ...List.generate(state.sections.length, (i) {
                            final section = state.sections[i];
                            return FocusTraversalOrder(
                              order: NumericFocusOrder((i + 2).toDouble()),
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 24.0),
                                child: MovieRow(
                                  key: _rowKeys[i],
                                  rowIndex: i + 2,
                                  title: section.title,
                                  movies: section.movies,
                                  onMoviePressed: (movie) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetailScreen(
                                            movie: movie, autoPlay: false),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }
}

// ====================================================================
// Top Bar widget (source selector + search button)
// ====================================================================
class _TopBar extends StatefulWidget {
  const _TopBar({super.key});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, right: 48.0, left: 48.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SourceButton(),
          _SearchButton(),
        ],
      ),
    );
  }
}

class _SourceButton extends StatefulWidget {
  @override
  State<_SourceButton> createState() => _SourceButtonState();
}

class _SourceButtonState extends State<_SourceButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final sourceManager = getIt<SourceManager>();
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
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
          transform: Matrix4.diagonal3Values(
              _isFocused ? 1.05 : 1.0, _isFocused ? 1.05 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isFocused ? AppColors.primary : Colors.black45,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.source, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                sourceManager.activeSource.sourceName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSourceSelectionDialog(BuildContext context) {
    final sourceManager = getIt<SourceManager>();
    final sources = sourceManager.getAvailableSources();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            const Text('Select Source', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sources.length,
            itemBuilder: (dialogCtx, index) {
              final source = sources[index];
              final isSelected =
                  sourceManager.activeSourceId == source['id'];
              return ListTile(
                autofocus: isSelected,
                focusColor: Colors.white24,
                title: Text(source['name'] ?? '',
                    style: const TextStyle(color: Colors.white)),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                tileColor:
                    isSelected ? Colors.white12 : Colors.transparent,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!isSelected) {
                    await sourceManager.setActiveSource(source['id']!);
                    // Chủ động xoá cache ảnh cũ khi đổi nguồn để giải phóng RAM cho TV Box
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    
                    if (!context.mounted) return;
                    context.read<HomeCubit>().loadData();
                    context.read<HistoryCubit>().loadHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Changed source to: ${source['name']}')),
                    );
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

class _SearchButton extends StatefulWidget {
  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
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
          transform: Matrix4.diagonal3Values(
              _isFocused ? 1.1 : 1.0, _isFocused ? 1.1 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isFocused ? AppColors.primary : Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: const Icon(Icons.search, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ====================================================================
// Focusable History Row
// ====================================================================
class _FocusableHistoryRow extends StatefulWidget {
  final Timer? pollingTimer;
  final void Function(HistoryItem item) onMoviePressed;
  final void Function(HistoryItem item) onDeleteItem;

  const _FocusableHistoryRow({
    super.key,
    this.pollingTimer,
    required this.onMoviePressed,
    required this.onDeleteItem,
  });

  @override
  State<_FocusableHistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_FocusableHistoryRow> {
  void requestFocusAtColumn(int column) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, historyState) {
          if (historyState is HistoryLoaded) {
            final activeSourceId = getIt<SourceManager>().activeSourceId;
            final filteredItems = historyState.items
                .where((i) => i.sourceId == activeSourceId)
                .toList();
            if (filteredItems.isNotEmpty) {
              return _buildHistoryColumn(filteredItems);
            }
          }
          return const Padding(
            padding: EdgeInsets.all(58.0),
            child: Text(
              'You haven\'t watched any movies yet. Use the Search button above!',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryColumn(List<HistoryItem> items) {
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
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 50.0, vertical: 10.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _HistoryCard(
                  key: ValueKey('history_${item.movieId}'),
                  item: item,
                  autoFocus: index == 0,
                  onFocus: () {},
                  onPlayPressed: () => widget.onMoviePressed(item),
                  onDeletePressed: () => widget.onDeleteItem(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final HistoryItem item;
  final bool autoFocus;
  final VoidCallback? onFocus;
  final VoidCallback onPlayPressed;
  final VoidCallback onDeletePressed;

  const _HistoryCard({
    super.key,
    required this.item,
    this.autoFocus = false,
    this.onFocus,
    required this.onPlayPressed,
    required this.onDeletePressed,
  });

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
        if (focused && widget.onFocus != null) widget.onFocus!();
      },
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (event is KeyDownEvent) {
            _longPressTimer ??=
                Timer(const Duration(milliseconds: 800), () {
              _longPressTimer = null;
              _showDeleteDialog(context);
            });
          } else if (event is KeyUpEvent) {
            if (_longPressTimer != null) {
              _longPressTimer?.cancel();
              _longPressTimer = null;
              widget.onPlayPressed();
            }
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPlayPressed,
        onLongPress: () => _showDeleteDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.diagonal3Values(
              _isFocused ? 1.05 : 1.0, _isFocused ? 1.05 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          width: 250,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.item.thumbnail != null)
                      Image.network(
                        widget.item.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(color: Colors.black26),
                      )
                    else
                      const ColoredBox(color: Colors.black26),
                    if (_isFocused)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: Icon(Icons.play_circle_fill,
                              color: Colors.white, size: 48),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.item.durationMs > 0)
                LinearProgressIndicator(
                  value: widget.item.positionMs / widget.item.durationMs,
                  backgroundColor: Colors.grey.shade900,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
                ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      text: widget.item.movieTitle,
                      isFocused: _isFocused,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Episode ${widget.item.episodeNumber.toInt()}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
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

  void _showDeleteDialog(BuildContext context) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    bool canDismiss = false;
    Timer(const Duration(milliseconds: 500), () => canDismiss = true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete History',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${widget.item.movieTitle}" from history?',
          style: const TextStyle(color: Colors.white70),
        ),
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
              Navigator.pop(ctx);
              widget.onDeletePressed();
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
        if (event is KeyUpEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.diagonal3Values(
              _isFocused ? 1.05 : 1.0, _isFocused ? 1.05 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isPrimary ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Text(
            widget.text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}