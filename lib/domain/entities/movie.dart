class Movie {
  final String id;
  final String title;
  final String? thumbnail;
  final String? type;
  final String? status;
  final String? year;
  final int? totalEpisodes;

  const Movie({
    required this.id,
    required this.title,
    this.thumbnail,
    this.type,
    this.status,
    this.year,
    this.totalEpisodes,
  });
}
