import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/challenge_config.dart';
import '../../../data/services/challenge_game_service.dart';
import 'challenge_result_screen.dart';
import 'widgets/legacy_multiplayer_views.dart';

/// شاشة اللعب التنافسي (Legacy/Offline/Wifi)
class MultiplayerQuizScreen extends StatefulWidget {
  const MultiplayerQuizScreen({super.key});

  @override
  State<MultiplayerQuizScreen> createState() => _MultiplayerQuizScreenState();
}

class _MultiplayerQuizScreenState extends State<MultiplayerQuizScreen>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _questionController;
  late Animation<double> _questionAnimation;

  int _selectedAnswer = -1;
  bool _isAnswered = false;
  int _timeLeft = 15;
  int _streak = 0;
  Timer? _countdownTimer;
  Timer? _nextQuestionTimer;

  @override
  void initState() {
    super.initState();

    _timerController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
    _questionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _questionAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _questionController, curve: Curves.easeOut),
    );

    ChallengeGameService.instance.addListener(_onGameStateChanged);
    _startQuestion();
  }

  @override
  void dispose() {
    _timerController.dispose();
    _questionController.dispose();
    _countdownTimer?.cancel();
    _nextQuestionTimer?.cancel();
    ChallengeGameService.instance.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});
    if (ChallengeGameService.instance.state == ChallengeState.finished) {
      _navigateToResults();
    }
  }

  void _startQuestion() {
    _selectedAnswer = -1;
    _isAnswered = false;
    _timeLeft = 15;

    _questionController.forward(from: 0);
    _timerController.forward(from: 0);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeft--;
        if (_timeLeft == 5) SoundService().startTimerTick();
        if (_timeLeft <= 0) {
          timer.cancel();
          SoundService().stopTimerTick();
          _timeExpired();
        }
      });
    });
  }

  void _timeExpired() {
    if (!_isAnswered) _submitAnswer(-1);
  }

  void _submitAnswer(int answerIndex) {
    if (_isAnswered) return;
    _countdownTimer?.cancel();

    setState(() {
      _isAnswered = true;
      _selectedAnswer = answerIndex;
    });

    SoundService().stopTimerTick();

    final isCorrect = answerIndex ==
        ChallengeGameService.instance.currentQuestion?.correctAnswerIndex;
    if (isCorrect) {
      SoundService().playCorrect();
      _streak++;
      if (_streak % 3 == 0) SoundService().playStreak();
    } else {
      SoundService().playWrong();
      _streak = 0;
    }

    ChallengeGameService.instance.submitAnswer(answerIndex);

    _nextQuestionTimer?.cancel();
    _nextQuestionTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      ChallengeGameService.instance.nextQuestion();
      if (ChallengeGameService.instance.state == ChallengeState.inProgress) {
        _startQuestion();
      }
    });
  }

  Future<void> _confirmExit() async {
    SoundService().playAlert();
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryDark,
        title: const Text(
          'انسحاب من التحدي؟',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'هل أنت متأكد من أنك تريد الخروج؟ سيتم اعتبار الجولة خاسرة.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SoundService().playBack();
              Navigator.of(context).pop(false);
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              SoundService().playClick();
              Navigator.of(context).pop(true);
            },
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      _countdownTimer?.cancel();
      _nextQuestionTimer?.cancel();
      SoundService().stopTimerTick();
      ChallengeGameService.instance.reset();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _navigateToResults() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChallengeResultScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameService = ChallengeGameService.instance;
    final question = gameService.currentQuestion;
    final players = gameService.players;
    final questionIndex = gameService.currentQuestionIndex;
    final totalQuestions = gameService.questions.length;

    if (question == null) {
      if (gameService.localPlayer?.hasFinished ?? false) {
        final player = gameService.localPlayer!;
        return LegacyMultiplayerFinishedView(
          score: player.score,
          correctAnswers: player.correctAnswers,
        );
      }
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
          child: SafeArea(
            child: Column(
              children: [
                LegacyMultiplayerHeader(
                  players: players,
                  localPlayerId: gameService.localPlayer?.id,
                  current: questionIndex + 1,
                  total: totalQuestions,
                  onConfirmExit: _confirmExit,
                ),
                LegacyMultiplayerTimer(
                  timeLeft: _timeLeft,
                  timerController: _timerController,
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _questionAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(_questionAnimation),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            LegacyMultiplayerQuestionCard(
                              text: question.questionText,
                            ),
                            const SizedBox(height: 24),
                            ...List.generate(
                              question.options.length,
                              (i) => LegacyMultiplayerOptionButton(
                                index: i,
                                text: question.options[i],
                                correctIndex: question.correctAnswerIndex,
                                selectedAnswer: _selectedAnswer,
                                isAnswered: _isAnswered,
                                onSelect: () => _submitAnswer(i),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
