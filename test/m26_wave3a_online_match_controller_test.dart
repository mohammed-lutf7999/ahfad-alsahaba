import 'dart:math';

import 'package:ahfad_alsahaba/data/models/arena_model.dart';
import 'package:ahfad_alsahaba/data/models/player_level_model.dart';
import 'package:ahfad_alsahaba/data/models/question_model.dart';
import 'package:ahfad_alsahaba/data/services/multiplayer_service.dart';
import 'package:ahfad_alsahaba/logic/online_match_controller.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/widgets/online_question_board.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/widgets/online_scoreboard_header.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/widgets/pin_code_boxes_widget.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/widgets/rematch_action_bar.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/widgets/versus_player_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Question> _sampleQuestions() => [
      Question(
        id: 'q1',
        categoryId: 'seerah',
        levelNumber: 1,
        questionText: 'من هو أول الخلفاء الراشدين؟',
        options: const [
          'أبو بكر الصديق',
          'عمر بن الخطاب',
          'عثمان بن عفان',
          'علي بن أبي طالب',
        ],
        correctAnswerIndex: 0,
        explanation: 'أبو بكر الصديق رضي الله عنه.',
      ),
      Question(
        id: 'q2',
        categoryId: 'seerah',
        levelNumber: 1,
        questionText: 'في أي سنة كانت غزوة بدر الكبرى؟',
        options: const ['السنة الأولى', 'السنة الثانية', 'السنة الثالثة', 'السنة الخامسة'],
        correctAnswerIndex: 1,
        explanation: 'وقعت في 17 رمضان سنة 2 هـ.',
      ),
    ];

void main() {
  group('Wave 3A: OnlineMatchController unit & timer-safety tests', () {
    testWidgets('Bot match scoring, idempotent answer guard, progression & finish',
        (tester) async {
      OnlineMatchFinishSummary? summary;
      int startedCount = 0;

      final controller = OnlineMatchController(
        matchId: 'bot_test_1',
        opponentId: 'bot_opponent',
        seed: 42,
        questionIds: const ['seerah:1:0', 'seerah:1:1'],
        isBot: true,
        enableAudioAndCloudSideEffects: false,
        random: Random(7),
        questionsLoaderOverride: () async => _sampleQuestions(),
        onQuestionStarted: () => startedCount++,
        onMatchFinished: (s) async => summary = s,
      );

      await controller.initialize();
      expect(controller.isLoading, isFalse);
      expect(controller.questions.length, 2);
      expect(startedCount, 1);
      expect(controller.timeLeft, 15);

      // Tick 2 seconds -> timeLeft == 13
      await tester.pump(const Duration(seconds: 2));
      expect(controller.timeLeft, 13);

      // Submit correct answer -> 10 + 13 = 23 pts
      await controller.submitAnswer(0);
      expect(controller.isAnswered, isTrue);
      expect(controller.myScore, 23);
      expect(controller.myCorrectAnswersCount, 1);

      // Duplicate submit while answered must be ignored
      await controller.submitAnswer(0);
      expect(controller.myScore, 23);

      // Advance 2s delay -> moves to question 2
      await tester.pump(const Duration(seconds: 2));
      expect(controller.currentQuestionIndex, 1);
      expect(controller.isAnswered, isFalse);
      expect(startedCount, 2);

      // Submit wrong answer on Q2 -> 0 pts
      await controller.submitAnswer(0);
      expect(controller.myScore, 23);
      expect(controller.myCorrectAnswersCount, 1);

      // Advance 2s delay -> finishes match
      await tester.pump(const Duration(seconds: 2));
      expect(controller.gameFinished, isTrue);
      expect(summary, isNotNull);
      expect(summary!.myScore, 23);

      controller.dispose();
      // Pump extra time to assert ZERO leaked timers (!timersPending)
      await tester.pump(const Duration(seconds: 20));
    });

    testWidgets('dispose() mid-match cancels ALL timers cleanly (!timersPending)',
        (tester) async {
      bool firedAfterDispose = false;
      final controller = OnlineMatchController(
        matchId: 'bot_dispose_test',
        opponentId: 'bot_opponent',
        seed: 99,
        questionIds: const ['quran:1:0', 'quran:1:1'],
        isBot: true,
        enableAudioAndCloudSideEffects: false,
        random: Random(1),
        questionsLoaderOverride: () async => _sampleQuestions(),
        onMatchFinished: (_) async => firedAfterDispose = true,
      );

      await controller.initialize();
      controller.showQuickPhrase('السلام عليكم');
      expect(controller.incomingQuickPhrase, 'السلام عليكم');
      await controller.submitAnswer(0); // arms 2s _nextQuestionTimer

      // Dispose while question, bot, banner, and next-question timers are active
      controller.dispose();

      // Advance far into the future: zero pending timers or post-dispose errors
      await tester.pump(const Duration(seconds: 30));
      expect(firedAfterDispose, isFalse);
    });

    testWidgets('Ghost playback updates opponent score and disposes cleanly',
        (tester) async {
      final controller = OnlineMatchController(
        matchId: 'ghost_test_1',
        opponentId: 'ghost_1',
        seed: 77,
        questionIds: const ['seerah:1:0', 'seerah:1:1'],
        isGhost: true,
        ghostTimeline: const [
          {'q': 0, 'ms': 1000, 'ans': 0, 'ok': true, 'pts': 22},
          {'q': 1, 'ms': 1000, 'ans': 1, 'ok': true, 'pts': 20},
        ],
        enableAudioAndCloudSideEffects: false,
        random: Random(3),
        questionsLoaderOverride: () async => _sampleQuestions(),
      );

      await controller.initialize();
      expect(controller.opponentScore, 0);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(controller.opponentScore, greaterThan(0));
      expect(controller.opponentQuestionIndex, 1);

      controller.dispose();
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('Tactical hidden options & quick phrases toggle + auto-hide',
        (tester) async {
      final controller = OnlineMatchController(
        matchId: 'ui_state_test',
        opponentId: 'opp_1',
        seed: 10,
        questionIds: const ['seerah:1:0'],
        enableAudioAndCloudSideEffects: false,
        questionsLoaderOverride: () async => _sampleQuestions(),
      );

      await controller.initialize();
      controller.applyHiddenOptions({2, 3});
      expect(controller.hiddenOptionIndices, {2, 3});

      expect(controller.showQuickPhrases, isFalse);
      controller.toggleQuickPhrases();
      expect(controller.showQuickPhrases, isTrue);

      controller.showQuickPhrase('أحسنت يا فارس!');
      expect(controller.incomingQuickPhrase, 'أحسنت يا فارس!');
      await tester.pump(const Duration(seconds: 3));
      expect(controller.incomingQuickPhrase, isNull);

      controller.dispose();
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Wave 3A: MultiplayerService Facade & 360dp RTL widget tests', () {
    test('MultiplayerService.createBotMatch returns 5 valid question specs',
        () async {
      final res = await MultiplayerService.instance.createBotMatch();
      expect(res.success, isTrue);
      expect(res.opponentId, 'bot_opponent');
      expect(res.questionIds?.length, 5);
      for (final spec in res.questionIds!) {
        expect(spec.split(':').length, 3);
      }

      MultiplayerService.instance.lastOpponentId = 'opp_abc';
      expect(MultiplayerService.instance.lastOpponentId, 'opp_abc');
    });

    testWidgets('Extracted 3A widgets render cleanly at 360x800dp RTL without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pinController = TextEditingController(text: '123');
      final pinFocus = FocusNode();
      addTearDown(() {
        pinController.dispose();
        pinFocus.dispose();
      });

      final q = _sampleQuestions().first;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: const Color(0xFF0D061A),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    OnlineScoreboardHeader(
                      myName: 'فارس السيرة النبوية',
                      myAvatarIndex: 0,
                      myEquippedFrame: 'frame_wood',
                      myWinStreak: 2,
                      myScore: 45,
                      opponentName: 'بطل القادسية الميداني',
                      opponentAvatarIndex: 1,
                      opponentScore: 30,
                      opponentQuestionIndex: 1,
                      currentQuestionIndex: 0,
                      totalQuestions: 5,
                      timeLeft: 12,
                      progressAnimation: const AlwaysStoppedAnimation(0.2),
                    ),
                    OnlineQuestionBoard(
                      question: q,
                      isBot: false,
                      isAnswered: false,
                      selectedAnswer: -1,
                      hiddenOptionIndices: const {},
                      showQuickPhrases: false,
                      random: Random(1),
                      onInsightUsed: (_) {},
                      onReactionSelected: (_) {},
                      onToggleQuickPhrases: () {},
                      onQuickPhraseSelected: (_) {},
                      onOptionSelected: (_) {},
                    ),
                    SizedBox(
                      height: 220,
                      child: VersusPlayerCard(
                        tintColor: Colors.blue,
                        name: 'فارس السيرة',
                        avatarIndex: 0,
                        frameKey: 'frame_wood',
                        winStreak: 1,
                        levelInfo: PlayerLevelInfo.fromTotalScore(500),
                        arena: ArenaModel.fromTrophies(1100),
                        score: 500,
                        trophies: 1100,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: PinCodeInputBoxes(
                        controller: pinController,
                        focusNode: pinFocus,
                        onChanged: (_) {},
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: RematchActionBar(
                        rematchState: RematchUIState.receivedOffer,
                        countdown: 8,
                        isGhost: false,
                        onAcceptRematch: () {},
                        onRequestRematch: () {},
                        onLeave: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byKey(const Key('toggle_quick_phrases_btn')), findsOneWidget);
      expect(find.text('قبول النزال ⚔️'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
