import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../data/models/achievement_model.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/progression_service.dart';
import '../../data/services/spaced_repetition_service.dart';
import '../../logic/game_controller.dart';
import '../../logic/timer_controller.dart';
import '../dialogs/app_dialogs.dart';
import '../widgets/historical_insight_sheet.dart';
import 'quiz/widgets/quiz_dialogs_and_states.dart';
import 'quiz/widgets/quiz_header.dart';
import 'quiz/widgets/quiz_lifelines_dock.dart';
import 'quiz/widgets/quiz_question_body.dart';

class QuizScreen extends StatefulWidget {
  final String categoryId;
  final String levelId;
  final int levelNumber;

  const QuizScreen({
    super.key,
    required this.categoryId,
    required this.levelId,
    required this.levelNumber,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  late GameController _gameController;
  late TimerController _timerController;
  int _streak = 0;
  late AnimationController _animationController;
  late AnimationController _successController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _nextQuestionTimer;
  bool _isLoading = true;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _gameController = GameController();
    _timerController = TimerController();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    _nextQuestionTimer?.cancel();
    _nextQuestionTimer = null;
    _isCompleting = false;
    _gameController.initializeCategories();
    await _gameController.loadQuestionsForLevel(
      widget.categoryId,
      widget.levelNumber,
    );
    _timerController.initialize();

    if (mounted) {
      setState(() => _isLoading = false);
      if (_gameController.currentQuestion != null) {
        _animationController.forward(from: 0);
        _startTimer();
      }
    }
  }

  void _startTimer() => _timerController.startTimer(
        onTimeUp: _onTimeUp,
        onTick: (remaining) {
          if (remaining == 5) SoundService().startTimerTick();
        },
      );

  void _onTimeUp() {
    SoundService().stopTimerTick();
    if (!_gameController.isAnswered) _handleAnswer(-1);
  }

  void _handleAnswer(int selectedIndex) {
    if (_gameController.isAnswered) return;
    _timerController.stopTimer();
    SoundService().stopTimerTick();

    final isCorrect =
        selectedIndex == _gameController.currentQuestion?.correctAnswerIndex;

    if (SharedPrefsService.getVibrationEnabled()) {
      isCorrect ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }

    if (isCorrect) {
      _successController.forward(from: 0);
      SoundService().playCorrect();
      _streak++;
      if (_streak % 3 == 0) SoundService().playStreak();
      if (_timerController.remainingTime >= 17) {
        AchievementService.instance.checkAchievements(
          AchievementEvent.fastAnswer(
            secondsRemaining: _timerController.remainingTime,
          ),
        );
      }
    } else {
      SoundService().playWrong();
      _streak = 0;
    }

    setState(() => _gameController.answerQuestion(selectedIndex));

    final answeredQ = _gameController.currentQuestion;
    if (answeredQ != null &&
        SpacedRepetitionService.instance.isEffectivelyEnabled) {
      unawaited(
        SpacedRepetitionService.instance.recordAnswer(
          questionId: answeredQ.id,
          categoryId: widget.categoryId,
          isCorrect: isCorrect,
        ),
      );
    }

    final isLastQuestion = _gameController.isLastQuestion;
    final totalQuestions = _gameController.currentQuestions.length;
    final currentPercentage = totalQuestions > 0
        ? (_gameController.correctAnswers / totalQuestions) * 100
        : 0.0;
    final hasPassedOnLastQuestion =
        isLastQuestion && currentPercentage >= AppConstants.passingScore;

    _nextQuestionTimer?.cancel();
    if (_gameController.lives == 0 && !hasPassedOnLastQuestion) {
      showQuizGameOverDialog(
        context,
        onRetry: () {
          _streak = 0;
          _isCompleting = false;
          setState(() => _isLoading = true);
          _initializeQuiz();
        },
        onExit: () => Navigator.pop(context),
      );
    } else if (!isCorrect &&
        answeredQ != null &&
        (answeredQ.explanation ?? '').trim().isNotEmpty &&
        SpacedRepetitionService.instance.isEffectivelyEnabled) {
      if (_gameController.lives == 1 && !isLastQuestion) {
        showQuizWarningToast(context);
      }
      _nextQuestionTimer = Timer(const Duration(milliseconds: 450), () async {
        if (!mounted) return;
        await HistoricalInsightSheet.show(context, question: answeredQ);
        if (mounted) _nextQuestion();
      });
    } else {
      if (_gameController.lives == 1 && !isLastQuestion) {
        showQuizWarningToast(context);
      }
      final delayMs = isLastQuestion ? 800 : 1200;
      _nextQuestionTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) _nextQuestion();
      });
    }
  }

  void _nextQuestion() {
    if (_gameController.isLastQuestion) {
      _completeQuiz();
    } else {
      _animationController.reset();
      setState(() => _gameController.nextQuestion());
      _animationController.forward();
      _timerController.resetTimer();
      _startTimer();
    }
  }

  Future<void> _completeQuiz() async {
    if (_isCompleting) return;
    _isCompleting = true;
    _nextQuestionTimer?.cancel();
    _timerController.stopTimer();
    SoundService().stopTimerTick();

    final preSnapshot = ProgressionService.instance.captureSnapshot();
    await _gameController.completeLevel();
    if (_gameController.score > 0) SoundService().playLevelComplete();

    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.result,
        arguments: {
          'correctAnswers': _gameController.correctAnswers,
          'totalQuestions': _gameController.currentQuestions.length,
          'totalScore': _gameController.score,
          'categoryId': widget.categoryId,
          'levelId': widget.levelId,
          'levelNumber': widget.levelNumber,
          'userAnswers': _gameController.userAnswers,
          'preSnapshot': preSnapshot,
        },
      );
    }
  }

  void _showExitDialog() {
    SoundService().playAlert();
    AppDialogs.showExitConfirmationDialog(
      context,
      title: 'هل تود الانسحاب؟',
      message:
          'خروجك الآن يعني فقدان تقدمك في هذا المستوى. هل أنت متأكد من قرارك؟',
      confirmLabel: 'تأكيد الخروج',
      cancelLabel: 'تراجع ومتابعة',
      onConfirm: () => Navigator.pop(context),
    );
  }

  @override
  void dispose() {
    _nextQuestionTimer?.cancel();
    _timerController.dispose();
    _animationController.dispose();
    _successController.dispose();
    SoundService().stopTimerTick();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = AppCustomTheme.of(context).backgroundGradient;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: const SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
              ),
            ),
          ),
        ),
      );
    }

    if (_gameController.error != null ||
        _gameController.currentQuestion == null) {
      return QuizErrorView(
        backgroundGradient: backgroundGradient,
        errorMessage: _gameController.error,
        onRetry: () {
          setState(() => _isLoading = true);
          _initializeQuiz();
        },
        onBack: () => Navigator.pop(context),
      );
    }

    final question = _gameController.currentQuestion!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                QuizHeader(
                  successController: _successController,
                  timerController: _timerController,
                  lives: _gameController.lives,
                  score: _gameController.score,
                  currentQuestionNumber:
                      _gameController.currentQuestionIndex + 1,
                  totalQuestions: _gameController.currentQuestions.length,
                  levelNumber: widget.levelNumber,
                  progress: _gameController.progress,
                  onExitTap: _showExitDialog,
                ),
                Expanded(
                  child: QuizQuestionBody(
                    question: question,
                    questionNumber: _gameController.currentQuestionIndex + 1,
                    totalQuestions: _gameController.currentQuestions.length,
                    isAnswered: _gameController.isAnswered,
                    selectedAnswerIndex: _gameController.selectedAnswerIndex,
                    hiddenOptionIndices: _gameController.hiddenOptionIndices,
                    fadeAnimation: _fadeAnimation,
                    slideAnimation: _slideAnimation,
                    onSelectOption: _handleAnswer,
                  ),
                ),
                QuizLifelinesDock(
                  gameController: _gameController,
                  timerController: _timerController,
                  onNextQuestion: _nextQuestion,
                  onStateChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
