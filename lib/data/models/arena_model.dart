import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents one of the 6 competitive historic arenas based on player Trophies.
class ArenaModel {
  static const int minFloorTrophies = 800;
  static const int defaultStartingTrophies = 1000;

  final int id;
  final String name;
  final String subtitle;
  final int minTrophies;
  final int? maxTrophies;
  final double coinMultiplier;
  final Color accentColor;
  final Color secondaryColor;
  final String themeKey;
  final IconData icon;

  const ArenaModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.minTrophies,
    this.maxTrophies,
    required this.coinMultiplier,
    required this.accentColor,
    required this.secondaryColor,
    required this.themeKey,
    required this.icon,
  });

  /// All 6 Historic Competitive Arenas in ascending order of Trophies.
  static const List<ArenaModel> allArenas = [
    ArenaModel(
      id: 1,
      name: 'ميدان يثرب',
      subtitle: 'روضة المدينة وميدان التأهيل',
      minTrophies: 800,
      maxTrophies: 999,
      coinMultiplier: 1.0,
      accentColor: Color(0xFFA3E635),
      secondaryColor: Color(0xFF4D7C0F),
      themeKey: 'emerald_banner',
      icon: Icons.mosque_rounded,
    ),
    ArenaModel(
      id: 2,
      name: 'ميدان بدر الكبرى',
      subtitle: 'نقطة انطلاق الفرسان وميلاد المجد',
      minTrophies: 1000,
      maxTrophies: 1199,
      coinMultiplier: 1.2,
      accentColor: Color(0xFF38BDF8),
      secondaryColor: Color(0xFF0284C7),
      themeKey: 'badr_meteors',
      icon: Icons.nights_stay_rounded,
    ),
    ArenaModel(
      id: 3,
      name: 'ميدان اليرموك',
      subtitle: 'هضاب الشام وملاحم البطولة',
      minTrophies: 1200,
      maxTrophies: 1399,
      coinMultiplier: 1.5,
      accentColor: Color(0xFFF43F5E),
      secondaryColor: Color(0xFFBE123C),
      themeKey: 'yarmouk_carnelian',
      icon: Icons.gavel_rounded,
    ),
    ArenaModel(
      id: 4,
      name: 'ميدان القادسية',
      subtitle: 'نزال القادة الكبار وكسر الإمبراطوريات',
      minTrophies: 1400,
      maxTrophies: 1599,
      coinMultiplier: 1.8,
      accentColor: Color(0xFF52B788),
      secondaryColor: Color(0xFF1B4332),
      themeKey: 'emerald_banner',
      icon: Icons.shield_moon_rounded,
    ),
    ArenaModel(
      id: 5,
      name: 'ميدان عمورية',
      subtitle: 'حلبة الفرسان المخضرمين وذروة الشجاعة',
      minTrophies: 1600,
      maxTrophies: 1849,
      coinMultiplier: 2.0,
      accentColor: Color(0xFFA855F7),
      secondaryColor: Color(0xFF6B21A8),
      themeKey: 'andalusian_gold',
      icon: Icons.fort_rounded,
    ),
    ArenaModel(
      id: 6,
      name: 'ميدان الفتوحات العظمى',
      subtitle: 'قمة النخبة في العالم الإسلامي',
      minTrophies: 1850,
      maxTrophies: null,
      coinMultiplier: 2.5,
      accentColor: Color(0xFFF3C644),
      secondaryColor: Color(0xFFB45309),
      themeKey: 'andalusian_gold',
      icon: Icons.emoji_events_rounded,
    ),
  ];

  /// Enforces the 800-trophy protection floor.
  static int clampTrophies(int rawTrophies) {
    return math.max(minFloorTrophies, rawTrophies);
  }

  /// Resolves the active [ArenaModel] for a given [trophies] count.
  static ArenaModel fromTrophies(int trophies) {
    final safeTrophies = clampTrophies(trophies);
    for (int i = allArenas.length - 1; i >= 0; i--) {
      if (safeTrophies >= allArenas[i].minTrophies) {
        return allArenas[i];
      }
    }
    return allArenas.first;
  }

  /// Returns the next arena above this one, or `null` if already at the pinnacle (Arena 6).
  ArenaModel? get nextArena {
    final idx = allArenas.indexWhere((a) => a.id == id);
    if (idx >= 0 && idx < allArenas.length - 1) {
      return allArenas[idx + 1];
    }
    return null;
  }

  /// Calculates progress percentage (0.0 to 1.0) inside the current arena towards the next arena.
  double progressInArena(int currentTrophies) {
    final next = nextArena;
    if (next == null) return 1.0;
    final safe = clampTrophies(currentTrophies);
    final span = math.max(1, next.minTrophies - minTrophies);
    final earnedInArena = math.max(0, safe - minTrophies);
    return (earnedInArena / span).clamp(0.0, 1.0);
  }

  /// Remaining trophies required to unlock the next arena (`0` if in the top arena).
  int trophiesToNextArena(int currentTrophies) {
    final next = nextArena;
    if (next == null) return 0;
    return math.max(0, next.minTrophies - currentTrophies);
  }

  /// Calculates coin reward for a match using this arena's multiplier:
  /// `FLOOR((baseCoins + correctAnswers * 3) * coinMultiplier)`.
  int calculateMatchCoins({
    int baseCoins = 10,
    required int correctAnswers,
  }) {
    final raw = (baseCoins + math.max(0, correctAnswers) * 3) * coinMultiplier;
    return raw.floor();
  }

  /// Calculates competitive trophy delta with win streak bonus:
  /// Win: `25 + min(winStreak * 2, 10)`
  /// Loss: `-12`
  /// Draw: `+5`
  static int calculateTrophyDelta({
    required bool isWin,
    required bool isDraw,
    int winStreak = 0,
  }) {
    if (isDraw) return 5;
    if (isWin) {
      final streakBonus = math.min(math.max(0, winStreak) * 2, 10);
      return 25 + streakBonus;
    }
    return -12;
  }
}

