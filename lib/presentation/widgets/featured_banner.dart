import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/entities/movie.dart';
import '../../../core/theme/app_colors.dart';

class FeaturedBanner extends StatelessWidget {
  final Movie? movie;
  final Function(Movie) onWatchClick;

  const FeaturedBanner({
    super.key,
    required this.movie,
    required this.onWatchClick,
  });

  @override
  Widget build(BuildContext context) {
    if (movie == null) {
      return Container(
        height: 340,
        color: AppColors.background,
      );
    }

    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (movie!.thumbnail != null)
            CachedNetworkImage(
              imageUrl: movie!.thumbnail!,
              fit: BoxFit.cover,
              memCacheWidth: 600,
              color: Colors.black.withValues(alpha:0.55),
              colorBlendMode: BlendMode.darken,
            ),
            
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.background.withValues(alpha:0.5),
                  AppColors.background,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Content
          Positioned(
            left: 58,
            bottom: 24,
            right: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (movie!.type ?? 'MOVIE').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  movie!.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 600,
                  child: Text(
                    'Stream and learn English now with dual subtitles. Press the center D-pad button to start playing this video directly with integrated translate cues.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.7),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Watch Button
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
                              onWatchClick(movie!);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: GestureDetector(
                        onTap: () => onWatchClick(movie!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.diagonal3Values(isFocused ? 1.05 : 1.0, isFocused ? 1.05 : 1.0, 1.0),
                          transformAlignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: isFocused ? const LinearGradient(
                              colors: [AppColors.primary, Color(0xFFFF5252)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ) : const LinearGradient(
                              colors: [Colors.white, Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isFocused ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.6),
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
                                color: isFocused ? Colors.white : Colors.black,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Watch Now',
                                style: TextStyle(
                                  color: isFocused ? Colors.white : Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
