import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class DebugOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const DebugOverlay({super.key, required this.controller});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  late Timer _timer;
  double _ramUsageMB = 0;
  String _resolution = '';
  String _buffered = '';
  String _position = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _updateStats();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateStats();
      }
    });
  }

  void _updateStats() {
    final value = widget.controller.value;
    
    // RAM usage
    _ramUsageMB = ProcessInfo.currentRss / (1024 * 1024);
    
    // Video Resolution
    _resolution = '${value.size.width.toInt()}x${value.size.height.toInt()}';
    
    // Position & Buffer
    _position = _formatDuration(value.position);
    if (value.buffered.isNotEmpty) {
      final lastBuffer = value.buffered.last;
      _buffered = '${_formatDuration(lastBuffer.start)} - ${_formatDuration(lastBuffer.end)}';
    } else {
      _buffered = '0s';
    }
    
    // Status
    if (value.hasError) {
      _status = 'Error';
    } else if (value.isBuffering) {
      _status = 'Buffering';
    } else if (value.isPlaying) {
      _status = 'Playing';
    } else {
      _status = 'Paused';
    }

    setState(() {});
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
    }
    return '${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.only(top: 16, left: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DEBUG STATS',
              style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildStatRow('RAM Usage:', '${_ramUsageMB.toStringAsFixed(1)} MB'),
            _buildStatRow('Resolution:', _resolution),
            _buildStatRow('Status:', _status),
            _buildStatRow('Position:', _position),
            _buildStatRow('Buffered:', _buffered),
            _buildStatRow('Playback Speed:', '${widget.controller.value.playbackSpeed}x'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
