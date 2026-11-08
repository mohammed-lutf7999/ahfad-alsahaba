import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/models/player_level_model.dart';
import 'package:ahfad_alsahaba/ui/widgets/animated_avatar_frame.dart';
import 'package:ahfad_alsahaba/ui/widgets/level_badge_widget.dart';
import 'package:ahfad_alsahaba/ui/widgets/glory_progress_bar.dart';

void main() {
  group('M3 Royal Visual Widgets & Shaders Tests', () {
    testWidgets('AnimatedAvatarFrame renders all 10 Royal Frames and Win Streak Aura cleanly', (tester) async {
      final frameKeys = RoyalFrameStyle.styles.keys.toList();
      expect(frameKeys.length, 10);

      for (final key in frameKeys) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedAvatarFrame(
                  frameKey: key,
                  size: 72,
                  winStreak: 5,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(AnimatedAvatarFrame), findsOneWidget);
        expect(find.text('5'), findsOneWidget); // Win streak badge
      }
    });

    testWidgets('LevelBadgeWidget renders all 10 tiers (Levels 1..100) in both Compact and Full modes', (tester) async {
      const sampleLevels = [1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

      for (final lvl in sampleLevels) {
        final info = PlayerLevelInfo.fromTotalScore(
          PlayerLevelInfo.cumulativeXpForLevel(lvl),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Column(
                  children: [
                    LevelBadgeWidget(levelInfo: info, isCompact: true),
                    LevelBadgeWidget(levelInfo: info, isCompact: false),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(LevelBadgeWidget), findsNWidgets(2));
        expect(find.text('م.$lvl'), findsOneWidget);
        expect(find.text('المستوى $lvl'), findsOneWidget);
        expect(find.text(info.title), findsNWidgets(2));
      }
    });

    testWidgets('GloryProgressBar animates XP and percentage across all 4 Royal Themes', (tester) async {
      final themes = [
        AppCustomTheme.andalusianGold,
        AppCustomTheme.emeraldBanner,
        AppCustomTheme.badrMeteors,
        AppCustomTheme.yarmoukCarnelian,
      ];

      final fahadInfo = PlayerLevelInfo.fromTotalScore(2804);

      for (final customTheme in themes) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: <ThemeExtension<dynamic>>[customTheme],
            ),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GloryProgressBar(
                    levelInfo: fahadInfo,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(GloryProgressBar), findsOneWidget);
        expect(
          find.text('${fahadInfo.currentLevelXp} / ${fahadInfo.requiredLevelXp} XP'),
          findsOneWidget,
        );
      }
    });
  });
}

