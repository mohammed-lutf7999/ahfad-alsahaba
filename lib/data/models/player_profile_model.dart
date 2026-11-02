import 'dart:convert';
import 'achievement_model.dart';

/// Represents a player profile with all associated data
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
  })  : createdAt = createdAt ?? DateTime.now(),
        lastPlayedAt = lastPlayedAt ?? DateTime.now(),
        categoryProgress = categoryProgress ?? {},
        levelStars = levelStars ?? {},
        levelScores = levelScores ?? {},
        achievementProgress = achievementProgress ?? {};

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
      'achievementProgress': achievementProgress.map((k, v) => MapEntry(k, v.toJson())),
      'currentStreak': currentStreak,
      'totalDaysPlayed': totalDaysPlayed,
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
          ? (json['achievementProgress'] as Map).map(
              (k, v) => MapEntry(k as String, AchievementProgress.fromJson(v as Map<String, dynamic>))
            )
          : {},
      currentStreak: json['currentStreak'] as int? ?? 0,
      totalDaysPlayed: json['totalDaysPlayed'] as int? ?? 0,
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

  /// Add score to total
  void addScore(int score) {
    totalScore += score;
    if (score > highScore) {
      highScore = score;
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
