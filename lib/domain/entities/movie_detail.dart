import 'episode.dart';
import 'stream_info.dart';

class MovieDetail {
  final String id;
  final String title;
  final String? description;
  final String? thumbnail;
  final String? type;
  final List<Episode> episodes;
  final List<VideoServer> servers;

  const MovieDetail({
    required this.id,
    required this.title,
    this.description,
    this.thumbnail,
    this.type,
    this.episodes = const [],
    this.servers = const [],
  });
}
