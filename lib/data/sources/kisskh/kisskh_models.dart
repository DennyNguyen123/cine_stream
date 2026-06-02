class KissKhMovieJson {
  final int id;
  final String title;
  final String? thumbnail;
  final String? type;
  final String? status; // or label

  KissKhMovieJson({
    required this.id,
    required this.title,
    this.thumbnail,
    this.type,
    this.status,
  });

  factory KissKhMovieJson.fromJson(Map<String, dynamic> json) {
    return KissKhMovieJson(
      id: json['id'] as int,
      title: json['title'] as String,
      thumbnail: json['thumbnail'] as String?,
      type: json['type'] as String?,
      status: json['status'] as String? ?? json['label'] as String?,
    );
  }
}

class KissKhEpisodeJson {
  final int id;
  final double number;
  final int sub;

  KissKhEpisodeJson({
    required this.id,
    required this.number,
    this.sub = 0,
  });

  factory KissKhEpisodeJson.fromJson(Map<String, dynamic> json) {
    return KissKhEpisodeJson(
      id: json['id'] as int,
      number: (json['number'] as num).toDouble(),
      sub: json['sub'] as int? ?? 0,
    );
  }
}

class KissKhMovieDetailJson {
  final int id;
  final String title;
  final String? description;
  final String? thumbnail;
  final String? type;
  final List<KissKhEpisodeJson> episodes;

  KissKhMovieDetailJson({
    required this.id,
    required this.title,
    this.description,
    this.thumbnail,
    this.type,
    required this.episodes,
  });

  factory KissKhMovieDetailJson.fromJson(Map<String, dynamic> json) {
    var episodesList = json['episodes'] as List?;
    return KissKhMovieDetailJson(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnail: json['thumbnail'] as String?,
      type: json['type'] as String?,
      episodes: episodesList?.map((e) => KissKhEpisodeJson.fromJson(e)).toList() ?? [],
    );
  }
}

class KissKhSubtitleJson {
  final String src;
  final String label;
  final String? land;

  KissKhSubtitleJson({
    required this.src,
    required this.label,
    this.land,
  });

  factory KissKhSubtitleJson.fromJson(Map<String, dynamic> json) {
    return KissKhSubtitleJson(
      src: json['src'] as String,
      label: json['label'] as String,
      land: json['land'] as String?,
    );
  }
}
