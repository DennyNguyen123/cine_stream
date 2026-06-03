import 'dart:convert';

class HistoryItem {
  final String movieId;
  final String movieTitle;
  final String? thumbnail;
  final String episodeId;
  final double episodeNumber;
  final int positionMs;
  final int durationMs;
  final int timestamp;
  final String sourceId;

  const HistoryItem({
    required this.movieId,
    required this.movieTitle,
    this.thumbnail,
    required this.episodeId,
    required this.episodeNumber,
    required this.positionMs,
    required this.durationMs,
    required this.timestamp,
    required this.sourceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'movieId': movieId,
      'movieTitle': movieTitle,
      'thumbnail': thumbnail,
      'episodeId': episodeId,
      'episodeNumber': episodeNumber,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'timestamp': timestamp,
      'sourceId': sourceId,
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      movieId: map['movieId']?.toString() ?? '',
      movieTitle: map['movieTitle'] ?? '',
      thumbnail: map['thumbnail'],
      episodeId: map['episodeId']?.toString() ?? '',
      episodeNumber: map['episodeNumber']?.toDouble() ?? 0.0,
      positionMs: map['positionMs']?.toInt() ?? 0,
      durationMs: map['durationMs']?.toInt() ?? 0,
      timestamp: map['timestamp']?.toInt() ?? 0,
      sourceId: map['sourceId'] ?? 'kisskh',
    );
  }

  String toJson() => json.encode(toMap());

  factory HistoryItem.fromJson(String source) => HistoryItem.fromMap(json.decode(source));

  HistoryItem copyWith({
    String? movieId,
    String? movieTitle,
    String? thumbnail,
    String? episodeId,
    double? episodeNumber,
    int? positionMs,
    int? durationMs,
    int? timestamp,
    String? sourceId,
  }) {
    return HistoryItem(
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      thumbnail: thumbnail ?? this.thumbnail,
      episodeId: episodeId ?? this.episodeId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      timestamp: timestamp ?? this.timestamp,
      sourceId: sourceId ?? this.sourceId,
    );
  }
}
