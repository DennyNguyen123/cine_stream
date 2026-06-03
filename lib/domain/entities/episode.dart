class Episode {
  final String id;
  final double number;
  final int season;
  final String? title;
  final bool hasSub;

  const Episode({
    required this.id,
    required this.number,
    this.season = 1,
    this.title,
    this.hasSub = false,
  });
}
