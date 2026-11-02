class RankEntry {
  final String name;
  final int score;
  final int rank;
  final String? avatarPath;
  final String countryCode; // e.g., 'SA', 'EG', 'YE' for flag display
  final bool isMe;

  const RankEntry({
    required this.name,
    required this.score,
    required this.rank,
    this.avatarPath,
    this.countryCode = 'YE',
    this.isMe = false,
  });
}
