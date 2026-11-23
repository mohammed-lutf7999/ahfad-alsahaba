import '../../local/shared_prefs_service.dart';
import '../../models/player_profile_model.dart';

/// Pure, deterministic profile merger enforcing AGENTS.md Rule #3:
/// Zero data loss on Google Sign-In or legacy storage migration by always
/// preserving the GREATEST score, level progress, stars, inventory, and achievements.
class ProfileMerger {
  ProfileMerger._();

  /// Merges [local] profile into [cloud] profile in-place, taking the highest
  /// values across all progression metrics.
  static void mergeLocalIntoCloud(PlayerProfile local, PlayerProfile cloud) {
    if (PlayerProfile.isValidPlayerCode(local.playerCode)) {
      cloud.playerCode = local.playerCode;
    }
    if (local.totalScore > cloud.totalScore) {
      cloud.totalScore = local.totalScore;
    }
    if (local.highScore > cloud.highScore) {
      cloud.highScore = local.highScore;
    }
    if (local.currentStreak > cloud.currentStreak) {
      cloud.currentStreak = local.currentStreak;
    }
    if (local.totalDaysPlayed > cloud.totalDaysPlayed) {
      cloud.totalDaysPlayed = local.totalDaysPlayed;
    }
    if (local.coins > cloud.coins) {
      cloud.coins = local.coins;
    }
    if (local.gems > cloud.gems) {
      cloud.gems = local.gems;
    }
    if (local.trophies > cloud.trophies && local.trophies != 1000) {
      cloud.trophies = local.trophies;
    }
    if (local.winStreak > cloud.winStreak) {
      cloud.winStreak = local.winStreak;
    }
    if (local.equippedTheme != 'andalusian_gold' &&
        cloud.equippedTheme == 'andalusian_gold') {
      cloud.equippedTheme = local.equippedTheme;
    }
    if (local.equippedFrame != 'frame_wood' &&
        cloud.equippedFrame == 'frame_wood') {
      cloud.equippedFrame = local.equippedFrame;
    }
    if (local.equippedTitle != null &&
        local.equippedTitle!.isNotEmpty &&
        (cloud.equippedTitle == null || cloud.equippedTitle!.isEmpty)) {
      cloud.equippedTitle = local.equippedTitle;
    }
    for (final itemId in local.unlockedItemIds) {
      if (!cloud.unlockedItemIds.contains(itemId)) {
        cloud.unlockedItemIds.add(itemId);
      }
    }

    if (local.name.isNotEmpty &&
        local.name != 'لاعب' &&
        local.name != 'لاعب 1' &&
        (cloud.name.isEmpty ||
            cloud.name == 'لاعب' ||
            cloud.name == 'لاعب 1')) {
      cloud.name = local.name;
    }

    for (final entry in local.categoryProgress.entries) {
      final cloudValue = cloud.categoryProgress[entry.key] ?? 0;
      if (entry.value > cloudValue) {
        cloud.categoryProgress[entry.key] = entry.value;
      }
    }

    for (final entry in local.levelStars.entries) {
      final cloudValue = cloud.levelStars[entry.key] ?? 0;
      if (entry.value > cloudValue) {
        cloud.levelStars[entry.key] = entry.value;
      }
    }

    for (final entry in local.levelScores.entries) {
      final cloudValue = cloud.levelScores[entry.key] ?? 0;
      if (entry.value > cloudValue) {
        cloud.levelScores[entry.key] = entry.value;
      }
    }

    for (final entry in local.achievementProgress.entries) {
      final cloudAch = cloud.achievementProgress[entry.key];
      if (cloudAch == null ||
          entry.value.currentValue > cloudAch.currentValue ||
          (entry.value.isUnlocked && !cloudAch.isUnlocked)) {
        cloud.achievementProgress[entry.key] = entry.value;
      }
    }
  }

  /// Merges any legacy SharedPreferences keys into [profile] if legacy values are higher.
  /// Returns `true` if any field was upgraded.
  static bool mergeLegacySharedPrefsInto(PlayerProfile profile) {
    bool changed = false;
    final existingScore = SharedPrefsService.getTotalScore();
    final existingHighScore = SharedPrefsService.getHighScore();

    if (existingScore > profile.totalScore) {
      profile.totalScore = existingScore;
      changed = true;
    }
    if (existingHighScore > profile.highScore) {
      profile.highScore = existingHighScore;
      changed = true;
    }

    const categories = [
      'quran',
      'hadith',
      'fiqh',
      'seerah',
      'history',
      'aqeedah',
    ];
    for (final cat in categories) {
      final unlocked = SharedPrefsService.getCategoryProgress(cat);
      final currentUnlocked = profile.categoryProgress[cat] ?? 1;
      if (unlocked > currentUnlocked) {
        profile.categoryProgress[cat] = unlocked;
        changed = true;
      }

      for (int level = 1; level <= 10; level++) {
        final stars = SharedPrefsService.getLevelStars(cat, level);
        final score = SharedPrefsService.getLevelScore(cat, level);
        final key = '${cat}_$level';
        if (stars > (profile.levelStars[key] ?? 0)) {
          profile.levelStars[key] = stars;
          changed = true;
        }
        if (score > (profile.levelScores[key] ?? 0)) {
          profile.levelScores[key] = score;
          changed = true;
        }
      }
    }
    return changed;
  }
}
