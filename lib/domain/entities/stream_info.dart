import 'subtitle.dart';

class StreamInfo {
  final String videoUrl;
  final List<SubtitleTrack> subtitles;

  const StreamInfo({
    required this.videoUrl,
    this.subtitles = const [],
  });
}
