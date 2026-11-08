import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/question_model.dart';
import 'package:ahfad_alsahaba/data/models/store_item_model.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/progression_service.dart';
import 'package:ahfad_alsahaba/data/services/store_service.dart';
import 'package:ahfad_alsahaba/logic/game_controller.dart';
import 'package:ahfad_alsahaba/ui/screens/global_ranking_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/animated_avatar_frame.dart';
import 'package:ahfad_alsahaba/ui/widgets/level_badge_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M6 Global App & UI Integration & Forensic Defect-Hunting Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'sound_enabled': false,
        'vibration_enabled': false,
      });
      await SharedPrefsService.init();
      await ProfileService.instance.init();
      await ProfileService.instance.createProfile(
        name: 'فارس الميدان',
        avatarIndex: 2,
      );
      final profile = ProfileService.instance.activeProfile!;
      profile.totalScore = 25000; // High enough for Level 25+
      profile.trophies = 1188;
      profile.coins = 10000;
      profile.gems = 100;
      profile.equippedFrame = 'frame_silver';
      profile.equippedTitle = null;
      profile.unlockedItemIds = ['theme_andalusian_gold', 'item_frame_wood'];
    });

    testWidgets(
      'GlobalRankingScreen renders AnimatedAvatarFrame, LevelBadgeWidget, equipped Honor Title, and Arena badges',
      (WidgetTester tester) async {
        final profile = ProfileService.instance.activeProfile!;
        profile.equippedTitle = 'صقر الأندلس';

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: const [AppCustomTheme.andalusianGold],
            ),
            home: const GlobalRankingScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('التصنيف العالمي'), findsWidgets);
        expect(find.text('فارس الميدان'), findsOneWidget);
        expect(find.byType(AnimatedAvatarFrame), findsWidgets);
        expect(find.byType(LevelBadgeWidget), findsWidgets);
        expect(find.textContaining('ميدان بدر الكبرى'), findsWidgets);
      },
    );

    test(
      'Honor Titles (StoreItemCategory.title) can be purchased, equipped, switched, and persisted',
      () async {
        final profile = ProfileService.instance.activeProfile!;
        final saqrItem = StoreItemModel.defaultCatalog.firstWhere(
          (i) => i.id == 'title_saqr_quraish',
        );
        final diraItem = StoreItemModel.defaultCatalog.firstWhere(
          (i) => i.id == 'title_dira_qadisiyah',
        );

        // Purchase first Honor Title
        final res1 = await StoreService.instance.purchaseOrEquip(saqrItem);
        expect(res1.success, isTrue);
        expect(profile.effectiveTitle, equals('صقر الأندلس'));
        expect(StoreService.instance.isItemEquipped(saqrItem), isTrue);
        expect(StoreService.instance.isItemEquipped(diraItem), isFalse);

        // Purchase second Honor Title -> automatically equips new title
        final res2 = await StoreService.instance.purchaseOrEquip(diraItem);
        expect(res2.success, isTrue);
        expect(profile.effectiveTitle, equals('درع القادسية'));
        expect(StoreService.instance.isItemEquipped(diraItem), isTrue);
        expect(StoreService.instance.isItemEquipped(saqrItem), isFalse);

        // Switch back to first owned Honor Title with 1 tap
        final res3 = await StoreService.instance.purchaseOrEquip(saqrItem);
        expect(res3.success, isTrue);
        expect(profile.effectiveTitle, equals('صقر الأندلس'));
        expect(StoreService.instance.isItemEquipped(saqrItem), isTrue);
      },
    );

    test(
      'Commander Insight (powerup_insight) consumes inventory item, hides 2 wrong options, and allows re-purchase',
      () async {
        final insightItem = StoreItemModel.defaultCatalog.firstWhere(
          (i) => i.id == 'powerup_insight',
        );

        // 1. Buy powerup_insight from StoreService
        final buy1 = await StoreService.instance.purchaseOrEquip(insightItem);
        expect(buy1.success, isTrue);
        expect(ProgressionService.instance.hasItem('powerup_insight'), isTrue);

        // 2. Consume powerup_insight in match
        final consumed = await ProgressionService.instance
            .consumeCommanderInsight();
        expect(consumed, isTrue);
        expect(ProgressionService.instance.hasItem('powerup_insight'), isFalse);

        final controller = GameController();
        controller.currentQuestions.add(
          Question(
            id: 'q1',
            questionText: 'من هو الصحابي الملقب بسيف الله المسلول؟',
            options: const [
              'خالد بن الوليد',
              'عمر بن الخطاب',
              'علي بن أبي طالب',
              'سعد بن أبي وقاص',
            ],
            correctAnswerIndex: 0,
            categoryId: 'history',
            levelNumber: 1,
          ),
        );

        final applied = controller.useCommanderInsight();
        expect(applied, isTrue);
        expect(controller.hiddenOptionIndices.length, equals(2));
        expect(controller.hiddenOptionIndices.contains(0), isFalse);

        // 3. Re-purchase powerup_insight after consumption
        final buy2 = await StoreService.instance.purchaseOrEquip(insightItem);
        expect(buy2.success, isTrue);
        expect(ProgressionService.instance.hasItem('powerup_insight'), isTrue);
      },
    );

    test(
      'powerup_shield protects trophies and winStreak on loss even if serverTotalTrophies has negative delta',
      () {
        final profile = ProfileService.instance.activeProfile!;
        profile.trophies = 1150;
        profile.winStreak = 4;
        profile.unlockedItemIds.add('powerup_shield');

        final outcome = ProgressionService.instance.applyMatchOutcome(
          rawMatchScore: 20,
          correctAnswers: 1,
          isWin: false,
          isDraw: false,
          serverTotalTrophies: 1138, // Server deducted -12
          serverTrophiesDelta: -12,
          updateTrophies: true,
        );

        expect(outcome.shieldConsumed, isTrue);
        expect(outcome.trophiesDelta, equals(0));
        expect(profile.trophies, equals(1150)); // Protected!
        expect(profile.winStreak, equals(4)); // Preserved!
        expect(profile.unlockedItemIds.contains('powerup_shield'), isFalse);
      },
    );

    test('AppRoutes registers gloryRoad and knightsStore routes cleanly', () {
      final gloryRoute = AppRoutes.generateRoute(
        const RouteSettings(name: AppRoutes.gloryRoad),
      );
      final storeRoute = AppRoutes.generateRoute(
        const RouteSettings(name: AppRoutes.knightsStore),
      );

      expect(gloryRoute, isNotNull);
      expect(storeRoute, isNotNull);
    });
  });
}
