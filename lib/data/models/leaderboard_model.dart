import 'arena_model.dart';
import 'player_level_model.dart';

class RankEntry {
  final String name;
  final int score;
  final int rank;
  final String? avatarPath;
  final String countryCode; // e.g., 'SA', 'EG', 'YE' for flag display
  final bool isMe;

  // Glory & Competitive Arena Fields (M2)
  final int playerLevel;
  final String playerTitle;
  final int trophies;
  final int arenaId;
  final String arenaName;
  final String equippedFrame;
  final int winsCount;
  final int matchesCount;

  const RankEntry({
    required this.name,
    required this.score,
    required this.rank,
    this.avatarPath,
    this.countryCode = 'YE',
    this.isMe = false,
    this.playerLevel = 1,
    this.playerTitle = 'طالب علم',
    this.trophies = 1000,
    this.arenaId = 2,
    this.arenaName = 'ميدان بدر الكبرى',
    this.equippedFrame = 'frame_wood',
    this.winsCount = 0,
    this.matchesCount = 0,
  });

  /// Resolved 100-Level Mastery info (uses score math when default/uncomputed).
  PlayerLevelInfo get levelInfo => PlayerLevelInfo.fromTotalScore(score);

  /// Resolved Competitive Arena info from [trophies].
  ArenaModel get arenaInfo => ArenaModel.fromTrophies(trophies);

  /// Creates a [RankEntry] from a Supabase `leaderboard` row with mathematical fallbacks.
  factory RankEntry.fromSupabaseMap(
    Map<String, dynamic> item, {
    required int rank,
    String? currentUserId,
  }) {
    final rawScore = (item['score'] as num?)?.toInt() ?? 0;
    final rawTrophies = (item['trophies'] as num?)?.toInt() ?? 1000;
    final computedLevel = PlayerLevelInfo.fromTotalScore(rawScore);
    final computedArena = ArenaModel.fromTrophies(rawTrophies);

    return RankEntry(
      name: item['display_name']?.toString() ?? 'مجهول',
      score: rawScore,
      rank: rank,
      avatarPath: item['avatar_url']?.toString(),
      countryCode: item['country_code']?.toString() ?? 'YE',
      isMe: currentUserId != null && item['user_id'] == currentUserId,
      playerLevel: (item['player_level'] as num?)?.toInt() ?? computedLevel.level,
      playerTitle: item['player_title']?.toString() ?? computedLevel.title,
      trophies: computedArena.minTrophies > rawTrophies
          ? ArenaModel.clampTrophies(rawTrophies)
          : rawTrophies,
      arenaId: (item['arena_id'] as num?)?.toInt() ?? computedArena.id,
      arenaName: item['arena_name']?.toString() ?? computedArena.name,
      equippedFrame: item['equipped_frame']?.toString() ?? computedLevel.frameKey,
      winsCount: (item['wins_count'] as num?)?.toInt() ?? 0,
      matchesCount: (item['matches_count'] as num?)?.toInt() ?? 0,
    );
  }
}
