import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahfad_alsahaba/core/app_constants.dart';
import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/core/app_theme.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/achievement_model.dart';
import 'package:ahfad_alsahaba/data/models/category_model.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/progression_service.dart';
import 'package:ahfad_alsahaba/data/services/question_service.dart';
import 'package:ahfad_alsahaba/logic/game_controller.dart';
import 'package:ahfad_alsahaba/logic/timer_controller.dart';
import 'package:ahfad_alsahaba/main.dart';
import 'package:ahfad_alsahaba/ui/screens/levels_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/quiz_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/result_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/achievement_popup.dart';
import 'package:ahfad_alsahaba/ui/widgets/category_item.dart';

void _markAllAchievementsSeen(PlayerProfile profile) {
  for (final achievement in AchievementDefinitions.all) {
    final progress = profile.getAchievementProgress(achievement.id);
    progress.currentValue = achievement.targetValue;
    progress.isUnlocked = true;
    progress.hasBeenSeen = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
    });
    await SharedPrefsService.init();
    await ProfileService.instance.init();
  });

  group('M13: Levels, Result Transition & Replay Integrity Tests', () {
    test('AppConstants.calculateStars unifies 50% passing threshold with 1 star', () {
      expect(AppConstants.calculateStars(0), 0);
      expect(AppConstants.calculateStars(40), 0);
      expect(AppConstants.calculateStars(49.9), 0);
      expect(AppConstants.calculateStars(50.0), 1);
      expect(AppConstants.calculateStars(60.0), 1);
      expect(AppConstants.calculateStars(70.0), 2);
      expect(AppConstants.calculateStars(89.9), 2);
      expect(AppConstants.calculateStars(90.0), 3);
      expect(AppConstants.calculateStars(100.0), 3);
    });

    test('AppConstants.getCategoryName returns distinct Arabic titles for all 6 categories', () {
      expect(AppConstants.getCategoryName(AppConstants.quranCategory), 'القرآن الكريم');
      expect(AppConstants.getCategoryName(AppConstants.hadithCategory), 'الحديث الشريف');
      expect(AppConstants.getCategoryName(AppConstants.fiqhCategory), 'الفقه الإسلامي');
      expect(AppConstants.getCategoryName(AppConstants.seerahCategory), 'السيرة النبوية');
      expect(AppConstants.getCategoryName(AppConstants.historyCategory), 'التاريخ الإسلامي');
      expect(AppConstants.getCategoryName(AppConstants.aqeedahCategory), 'العقيدة الإسلامية');
    });

    test('PlayerProfile clamps unlocked levels to 10 and reconciles isLevelUnlocked', () {
      final profile = PlayerProfile(id: 'test_1', name: 'فارس الاختبار');

      // Setting 11 (after completing level 10) must clamp to 10
      profile.setCategoryUnlockedLevels('quran', 11);
      expect(profile.getCategoryUnlockedLevels('quran'), 10);

      // Level <= unlockedLevels is unlocked even if stars map was not yet populated
      profile.setCategoryUnlockedLevels('hadith', 4);
      expect(profile.isLevelUnlocked('hadith', 1), isTrue);
      expect(profile.isLevelUnlocked('hadith', 4), isTrue);
      expect(profile.isLevelUnlocked('hadith', 5), isFalse);

      // Level with completed previous level (stars > 0) is also unlocked
      profile.setLevelStars('hadith', 4, 2);
      expect(profile.isLevelUnlocked('hadith', 5), isTrue);
    });

    testWidgets('CategoryItem never displays negative locked count even if unlockedLevels > totalLevels',
        (tester) async {
      final category = Category(
        id: 'quran',
        name: 'القرآن الكريم',
        description: 'أسئلة في القرآن',
        icon: Icons.menu_book_rounded,
        totalLevels: 10,
        unlockedLevels: 11,
      );

      expect(category.progressPercentage, 1.0);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 260,
              child: CategoryItem(
                category: category,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('-1'), findsNothing);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    test('TimerController.freezeTimer pauses and cancels cleanly on stopTimer/dispose', () async {
      final timer = TimerController();
      timer.setTotalTime(20);
      timer.startTimer();
      expect(timer.isRunning, isTrue);

      timer.freezeTimer(
        duration: const Duration(milliseconds: 80),
        shouldResume: () => true,
      );
      expect(timer.isRunning, isFalse);

      // Stopping before freeze expires must cancel the freeze timer so it never auto-resumes
      timer.stopTimer();
      await Future.delayed(const Duration(milliseconds: 120));
      expect(timer.isRunning, isFalse);
      timer.dispose();
    });

    testWidgets('ResultScreen awards 1 star at 50% (5/10) and hides Next Level on Level 10',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const ResultScreen(
            correctAnswers: 5,
            totalQuestions: 10,
            totalScore: 50,
            categoryId: 'quran',
            levelId: 'quran_level_10',
            levelNumber: 10,
          ),
        ),
      );

      // Advance past initial 150ms + 300ms + 900ms timers
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1500));

      // Passed at 50%, on Level 10: must show 'إعادة المستوى' instead of 'المستوى التالي'
      expect(find.text('مبارك! 🏆'), findsOneWidget);
      expect(find.text('المستوى التالي'), findsNothing);
      expect(find.text('إعادة المستوى'), findsOneWidget);
    });
  });

  group('M13: Performance, Speed, Isolate Cache & Transition Benchmarks', () {
    test('QuestionService coalesces concurrent loads via compute() and serves cached levels fast',
        () async {
      final service = QuestionService();
      service.clearCache();
      expect(service.isCached('quran'), isFalse);

      final coldWatch = Stopwatch()..start();
      final results = await Future.wait([
        service.preloadCategory('quran'),
        service.loadQuestions(categoryId: 'quran', levelNumber: 1),
        service.loadQuestions(categoryId: 'quran', levelNumber: 2),
      ]);
      coldWatch.stop();

      expect(service.isCached('quran'), isTrue);
      final level1 = results[1] as List;
      final level2 = results[2] as List;
      expect(level1.length, 10);
      expect(level2.length, 10);

      final warmWatch = Stopwatch()..start();
      final level3 = await service.loadQuestions(categoryId: 'quran', levelNumber: 3);
      warmWatch.stop();

      expect(level3.length, 10);
      expect(warmWatch.elapsedMilliseconds, lessThan(50));
      debugPrint(
        'M13 Benchmark - QuestionService cold coalesced: ${coldWatch.elapsedMilliseconds}ms, '
        'warm cached: ${warmWatch.elapsedMilliseconds}ms',
      );
    });

    test('GameController.completeLevel persists locally without blocking on network sync',
        () async {
      final profile = await ProfileService.instance.createProfile(
        name: 'فارس السرعة',
        avatarIndex: 0,
      );
      expect(profile.totalScore, 0);

      final controller = GameController();
      await controller.loadQuestionsForLevel('quran', 1);
      expect(controller.currentQuestions.length, 10);

      for (int i = 0; i < controller.currentQuestions.length; i++) {
        final q = controller.currentQuestion!;
        controller.answerQuestion(q.correctAnswerIndex);
        if (i < controller.currentQuestions.length - 1) {
          controller.nextQuestion();
        }
      }

      final sw = Stopwatch()..start();
      await controller.completeLevel();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(500));
      expect(profile.totalScore, greaterThan(0));
      expect(profile.getLevelStars('quran', 1), 3);
      expect(profile.getCategoryUnlockedLevels('quran'), 2);
      debugPrint('M13 Benchmark - GameController.completeLevel: ${sw.elapsedMilliseconds}ms');
    });

    testWidgets('IslamicQuizApp skips root MaterialApp rebuilds unless active theme changes',
        (tester) async {
      final profile = ProfileService.instance.activeProfile ??
          await ProfileService.instance.createProfile(
            name: 'فارس العزل',
            avatarIndex: 0,
          );
      profile.equippedTheme = AppCustomTheme.andalusianGold.themeId;

      await tester.pumpWidget(const IslamicQuizApp());
      await tester.pump();

      final appElement = tester.element(find.byType(IslamicQuizApp));
      expect(appElement.dirty, isFalse);

      // Saving score/progress without theme change must NOT dirty root IslamicQuizApp
      profile.addScore(150);
      await ProfileService.instance.saveActiveProfileLocally(triggerBackgroundSync: false);
      expect(appElement.dirty, isFalse);

      // Changing equipped theme MUST mark root IslamicQuizApp dirty and apply new theme
      await ProgressionService.instance.equipTheme(AppCustomTheme.emeraldBanner.themeId);
      expect(appElement.dirty, isTrue);

      await tester.pump();
      final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        updatedApp.theme?.extension<AppCustomTheme>()?.themeId,
        AppCustomTheme.emeraldBanner.themeId,
      );

      // Drain SplashScreen timer cleanly
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('ResultScreen Next Level uses pushReplacementNamed cleanly without stacking results',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final profile = ProfileService.instance.activeProfile ??
          await ProfileService.instance.createProfile(
            name: 'فارس الانتقال',
            avatarIndex: 0,
          );
      _markAllAchievementsSeen(profile);
      profile.setCategoryUnlockedLevels('quran', 2);
      profile.setLevelStars('quran', 1, 2);

      await tester.runAsync(() => QuestionService().preloadCategory('quran'));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          onGenerateRoute: AppRoutes.generateRoute,
          home: Builder(
            builder: (context) => const LevelsScreen(categoryId: 'quran'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const ResultScreen(
            correctAnswers: 7,
            totalQuestions: 10,
            totalScore: 70,
            categoryId: 'quran',
            levelId: 'quran_level_1',
            levelNumber: 1,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.text('المستوى التالي'), findsOneWidget);

      await tester.ensureVisible(find.text('المستوى التالي'));
      await tester.tap(find.text('المستوى التالي'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(QuizScreen), findsOneWidget);
    });

    testWidgets('ResultScreen replay keeps Next Level unlocked and pops back cleanly to LevelsScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final profile = ProfileService.instance.activeProfile ??
          await ProfileService.instance.createProfile(
            name: 'فارس الإعادة',
            avatarIndex: 0,
          );
      _markAllAchievementsSeen(profile);
      // Level 1 was already completed and Level 2 unlocked previously; replaying and scoring 0/10
      profile.setCategoryUnlockedLevels('quran', 3);
      profile.setLevelStars('quran', 1, 2);

      await tester.runAsync(() => QuestionService().preloadCategory('quran'));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          onGenerateRoute: AppRoutes.generateRoute,
          home: const LevelsScreen(categoryId: 'quran'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const ResultScreen(
            correctAnswers: 0,
            totalQuestions: 10,
            totalScore: 0,
            categoryId: 'quran',
            levelId: 'quran_level_1',
            levelNumber: 1,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1200));

      // Even though replay scored 0/10, Level 2 is already unlocked in profile
      expect(find.text('المستوى التالي'), findsOneWidget);
      expect(find.text('المستويات'), findsOneWidget);

      await tester.ensureVisible(find.text('المستويات'));
      await tester.tap(find.text('المستويات'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(LevelsScreen), findsOneWidget);
    });

    testWidgets('AchievementPopup renders cleanly without RenderFlex overflow on compact screens',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0; // 360x640 logical dp
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Scaffold(
            body: Center(
              child: AchievementPopup(
                achievement: AchievementDefinitions.all.first,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('رائـــع!'), findsOneWidget);

      await tester.tap(find.text('رائـــع!'));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('QuizScreen displays Arabic error UI and recovery actions for invalid level 11',
        (tester) async {
      await tester.runAsync(() => QuestionService().preloadCategory('quran'));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          onGenerateRoute: AppRoutes.generateRoute,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.quiz,
                  arguments: {
                    'categoryId': 'quran',
                    'levelId': 'quran_level_11',
                    'levelNumber': 11,
                  },
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('العودة'), findsOneWidget);
    });
  });
}
