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
