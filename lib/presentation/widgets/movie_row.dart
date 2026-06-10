import 'package:flutter/material.dart';
import '../../../domain/entities/movie.dart';
import 'movie_card.dart';

class MovieRow extends StatefulWidget {
  final int rowIndex;
  final String? title;
  final List<Movie> movies;
  final Function(Movie) onMoviePressed;
  final Function(Movie, int index)? onMovieFocused;
  final bool autoFocus;
  final ScrollController? scrollController;

  const MovieRow({
    super.key,
    required this.rowIndex,
    this.title,
    required this.movies,
    required this.onMoviePressed,
    this.onMovieFocused,
    this.autoFocus = false,
    this.scrollController,
  });

  @override
  State<MovieRow> createState() => MovieRowState();
}

class MovieRowState extends State<MovieRow> {
  void focusAtColumn(int column) {
    // Reserved for cross-row column navigation
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null && widget.title!.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 58.0),
              child: Text(
                widget.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.0 : 50.0),
            child: SizedBox(
              height: isMobile ? 180 : 240,
              child: ListView.builder(
                controller: widget.scrollController,
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                itemCount: widget.movies.length,
                itemBuilder: (context, index) {
                final movie = widget.movies[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: FocusTraversalOrder(
                    order: NumericFocusOrder(index.toDouble()),
                    child: MovieCard(
                      key: ValueKey('${widget.rowIndex}_${movie.id}'),
                      movie: movie,
                      autoFocus: widget.autoFocus && index == 0,
                      onFocused: () {
                        widget.onMovieFocused?.call(movie, index);
                      },
                      onClick: () => widget.onMoviePressed(movie),
                    ),
                  ),
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }
}