import 'subtitle.dart';

class VideoServer {
  final String id;
  final String name;

  const VideoServer({required this.id, required this.name});
}

class StreamInfo {
  final String videoUrl;
  final List<SubtitleTrack> subtitles;
  final List<VideoServer> servers;
  final String? currentServerId;
  final Map<String, String>? headers;

  const StreamInfo({
    required this.videoUrl,
    this.subtitles = const [],
    this.servers = const [],
    this.currentServerId,
    this.headers,
  });
}
