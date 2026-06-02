import 'episode.dart';

class MovieDetail {
  final int id;
  final String title;
  final String? description;
  final String? thumbnail;
  final String? type;
  final List<Episode> episodes;

  const MovieDetail({
    required this.id,
    required this.title,
    this.description,
    this.thumbnail,
    this.type,
    this.episodes = const [],
  });
}
