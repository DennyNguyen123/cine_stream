import 'package:flutter/material.dart';
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
                ElevatedButton(
                  onPressed: () => onWatchClick(movie!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Watch Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
