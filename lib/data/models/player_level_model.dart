import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents a major historical rank tier in the 100-level mastery ladder.
class LevelTierDefinition {
  final int minLevel;
  final int maxLevel;
  final String title;
  final String frameKey;
  final String frameName;
  final int tierBonusCoins;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;

  const LevelTierDefinition({
    required this.minLevel,
    required this.maxLevel,
    required this.title,
    required this.frameKey,
    required this.frameName,
    required this.tierBonusCoins,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
  });
}

/// Complete computed level information for a player based on total XP (score).
class PlayerLevelInfo {
  static const int maxLevel = 100;

  final int level;
  final String title;
  final int totalScore;
  final int currentLevelXp;
  final int requiredLevelXp;
  final int currentLevelFloorXp;
  final int nextLevelCeilingXp;
  final double progressPercent;
  final Color badgeColor;
  final Color secondaryColor;
  final String frameKey;
  final String frameName;
  final int coinGrantForThisLevel;
  final IconData tierIcon;

  const PlayerLevelInfo({
    required this.level,
    required this.title,
    required this.totalScore,
    required this.currentLevelXp,
    required this.requiredLevelXp,
    required this.currentLevelFloorXp,
    required this.nextLevelCeilingXp,
    required this.progressPercent,
    required this.badgeColor,
    required this.secondaryColor,
    required this.frameKey,
    required this.frameName,
    required this.coinGrantForThisLevel,
    required this.tierIcon,
  });

  /// The 10 Grand Historical Tiers across the 100-Level Mastery Ladder.
  static const List<LevelTierDefinition> allTiers = [
    LevelTierDefinition(
      minLevel: 1,
      maxLevel: 9,
      title: 'طالب علم',
      frameKey: 'frame_wood',
      frameName: 'إطار خشبي عتيق',
      tierBonusCoins: 100,
      primaryColor: Color(0xFFA16207),
      secondaryColor: Color(0xFFD97706),
      icon: Icons.menu_book_rounded,
    ),
    LevelTierDefinition(
      minLevel: 10,
      maxLevel: 19,
      title: 'راوي الأثر',
      frameKey: 'frame_copper',
      frameName: 'إطار نحاسي منقوش',
      tierBonusCoins: 250,
      primaryColor: Color(0xFFD97706),
      secondaryColor: Color(0xFFF59E0B),
      icon: Icons.history_edu_rounded,
    ),
    LevelTierDefinition(
      minLevel: 20,
      maxLevel: 29,
      title: 'محدث الميدان',
      frameKey: 'frame_bronze',
      frameName: 'إطار برونزي مذهب',
      tierBonusCoins: 500,
      primaryColor: Color(0xFFB45309),
      secondaryColor: Color(0xFFFBBF24),
      icon: Icons.auto_stories_rounded,
    ),
    LevelTierDefinition(
      minLevel: 30,
      maxLevel: 39,
      title: 'فارس المعرفة',
      frameKey: 'frame_silver',
      frameName: 'إطار فضي دمشقي',
      tierBonusCoins: 750,
      primaryColor: Color(0xFF94A3B8),
      secondaryColor: Color(0xFFE2E8F0),
      icon: Icons.shield_rounded,
    ),
    LevelTierDefinition(
      minLevel: 40,
      maxLevel: 49,
      title: 'قائد الكتيبة',
      frameKey: 'frame_gold',
      frameName: 'إطار ذهبي موحد',
      tierBonusCoins: 1000,
      primaryColor: Color(0xFFD4AF37),
      secondaryColor: Color(0xFFF3C644),
      icon: Icons.military_tech_rounded,
    ),
    LevelTierDefinition(
      minLevel: 50,
      maxLevel: 59,
      title: 'حكيم السيرة',
      frameKey: 'frame_emerald',
      frameName: 'إطار زمردي ملكي',
      tierBonusCoins: 1500,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF52B788),
      icon: Icons.psychology_rounded,
    ),
    LevelTierDefinition(
      minLevel: 60,
      maxLevel: 69,
      title: 'وزير الديوان',
      frameKey: 'frame_ruby',
      frameName: 'إطار ياقوتي مشرق',
      tierBonusCoins: 2000,
      primaryColor: Color(0xFFE11D48),
      secondaryColor: Color(0xFFF43F5E),
      icon: Icons.account_balance_rounded,
    ),
    LevelTierDefinition(
      minLevel: 70,
      maxLevel: 79,
      title: 'أمير الفتح',
      frameKey: 'frame_sapphire',
      frameName: 'إطار لازوردي سلطاني',
      tierBonusCoins: 3000,
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF60A5FA),
      icon: Icons.flag_circle_rounded,
    ),
    LevelTierDefinition(
      minLevel: 80,
      maxLevel: 89,
      title: 'أسد الملاحم',
      frameKey: 'frame_platinum',
      frameName: 'إطار بلاتيني متوهج',
      tierBonusCoins: 4000,
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFFC084FC),
      icon: Icons.stars_rounded,
    ),
    LevelTierDefinition(
      minLevel: 90,
      maxLevel: 100,
      title: 'نخبة الأحفاد 👑',
      frameKey: 'frame_diamond',
      frameName: 'إطار ماسي أندلسي مشع',
      tierBonusCoins: 5000,
      primaryColor: Color(0xFF0EA5E9),
      secondaryColor: Color(0xFF38BDF8),
      icon: Icons.workspace_premium_rounded,
    ),
  ];

  /// Exact mathematical formula for cumulative XP required to reach [level] (1..100).
  /// Level 1 starts at 0 XP; Level 2 requires 250 XP; scales via `FLOOR(100 * L^1.6 + 150 * L)`.
  static int cumulativeXpForLevel(int level) {
    if (level <= 1) return 0;
    if (level == 2) return 250;
    final clamped = level.clamp(1, maxLevel);
    final prevLevel = clamped - 1;
    return (100.0 * math.pow(prevLevel, 1.6) + 150.0 * prevLevel).floor();
  }

  /// Calculates full [PlayerLevelInfo] from a player's cumulative [totalScore].
  factory PlayerLevelInfo.fromTotalScore(int totalScore) {
    final safeScore = math.max(0, totalScore);
    int lvl = 1;
    int prevXp = 0;
    int targetXp = 250;

    while (safeScore >= targetXp && lvl < maxLevel) {
      lvl++;
      prevXp = targetXp;
      targetXp = (100.0 * math.pow(lvl, 1.6) + 150.0 * lvl).floor();
    }

    final curXp = math.max(0, safeScore - prevXp);
    final reqXp = math.max(1, targetXp - prevXp);
    final progress = lvl >= maxLevel ? 1.0 : (curXp / reqXp).clamp(0.0, 1.0);
    final tier = resolveTier(lvl);

    return PlayerLevelInfo(
      level: lvl,
      title: tier.title,
      totalScore: safeScore,
      currentLevelXp: curXp,
      requiredLevelXp: reqXp,
      currentLevelFloorXp: prevXp,
      nextLevelCeilingXp: targetXp,
      progressPercent: progress,
      badgeColor: tier.primaryColor,
      secondaryColor: tier.secondaryColor,
      frameKey: tier.frameKey,
      frameName: tier.frameName,
      coinGrantForThisLevel: coinRewardForLevel(lvl),
      tierIcon: tier.icon,
    );
  }

  /// Returns milestone preview info for any specific [targetLevel] (1..100) on the Glory Road.
  factory PlayerLevelInfo.forMilestoneLevel(int targetLevel) {
    final lvl = targetLevel.clamp(1, maxLevel);
    final floorXp = cumulativeXpForLevel(lvl);
    final ceilingXp = lvl >= maxLevel
        ? floorXp
        : (100.0 * math.pow(lvl, 1.6) + 150.0 * lvl).floor();
    final tier = resolveTier(lvl);

    return PlayerLevelInfo(
      level: lvl,
      title: tier.title,
      totalScore: floorXp,
      currentLevelXp: 0,
      requiredLevelXp: math.max(1, ceilingXp - floorXp),
      currentLevelFloorXp: floorXp,
      nextLevelCeilingXp: ceilingXp,
      progressPercent: 0.0,
      badgeColor: tier.primaryColor,
      secondaryColor: tier.secondaryColor,
      frameKey: tier.frameKey,
      frameName: tier.frameName,
      coinGrantForThisLevel: coinRewardForLevel(lvl),
      tierIcon: tier.icon,
    );
  }

  /// Resolves the [LevelTierDefinition] for a given [level].
  static LevelTierDefinition resolveTier(int level) {
    for (final tier in allTiers) {
      if (level >= tier.minLevel && level <= tier.maxLevel) {
        return tier;
      }
    }
    return allTiers.last;
  }

  /// Calculates the coin grant awarded upon reaching [level]: `L * 50`.
  static int coinRewardForLevel(int level) {
    return level.clamp(1, maxLevel) * 50;
  }

  /// Calculates total coins granted when jumping from [oldLevel] to [newLevel].
  static int totalCoinsGrantedBetweenLevels(int oldLevel, int newLevel) {
    if (newLevel <= oldLevel) return 0;
    int sum = 0;
    for (int l = oldLevel + 1; l <= math.min(newLevel, maxLevel); l++) {
      sum += coinRewardForLevel(l);
    }
    return sum;
  }

  /// Remaining XP needed to reach the next level.
  int get remainingXpForNextLevel =>
      level >= maxLevel ? 0 : math.max(0, requiredLevelXp - currentLevelXp);

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'title': title,
      'totalScore': totalScore,
      'currentLevelXp': currentLevelXp,
      'requiredLevelXp': requiredLevelXp,
      'progressPercent': progressPercent,
      'frameKey': frameKey,
    };
  }
}
