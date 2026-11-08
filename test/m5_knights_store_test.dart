import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/store_item_model.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/progression_service.dart';
import 'package:ahfad_alsahaba/data/services/store_service.dart';
import 'package:ahfad_alsahaba/ui/screens/store/knights_store_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
    });
    await SharedPrefsService.init();
    await ProfileService.instance.init();
    await ProfileService.instance.createProfile(
      name: 'فهد الحلياني',
      avatarIndex: 0,
    );
    final profile = ProfileService.instance.activeProfile!;
    profile.totalScore = 5000; // Level 10+
    profile.coins = 4000;
    profile.gems = 50;
    profile.trophies = 1188;
    profile.winStreak = 4;
  });

  group('M5 KnightsStoreScreen & StoreService Economy Tests', () {
    testWidgets('KnightsStoreScreen renders wallet header and switches across all 4 tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const <ThemeExtension<dynamic>>[
              AppCustomTheme.andalusianGold,
            ],
          ),
          home: const KnightsStoreScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('سوق الفرسان الملكي 🪙'), findsOneWidget);
      expect(find.byKey(const Key('wallet_coins_badge')), findsOneWidget);
      expect(find.byKey(const Key('wallet_gems_badge')), findsOneWidget);

      // Tab 1: Themes
      expect(find.text('ثيم الدرع الأندلسي'), findsOneWidget);
      expect(find.text('ثيم راية الفتح الزمردي'), findsOneWidget);

      // Switch to Tab 2: Frames
      await tester.tap(find.text('الأطر المتوهجة (10)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('store_tab_frames')), findsOneWidget);
      expect(find.text('الإطار الخشبي العتيق'), findsOneWidget);

      // Switch to Tab 3: Honor Titles
      await tester.tap(find.text('أوسمة الفرسان'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('store_tab_titles')), findsOneWidget);
      expect(find.text('لقب «صقر الأندلس»'), findsOneWidget);

      // Switch to Tab 4: Smart Power-ups
      await tester.tap(find.text('وسائل المساعدة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('store_tab_powerups')), findsOneWidget);
      expect(find.text('درع الحماية التنافسي'), findsOneWidget);
    });

    test('Purchasing a Royal Theme deducts coins, unlocks item, and switches activeTheme immediately', () async {
      final profile = ProfileService.instance.activeProfile!;
      final emeraldItem = StoreItemModel.defaultCatalog.firstWhere(
        (i) => i.id == 'theme_emerald_banner',
      );

      expect(profile.coins, 4000);
      final res = await StoreService.instance.purchaseOrEquip(emeraldItem);
      expect(res.success, isTrue);
      expect(profile.coins, 4000 - 2500);
      expect(profile.equippedTheme, 'emerald_banner');
      expect(
        ProgressionService.instance.activeTheme.themeId,
        'emerald_banner',
      );

      // Preventing duplicate purchase: calling purchaseOrEquip again equips for free without deducting coins
      final res2 = await StoreService.instance.purchaseOrEquip(emeraldItem);
      expect(res2.success, isTrue);
      expect(profile.coins, 1500);
    });

    test('Purchasing powerup_shield protects trophies and winStreak upon match loss', () async {
      final profile = ProfileService.instance.activeProfile!;
      final shieldItem = StoreItemModel.defaultCatalog.firstWhere(
        (i) => i.id == 'powerup_shield',
      );

      final buyRes = await StoreService.instance.purchaseOrEquip(shieldItem);
      expect(buyRes.success, isTrue);
      expect(profile.unlockedItemIds.contains('powerup_shield'), isTrue);

      final beforeTrophies = profile.trophies;
      final beforeStreak = profile.winStreak;

      final outcome = ProgressionService.instance.applyMatchOutcome(
        rawMatchScore: 60,
        correctAnswers: 3,
        isWin: false,
        isDraw: false,
      );

      expect(outcome.shieldConsumed, isTrue);
      expect(outcome.trophiesDelta, 0); // Shield absorbed -12 penalty
      expect(profile.trophies, beforeTrophies);
      expect(profile.winStreak, beforeStreak); // Win streak preserved!
      expect(profile.unlockedItemIds.contains('powerup_shield'), isFalse);
    });
  });
}

