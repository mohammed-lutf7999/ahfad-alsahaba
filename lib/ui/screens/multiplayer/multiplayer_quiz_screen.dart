import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/challenge_game_service.dart';
import '../../../data/models/challenge_config.dart';
import '../../widgets/avatar_selector.dart';
import 'challenge_result_screen.dart';

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
  int _timeLeft = 15; // ثواني
  int _streak = 0; // Track consecutive correct answers
  Timer? _countdownTimer;

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
    ChallengeGameService.instance.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (mounted) {
      setState(() {});
      
      if (ChallengeGameService.instance.state == ChallengeState.finished) {
        _navigateToResults();
      }
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
      if (mounted) {
        setState(() {
          _timeLeft--;
          if (_timeLeft == 5) {
             SoundService().startTimerTick(); // Start ticking sound
          }
          if (_timeLeft <= 0) {
            timer.cancel();
            SoundService().stopTimerTick(); // Stop ticking
            _timeExpired();
          }
        });
      }
    });
  }

  void _timeExpired() {
    if (!_isAnswered) {
      _submitAnswer(-1); // وقت منتهي بدون إجابة
    }
  }

  void _submitAnswer(int answerIndex) {
    if (_isAnswered) return;
    
    _countdownTimer?.cancel();
    
    setState(() {
      _isAnswered = true;
      _selectedAnswer = answerIndex;
    });
    
    SoundService().stopTimerTick(); // Stop ticking immediately
    
    // Check correctness locally for sound feedback
    final isCorrect = answerIndex == ChallengeGameService.instance.currentQuestion?.correctAnswerIndex;
    if (isCorrect) {
      SoundService().playCorrect();
      _streak++;
      if (_streak % 3 == 0) {
        SoundService().playStreak(); // Bonus sound every 3 streaks
      }
    } else {
      SoundService().playWrong();
      _streak = 0; // Reset streak
    }
    
    ChallengeGameService.instance.submitAnswer(answerIndex);
    
    _countdownTimer?.cancel();
    
    // انتقل للسؤال التالي بعد ثانيتين
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ChallengeGameService.instance.nextQuestion();
        if (ChallengeGameService.instance.state == ChallengeState.inProgress) {
          _startQuestion();
        }
      }
    });
  }
  
  // Helper for fix above: _questionTimer was a typo in original read file, likely meant _countdownTimer
  // But let's check original. It used _countdownTimer.
  // Wait, in my previous read of original file (step 867), line 129 said `_countdownTimer?.cancel();`
  // And line 133 had `if (mounted)`.
  
  // I will just use _countdownTimer consistently.

  Future<void> _confirmExit() async {
    SoundService().playAlert();
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryDark,
        title: const Text('انسحاب من التحدي؟', style: TextStyle(color: Colors.white)),
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

    if (shouldExit == true) {
      if (mounted) {
        _countdownTimer?.cancel();
        SoundService().stopTimerTick();
        // Reset game service logic here if needed, or just pop
        ChallengeGameService.instance.reset(); // Reset game state
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Text(
                     '🎉 أنهيت التحدي!',
                     style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                   ),
                   const SizedBox(height: 20),
                   Container(
                     padding: const EdgeInsets.all(20),
                     margin: const EdgeInsets.symmetric(horizontal: 40),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(20),
                       border: Border.all(color: AppTheme.accentColor.withOpacity(0.5)),
                     ),
                     child: Column(
                       children: [
                         Text(
                           '${player.score} نقطة',
                           style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                         ),
                         const SizedBox(height: 10),
                         Text(
                           '${player.correctAnswers} إجابة صحيحة',
                           style: const TextStyle(color: Colors.white70),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 40),
                   const CircularProgressIndicator(color: AppTheme.accentColor),
                   const SizedBox(height: 16),
                   const Text(
                     'بانتظار انتهاء باقي اللاعبين لعرض الترتيب...',
                     style: TextStyle(color: Colors.white54),
                     textAlign: TextAlign.center,
                   ),
                ],
              ),
            ),
          ),
        );
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return WillPopScope(
      onWillPop: () async => false, // منع الخروج أثناء اللعب
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
          child: SafeArea(
            child: Column(
              children: [
                // Header with scores
                _buildHeader(players, questionIndex + 1, totalQuestions),
                
                // Timer
                _buildTimer(),
                
                // Question
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
                            // Question Text
                            _buildQuestionCard(question.questionText),
                            
                            const SizedBox(height: 24),
                            
                            // Options
                            ...List.generate(
                              question.options.length,
                              (i) => _buildOptionButton(
                                i,
                                question.options[i],
                                question.correctAnswerIndex,
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

  Widget _buildHeader(List players, int current, int total) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Progress
          // Progress & Exit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                onPressed: _confirmExit,
                tooltip: 'انسحاب',
              ),
              Text(
                'السؤال $current من $total',
                style: const TextStyle(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 48), // Balance the row
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Players scores
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: players.map((player) {
                final isLocal = player.id == ChallengeGameService.instance.localPlayer?.id;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isLocal ? AppTheme.accentColor : Colors.white).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isLocal ? AppTheme.accentColor : Colors.white).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProfileAvatar(avatarIndex: player.avatarIndex, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${player.score}',
                        style: TextStyle(
                          color: isLocal ? AppTheme.accentColor : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final color = _timeLeft <= 5 ? Colors.red : AppTheme.accentColor;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '$_timeLeft',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _timerController,
            builder: (context, _) {
              return LinearProgressIndicator(
                value: 1 - _timerController.value,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryLight.withOpacity(0.3),
            AppTheme.primaryColor.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          height: 1.6,
          fontFamily: 'Cairo',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOptionButton(int index, String text, int correctIndex) {
    final isSelected = _selectedAnswer == index;
    final isCorrect = index == correctIndex;
    final showResult = _isAnswered;
    
    Color bgColor;
    Color borderColor;
    IconData? icon;
    
    if (showResult) {
      if (isCorrect) {
        bgColor = Colors.green.withOpacity(0.2);
        borderColor = Colors.green;
        icon = Icons.check_circle_rounded;
      } else if (isSelected && !isCorrect) {
        bgColor = Colors.red.withOpacity(0.2);
        borderColor = Colors.red;
        icon = Icons.cancel_rounded;
      } else {
        bgColor = Colors.white.withOpacity(0.05);
        borderColor = Colors.white.withOpacity(0.1);
      }
    } else {
      bgColor = isSelected 
          ? AppTheme.accentColor.withOpacity(0.2)
          : Colors.white.withOpacity(0.05);
      borderColor = isSelected 
          ? AppTheme.accentColor 
          : Colors.white.withOpacity(0.1);
    }
    
    return GestureDetector(
      onTap: _isAnswered ? null : () => _submitAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: borderColor, size: 20)
                    : Text(
                        String.fromCharCode(65 + index), // A, B, C, D
                        style: TextStyle(
                          color: isSelected ? AppTheme.accentColor : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: showResult && isCorrect 
                      ? Colors.green 
                      : (showResult && isSelected && !isCorrect ? Colors.red : Colors.white),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
