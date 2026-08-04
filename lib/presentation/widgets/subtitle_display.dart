import 'package:flutter/material.dart';
import '../../domain/entities/subtitle.dart';
import '../../core/theme/app_colors.dart';

class DualSubtitleDisplay extends StatelessWidget {
  final SubtitleCue? topCue;
  final SubtitleCue? bottomCue;
  final bool isDualEnabled;

  const DualSubtitleDisplay({
    super.key,
    this.topCue,
    this.bottomCue,
    this.isDualEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (topCue == null && bottomCue == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (topCue != null)
            _buildSubText(
              topCue!.text,
              isDualEnabled ? AppColors.subtitleTop : AppColors.subtitleTop,
              isDualEnabled ? 22 : 24,
            ),

          if (topCue != null && bottomCue != null) const SizedBox(height: 4),

          if (bottomCue != null)
            _buildSubText(
              bottomCue!.text,
              isDualEnabled ? AppColors.subtitleBottom : AppColors.subtitleTop,
              isDualEnabled ? 28 : 24,
            ),
        ],
      ),
    );
  }

  Widget _buildSubText(String text, Color color, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              offset: Offset(1.0, 1.0),
              blurRadius: 3.0,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
