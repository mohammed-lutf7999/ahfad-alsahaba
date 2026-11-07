import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahfad_alsahaba/core/sound_service.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/arena_model.dart';
import 'package:ahfad_alsahaba/data/models/player_level_model.dart';
import 'package:ahfad_alsahaba/data/services/progression_service.dart';
import 'package:ahfad_alsahaba/ui/dialogs/arena_promotion_dialog.dart';
import 'package:ahfad_alsahaba/ui/dialogs/level_up_celebration_dialog.dart';
import 'package:ahfad_alsahaba/ui/screens/glory/glory_road_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/animated_avatar_frame.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_enabled': true,
      'vibration_enabled': true,
    });
    await SharedPrefsService.init();
    SoundService().rankUpPlayCount = 0;
  });

  group('M4 Glory Road & Epic Celebration Dialogs Tests', () {
    testWidgets('GloryRoadScreen renders 100-Level Ladder and switches to 6 Arenas tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const <ThemeExtension<dynamic>>[
              AppCustomTheme.andalusianGold,
            ],
          ),
          home: const GloryRoadScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));

      // Verify AppBar & Tabs exist
      expect(find.text('طريق المجد والميادين 👑'), findsOneWidget);
      expect(find.text('سُلّم الـ 100 مستوى'), findsOneWidget);
      expect(find.text('الميادين الستة (6)'), findsOneWidget);

      // Verify Tab 1 (100-Level ListView) renders
      expect(find.byKey(const Key('glory_road_levels_list')), findsOneWidget);
      expect(find.text('المستوى 1'), findsOneWidget);

      // Switch to Tab 2 (6 Historic Arenas)
      await tester.tap(find.text('الميادين الستة (6)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('glory_road_arenas_list')), findsOneWidget);
      expect(
        find.textContaining('درع الأمان التنافسي: محمي عند سقف 800 كأس'),
        findsOneWidget,
      );
      expect(find.textContaining('ميدان يثرب'), findsWidgets);
      expect(find.textContaining('ميدان بدر الكبرى'), findsWidgets);
    });

    testWidgets('LevelUpCelebrationDialog displays new level, title, frame, coin grant, and action buttons', (tester) async {
      final transition = ProgressionService.instance.evaluateScoreTransition(
        oldScore: 200, // Level 1
        newScore: 5000, // Level 10 (راوي الأثر)
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => LevelUpCelebrationDialog(
                      transition: transition,
                      triggerSensoryOnOpen: false,
                    ),
                  );
                },
                child: const Text('Open LevelUp'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open LevelUp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LevelUpCelebrationDialog), findsOneWidget);
      expect(find.byType(AnimatedAvatarFrame), findsOneWidget);
      expect(
        find.text('بلغت المستوى ${transition.newLevel.level}!'),
        findsOneWidget,
      );
      expect(find.text(transition.newLevel.title), findsOneWidget);
      expect(
        find.textContaining('+${transition.coinsAwarded} دينار فتح'),
        findsOneWidget,
      );
      expect(find.text('متابعة المسيرة'), findsOneWidget);
      expect(find.text('مشاركة الفخر 📲'), findsOneWidget);

      // Dismiss via «متابعة المسيرة»
      await tester.tap(find.text('متابعة المسيرة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LevelUpCelebrationDialog), findsNothing);
    });

    testWidgets('ArenaPromotionDialog displays new arena, multiplier, and dismisses cleanly', (tester) async {
      final transition = ArenaPromotionTransition(
        oldArena: ArenaModel.fromTrophies(1188), // Badr (1.2x)
        newArena: ArenaModel.fromTrophies(1220), // Yarmouk (1.5x)
        currentTrophies: 1220,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => ArenaPromotionDialog(
                      transition: transition,
                      triggerSensoryOnOpen: false,
                    ),
                  );
                },
                child: const Text('Open ArenaPromo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open ArenaPromo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ArenaPromotionDialog), findsOneWidget);
      expect(find.text('ميدان اليرموك'), findsOneWidget);
      expect(find.textContaining('1.5x'), findsWidgets);
      expect(find.text('دخول الميدان بعزة ⚔️'), findsOneWidget);

      await tester.tap(find.text('دخول الميدان بعزة ⚔️'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ArenaPromotionDialog), findsNothing);
    });

    test('SoundService.playRankUp respects mute setting without throwing errors', () async {
      // 1. When sound is muted -> rankUpPlayCount remains 0
      await SharedPrefsService.setSoundEnabled(false);
      await SoundService().playRankUp();
      expect(SoundService().rankUpPlayCount, 0);

      // 2. When sound is enabled -> rankUpPlayCount increments to 1
      await SharedPrefsService.setSoundEnabled(true);
      await SoundService().playRankUp();
      expect(SoundService().rankUpPlayCount, 1);

      // 3. Also verify PlayerLevelInfo milestone helper for Level 100
      final lvl100 = PlayerLevelInfo.forMilestoneLevel(100);
      expect(lvl100.level, 100);
      expect(lvl100.title, 'نخبة الأحفاد 👑');
    });
  });
}

