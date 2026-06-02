class Episode {
  final int id;
  final double number;
  final bool hasSub;

  const Episode({
    required this.id,
    required this.number,
    this.hasSub = false,
  });
}
