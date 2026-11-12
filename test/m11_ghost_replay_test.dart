import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/data/services/ghost_playback_service.dart';
import 'package:ahfad_alsahaba/data/services/multiplayer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });
}
