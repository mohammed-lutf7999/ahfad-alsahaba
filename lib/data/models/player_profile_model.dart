import 'dart:convert';
import 'achievement_model.dart';
import 'arena_model.dart';
import 'player_level_model.dart';

/// Represents a player profile with all associated data, level mastery, arena rank, and economy.
class PlayerProfile {
  final String id;
  String name;
  int avatarIndex; // Index of preset avatar (0-7)
  String? customAvatarPath; // Path to custom avatar image (future feature)
  String? linkedUserId; // Supabase user ID for account binding
  int totalScore;
  int highScore;
  DateTime createdAt;
  DateTime lastPlayedAt;

  // Per-category unlocked levels: {"quran": 3, "hadith": 1, ...}
  Map<String, int> categoryProgress;

  // Per-level stars: {"quran_1": 3, "quran_2": 2, ...}
  Map<String, int> levelStars;

  // Per-level scores
  Map<String, int> levelScores;

  // Achievement progress tracking
  Map<String, AchievementProgress> achievementProgress;

  // Streak and dedication tracking
  int currentStreak;
  int totalDaysPlayed;

  // Economy, Trophies & Customization
  int coins;
  int gems;
  int trophies;
  int winStreak;
  String equippedTheme;
  String equippedFrame;
  List<String> unlockedItemIds;

  PlayerProfile({
    required this.id,
    required this.name,
    this.avatarIndex = 0,
    this.customAvatarPath,
    this.linkedUserId,
    this.totalScore = 0,
    this.highScore = 0,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    Map<String, int>? categoryProgress,
    Map<String, int>? levelStars,
    Map<String, int>? levelScores,
    Map<String, AchievementProgress>? achievementProgress,
    this.currentStreak = 0,
    this.totalDaysPlayed = 0,
    this.coins = 100,
    this.gems = 10,
    this.trophies = 1000,
    this.winStreak = 0,
    this.equippedTheme = 'andalusian_gold',
    this.equippedFrame = 'frame_wood',
    List<String>? unlockedItemIds,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastPlayedAt = lastPlayedAt ?? DateTime.now(),
        categoryProgress = categoryProgress ?? {},
        levelStars = levelStars ?? {},
        levelScores = levelScores ?? {},
        achievementProgress = achievementProgress ?? {},
        unlockedItemIds = unlockedItemIds ??
            ['theme_andalusian_gold', 'item_frame_wood'];

  /// Computed 100-Level Mastery Info from [totalScore].
  PlayerLevelInfo get levelInfo => PlayerLevelInfo.fromTotalScore(totalScore);

  /// Computed Competitive Arena Info from [trophies].
  ArenaModel get arenaInfo => ArenaModel.fromTrophies(trophies);

  /// Create a new profile with a unique ID
  factory PlayerProfile.create({
    required String name,
    int avatarIndex = 0,
    String? linkedUserId,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return PlayerProfile(
      id: id,
      name: name,
      avatarIndex: avatarIndex,
      linkedUserId: linkedUserId,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarIndex': avatarIndex,
      'customAvatarPath': customAvatarPath,
      'linkedUserId': linkedUserId,
      'totalScore': totalScore,
      'highScore': highScore,
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'categoryProgress': categoryProgress,
      'levelStars': levelStars,
      'levelScores': levelScores,
      'achievementProgress':
          achievementProgress.map((k, v) => MapEntry(k, v.toJson())),
      'currentStreak': currentStreak,
      'totalDaysPlayed': totalDaysPlayed,
      'coins': coins,
      'gems': gems,
      'trophies': trophies,
      'winStreak': winStreak,
      'equippedTheme': equippedTheme,
      'equippedFrame': equippedFrame,
      'unlockedItemIds': unlockedItemIds,
    };
  }

  /// Create from JSON
  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarIndex: json['avatarIndex'] as int? ?? 0,
      customAvatarPath: json['customAvatarPath'] as String?,
      linkedUserId: json['linkedUserId'] as String?,
      totalScore: json['totalScore'] as int? ?? 0,
      highScore: json['highScore'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.parse(json['lastPlayedAt'] as String)
          : DateTime.now(),
      categoryProgress: json['categoryProgress'] != null
          ? Map<String, int>.from(json['categoryProgress'] as Map)
          : {},
      levelStars: json['levelStars'] != null
          ? Map<String, int>.from(json['levelStars'] as Map)
          : {},
      levelScores: json['levelScores'] != null
          ? Map<String, int>.from(json['levelScores'] as Map)
          : {},
      achievementProgress: json['achievementProgress'] != null
          ? (json['achievementProgress'] as Map).map((k, v) => MapEntry(
              k as String,
              AchievementProgress.fromJson(v as Map<String, dynamic>)))
          : {},
      currentStreak: json['currentStreak'] as int? ?? 0,
      totalDaysPlayed: json['totalDaysPlayed'] as int? ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 100,
      gems: (json['gems'] as num?)?.toInt() ?? 10,
      trophies: (json['trophies'] as num?)?.toInt() ?? 1000,
      winStreak: (json['winStreak'] as num?)?.toInt() ?? 0,
      equippedTheme: json['equippedTheme'] as String? ?? 'andalusian_gold',
      equippedFrame: json['equippedFrame'] as String? ?? 'frame_wood',
      unlockedItemIds: json['unlockedItemIds'] != null
          ? List<String>.from(json['unlockedItemIds'] as List)
          : ['theme_andalusian_gold', 'item_frame_wood'],
    );
  }

  /// Convert list of profiles to JSON string
  static String profilesToJson(List<PlayerProfile> profiles) {
    final jsonList = profiles.map((p) => p.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// Parse list of profiles from JSON string
  static List<PlayerProfile> profilesFromJson(String jsonString) {
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList
        .map((json) => PlayerProfile.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get category progress (unlocked levels)
  int getCategoryUnlockedLevels(String categoryId) {
    return categoryProgress[categoryId] ?? 1;
  }

  /// Set category progress
  void setCategoryUnlockedLevels(String categoryId, int levels) {
    categoryProgress[categoryId] = levels;
    lastPlayedAt = DateTime.now();
  }

  /// Get level stars
  int getLevelStars(String categoryId, int levelNumber) {
    return levelStars['${categoryId}_$levelNumber'] ?? 0;
  }

  /// Set level stars (only if higher)
  void setLevelStars(String categoryId, int levelNumber, int stars) {
    final key = '${categoryId}_$levelNumber';
    final currentStars = levelStars[key] ?? 0;
    if (stars > currentStars) {
      levelStars[key] = stars;
    }
    lastPlayedAt = DateTime.now();
  }

  /// Get level score
  int getLevelScore(String categoryId, int levelNumber) {
    return levelScores['${categoryId}_$levelNumber'] ?? 0;
  }

  /// Set level score (only if higher)
  void setLevelScore(String categoryId, int levelNumber, int score) {
    final key = '${categoryId}_$levelNumber';
    final currentScore = levelScores[key] ?? 0;
    if (score > currentScore) {
      levelScores[key] = score;
    }
    lastPlayedAt = DateTime.now();
  }

  /// Check if level is completed (has stars)
  bool isLevelCompleted(String categoryId, int levelNumber) {
    return getLevelStars(categoryId, levelNumber) > 0;
  }

  /// Check if level is unlocked
  bool isLevelUnlocked(String categoryId, int levelNumber) {
    if (levelNumber == 1) return true;
    return isLevelCompleted(categoryId, levelNumber - 1);
  }

  /// Add score to total, automatically awarding level-up coins when crossing level thresholds.
  void addScore(int score) {
    if (score <= 0) {
      lastPlayedAt = DateTime.now();
      return;
    }
    final oldLevel = levelInfo.level;
    totalScore += score;
    if (score > highScore) {
      highScore = score;
    }
    final newLevel = levelInfo.level;
    if (newLevel > oldLevel) {
      coins += PlayerLevelInfo.totalCoinsGrantedBetweenLevels(oldLevel, newLevel);
      equippedFrame = levelInfo.frameKey;
    }
    lastPlayedAt = DateTime.now();
  }

  /// Copy with modifications
  PlayerProfile copyWith({
    String? name,
    int? avatarIndex,
    String? customAvatarPath,
    String? linkedUserId,
    int? totalScore,
    int? coins,
    int? gems,
    int? trophies,
    int? winStreak,
    String? equippedTheme,
    String? equippedFrame,
    List<String>? unlockedItemIds,
  }) {
    return PlayerProfile(
      id: id,
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      customAvatarPath: customAvatarPath ?? this.customAvatarPath,
      linkedUserId: linkedUserId ?? this.linkedUserId,
      totalScore: totalScore ?? this.totalScore,
      highScore: highScore,
      createdAt: createdAt,
      lastPlayedAt: lastPlayedAt,
      categoryProgress: Map.from(categoryProgress),
      levelStars: Map.from(levelStars),
      levelScores: Map.from(levelScores),
      achievementProgress: Map.from(achievementProgress),
      currentStreak: currentStreak,
      totalDaysPlayed: totalDaysPlayed,
      coins: coins ?? this.coins,
      gems: gems ?? this.gems,
      trophies: trophies ?? this.trophies,
      winStreak: winStreak ?? this.winStreak,
      equippedTheme: equippedTheme ?? this.equippedTheme,
      equippedFrame: equippedFrame ?? this.equippedFrame,
      unlockedItemIds: unlockedItemIds ?? List.from(this.unlockedItemIds),
    );
  }

  /// Get achievement progress, creating if not exists
  AchievementProgress getAchievementProgress(String achievementId) {
    if (!achievementProgress.containsKey(achievementId)) {
      achievementProgress[achievementId] = AchievementProgress(
        achievementId: achievementId,
      );
    }
    return achievementProgress[achievementId]!;
  }

  /// Count unlocked achievements
  int get unlockedAchievementsCount {
    return achievementProgress.values.where((p) => p.isUnlocked).length;
  }

  /// Count total stars
  int get totalStars {
    return levelStars.values.fold(0, (sum, stars) => sum + stars);
  }
}
