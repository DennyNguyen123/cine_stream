import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';


class SubtitleSettingsDialog extends StatefulWidget {
  const SubtitleSettingsDialog({super.key});

  @override
  State<SubtitleSettingsDialog> createState() => _SubtitleSettingsDialogState();
}

class _SubtitleSettingsDialogState extends State<SubtitleSettingsDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subtitle Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 16),
          const Text(
            'More settings (Size, Background, etc.) coming soon...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

}
