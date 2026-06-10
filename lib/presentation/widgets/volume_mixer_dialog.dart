import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../di/injection.dart';
import '../../../core/theme/app_colors.dart';

class VolumeMixerDialog extends StatefulWidget {
  final double initialVideoVolume;
  final double initialTtsVolume;
  final ValueChanged<double> onVideoVolumeChanged;
  final ValueChanged<double> onTtsVolumeChanged;

  const VolumeMixerDialog({
    super.key,
    required this.initialVideoVolume,
    required this.initialTtsVolume,
    required this.onVideoVolumeChanged,
    required this.onTtsVolumeChanged,
  });

  @override
  State<VolumeMixerDialog> createState() => _VolumeMixerDialogState();
}

class _VolumeMixerDialogState extends State<VolumeMixerDialog> {
  late double _videoVolume;
  late double _ttsVolume;

  @override
  void initState() {
    super.initState();
    _videoVolume = widget.initialVideoVolume;
    _ttsVolume = widget.initialTtsVolume;
  }

  void _saveVideoVolume(double val) {
    getIt<SharedPreferences>().setDouble('cinestream_video_volume', val);
  }

  void _saveTtsVolume(double val) {
    getIt<SharedPreferences>().setDouble('cinestream_tts_volume', val);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Volume Mixer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Video Volume
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.movie, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Media Volume', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
              Text('${(_videoVolume * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          Slider(
            value: _videoVolume,
            min: 0.0,
            max: 1.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.white24,
            onChanged: (val) {
              setState(() => _videoVolume = val);
              widget.onVideoVolumeChanged(val);
            },
            onChangeEnd: _saveVideoVolume,
          ),
          const SizedBox(height: 16),

          // Voice-over Volume
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.record_voice_over, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Voice-over Volume', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
              Text('${(_ttsVolume * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          Slider(
            value: _ttsVolume,
            min: 0.0,
            max: 1.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.white24,
            onChanged: (val) {
              setState(() => _ttsVolume = val);
              widget.onTtsVolumeChanged(val);
            },
            onChangeEnd: _saveTtsVolume,
          ),
        ],
      ),
    );
  }
}
