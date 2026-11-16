import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// محرك محاكاة وتشغيل أشباح الصحابة للاعبين الحقيقيين مع الانتروبيا البشرية
class GhostPlaybackService {
  final List<Map<String, dynamic>> timeline;
  final void Function({
    required int questionIndex,
    required int selectedOption,
    required bool isCorrect,
    required int scoreGained,
  }) onGhostAnswer;

  Timer? _activeQuestionTimer;
  final math.Random _random = math.Random();
  bool _isDisposed = false;

  GhostPlaybackService({
    required this.timeline,
    required this.onGhostAnswer,
  });

  /// Computes deterministic score for a single timeline entry under the canonical
  /// 15-second round timer (`pts` when recorded, else `10 + floor((15000 - ms)/1000)`).
  static int computeScoreForRecord(Map<String, dynamic> record) {
    final explicitPts = (record['pts'] as num?)?.toInt();
    if (explicitPts != null) return explicitPts.clamp(0, 25);
    final isCorrect = (record['ok'] as bool?) ?? false;
    if (!isCorrect) return 0;
    final baseDelayMs = (record['ms'] as num?)?.toInt() ?? 3000;
    final simulatedSecondsLeft =
        ((15000 - baseDelayMs) / 1000).clamp(0, 15).floor();
    return 10 + simulatedSecondsLeft;
  }

  /// Starts playback for a specific question with human visual jitter (±150ms to ±300ms).
  /// Score is deterministic and never affected by timing jitter.
  void playQuestion(int questionIndex) {
    if (_isDisposed) return;
    _cancelActiveTimer();

    if (questionIndex < 0 || questionIndex >= timeline.length) {
      debugPrint('GhostPlaybackService: Invalid question index $questionIndex');
      return;
    }

    Map<String, dynamic> record = timeline[questionIndex];
    for (final item in timeline) {
      if ((item['q'] as num?)?.toInt() == questionIndex) {
        record = item;
        break;
      }
    }
    final baseDelayMs = (record['ms'] as num?)?.toInt() ?? 3000;
    final selectedOption = (record['ans'] as num?)?.toInt() ?? 0;
    final isCorrect = (record['ok'] as bool?) ?? false;

    // Human Entropy Jitter: ±150ms to ±300ms (display timing only)
    final jitterRange = 150 + _random.nextInt(151); // 150..300
    final sign = _random.nextBool() ? 1 : -1;
    final jitter = jitterRange * sign;

    // Clamped within canonical 15s round bounds: 650ms to 14500ms
    final effectiveDelayMs = (baseDelayMs + jitter).clamp(650, 14500);
    final scoreGained = computeScoreForRecord(record);

    _activeQuestionTimer = Timer(Duration(milliseconds: effectiveDelayMs), () {
      if (_isDisposed) return;
      onGhostAnswer(
        questionIndex: questionIndex,
        selectedOption: selectedOption,
        isCorrect: isCorrect,
        scoreGained: scoreGained,
      );
    });
  }

  /// Cancels any active pending timer for the current question
  void _cancelActiveTimer() {
    _activeQuestionTimer?.cancel();
    _activeQuestionTimer = null;
  }

  /// Explicit cleanup of all timers and state (Rule 1 compliance)
  void dispose() {
    _isDisposed = true;
    _cancelActiveTimer();
  }
}
