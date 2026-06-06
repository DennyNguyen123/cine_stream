import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/entities/movie.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'marquee_text.dart';

import '../../../domain/repositories/source_manager.dart';
import '../../../di/injection.dart';

class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onFocused;
  final VoidCallback onClick;
  final bool autoFocus;
  final FocusNode? focusNode;

  const MovieCard({
    super.key,
    required this.movie,
    required this.onFocused,
    required this.onClick,
    this.autoFocus = false,
    this.focusNode,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autoFocus,
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
        if (focused) {
          widget.onFocused();
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onClick();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onClick,
        child: AnimatedScale(
          scale: _isFocused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: isMobile ? 110 : 140,
            height: isMobile ? 165 : 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isFocused ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: _isFocused ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha:0.6),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ] : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster
                  if (widget.movie.thumbnail != null && widget.movie.thumbnail!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.movie.thumbnail!,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      errorWidget: (context, url, error) => _buildFallback(),
                      placeholder: (context, url) => Container(color: AppColors.surfaceVariant),
                    )
                  else
                    _buildFallback(),
                  
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.4, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Hover Play Icon Overlay
                  AnimatedOpacity(
                    opacity: _isFocused ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),

                  // Badge DUAL SUB (Only show for KissKH where soft subs are available)
                  if (getIt<SourceManager>().activeSourceId == 'kisskh')
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.75),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primary.withValues(alpha:0.8), width: 1),
                        ),
                        child: const Text(
                          'DUAL SUB',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Title & Metadata
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarqueeText(
                          text: widget.movie.title,
                          isFocused: _isFocused,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (widget.movie.year != null && widget.movie.year!.isNotEmpty)
                              _buildBadge(widget.movie.year!),
                            if (widget.movie.type != null && widget.movie.type!.isNotEmpty)
                              _buildBadge(widget.movie.type!, color: AppColors.primary),
                            if (widget.movie.totalEpisodes != null && widget.movie.totalEpisodes! > 0)
                              _buildBadge('${widget.movie.totalEpisodes} EPS'),
                            if (widget.movie.status != null && widget.movie.status!.isNotEmpty)
                              _buildBadge(widget.movie.status!),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Text(
          widget.movie.title.isNotEmpty ? widget.movie.title[0] : '?',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.2),
            fontSize: 60,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, {Color color = Colors.white70}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
          ),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
