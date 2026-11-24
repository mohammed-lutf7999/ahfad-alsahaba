import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/sound_service.dart';
import '../data/models/achievement_model.dart';
import '../data/models/question_model.dart';
import '../data/services/achievement_service.dart';
import '../data/services/app_control_service.dart';
import '../data/services/ghost_playback_service.dart';
import '../data/services/multiplayer_service.dart';
import '../data/services/question_service.dart';
import 'online_match_finisher.dart';

export 'online_match_finisher.dart' show OnlineMatchFinishSummary;

/// Pure business logic & lifecycle controller for [OnlineGameScreen].
/// Owns all timers, bot/ghost engines, scoring, and Realtime subscriptions,
/// guaranteeing zero leaked timers on [dispose].
class OnlineMatchController extends ChangeNotifier {
  OnlineMatchController({
    required this.matchId,
    required this.opponentId,
    required this.seed,
    required this.questionIds,
    this.isBot = false,
    this.isGhost = false,
    this.isFriendly = false,
    this.ghostTimeline,
    this.onQuestionStarted,
    this.onIncomingReaction,
    this.onLoadError,
    this.onMatchFinished,
    Future<List<Question>> Function()? questionsLoaderOverride,
    bool enableAudioAndCloudSideEffects = true,
    Random? random,
  })  : _questionsLoaderOverride = questionsLoaderOverride,
        _enableSideEffects = enableAudioAndCloudSideEffects,
        random = random ?? Random();

  final String matchId;
  final String opponentId;
  final int seed;
  final List<String> questionIds;
  final bool isBot;
  final bool isGhost;
  final bool isFriendly;
  final List<Map<String, dynamic>>? ghostTimeline;

  final VoidCallback? onQuestionStarted;
  final void Function(String emoji)? onIncomingReaction;
  final void Function(String message)? onLoadError;
  final Future<void> Function(OnlineMatchFinishSummary summary)? onMatchFinished;

  final Future<List<Question>> Function()? _questionsLoaderOverride;
  final bool _enableSideEffects;
  final Random random;

  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int _myScore = 0;
  int _myCorrectAnswersCount = 0;
  final Set<int> _hiddenOptionIndices = {};
  bool _isLoading = true;
  bool _gameFinished = false;
  bool _isDisposed = false;

  int _opponentScore = 0;
  int _opponentQuestionIndex = 0;

  int _selectedAnswer = -1;
  bool _isAnswered = false;
  int _timeLeft = 15;
  DateTime _questionStartTime = DateTime.now();
  final List<Map<String, dynamic>> _myAnswerTimelines = [];

  String? _incomingReactionEmoji;
  String? _incomingQuickPhrase;
  bool _showQuickPhrases = false;

  // Tracked timers & subscriptions — EVERY one explicitly cancelled in dispose()
  Timer? _botTimer;
  Timer? _questionTimer;
  Timer? _nextQuestionTimer;
  Timer? _reactionDelayTimer;
  Timer? _quickPhraseBannerTimer;
  GhostPlaybackService? _ghostPlaybackService;
  StreamSubscription<Map<String, dynamic>>? _opponentSubscription;
  StreamSubscription<String>? _reactionSubscription;
  StreamSubscription<String>? _quickPhraseSubscription;

  List<Question> get questions => _questions;
  int get currentQuestionIndex => _currentQuestionIndex;
  Question? get currentQuestion =>
      (_currentQuestionIndex >= 0 && _currentQuestionIndex < _questions.length)
          ? _questions[_currentQuestionIndex]
          : null;
  int get myScore => _myScore;
  int get myCorrectAnswersCount => _myCorrectAnswersCount;
  Set<int> get hiddenOptionIndices => _hiddenOptionIndices;
  bool get isLoading => _isLoading;
  bool get gameFinished => _gameFinished;
  int get opponentScore => _opponentScore;
  int get opponentQuestionIndex => _opponentQuestionIndex;
  int get selectedAnswer => _selectedAnswer;
  bool get isAnswered => _isAnswered;
  int get timeLeft => _timeLeft;
  String? get incomingReactionEmoji => _incomingReactionEmoji;
  String? get incomingQuickPhrase => _incomingQuickPhrase;
  bool get showQuickPhrases => _showQuickPhrases;

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      List<Question> loaded = [];
      if (_questionsLoaderOverride != null) {
        loaded = await _questionsLoaderOverride();
      } else {
        if (questionIds.isNotEmpty) loaded = await _loadQuestionsFromIds(questionIds);
        if (loaded.isEmpty) {
          loaded = await QuestionService().getQuestionsForMultiplayer(seed);
        }
      }
      if (_isDisposed) return;

      _questions = loaded;
      _isLoading = false;
      _safeNotify();

      if (isBot) {
        _botWaitAndAnswer();
      } else if (isGhost) {
        if (ghostTimeline != null && ghostTimeline!.isNotEmpty) _startGhostLogic();
      } else if (_enableSideEffects) {
        _subscribeOnlineStreams();
      }

      if (_questions.isNotEmpty) {
        _startQuestionTimer();
      } else {
        onLoadError?.call('لا توجد أسئلة متاحة');
      }
    } catch (e) {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotify();
        onLoadError?.call('خطأ في تحميل الأسئلة: $e');
      }
    }
  }

  void _subscribeOnlineStreams() {
    _opponentSubscription = MultiplayerService.instance
        .listenToOpponentProgress(matchId, opponentId)
        .listen((data) {
      if (_isDisposed || data.isEmpty) return;
      _opponentScore = (data['current_score'] as num?)?.toInt() ?? 0;
      _opponentQuestionIndex =
          (data['current_question_index'] as num?)?.toInt() ?? 0;
      _safeNotify();
    });
    _reactionSubscription = MultiplayerService.instance
        .listenToReactions(matchId)
        .listen(triggerIncomingReaction);
    _quickPhraseSubscription =
        MultiplayerService.instance.quickPhrasesStream.listen(showQuickPhrase);
  }

  Future<List<Question>> _loadQuestionsFromIds(List<String> ids) async {
    final loaded = <Question>[];
    for (int slot = 0; slot < ids.length; slot++) {
      final parts = ids[slot].split(':');
      if (parts.length < 3) continue;
      try {
        final q = await QuestionService().loadQuestionBySpec(
          categoryId: parts[0],
          levelNumber: int.tryParse(parts[1]) ?? 1,
          questionIndex: int.tryParse(parts[2]) ?? 0,
          seed: seed,
          slotOffset: slot,
        );
        if (q != null) loaded.add(q);
      } catch (e) {
        debugPrint('Error loading question ${ids[slot]}: $e');
      }
    }
    return loaded;
  }

  void _startGhostLogic() {
    _ghostPlaybackService = GhostPlaybackService(
      timeline: ghostTimeline!,
      onGhostAnswer: ({
        required int questionIndex,
        required int selectedOption,
        required bool isCorrect,
        required int scoreGained,
      }) {
        if (_isDisposed || _gameFinished) return;
        _opponentScore += scoreGained;
        _opponentQuestionIndex = questionIndex + 1;
        _safeNotify();
        if (random.nextDouble() < 0.25) {
          _scheduleDelayedReaction(
            isCorrect ? '⚔️' : '😅',
            const Duration(milliseconds: 400),
          );
        }
      },
    );
  }

  void _botWaitAndAnswer() {
    if (_isDisposed || _gameFinished || _opponentQuestionIndex >= _questions.length) {
      return;
    }
    _botTimer?.cancel();
    final readingTime = _questions[_opponentQuestionIndex].questionText.length * 40;
    final finalDelay = min(1500 + random.nextInt(3000) + readingTime, 12000);

    _botTimer = Timer(Duration(milliseconds: finalDelay), () {
      if (_isDisposed || _gameFinished) return;
      final isCorrect = random.nextDouble() < 0.85;
      if (isCorrect) {
        _opponentScore += 10 + ((15000 - finalDelay) ~/ 1000).clamp(0, 15);
      }
      _opponentQuestionIndex++;
      _safeNotify();
      if (random.nextDouble() < 0.2) {
        _scheduleDelayedReaction(
          isCorrect ? '😎' : '😡',
          const Duration(milliseconds: 500),
        );
      }
      if (_opponentQuestionIndex < _questions.length) _botWaitAndAnswer();
    });
  }

  void _scheduleDelayedReaction(String emoji, Duration delay) {
    _reactionDelayTimer?.cancel();
    _reactionDelayTimer = Timer(delay, () {
      if (!_isDisposed) triggerIncomingReaction(emoji);
    });
  }

  void _startQuestionTimer() {
    _questionStartTime = DateTime.now();
    if (isGhost && _ghostPlaybackService != null) {
      _ghostPlaybackService!.playQuestion(_currentQuestionIndex);
    }
    _timeLeft = 15;
    _selectedAnswer = -1;
    _isAnswered = false;
    _hiddenOptionIndices.clear();
    onQuestionStarted?.call();
    _safeNotify();

    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed) return;
      if (_timeLeft > 0) {
        _timeLeft--;
        if (_enableSideEffects && _timeLeft <= 5) {
          SoundService().startTimerTick();
        }
        _safeNotify();
      } else {
        if (_enableSideEffects) SoundService().stopTimerTick();
        submitAnswer(-1);
      }
    });
  }

  void applyHiddenOptions(Iterable<int> newHidden) {
    _hiddenOptionIndices.addAll(newHidden);
    _safeNotify();
  }

  void toggleQuickPhrases() {
    if (_enableSideEffects) SoundService().playClick();
    _showQuickPhrases = !_showQuickPhrases;
    _safeNotify();
  }

  void triggerIncomingReaction(String emoji) {
    if (_isDisposed) return;
    _incomingReactionEmoji = emoji;
    _safeNotify();
    onIncomingReaction?.call(emoji);
  }

  Future<void> sendReaction(String emoji) async {
    if (_enableSideEffects) {
      await MultiplayerService.instance.sendReaction(matchId, emoji);
    }
  }

  void showQuickPhrase(String phrase) {
    if (_isDisposed) return;
    if (_enableSideEffects &&
        !AppControlService.instance.featureFlagsNotifier.value.quickPhrases) {
      return;
    }
    _quickPhraseBannerTimer?.cancel();
    _incomingQuickPhrase = phrase;
    _safeNotify();
    _quickPhraseBannerTimer = Timer(const Duration(seconds: 3), () {
      if (_isDisposed) return;
      _incomingQuickPhrase = null;
      _safeNotify();
    });
  }

  Future<void> sendQuickPhrase(String phrase) async {
    if (_enableSideEffects) SoundService().playClick();
    _showQuickPhrases = false;
    _safeNotify();
    showQuickPhrase('أنت: $phrase');
    if (_enableSideEffects && !isBot && !isGhost) {
      await MultiplayerService.instance.sendQuickPhrase(matchId, phrase);
    }
  }

  Future<void> submitAnswer(int index) async {
    if (_isAnswered || _isDisposed) return;
    _questionTimer?.cancel();
    if (_enableSideEffects) SoundService().stopTimerTick();

    final isCorrect = index != -1 &&
        _currentQuestionIndex < _questions.length &&
        index == _questions[_currentQuestionIndex].correctAnswerIndex;
    final ptsEarned = isCorrect ? (10 + _timeLeft.clamp(0, 15)) : 0;

    _myAnswerTimelines.add({
      'q': _currentQuestionIndex,
      'ms': DateTime.now().difference(_questionStartTime).inMilliseconds,
      'ans': index,
      'ok': isCorrect,
      'pts': ptsEarned,
    });

    _isAnswered = true;
    _selectedAnswer = index;
    if (isCorrect) {
      _myCorrectAnswersCount++;
      if (_enableSideEffects) {
        SoundService().playCorrect();
        if (_timeLeft >= 12) {
          AchievementService.instance.checkAchievements(
            AchievementEvent.fastAnswer(
              secondsRemaining: _timeLeft,
              totalTime: 15,
            ),
          );
        }
      }
    } else if (_enableSideEffects) {
      SoundService().playWrong();
    }
    _safeNotify();

    if (isBot || !_enableSideEffects) {
      _myScore += ptsEarned;
      _safeNotify();
    } else {
      final scores = await MultiplayerService.instance.submitAnswer(
        matchId: matchId,
        questionIndex: _currentQuestionIndex,
        isCorrect: isCorrect,
        timeLeft: _timeLeft,
        currentLocalScore: _myScore,
      );
      if (!_isDisposed) {
        _myScore = scores['myScore'] ?? _myScore;
        if (!isGhost) {
          final oppScore = scores['opponentScore'] ?? 0;
          if (oppScore > _opponentScore) _opponentScore = oppScore;
        }
        _safeNotify();
      }
    }

    if (_isDisposed) return;
    _nextQuestionTimer?.cancel();
    _nextQuestionTimer = Timer(const Duration(seconds: 2), () {
      if (_isDisposed) return;
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
        _startQuestionTimer();
      } else {
        unawaited(_finishGame());
      }
    });
  }

  Future<void> _finishGame() async {
    if (_gameFinished || _isDisposed) return;
    _gameFinished = true;
    _botTimer?.cancel();
    _questionTimer?.cancel();
    _ghostPlaybackService?.dispose();
    _safeNotify();

    final summary = await OnlineMatchFinisher.finalize(
      matchId: matchId,
      opponentId: opponentId,
      isBot: isBot,
      isGhost: isGhost,
      isFriendly: isFriendly,
      enableSideEffects: _enableSideEffects,
      myScore: _myScore,
      opponentScore: _opponentScore,
      myCorrectAnswersCount: _myCorrectAnswersCount,
      myAnswerTimelines: _myAnswerTimelines,
      ghostTimeline: ghostTimeline,
    );
    if (_isDisposed) return;

    _myScore = summary.myScore;
    _opponentScore = summary.opponentScore;
    _safeNotify();
    await onMatchFinished?.call(summary);
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_enableSideEffects) SoundService().stopTimerTick();
    _ghostPlaybackService?.dispose();
    _ghostPlaybackService = null;
    _botTimer?.cancel();
    _questionTimer?.cancel();
    _nextQuestionTimer?.cancel();
    _reactionDelayTimer?.cancel();
    _quickPhraseBannerTimer?.cancel();
    _opponentSubscription?.cancel();
    _reactionSubscription?.cancel();
    _quickPhraseSubscription?.cancel();
    super.dispose();
  }
}
