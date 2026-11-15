import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_latest;
import 'package:timezone/data/latest_10y.dart' as tz_10y;
import 'package:timezone/timezone.dart' as tz;

import 'package:ahfad_alsahaba/core/app_constants.dart';
import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/core/app_theme.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/achievement_model.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/services/achievement_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/question_service.dart';
import 'package:ahfad_alsahaba/data/services/quote_service.dart';
import 'package:ahfad_alsahaba/ui/screens/achievements_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/home/widgets/home_glowing_trophy_button.dart';
import 'package:ahfad_alsahaba/ui/screens/home_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/splash_screen.dart';

PlayerProfile _buildRealisticPopulatedProfile({bool markSeen = true}) {
  final levelStars = <String, int>{};
  final levelScores = <String, int>{};
  final categoryProgress = <String, int>{};
  const categories = [
    AppConstants.quranCategory,
    AppConstants.hadithCategory,
    AppConstants.fiqhCategory,
    AppConstants.seerahCategory,
    AppConstants.historyCategory,
    AppConstants.aqeedahCategory,
  ];

  for (final cat in categories) {
    categoryProgress[cat] = 10;
    for (int lvl = 1; lvl <= 10; lvl++) {
      levelStars['${cat}_level_$lvl'] = 3;
      levelScores['${cat}_level_$lvl'] = 100;
    }
  }

  final achievements = <String, AchievementProgress>{};
  for (final achievement in AchievementDefinitions.all) {
    achievements[achievement.id] = AchievementProgress(
      achievementId: achievement.id,
      currentValue: achievement.targetValue,
      isUnlocked: true,
      unlockedAt: DateTime(2026, 11, 14),
      hasBeenSeen: markSeen,
    );
  }

  return PlayerProfile(
    id: 'bench_profile_1',
    name: 'فارس الاختبار',
    totalScore: 6000,
    highScore: 100,
    categoryProgress: categoryProgress,
    levelStars: levelStars,
    levelScores: levelScores,
    achievementProgress: achievements,
    currentStreak: 7,
    totalDaysPlayed: 30,
    coins: 500,
    gems: 40,
    trophies: 1450,
    winStreak: 3,
  );
}

Future<void> _seedLocalStorageWithProfile(PlayerProfile profile) async {
  final encodedJson = PlayerProfile.profilesToJson([profile]);
  await SharedPrefsService.init();
  await SharedPrefsService.saveSoundEnabled(false);
  await SharedPrefsService.saveVibrationEnabled(false);
  await SharedPrefsService.saveOnboardingSeen();
  await SharedPrefsService.setHasSeenTutorial(true);
  await SharedPrefsService.saveProfilesJson(encodedJson);
  await SharedPrefsService.setActiveProfileId(profile.id);
  await ProfileService.instance.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
      'onboarding_seen': true,
      'has_seen_tutorial': true,
    });
    await SharedPrefsService.init();

    // Measure Supabase local initialization cost cleanly (no deep-link platform plugin needed in test)
    final sbSw = Stopwatch()..start();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key-benchmark',
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
    sbSw.stop();
    debugPrint(
      '[BENCHMARK 0] Supabase.initialize() local init (no network call): '
      '${(sbSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms',
    );
  });

  setUp(() async {
    await SharedPrefsService.init();
    await SharedPrefsService.saveSoundEnabled(false);
    await SharedPrefsService.saveVibrationEnabled(false);
    await SharedPrefsService.saveOnboardingSeen();
    await SharedPrefsService.setHasSeenTutorial(true);
  });

  group('Startup & Badge Performance Benchmarks (Post-Optimization)', () {
    test('Benchmark 1: Timezone database init cost (latest.dart vs latest_10y.dart)', () {
      tz.timeZoneDatabase.clear();
      final latestSw = Stopwatch()..start();
      tz_latest.initializeTimeZones();
      latestSw.stop();
      final latestLocations = tz.timeZoneDatabase.locations.length;
      final riyadhFull = tz.getLocation('Asia/Riyadh');

      tz.timeZoneDatabase.clear();
      final tenYearSw = Stopwatch()..start();
      tz_10y.initializeTimeZones();
      tenYearSw.stop();
      final tenYearLocations = tz.timeZoneDatabase.locations.length;
      final riyadhTenYear = tz.getLocation('Asia/Riyadh');

      expect(riyadhFull.name, 'Asia/Riyadh');
      expect(riyadhTenYear.name, 'Asia/Riyadh');
      expect(latestLocations, greaterThan(400));
      expect(tenYearLocations, greaterThan(400));
      expect(tenYearSw.elapsedMicroseconds, lessThan(latestSw.elapsedMicroseconds));

      final ratio = latestSw.elapsedMicroseconds /
          (tenYearSw.elapsedMicroseconds == 0 ? 1 : tenYearSw.elapsedMicroseconds);
      debugPrint(
        '[BENCHMARK 1] tz_latest (current main/NotificationService): '
        '${(latestSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms ($latestLocations zones)',
      );
      debugPrint(
        '[BENCHMARK 1] tz_latest_10y (recommended): '
        '${(tenYearSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms ($tenYearLocations zones) '
        '-> ${ratio.toStringAsFixed(1)}x faster',
      );
    });

    test('Benchmark 2: Local profile JSON, salaf_quotes.json, and quran.json main-thread parse timings',
        () async {
      final profile = _buildRealisticPopulatedProfile(markSeen: true);
      final encodedJson = PlayerProfile.profilesToJson([profile]);
      await SharedPrefsService.saveProfilesJson(encodedJson);
      await SharedPrefsService.setActiveProfileId(profile.id);

      final coldProfileSw = Stopwatch()..start();
      final coldParsed = PlayerProfile.profilesFromJson(encodedJson);
      coldProfileSw.stop();

      final profileInitSw = Stopwatch()..start();
      await ProfileService.instance.init();
      profileInitSw.stop();

      final quotesSw = Stopwatch()..start();
      await QuoteService.instance.loadQuotes();
      quotesSw.stop();

      final quranSw = Stopwatch()..start();
      await QuestionService().preloadCategory(AppConstants.quranCategory);
      quranSw.stop();

      final libraryRaw = await rootBundle.loadString('assets/data/library/content.json');
      final libraryFileBytes = File('assets/data/library/content.json').lengthSync();

      expect(coldParsed.single.levelStars.length, 60);
      expect(ProfileService.instance.activeProfile?.id, profile.id);
      expect(QuoteService.instance.allQuotes, isNotEmpty);

      debugPrint(
        '[BENCHMARK 2] Cold profilesFromJson (${encodedJson.length} chars): '
        '${(coldProfileSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms | '
        'ProfileService.init(): ${(profileInitSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms',
      );
      debugPrint(
        '[BENCHMARK 2] QuoteService.loadQuotes() (salaf_quotes.json): '
        '${(quotesSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms '
        '(${QuoteService.instance.allQuotes.length} quotes)',
      );
      debugPrint(
        '[BENCHMARK 2] QuestionService.preloadCategory(quran): '
        '${(quranSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms | '
        'library/content.json=${(libraryFileBytes / 1024).toStringAsFixed(1)} KB disk (${libraryRaw.length} chars)',
      );
    });

    testWidgets('Benchmark 3: logo.png unscaled 1080x1080 decode vs bounded cacheWidth=256 decode',
        (tester) async {
      await tester.runAsync(() async {
        final logoFile = File('assets/images/logo.png');
        final bytes = await logoFile.readAsBytes();

        final fullSw = Stopwatch()..start();
        final fullCodec = await ui.instantiateImageCodec(bytes);
        final fullFrame = await fullCodec.getNextFrame();
        fullSw.stop();
        final fullImage = fullFrame.image;
        final fullRgbaBytes = fullImage.width * fullImage.height * 4;

        final scaledSw = Stopwatch()..start();
        final scaledCodec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 256,
          targetHeight: 256,
        );
        final scaledFrame = await scaledCodec.getNextFrame();
        scaledSw.stop();
        final scaledImage = scaledFrame.image;
        final scaledRgbaBytes = scaledImage.width * scaledImage.height * 4;

        expect(fullImage.width, 1080);
        expect(fullImage.height, 1080);
        expect(scaledImage.width, 256);
        expect(scaledImage.height, 256);
        expect(fullRgbaBytes, greaterThan(4 * 1024 * 1024));

        debugPrint(
          '[BENCHMARK 3] assets/images/logo.png (${(bytes.length / 1024).toStringAsFixed(1)} KB): '
          'Unscaled ${fullImage.width}x${fullImage.height} = ${(fullRgbaBytes / (1024 * 1024)).toStringAsFixed(2)} MB RGBA '
          'in ${(fullSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms',
        );
        debugPrint(
          '[BENCHMARK 3] Bounded 256x256 = ${(scaledRgbaBytes / 1024).toStringAsFixed(1)} KB RGBA '
          'in ${(scaledSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms '
          '(memory saving ${(100 * (1 - scaledRgbaBytes / fullRgbaBytes)).toStringAsFixed(1)}%)',
        );

        fullImage.dispose();
        scaledImage.dispose();
      });
    });

    testWidgets(
        'Benchmark 4: SplashScreen routes local-first with 0ms hardcoded delay on 360x800 dp',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0; // 360x800 logical dp (verifies zero AppBar overflow)
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final profile = _buildRealisticPopulatedProfile(markSeen: true);
      await _seedLocalStorageWithProfile(profile);
      expect(ProfileService.instance.hasProfiles, isTrue);

      final splashFirstFrameSw = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          onGenerateRoute: AppRoutes.generateRoute,
          initialRoute: AppRoutes.splash,
        ),
      );
      splashFirstFrameSw.stop();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(AppConstants.splashDuration, 0);

      // Local-first 0ms routing: transitions immediately after first frame + fade animation, no 3000ms delay
      final transitionSw = Stopwatch()..start();
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      transitionSw.stop();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      debugPrint(
        '[BENCHMARK 4] SplashScreen first frame build+paint: '
        '${(splashFirstFrameSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms | '
        'Local-first delay: ${AppConstants.splashDuration} ms',
      );
      debugPrint(
        '[BENCHMARK 4] Splash -> Home transition (0ms forced delay): '
        '${(transitionSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms',
      );

      // Dispose HomeScreen cleanly: cancellable timers leave zero pending timers
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'Benchmark 5: HomeScreen 360dp zero-overflow & Achievements badge clears (4 -> 0) after opening AchievementsScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0; // 360x800 logical dp (verifies zero AppBar/Header overflow)
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final profile = _buildRealisticPopulatedProfile(markSeen: true);
      final unseenIds = AchievementDefinitions.all.take(4).map((a) => a.id).toList();
      for (final id in unseenIds) {
        profile.achievementProgress[id]!.hasBeenSeen = false;
      }
      await _seedLocalStorageWithProfile(profile);

      expect(AchievementService.instance.newAchievementsCount, 4);

      final homeBuildSw = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          onGenerateRoute: AppRoutes.generateRoute,
          home: const HomeScreen(),
        ),
      );
      homeBuildSw.stop();

      // Pump once for post-frame callbacks (quotes + initial animation)
      await tester.pump(const Duration(milliseconds: 50));

      final trophyFinder = find.byType(HomeGlowingTrophyButton);
      expect(trophyFinder, findsOneWidget);
      final trophyBefore = tester.widget<HomeGlowingTrophyButton>(trophyFinder);
      expect(trophyBefore.hasNotification, isTrue);
      expect(trophyBefore.notificationCount, 4);
      expect(find.text('4'), findsOneWidget);

      // Open AchievementsScreen via Trophy button
      final openAchSw = Stopwatch()..start();
      await tester.tap(
        find.descendant(
          of: trophyFinder,
          matching: find.byIcon(Icons.emoji_events_rounded),
        ),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      openAchSw.stop();

      expect(find.byType(AchievementsScreen), findsOneWidget);
      final pointsTab = find.text('نقاط');
      expect(pointsTab, findsOneWidget);
      await tester.ensureVisible(pointsTab);
      await tester.pump();
      await tester.tap(pointsTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();

      // Return to HomeScreen: badge clears optimistically to 0 after opening AchievementsScreen
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomeScreen), findsOneWidget);
      final trophyAfter = tester.widget<HomeGlowingTrophyButton>(find.byType(HomeGlowingTrophyButton));
      expect(
        AchievementService.instance.newAchievementsCount,
        0,
        reason: 'AchievementsScreen marks unlocked achievements as seen optimistically (4 -> 0).',
      );
      expect(trophyAfter.notificationCount, 0);
      expect(trophyAfter.hasNotification, isFalse);
      expect(
        find.descendant(
          of: find.byType(HomeGlowingTrophyButton),
          matching: find.text('4'),
        ),
        findsNothing,
      );

      debugPrint(
        '[BENCHMARK 5] HomeScreen first frame build+paint: '
        '${(homeBuildSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms | '
        'Home -> Achievements push+build: ${(openAchSw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms',
      );
      debugPrint(
        '[BENCHMARK 5] Achievements badge before viewing=${trophyBefore.notificationCount}, '
        'after viewing AchievementsScreen & returning=${trophyAfter.notificationCount} (CLEARED 4 -> 0!)',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
