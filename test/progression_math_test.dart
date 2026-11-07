import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/data/models/player_level_model.dart';
import 'package:ahfad_alsahaba/data/models/arena_model.dart';
import 'package:ahfad_alsahaba/data/models/store_item_model.dart';
import 'package:ahfad_alsahaba/data/models/leaderboard_model.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';

void main() {
  group('PlayerLevelInfo 100-Level Mastery Math Tests', () {
    test('Level 1 starts at 0 XP with طالب علم title', () {
      final info = PlayerLevelInfo.fromTotalScore(0);
      expect(info.level, 1);
      expect(info.title, 'طالب علم');
      expect(info.currentLevelXp, 0);
      expect(info.requiredLevelXp, 250);
      expect(info.progressPercent, 0.0);
    });

    test('Level 2 reached at 250 XP', () {
      final info = PlayerLevelInfo.fromTotalScore(250);
      expect(info.level, 2);
      expect(info.title, 'طالب علم');
      expect(info.currentLevelXp, 0);
    });

    test('Fahad Al-Halyani live score (2804 XP) resolves accurately', () {
      final info = PlayerLevelInfo.fromTotalScore(2804);
      expect(info.level, greaterThanOrEqualTo(6));
      expect(info.progressPercent, inInclusiveRange(0.0, 1.0));
      expect(info.remainingXpForNextLevel, greaterThan(0));
    });

    test('Omni-Tech live score (1965 XP) resolves accurately', () {
      final info = PlayerLevelInfo.fromTotalScore(1965);
      expect(info.level, greaterThanOrEqualTo(5));
      expect(info.progressPercent, inInclusiveRange(0.0, 1.0));
    });

    test('Level 100 cap and نخبة الأحفاد title', () {
      final info = PlayerLevelInfo.fromTotalScore(500000);
      expect(info.level, 100);
      expect(info.title, 'نخبة الأحفاد 👑');
      expect(info.progressPercent, 1.0);
      expect(info.remainingXpForNextLevel, 0);
    });

    test('Coin grant formula awards L * 50 coins per level', () {
      expect(PlayerLevelInfo.coinRewardForLevel(1), 50);
      expect(PlayerLevelInfo.coinRewardForLevel(10), 500);
      expect(PlayerLevelInfo.totalCoinsGrantedBetweenLevels(1, 3), 100 + 150);
    });
  });

  group('ArenaModel 6-Arena Competitive Tests', () {
    test('800 Trophy Floor Protection works', () {
      expect(ArenaModel.clampTrophies(500), 800);
      final arena = ArenaModel.fromTrophies(500);
      expect(arena.id, 1);
      expect(arena.name, 'ميدان يثرب');
    });

    test('Fahad (1188 Trophies) and Omni-Tech (1090 Trophies) are in ميدان بدر الكبرى', () {
      final fahadArena = ArenaModel.fromTrophies(1188);
      final omniArena = ArenaModel.fromTrophies(1090);
      expect(fahadArena.id, 2);
      expect(fahadArena.name, 'ميدان بدر الكبرى');
      expect(fahadArena.trophiesToNextArena(1188), 12); // 12 trophies away from Yarmouk (1200)
      expect(omniArena.id, 2);
      expect(omniArena.trophiesToNextArena(1090), 110);
    });

    test('Trophy delta with win streak', () {
      expect(ArenaModel.calculateTrophyDelta(isWin: true, isDraw: false, winStreak: 0), 25);
      expect(ArenaModel.calculateTrophyDelta(isWin: true, isDraw: false, winStreak: 3), 31);
      expect(ArenaModel.calculateTrophyDelta(isWin: true, isDraw: false, winStreak: 10), 35);
      expect(ArenaModel.calculateTrophyDelta(isWin: false, isDraw: false), -12);
      expect(ArenaModel.calculateTrophyDelta(isWin: false, isDraw: true), 5);
    });
  });

  group('AppCustomTheme 4-Themes Tests', () {
    test('Theme lookup and lerp work cleanly', () {
      expect(AppCustomTheme.fromId('andalusian_gold').themeName, 'الدرع الأندلسي');
      expect(AppCustomTheme.fromId('emerald_banner').themeName, 'راية الفتح الزمردي');
      expect(AppCustomTheme.fromId('badr_meteors').themeName, 'شهب ليلة بدر');
      expect(AppCustomTheme.fromId('yarmouk_carnelian').themeName, 'عقيق اليرموك');

      final lerped = AppCustomTheme.andalusianGold.lerp(AppCustomTheme.emeraldBanner, 0.5);
      expect(lerped.deepBackground, isNotNull);
    });
  });

  group('StoreItemModel & RankEntry M2 Sync Tests', () {
    test('StoreItemModel defaultCatalog has all 20 items (4 themes, 10 frames, 3 titles, 3 powerups)', () {
      const catalog = StoreItemModel.defaultCatalog;
      expect(catalog.length, 20);
      expect(catalog.where((i) => i.category == StoreItemCategory.theme).length, 4);
      expect(catalog.where((i) => i.category == StoreItemCategory.frame).length, 10);
      expect(catalog.where((i) => i.category == StoreItemCategory.title).length, 3);
      expect(catalog.where((i) => i.category == StoreItemCategory.powerup).length, 3);
    });

    test('RankEntry.fromSupabaseMap parses and computes glory metadata accurately', () {
      final fahadRank = RankEntry.fromSupabaseMap(
        {
          'user_id': '4f0ed9dd-f266-4ef5-a978-e159abfb821c',
          'display_name': 'فهد الحلياني',
          'score': 2804,
          'trophies': 1188,
          'wins_count': 8,
          'matches_count': 9,
        },
        rank: 1,
        currentUserId: '4f0ed9dd-f266-4ef5-a978-e159abfb821c',
      );
      expect(fahadRank.isMe, isTrue);
      expect(fahadRank.playerLevel, 7);
      expect(fahadRank.playerTitle, 'طالب علم');
      expect(fahadRank.arenaId, 2);
      expect(fahadRank.arenaName, 'ميدان بدر الكبرى');
      expect(fahadRank.equippedFrame, 'frame_wood');
    });
  });
}

