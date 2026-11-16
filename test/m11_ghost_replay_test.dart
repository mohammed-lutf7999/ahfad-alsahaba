import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/services/ghost_playback_service.dart';
import 'package:ahfad_alsahaba/data/services/multiplayer_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/progression_service.dart';
import 'package:ahfad_alsahaba/data/services/question_service.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/lobby_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/versus_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/widgets/game_match_result_dialog.dart';

Future<void> _ensureTestEnvReady() async {
  SharedPreferences.setMockInitialValues({
    'sound_enabled': false,
    'vibration_enabled': false,
  });
  await SharedPrefsService.init();
  final profile = PlayerProfile(
    id: 'm11_test_user',
    name: 'فارس الاختبار',
    totalScore: 1200,
    trophies: 1050,
  );
  await SharedPrefsService.saveProfilesJson(PlayerProfile.profilesToJson([profile]));
  await SharedPrefsService.setActiveProfileId(profile.id);
  await ProfileService.instance.init();

  try {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key-m11',
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  } catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _ensureTestEnvReady();
  });

  group('Milestone 4 Ghost Replay Engine & Chivalric Playback Tests', () {
    test('GhostPlaybackService initializes and triggers onGhostAnswer with human jitter', () async {
      final timeline = [
        {'q': 0, 'ms': 700, 'ans': 2, 'ok': true},
        {'q': 1, 'ms': 1200, 'ans': 1, 'ok': false},
      ];

      int callbackCount = 0;
      int answeredIndex = -1;
      int chosenOption = -1;
      bool wasCorrect = false;
      int gainedScore = 0;

      final ghost = GhostPlaybackService(
        timeline: timeline,
        onGhostAnswer: ({
          required int questionIndex,
          required int selectedOption,
          required bool isCorrect,
          required int scoreGained,
        }) {
          callbackCount++;
          answeredIndex = questionIndex;
          chosenOption = selectedOption;
          wasCorrect = isCorrect;
          gainedScore = scoreGained;
        },
      );

      // Trigger question 0
      ghost.playQuestion(0);

      // Timeline has base 700ms with jitter ±150..300ms (clamped min 650ms, max 1000ms)
      expect(callbackCount, equals(0));

      // Advance by 1300ms to guarantee completion
      await Future.delayed(const Duration(milliseconds: 1300));

      expect(callbackCount, equals(1));
      expect(answeredIndex, equals(0));
      expect(chosenOption, equals(2));
      expect(wasCorrect, isTrue);
      expect(gainedScore, greaterThan(10)); // 10 base + remaining time bonus

      ghost.dispose();
    });

    test('GhostPlaybackService 15s formula & founding ghost totals match server (83, 107, 89)', () {
      final seifYarmouk = [
        {'q': 0, 'ms': 2850, 'ans': 1, 'ok': true},
        {'q': 1, 'ms': 4120, 'ans': 0, 'ok': true},
        {'q': 2, 'ms': 3200, 'ans': 2, 'ok': false},
        {'q': 3, 'ms': 2100, 'ans': 3, 'ok': true},
        {'q': 4, 'ms': 5300, 'ans': 1, 'ok': true},
      ];
      final farisQadisiyyah = [
        {'q': 0, 'ms': 1950, 'ans': 0, 'ok': true},
        {'q': 1, 'ms': 3400, 'ans': 2, 'ok': true},
        {'q': 2, 'ms': 2800, 'ans': 1, 'ok': true},
        {'q': 3, 'ms': 4600, 'ans': 0, 'ok': true},
        {'q': 4, 'ms': 3100, 'ans': 2, 'ok': true},
      ];
      final dirHittin = [
        {'q': 0, 'ms': 2100, 'ans': 3, 'ok': true},
        {'q': 1, 'ms': 2900, 'ans': 1, 'ok': true},
        {'q': 2, 'ms': 3800, 'ans': 0, 'ok': false},
        {'q': 3, 'ms': 1800, 'ans': 2, 'ok': true},
        {'q': 4, 'ms': 2700, 'ans': 1, 'ok': true},
      ];

      int sumTimeline(List<Map<String, dynamic>> t) =>
          t.fold(0, (acc, r) => acc + GhostPlaybackService.computeScoreForRecord(r));

      expect(sumTimeline(seifYarmouk), equals(83));
      expect(sumTimeline(farisQadisiyyah), equals(107));
      expect(sumTimeline(dirHittin), equals(89));
      expect(
        GhostPlaybackService.computeScoreForRecord({'q': 0, 'ms': 1000, 'ans': 1, 'ok': true, 'pts': 22}),
        equals(22),
      );
      expect(
        GhostPlaybackService.computeScoreForRecord({'q': 0, 'ms': 1000, 'ans': 1, 'ok': false, 'pts': 0}),
        equals(0),
      );
    });

    test('GhostPlaybackService score is invariant under visual timing jitter', () async {
      final timeline = [
        {'q': 0, 'ms': 800, 'ans': 2, 'ok': true, 'pts': 24},
      ];
      final scores = <int>[];
      final ghost = GhostPlaybackService(
        timeline: timeline,
        onGhostAnswer: ({
          required int questionIndex,
          required int selectedOption,
          required bool isCorrect,
          required int scoreGained,
        }) {
          scores.add(scoreGained);
        },
      );

      for (int i = 0; i < 3; i++) {
        ghost.playQuestion(0);
        await Future.delayed(const Duration(milliseconds: 1200));
      }
      expect(scores, equals([24, 24, 24]));
      ghost.dispose();
    });

    test('QuestionService.loadQuestionBySpec loads deterministically across all 6 categories (all 600 questions)', () async {
      final service = QuestionService();
      final categories = ['quran', 'hadith', 'fiqh', 'seerah', 'history', 'aqeedah'];

      for (final cat in categories) {
        for (int level = 1; level <= 10; level++) {
          final qFirst = await service.loadQuestionBySpec(
            categoryId: cat,
            levelNumber: level,
            questionIndex: 0,
            seed: 7777,
            slotOffset: 1,
          );
          final qLast = await service.loadQuestionBySpec(
            categoryId: cat,
            levelNumber: level,
            questionIndex: 9,
            seed: 7777,
            slotOffset: 4,
          );
          expect(qFirst, isNotNull, reason: 'Failed loading $cat:$level:0');
          expect(qLast, isNotNull, reason: 'Failed loading $cat:$level:9');
        }
      }

      // Same spec + seed on Device A and Device B must produce identical question & option order
      final devA = await service.loadQuestionBySpec(
        categoryId: 'history',
        levelNumber: 7,
        questionIndex: 5,
        seed: 987654,
        slotOffset: 2,
      );
      final devB = await service.loadQuestionBySpec(
        categoryId: 'history',
        levelNumber: 7,
        questionIndex: 5,
        seed: 987654,
        slotOffset: 2,
      );
      expect(devA!.id, equals(devB!.id));
      expect(devA.questionText, equals(devB.questionText));
      expect(devA.options, equals(devB.options));
      expect(devA.correctAnswerIndex, equals(devB.correctAnswerIndex));
    });

    testWidgets('GameMatchResultDialog shows instant ghost rematch button without overflow on 360x800', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  GameMatchResultDialog.show(
                    context,
                    isWinner: true,
                    isDraw: false,
                    effectiveDelta: 27,
                    totalTrophies: 1027,
                    coinsEarned: 30,
                    myScore: 95,
                    opponentScore: 83,
                    opponentName: 'سيف اليرموك',
                    matchId: 'match_123',
                    opponentId: 'ghost_1',
                    isGhost: true,
                    onDismiss: () {},
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('مباراة جديدة ⚔️'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('GhostPlaybackService dispose cancels active timers cleanly (Rule 1 compliance)', () async {
      final timeline = [
        {'q': 0, 'ms': 3000, 'ans': 0, 'ok': true},
      ];

      bool callbackFired = false;
      final ghost = GhostPlaybackService(
        timeline: timeline,
        onGhostAnswer: ({
          required int questionIndex,
          required int selectedOption,
          required bool isCorrect,
          required int scoreGained,
        }) {
          callbackFired = true;
        },
      );

      ghost.playQuestion(0);
      // Immediately dispose
      ghost.dispose();

      // Wait 1000ms
      await Future.delayed(const Duration(milliseconds: 1000));
      expect(callbackFired, isFalse);
    });

    test('Hygiene filter rejects recordings violating anti-bot/integrity criteria', () {
      bool isRecordingHygienic({
        required List<Map<String, dynamic>> timeline,
        required int totalScore,
      }) {
        // 1. Must be complete 5 questions
        if (timeline.length != 5) return false;
        // 2. Score must be positive
        if (totalScore <= 0) return false;
        // 3. Each answer must take at least 600ms (anti-script bot protection)
        for (final item in timeline) {
          final ms = item['ms'] as int? ?? 0;
          if (ms < 600) return false;
        }
        return true;
      }

      // Valid recording
      final validTimeline = [
        {'q': 0, 'ms': 3420, 'ans': 2, 'ok': true},
        {'q': 1, 'ms': 2100, 'ans': 1, 'ok': true},
        {'q': 2, 'ms': 4500, 'ans': 0, 'ok': false},
        {'q': 3, 'ms': 1800, 'ans': 3, 'ok': true},
        {'q': 4, 'ms': 3100, 'ans': 2, 'ok': true},
      ];
      expect(isRecordingHygienic(timeline: validTimeline, totalScore: 85), isTrue);

      // Incomplete recording (e.g. Rage quit / early surrender)
      final incompleteTimeline = [
        {'q': 0, 'ms': 3420, 'ans': 2, 'ok': true},
        {'q': 1, 'ms': 2100, 'ans': 1, 'ok': true},
      ];
      expect(isRecordingHygienic(timeline: incompleteTimeline, totalScore: 40), isFalse);

      // Bot/Scripting abuse: Impossible human reflex (ms < 600)
      final botTimeline = [
        {'q': 0, 'ms': 120, 'ans': 2, 'ok': true}, // Suspicious!
        {'q': 1, 'ms': 2100, 'ans': 1, 'ok': true},
        {'q': 2, 'ms': 4500, 'ans': 0, 'ok': false},
        {'q': 3, 'ms': 1800, 'ans': 3, 'ok': true},
        {'q': 4, 'ms': 3100, 'ans': 2, 'ok': true},
      ];
      expect(isRecordingHygienic(timeline: botTimeline, totalScore: 90), isFalse);

      // Zero score recording
      expect(isRecordingHygienic(timeline: validTimeline, totalScore: 0), isFalse);
    });

    test('Server-side daily cap accurately marks match as friendly beyond 15 rounds', () {
      bool evaluateMatchRankedStatus(int currentDailyGhostCount) {
        const int maxRankedGhostPerDay = 15;
        // If count >= 15, match becomes friendly (no trophy change)
        return currentDailyGhostCount < maxRankedGhostPerDay;
      }

      // 0 to 14 rounds are ranked
      expect(evaluateMatchRankedStatus(0), isTrue);
      expect(evaluateMatchRankedStatus(14), isTrue);

      // 15th round and above become friendly
      expect(evaluateMatchRankedStatus(15), isFalse);
      expect(evaluateMatchRankedStatus(22), isFalse);
    });

    test('GhostMatchResult model instantiates and parses fields faithfully', () {
      final result = GhostMatchResult(
        success: true,
        matchId: 'ghost_match_101',
        ghostUserId: 'usr_ghost_ali',
        ghostName: 'سيف اليرموك',
        ghostAvatarIndex: 3,
        ghostFrame: 'frame_gold',
        ghostLevel: 14,
        ghostTrophies: 1250,
        seed: 778899,
        questionIds: ['sahaba:1:0', 'sahaba:1:1', 'sahaba:1:2', 'sahaba:1:3', 'sahaba:1:4'],
        timeline: [
          {'q': 0, 'ms': 2500, 'ans': 1, 'ok': true},
        ],
        isFriendly: false,
        dailyGhostCount: 4,
      );

      expect(result.success, isTrue);
      expect(result.matchId, equals('ghost_match_101'));
      expect(result.ghostName, equals('سيف اليرموك'));
      expect(result.ghostLevel, equals(14));
      expect(result.ghostTrophies, equals(1250));
      expect(result.seed, equals(778899));
      expect(result.questionIds!.length, equals(5));
      expect(result.timeline!.first['ms'], equals(2500));
      expect(result.isFriendly, isFalse);
      expect(result.dailyGhostCount, equals(4));
    });

    test('QuestionService.getQuestionsForMultiplayer is deterministic across repeated calls with identical seed', () async {
      final qs = QuestionService();
      final runA = await qs.getQuestionsForMultiplayer(778899);
      final runB = await qs.getQuestionsForMultiplayer(778899);

      expect(runA.length, equals(5));
      expect(runB.length, equals(5));
      for (int i = 0; i < 5; i++) {
        expect(runA[i].id, equals(runB[i].id));
        expect(runA[i].options, equals(runB[i].options));
        expect(runA[i].correctAnswerIndex, equals(runB[i].correctAnswerIndex));
      }

      final otherSeed = await qs.getQuestionsForMultiplayer(112233);
      expect(
        otherSeed.map((q) => q.id).toList(),
        isNot(equals(runA.map((q) => q.id).toList())),
      );
    });

    testWidgets('GameMatchResultDialog displays friendly match badge when isFriendly is true', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  GameMatchResultDialog.show(
                    context,
                    isWinner: false,
                    isDraw: true,
                    effectiveDelta: 0,
                    totalTrophies: 1000,
                    myScore: 70,
                    opponentScore: 70,
                    opponentName: 'فارس القادسية',
                    matchId: 'friendly_match_1',
                    opponentId: 'ghost_2',
                    isGhost: true,
                    isFriendly: true,
                    onDismiss: () {},
                  );
                },
                child: const Text('open_friendly'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open_friendly'));
      await tester.pumpAndSettle();

      expect(find.text('مباراة ودية — الكؤوس والدروع محمية 🛡️'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LobbyScreen hides bot fallback button while actively searching online', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = StreamController<Map<String, dynamic>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: LobbyScreen(
            findMatchOverride: ({
              required String appVersion,
              int? trophies,
              String? lastOpponentId,
            }) async =>
                MatchmakingResult(success: true, isWaiting: true),
            matchFoundStreamOverride: controller.stream,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('جاري البحث عن خصم في فئتك...'), findsOneWidget);
      expect(find.text('تحدي الذكاء الاصطناعي 🤖'), findsNothing);
      expect(find.text('إلغاء'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('LobbyScreen shows bot fallback button on network error and falls back immediately to VersusScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LobbyScreen(
            findMatchOverride: ({
              required String appVersion,
              int? trophies,
              String? lastOpponentId,
            }) async =>
                MatchmakingResult(error: 'SocketException: Failed host lookup'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final botBtnFinder = find.text('تحدي الذكاء الاصطناعي 🤖');
      expect(botBtnFinder, findsOneWidget);

      await tester.ensureVisible(botBtnFinder);
      await tester.tap(botBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(VersusScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Flush VersusScreen pending timers cleanly before test exits
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('VersusScreen renders friendly match badge without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: VersusScreen(
            matchId: 'bot_friendly_1',
            opponentId: 'bot_1',
            seed: 42,
            isBot: true,
            isFriendly: true,
            questionIds: const ['quran:1:0'],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('مباراة ودية — الكؤوس والدروع محمية 🛡️'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    });

    test('Friendly match mode (updateTrophies: false) protects shields, winStreak, and trophies on loss', () async {
      await SharedPrefsService.init(forceReload: true);
      final protectedProfile = PlayerProfile(
        id: 'friendly_shield_user',
        name: 'حامي الدرع',
        totalScore: 2000,
        trophies: 1240,
        winStreak: 4,
        unlockedItemIds: [
          'theme_andalusian_gold',
          'item_frame_wood',
          'powerup_shield',
        ],
      );
      await SharedPrefsService.saveProfilesJson(
        PlayerProfile.profilesToJson([protectedProfile]),
      );
      await SharedPrefsService.setActiveProfileId(protectedProfile.id);
      await ProfileService.instance.init();

      final outcome = ProgressionService.instance.applyMatchOutcome(
        rawMatchScore: 55,
        correctAnswers: 3,
        isWin: false,
        isDraw: false,
        serverTotalTrophies: null,
        serverTrophiesDelta: 0,
        updateTrophies: false,
      );

      final updated = ProfileService.instance.activeProfile!;
      expect(outcome.trophiesDelta, equals(0));
      expect(outcome.shieldConsumed, isFalse);
      expect(updated.trophies, equals(1240));
      expect(updated.winStreak, equals(4));
      expect(updated.unlockedItemIds.contains('powerup_shield'), isTrue);
    });
  });
}
