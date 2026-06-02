import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/filter.dart';
import '../../domain/entities/movie.dart';
import '../../core/theme/app_colors.dart';
import '../../di/injection.dart';
import '../bloc/search/search_cubit.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showFilters = false; // Hide filters by default to save space

  @override
  void initState() {
    super.initState();
    _searchFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          FocusScope.of(context).focusInDirection(TraversalDirection.down);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          FocusScope.of(context).focusInDirection(TraversalDirection.right);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          FocusScope.of(context).focusInDirection(TraversalDirection.left);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<SearchCubit>()..initSearch(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocBuilder<SearchCubit, SearchState>(
            builder: (context, state) {
              FilterConfig? config;
              Map<String, dynamic> currentFilters = {};
              List<Movie> movies = [];
              bool isLoading = false;

              if (state is SearchLoading) {
                config = state.filterConfig;
                currentFilters = state.currentFilters;
                isLoading = true;
              } else if (state is SearchLoaded) {
                config = state.filterConfig;
                currentFilters = state.currentFilters;
                movies = state.movies;
              } else if (state is SearchError) {
                config = state.filterConfig;
                currentFilters = state.currentFilters;
              }

              return CustomScrollView(
                slivers: [
                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 24.0, 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                                        Navigator.pop(context);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        transform: Matrix4.diagonal3Values(isFocused ? 1.1 : 1.0, isFocused ? 1.1 : 1.0, 1.0),
                                        transformAlignment: Alignment.center,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isFocused ? AppColors.primary : Colors.transparent,
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
                                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: TextField(
                                focusNode: _searchFocusNode,
                                controller: _searchController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white, fontSize: 18),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  hintText: 'Search movies, tv shows...',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2),
                                  ),
                                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                                ),
                                onSubmitted: (value) {
                                  context.read<SearchCubit>().updateQuery(value);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              bool isFocused = false;
                              return StatefulBuilder(
                                builder: (context, setStateFocus) {
                                  return Focus(
                                    onFocusChange: (focused) => setStateFocus(() => isFocused = focused),
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent &&
                                          (event.logicalKey == LogicalKeyboardKey.select ||
                                           event.logicalKey == LogicalKeyboardKey.enter)) {
                                        setState(() => _showFilters = !_showFilters);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _showFilters = !_showFilters);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        transform: Matrix4.diagonal3Values(isFocused ? 1.1 : 1.0, isFocused ? 1.1 : 1.0, 1.0),
                                        transformAlignment: Alignment.center,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isFocused ? AppColors.primary : Colors.transparent,
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
                                        child: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Filter Sections
                  if (config != null && _showFilters)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: config.fields.map((field) {
                            final selectedValue = currentFilters[field.key] ?? field.defaultValue;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                              child: SizedBox(
                                height: 44, // Minimum 44pt touch target as per UX guidelines
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: field.options.length,
                                  itemBuilder: (context, optIndex) {
                                    final option = field.options[optIndex];
                                    final isSelected = selectedValue == option.value;
                                    
                                    bool isFocused = false;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12.0),
                                      child: StatefulBuilder(
                                        builder: (context, setState) {
                                          return Focus(
                                            onFocusChange: (focused) => setState(() => isFocused = focused),
                                            onKeyEvent: (node, event) {
                                              if (event is KeyDownEvent &&
                                                  (event.logicalKey == LogicalKeyboardKey.select ||
                                                   event.logicalKey == LogicalKeyboardKey.enter)) {
                                                context.read<SearchCubit>().updateFilter(field.key, option.value);
                                                return KeyEventResult.handled;
                                              }
                                              return KeyEventResult.ignored;
                                            },
                                            child: GestureDetector(
                                              onTap: () {
                                                context.read<SearchCubit>().updateFilter(field.key, option.value);
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                curve: Curves.easeOutCubic,
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isFocused 
                                                      ? AppColors.primary 
                                                      : (isSelected ? Colors.white : AppColors.surface),
                                                  borderRadius: BorderRadius.circular(24), // pill shape
                                                  border: Border.all(
                                                    color: isFocused ? Colors.white : Colors.transparent,
                                                    width: 2, // Stable layout bounds
                                                  ),
                                                  boxShadow: isFocused ? [
                                                    BoxShadow(
                                                      color: AppColors.primary.withValues(alpha: 0.6),
                                                      blurRadius: 10,
                                                      spreadRadius: 2,
                                                    )
                                                  ] : [],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    option.label,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.black : (isFocused ? Colors.white : Colors.white70),
                                                      fontWeight: isSelected || isFocused ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  if (_showFilters)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        child: Divider(color: Colors.white24),
                      ),
                    ),

                  // Results Grid
                  if (isLoading && movies.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (movies.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No results found', style: TextStyle(color: Colors.white54, fontSize: 18))),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(24.0),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return MovieCard(
                              key: ValueKey('search_${movies[index].id}'),
                              movie: movies[index],
                              autoFocus: index == 0,
                              onFocused: () {
                                // Trigger loadMore when focusing on one of the last 10 items
                                if (index >= movies.length - 10) {
                                  context.read<SearchCubit>().loadMore();
                                }
                              },
                              onClick: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DetailScreen(movie: movies[index])),
                                );
                              },
                            );
                          },
                          childCount: movies.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
