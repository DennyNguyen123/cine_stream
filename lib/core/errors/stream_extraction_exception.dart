import '../../domain/entities/subtitle.dart';

class StreamExtractionException implements Exception {
  final String embedUrl;
  final String serverId;
  final List<SubtitleTrack> subtitles;
  final String message;

  StreamExtractionException({
    required this.embedUrl,
    required this.serverId,
    required this.subtitles,
    this.message = 'Stream extraction timed out or failed.',
  });

  @override
  String toString() {
    return 'StreamExtractionException: $message';
  }
}
