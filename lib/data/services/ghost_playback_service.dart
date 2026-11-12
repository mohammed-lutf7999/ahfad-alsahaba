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

  /// Starts playback for a specific question with human jitter / entropy (±150ms to ±300ms)
  void playQuestion(int questionIndex) {
    if (_isDisposed) return;
    _cancelActiveTimer();

    if (questionIndex < 0 || questionIndex >= timeline.length) {
      debugPrint('GhostPlaybackService: Invalid question index $questionIndex');
      return;
    }

    final record = timeline[questionIndex];
    final baseDelayMs = (record['ms'] as num?)?.toInt() ?? 3000;
    final selectedOption = (record['ans'] as num?)?.toInt() ?? 0;
    final isCorrect = (record['ok'] as bool?) ?? false;

    // Human Entropy Jitter: ±150ms to ±300ms
    final jitterRange = 150 + _random.nextInt(151); // 150..300
    final sign = _random.nextBool() ? 1 : -1;
    final jitter = jitterRange * sign;

    // Clamped realistic bounds: 650ms to 18500ms
    final effectiveDelayMs = (baseDelayMs + jitter).clamp(650, 18500);

    // Calculate score gained based on simulated remaining time (assuming 20s total timer)
    final simulatedSecondsLeft = ((20000 - effectiveDelayMs) / 1000).clamp(0, 15).floor();
    final scoreGained = isCorrect ? (10 + simulatedSecondsLeft) : 0;

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
