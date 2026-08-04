import 'subtitle.dart';

class VideoServer {
  final String id;
  final String name;

  const VideoServer({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory VideoServer.fromJson(Map<String, dynamic> json) {
    return VideoServer(id: json['id'] as String, name: json['name'] as String);
  }
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

  Map<String, dynamic> toJson() => {
    'videoUrl': videoUrl,
    'subtitles': subtitles.map((e) => e.toJson()).toList(),
    'servers': servers.map((e) => e.toJson()).toList(),
    'currentServerId': currentServerId,
    'headers': headers,
  };

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      videoUrl: json['videoUrl'] as String,
      subtitles:
          (json['subtitles'] as List<dynamic>?)
              ?.map((e) => SubtitleTrack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      servers:
          (json['servers'] as List<dynamic>?)
              ?.map((e) => VideoServer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      currentServerId: json['currentServerId'] as String?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }
}
