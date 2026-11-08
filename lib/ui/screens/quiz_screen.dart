import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../core/app_routes.dart';
import '../../logic/game_controller.dart';
import '../../logic/timer_controller.dart';
import '../../core/sound_service.dart';
import '../../data/local/shared_prefs_service.dart';
import '../widgets/question_card.dart';
import '../widgets/option_button.dart';
import '../widgets/timer_widget.dart';
import '../dialogs/app_dialogs.dart';
import 'quiz/widgets/quiz_lifelines_dock.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/progression_service.dart';
import '../../data/models/achievement_model.dart';

class QuizScreen extends StatefulWidget {
  final String categoryId;
  final String levelId;
  final int levelNumber;

  const QuizScreen({super.key, required this.categoryId, required this.levelId, required this.levelNumber});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  late GameController _gameController;
  late TimerController _timerController;
  int _streak = 0; // Track consecutive correct answers
  late AnimationController _animationController;
  late AnimationController _successController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _gameController = GameController();
    _timerController = TimerController();

    _animationController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _successController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    _gameController.initializeCategories();
    await _gameController.loadQuestionsForLevel(widget.categoryId, widget.levelNumber);
    _timerController.initialize();

    if (mounted) {
      setState(() => _isLoading = false);
      _animationController.forward();
      _startTimer();
    }
  }

  void _startTimer() => _timerController.startTimer(
    onTimeUp: _onTimeUp,
    onTick: (remaining) {
      if (remaining == 5) SoundService().startTimerTick();
    }
  );

  void _onTimeUp() {
     SoundService().stopTimerTick();
     if (!_gameController.isAnswered) _handleAnswer(-1);
  }

  void _handleAnswer(int selectedIndex) {
    if (_gameController.isAnswered) return;
    _timerController.stopTimer();
    SoundService().stopTimerTick();

    bool isCorrect = selectedIndex == _gameController.currentQuestion?.correctAnswerIndex;

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
          AchievementEvent.fastAnswer(secondsRemaining: _timerController.remainingTime),
        );
      }
    } else {
      SoundService().playWrong();
      _streak = 0;
    }

    setState(() => _gameController.answerQuestion(selectedIndex));

    // Handle Lives Logic
    if (_gameController.lives == 0) {
      _showGameOverDialog();
    } else {
        if (_gameController.lives == 1) {
            _showWarningToast();
        }
        Future.delayed(const Duration(milliseconds: 1500), () { if (mounted) _nextQuestion(); });
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
    final preSnapshot = ProgressionService.instance.captureSnapshot();
    await _gameController.completeLevel();
    if (_gameController.score > 0) {
      SoundService().playLevelComplete();
    }

    if (mounted) {
      await ProgressionService.instance.checkAndTriggerCelebrations(
        context,
        before: preSnapshot,
      );
    }

    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.result, arguments: {
        'correctAnswers': _gameController.correctAnswers,
        'totalQuestions': _gameController.currentQuestions.length,
        'totalScore': _gameController.score,
        'categoryId': widget.categoryId,
        'levelId': widget.levelId,
        'userAnswers': _gameController.userAnswers,
      });
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    _animationController.dispose();
    _successController.dispose();
    SoundService().stopTimerTick(); // Safety cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _gameController.currentQuestion == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
          child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor))),
        ),
      );
    }

    final question = _gameController.currentQuestion!;
    final progress = _gameController.progress;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppCustomTheme.of(context).backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              AnimatedBuilder(
                animation: _successController,
                builder: (context, child) {
                  final glow = _successController.value * 5;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                         Color.lerp(AppTheme.primaryLight, AppTheme.accentColor, _successController.value * 0.3)!.withAlpha(200),
                         Color.lerp(AppTheme.primaryColor, AppTheme.accentDark, _successController.value * 0.3)!
                      ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentColor.withAlpha(60 + (100 * _successController.value).toInt()), width: 1.5 + _successController.value),
                      boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(40 + (50 * _successController.value).toInt()), blurRadius: 15 + glow)],
                    ),
                    child: child,
                  );
                },
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _showExitDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.accentColor.withAlpha(40)),
                            ),
                            child: const Icon(Icons.close_rounded, color: AppTheme.accentColor, size: 20),
                          ),
                        ),
                        
                        // Lives Bar (Shattering Hearts)
                        Row(
                          children: List.generate(3, (index) {
                            final isActive = index < _gameController.lives;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: _ShatteringHeart(isActive: isActive),
                            );
                          }),
                        ),

                        // Timer (Smaller)
                        Transform.scale(
                          scale: 0.85, 
                          child: ListenableBuilder(
                            listenable: _timerController,
                            builder: (context, _) => TimerWidget(
                              remainingTime: _timerController.remainingTime,
                              totalTime: _timerController.totalTime,
                              isRunning: _timerController.isRunning,
                            ),
                          ),
                        ),

                        // Score Area with Shine Effect
                        AnimatedBuilder(
                          animation: _successController,
                           builder: (context, child) {
                             final glow = _successController.value * 10;
                             return Container(
                               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                               decoration: BoxDecoration(
                                  gradient: AppTheme.goldGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentColor.withAlpha(80 + (100 * _successController.value).toInt()),
                                      blurRadius: 8 + glow,
                                      spreadRadius: _successController.value * 3
                                    )
                                  ],
                               ),
                               child: Row(
                                 children: [
                                   const Icon(Icons.stars_rounded, color: AppTheme.primaryDark, size: 18),
                                   const SizedBox(width: 6),
                                   Text('${_gameController.score}', style: const TextStyle(color: AppTheme.primaryDark, fontSize: 16, fontWeight: FontWeight.bold)),
                                 ],
                               ),
                             );
                           },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text('السؤال ${_gameController.currentQuestionIndex + 1}/${_gameController.currentQuestions.length}', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12)),
                        Text('المستوى ${widget.levelNumber}', style: TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          LinearProgressIndicator(value: progress, backgroundColor: Colors.black26, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentColor), minHeight: 6),
                          if (_successController.isAnimating)
                            Positioned.fill(
                              child: LayoutBuilder(builder: (ctx, constraints) {
                                return Transform.translate(
                                  offset: Offset(constraints.maxWidth * (_successController.value - 1), 0),
                                  child: Container(width: constraints.maxWidth / 3, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withOpacity(0.5), Colors.transparent]))),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    

                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          QuestionCard(
                            questionText: question.questionText,
                            questionNumber: _gameController.currentQuestionIndex + 1,
                            totalQuestions: _gameController.currentQuestions.length,
                          ),
                          const SizedBox(height: 8),
                          if (_gameController.isAnswered && question.explanation != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  const Icon(Icons.lightbulb_rounded, color: AppTheme.accentColor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(question.explanation!,
                                          textAlign: TextAlign.right,
                                          textDirection: TextDirection.rtl,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                              height: 1.3))),
                                ],
                              ),
                            ),
                          if (!(_gameController.isAnswered &&
                              question.explanation != null))
                            const SizedBox(height: 8),
                          ...List.generate(question.options.length, (index) {
                            // Hide options if 50/50 is used on them
                            if (_gameController.hiddenOptionIndices.contains(index)) {
                               return const SizedBox.shrink(); // Hide completely
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: OptionButton(
                                text: question.options[index],
                                index: index,
                                isSelected: _gameController.selectedAnswerIndex == index,
                                isCorrect: index == question.correctAnswerIndex,
                                isAnswered: _gameController.isAnswered,
                                onTap: () => _handleAnswer(index),
                              ),
                            );
                          }),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- Bottom Lifelines Dock ---
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

  void _showExitDialog() {
    SoundService().playAlert();
    AppDialogs.showExitConfirmationDialog(
      context,
      title: 'هل تود الانسحاب؟',
      message: 'خروجك الآن يعني فقدان تقدمك في هذا المستوى. هل أنت متأكد من قرارك؟',
      confirmLabel: 'تأكيد الخروج',
      cancelLabel: 'تراجع ومتابعة',
      onConfirm: () {
        Navigator.pop(context);
      },
    );
  }
  void _showWarningToast() {
    SoundService().playAlert();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text("تبقت لك محاولة واحدة!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showGameOverDialog() {
    SoundService().playDefeat(); // Sad sound for game over
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  // Purple Gradient (Dark to Light)
                  gradient: const LinearGradient(
                    colors: [Color(0xFF311B92), Color(0xFF673AB7)], // Deep Purple to Purple
                    begin: Alignment.topCenter, 
                    end: Alignment.bottomCenter
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF9575CD), width: 2),
                  boxShadow: [BoxShadow(color: const Color(0xFF311B92).withOpacity(0.6), blurRadius: 40, spreadRadius: 5)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Blinking Game Over Text
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: 0.5),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return Opacity(opacity: value, child: child);
                      },
                      onEnd: () {}, // Loop handled by rebuilding widget tree usually, but for simple dialog this is okay-ish static. For loop, we need StatefulWidget.
                      // Making it a simple static glow for now to avoid state complexity in dialog builder
                      child: const Text(
                        "حسرت المسابقة", 
                        style: TextStyle(
                          fontSize: 32, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          shadows: [BoxShadow(color: Colors.white, blurRadius: 15, spreadRadius: 2)]
                        )
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Gold Subtext
                    const Text(
                      "هل ترغب في إعادة المحاولة؟", 
                      textAlign: TextAlign.center, 
                      style: TextStyle(
                        fontSize: 18, 
                        color: Color(0xFFFFD700), // Gold
                        height: 1.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo' // Assuming default font supports Arabic.
                      )
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                                Navigator.pop(context); // Close dialog
                                _initializeQuiz(); // Restart level
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E57C2), // Lighter Purple
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 8,
                                shadowColor: const Color(0xFFFFD700).withOpacity(0.4), // Gold Shadow
                            ),
                            child: const Text("إعادة المحاولة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                                Navigator.pop(context); // Close dialog
                                Navigator.pop(context); // Exit screen
                            },
                             style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFF210857), // Very Dark Purple
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFF9575CD), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text("خروج", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShatteringHeart extends StatefulWidget {
  final bool isActive;
  const _ShatteringHeart({required this.isActive});

  @override
  State<_ShatteringHeart> createState() => _ShatteringHeartState();
}

class _ShatteringHeartState extends State<_ShatteringHeart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
  }

  @override
  void didUpdateWidget(covariant _ShatteringHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _controller.forward();
    } else if (!oldWidget.isActive && widget.isActive) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isActive) {
       return const Icon(Icons.favorite_rounded, color: Color(0xFFFFD700), size: 24);
    }
    
    // Shattering Animation
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0 && !widget.isActive) {
          return Icon(Icons.favorite_border_rounded, color: Colors.grey.withOpacity(0.5), size: 24);
        }

        // Shake Effect
        final offset = Offset(
           (2 * (0.5 - (0.5 - _controller.value).abs())) * 5 * (isOddFrame ? 1 : -1),
           0
        );

        // Fade Out / Break Effect (simulated by scale/opacity)
        return Transform.translate(
           offset: _controller.isAnimating ? offset : Offset.zero,
           child: Opacity(
             opacity: 1.0 - _controller.value,
             child: const Icon(Icons.heart_broken_rounded, color: Colors.redAccent, size: 24),
           ),
        );
      },
    );
  }
  
  bool get isOddFrame => DateTime.now().millisecond % 2 == 0;
}
