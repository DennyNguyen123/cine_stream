class SubtitleTrack {
  final int id;
  final String src;
  final String label;
  final String? languageCode;

  const SubtitleTrack({
    required this.id,
    required this.src,
    required this.label,
    this.languageCode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'src': src,
        'label': label,
        'languageCode': languageCode,
      };

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    return SubtitleTrack(
      id: json['id'] as int,
      src: json['src'] as String,
      label: json['label'] as String,
      languageCode: json['languageCode'] as String?,
    );
  }
}

class SubtitleCue {
  final int startMs;
  final int endMs;
  final String text;

  const SubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
}
