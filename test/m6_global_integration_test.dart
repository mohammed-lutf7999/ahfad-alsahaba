import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/question_model.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/progression_service.dart';
import 'package:ahfad_alsahaba/logic/game_controller.dart';
import 'package:ahfad_alsahaba/ui/screens/global_ranking_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/animated_avatar_frame.dart';
import 'package:ahfad_alsahaba/ui/widgets/level_badge_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M6 Global App & UI Integration Tests', () {
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
      profile.totalScore = 2804;
      profile.trophies = 1188;
      profile.equippedFrame = 'frame_silver';
    });

    testWidgets(
      'GlobalRankingScreen renders AnimatedAvatarFrame, LevelBadgeWidget, and Arena badges',
      (WidgetTester tester) async {
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
      'Commander Insight (powerup_insight) consumes inventory item and hides 2 wrong options',
      () async {
        final profile = ProfileService.instance.activeProfile!;
        profile.unlockedItemIds.add('powerup_insight');
        expect(ProgressionService.instance.hasItem('powerup_insight'), isTrue);

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
