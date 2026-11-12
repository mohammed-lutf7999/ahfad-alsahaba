import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../data/services/question_service.dart';
import '../../../data/services/profile_service.dart';
import '../../../data/services/progression_service.dart';
import '../../../data/services/achievement_service.dart';
import '../../../data/models/achievement_model.dart';
import '../../../data/models/question_model.dart';
import '../../widgets/avatar_selector.dart';
import '../../widgets/animated_avatar_frame.dart';
import '../../dialogs/app_dialogs.dart';
import 'widgets/game_match_result_dialog.dart';
import 'widgets/game_tactical_powerups_bar.dart';
import 'widgets/game_reactions_ribbon.dart';
import '../../../data/services/ghost_playback_service.dart';

class OnlineGameScreen extends StatefulWidget {
  final String matchId;
  final String opponentId;
  final int seed;
  final List<String> questionIds;
  final String opponentName;
  final int opponentAvatarIndex;
  final bool isBot; // New parameter
  final bool isGhost;
  final List<Map<String, dynamic>>? ghostTimeline;
  final String? ghostFrame;
  final int? ghostLevel;
  final int? ghostTrophies;

  const OnlineGameScreen({
    super.key,
    required this.matchId,
    required this.opponentId,
    required this.seed,
    required this.questionIds,
    required this.opponentName,
    required this.opponentAvatarIndex,
    this.isBot = false,
    this.isGhost = false,
    this.ghostTimeline,
    this.ghostFrame,
    this.ghostLevel,
    this.ghostTrophies,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> with TickerProviderStateMixin {
  // Game State
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int _myScore = 0;
  int _myCorrectAnswersCount = 0;
  final Set<int> _hiddenOptionIndices = {};
  bool _isLoading = true;
  bool _gameFinished = false;

  // Opponent State
  int _opponentScore = 0;
  int _opponentQuestionIndex = 0;

  // Bot State
  Timer? _botTimer;
  final Random _rnd = Random();
  GhostPlaybackService? _ghostPlaybackService;
  DateTime _questionStartTime = DateTime.now();
  final List<Map<String, dynamic>> _myAnswerTimelines = [];


  // UI State
  int _selectedAnswer = -1;
  bool _isAnswered = false;
  int _timeLeft = 15;
  Timer? _questionTimer;
  late AnimationController _progressController;
  
  // Reactions State
  late AnimationController _reactionController;
  late Animation<Offset> _emojiSlideAnim;
  late Animation<double> _emojiFadeAnim;
  String? _incomingReactionEmoji;
  
  StreamSubscription? _opponentSubscription;
  StreamSubscription? _reactionSubscription;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 15));
    
    // Reaction Animation
    _reactionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _emojiSlideAnim = Tween<Offset>(begin: const Offset(0, 2), end: const Offset(0, -1.5)).animate(
      CurvedAnimation(parent: _reactionController, curve: Curves.easeOutQuad),
    );
    _emojiFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _reactionController, curve: const Interval(0.7, 1.0)),
    );

    _initGame();
  }

  @override
  void dispose() {
    _ghostPlaybackService?.dispose();
    _botTimer?.cancel();
    _questionTimer?.cancel();
    _progressController.dispose();
    _reactionController.dispose();
    _opponentSubscription?.cancel();
    _reactionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initGame() async {
    try {
      List<Question> questions = [];
      
      // Load questions based on question_ids from Supabase
      if (widget.questionIds.isNotEmpty) {
        questions = await _loadQuestionsFromIds(widget.questionIds);
      }
      
      // Fallback to seed-based loading if questionIds failed
      if (questions.isEmpty) {
        questions = await QuestionService().getQuestionsForMultiplayer(widget.seed);
      }
      
      if (!mounted) return;
      
      setState(() {
        _questions = questions;
        _isLoading = false;
      });

      if (widget.isBot) {
        // Start Bot Logic after questions are loaded
        _startBotLogic();
      } else if (widget.isGhost && widget.ghostTimeline != null && widget.ghostTimeline!.isNotEmpty) {
        // Start Ghost Replay Logic
        _startGhostLogic();
      } else {
        // 2. Listen to Opponent progress
        _opponentSubscription = MultiplayerService.instance
            .listenToOpponentProgress(widget.matchId, widget.opponentId)
            .listen((data) {
              if (mounted && data.isNotEmpty) {
                setState(() {
                  _opponentScore = (data['current_score'] as num?)?.toInt() ?? 0;
                  _opponentQuestionIndex = (data['current_question_index'] as num?)?.toInt() ?? 0;
                });
              }
            });

        // 3. Listen to Reactions
        _reactionSubscription = MultiplayerService.instance
            .listenToReactions(widget.matchId)
            .listen((emoji) {
              _showIncomingReaction(emoji);
            });
      }

      if (_questions.isNotEmpty) {
        _startQuestionTimer();
      } else {
        // No questions available
        _showErrorDialog('لا توجد أسئلة متاحة');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('خطأ في تحميل الأسئلة: $e');
      }
    }
  }

  // --- GHOST REPLAY LOGIC ---

  void _startGhostLogic() {
    _ghostPlaybackService = GhostPlaybackService(
      timeline: widget.ghostTimeline!,
      onGhostAnswer: ({
        required int questionIndex,
        required int selectedOption,
        required bool isCorrect,
        required int scoreGained,
      }) {
        if (!mounted || _gameFinished) return;
        setState(() {
          _opponentScore += scoreGained;
          _opponentQuestionIndex = questionIndex + 1;
        });

        // Occasional chivalric reaction
        if (_rnd.nextDouble() < 0.25) {
          final reaction = isCorrect ? '⚔️' : '😅';
          Future.delayed(const Duration(milliseconds: 400), () => _showIncomingReaction(reaction));
        }
      },
    );
  }

  // --- BOT LOGIC ---

  void _startBotLogic() {
    _botWaitAndAnswer();
  }

  void _botWaitAndAnswer() {
    if (_opponentQuestionIndex >= _questions.length) return;
    _botTimer?.cancel();

    // 1. Simulate "Thinking Time"
    // Base time: 3 seconds || Random variance: 2-5 seconds
    // Reading time: 40ms per character (Faster reader)
    final currentQ = _questions[_opponentQuestionIndex];
    final readingTime = currentQ.questionText.length * 40; 
    final thinkingTime = 1500 + _rnd.nextInt(3000) + readingTime; 
    
    // Cap at 12 seconds max to stay within 15s limit
    final finalDelay = min(thinkingTime, 12000);

    _botTimer = Timer(Duration(milliseconds: finalDelay), () {
      if (!mounted || _gameFinished) return;

      // 2. Determine Correctness
      // Base accuracy: 85% (Smarter bot)
      final isCorrect = _rnd.nextDouble() < 0.85;  
      
      // Calculate Score
      // If correct: Base points (10) + Time bonus (max 5)
      int points = 0;
      if (isCorrect) {
        final timeLeft = (15000 - finalDelay) ~/ 1000;
        points = 10 + timeLeft.clamp(0, 15);
        _opponentScore += points;
      }

      setState(() {
        _opponentQuestionIndex++;
      });

      // 3. Bot Reaction (Optional)
      if (_rnd.nextDouble() < 0.2) { // 20% chance
         final reaction = isCorrect ? '😎' : '😡';
         Future.delayed(const Duration(milliseconds: 500), () => _showIncomingReaction(reaction));
      }

      // Check for finish
      if (_opponentQuestionIndex < _questions.length) {
         // Next question logic handled by next call
         _botWaitAndAnswer();
      }
    });
  }

  void _showIncomingReaction(String emoji) {
    if (!mounted) return;
    setState(() {
      _incomingReactionEmoji = emoji;
    });
    _reactionController.forward(from: 0);
  }

  Future<void> _sendReaction(String emoji) async {
    await MultiplayerService.instance.sendReaction(widget.matchId, emoji);
  }

  /// Load questions based on question IDs from Supabase
  /// Format: 'category:level:question_index'
  Future<List<Question>> _loadQuestionsFromIds(List<String> questionIds) async {
    final questions = <Question>[];
    
    for (final qId in questionIds) {
      try {
        final parts = qId.split(':');
        if (parts.length >= 3) {
          final categoryId = parts[0];
          final level = int.tryParse(parts[1]) ?? 1;
          final questionIndex = int.tryParse(parts[2]) ?? 0;
          
          // Load questions for this category and level
          final levelQuestions = await QuestionService().loadQuestions(
            categoryId: categoryId,
            levelNumber: level,
          );
          
          if (questionIndex < levelQuestions.length) {
            questions.add(levelQuestions[questionIndex]);
          } else if (levelQuestions.isNotEmpty) {
            // Fallback to first question if index out of range
            questions.add(levelQuestions[questionIndex % levelQuestions.length]);
          }
        }
      } catch (e) {
        print('Error loading question $qId: $e');
      }
    }
    
    return questions;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.primaryDark,
        title: const Text('خطأ', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('عودة'),
          ),
        ],
      ),
    );
  }

  void _startQuestionTimer() {
    _questionStartTime = DateTime.now();
    if (widget.isGhost && _ghostPlaybackService != null) {
      _ghostPlaybackService!.playQuestion(_currentQuestionIndex);
    }
    _timeLeft = 15;
    _progressController.forward(from: 0);
    _selectedAnswer = -1;
    _isAnswered = false;
    _hiddenOptionIndices.clear();

    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          if (_timeLeft <= 5) SoundService().startTimerTick();
        } else {
          _timeout();
        }
      });
    });
  }

  void _timeout() {
    SoundService().stopTimerTick();
    _submitAnswer(-1); // Timeout
  }

  Future<void> _submitAnswer(int index) async {
    if (_isAnswered) return;
    
    _questionTimer?.cancel();
    SoundService().stopTimerTick();
    
    bool isCorrect = false;
    if (index != -1 && _currentQuestionIndex < _questions.length) {
      final question = _questions[_currentQuestionIndex];
      isCorrect = index == question.correctAnswerIndex;
    }

    final elapsedMs = DateTime.now().difference(_questionStartTime).inMilliseconds;
    _myAnswerTimelines.add({
      'q': _currentQuestionIndex,
      'ms': elapsedMs,
      'ans': index,
      'ok': isCorrect,
    });

    setState(() {
      _isAnswered = true;
      _selectedAnswer = index;
      if (isCorrect) {
        _myCorrectAnswersCount++;
        SoundService().playCorrect();
        if (_timeLeft >= 12) {
          AchievementService.instance.checkAchievements(
            AchievementEvent.fastAnswer(secondsRemaining: _timeLeft, totalTime: 15),
          );
        }
      } else {
        SoundService().playWrong();
      }
    });

    // Submit to Supabase and get updated scores
    if (widget.isBot) {
       // Local calculation for bot mode (10 base + clamp(time, 0, 15) matching online RPC)
       int points = 0;
       if (isCorrect) {
         points = 10 + _timeLeft.clamp(0, 15);
       }
       setState(() {
         _myScore += points;
       });
       // Opponent score is updated by _botWaitAndAnswer
    } else {
       // Online match (human or ghost on Supabase)
       final scores = await MultiplayerService.instance.submitAnswer(
        matchId: widget.matchId,
        questionIndex: _currentQuestionIndex,
        isCorrect: isCorrect,
        timeLeft: _timeLeft,
        currentLocalScore: _myScore,
      );
      
      if (mounted) {
        setState(() {
          _myScore = scores['myScore'] ?? _myScore;
          if (!widget.isGhost) {
            final oppScore = scores['opponentScore'] ?? 0;
            if (oppScore > _opponentScore) {
              _opponentScore = oppScore;
            }
          }
        });
      }
    }

    // Next Question Delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
        _startQuestionTimer();
      } else {
        _finishGame();
      }
    });
  }

  Future<void> _finishGame() async {
    // Strict Guard: Prevent any duplicate execution or double score/trophy counting
    if (_gameFinished) return;
    _gameFinished = true;
    if (mounted) setState(() {});
    _botTimer?.cancel(); // Stop bot if running
    _ghostPlaybackService?.dispose();

    if (!widget.isBot && !widget.isGhost && _myAnswerTimelines.length == 5) {
      unawaited(MultiplayerService.instance.saveGhostTimeline(
        matchId: widget.matchId,
        timeline: _myAnswerTimelines,
      ));
    }
    
    String? winnerId;
    int? trophiesDelta;
    int? totalTrophies;

    if (widget.isBot) {
       // Determine winner locally
       final myId = MultiplayerService.instance.currentUserId;
       if (_myScore > _opponentScore) {
         winnerId = myId;
       } else if (_opponentScore > _myScore) {
         winnerId = widget.opponentId;
       } else {
         winnerId = null; // Draw
       }
    } else {
      if (widget.opponentId.isNotEmpty) {
        MultiplayerService.instance.lastOpponentId = widget.opponentId;
      }
      final result = await MultiplayerService.instance.finishMatch(widget.matchId);
      
      if (mounted) {
        setState(() {
          _myScore = result['myScore'] ?? _myScore;
          _opponentScore = result['opponentScore'] ?? _opponentScore;
        });
      }
      winnerId = result['winnerId'];
      trophiesDelta = result['trophiesDelta'] as int?;
      totalTrophies = result['totalTrophies'] as int?;
    }

    final myId = MultiplayerService.instance.currentUserId;
    final isWinner = winnerId != null ? (winnerId == myId) : (_myScore > _opponentScore);
    final isDraw = (winnerId == null && _myScore == _opponentScore) || (!isWinner && _myScore == _opponentScore);

    // Capture pre-match progression snapshot BEFORE modifying activeProfile
    final preSnapshot = ProgressionService.instance.captureSnapshot();

    // Apply progression outcome (XP + Trophies + Arena Coins + Shield / XP Banner)
    final outcome = ProgressionService.instance.applyMatchOutcome(
      rawMatchScore: _myScore,
      correctAnswers: _myCorrectAnswersCount,
      isWin: isWinner,
      isDraw: isDraw,
      serverTotalTrophies: totalTrophies,
      serverTrophiesDelta: trophiesDelta,
      updateTrophies: true,
    );

    await ProfileService.instance.saveActiveProfileAndSync();
    
    // فحص وتسوية الإنجازات فوراً بنقاط المسابقة الجماعية
    await AchievementService.instance.reconcileAchievements();

    // Trigger Epic Level-Up & Arena Promotion Celebration Dialogs if promoted!
    if (mounted) {
      await ProgressionService.instance.checkAndTriggerCelebrations(
        context,
        before: preSnapshot,
      );
    }
    
    if (mounted) {
      _showResultDialog(
        winnerId,
        trophiesDelta: outcome.trophiesDelta,
        totalTrophies: ProfileService.instance.activeProfile?.trophies ?? totalTrophies,
        coinsEarned: outcome.coinsEarned,
        shieldConsumed: outcome.shieldConsumed,
        xpBannerConsumed: outcome.xpBannerConsumed,
      );
    }
  }

  void _onRematchAccepted(MatchmakingResult newMatch) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          matchId: newMatch.matchId!,
          opponentId: newMatch.opponentId ?? widget.opponentId,
          seed: newMatch.seed ?? widget.seed,
          questionIds: newMatch.questionIds ?? [],
          opponentName: widget.opponentName,
          opponentAvatarIndex: widget.opponentAvatarIndex,
          isBot: widget.isBot,
        ),
      ),
    );
  }

  void _showResultDialog(
    String? winnerId, {
    int? trophiesDelta,
    int? totalTrophies,
    int coinsEarned = 0,
    bool shieldConsumed = false,
    bool xpBannerConsumed = false,
  }) {
    final myId = MultiplayerService.instance.currentUserId;
    final isWinner = winnerId != null ? (winnerId == myId) : (_myScore > _opponentScore);
    final isDraw = (winnerId == null && _myScore == _opponentScore) || (!isWinner && _myScore == _opponentScore);
    final effectiveDelta = trophiesDelta ?? (isDraw ? 5 : (isWinner ? 25 : -12));

    GameMatchResultDialog.show(
      context,
      isWinner: isWinner,
      isDraw: isDraw,
      effectiveDelta: effectiveDelta,
      totalTrophies: totalTrophies,
      coinsEarned: coinsEarned,
      shieldConsumed: shieldConsumed,
      xpBannerConsumed: xpBannerConsumed,
      myScore: _myScore,
      opponentScore: _opponentScore,
      opponentName: widget.opponentName,
      matchId: widget.matchId,
      opponentId: widget.opponentId,
      isBot: widget.isBot || widget.isGhost,
      onRematchAccepted: _onRematchAccepted,
      onDismiss: () => Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('جاري تحميل الأسئلة...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                const Text('لا توجد أسئلة', style: TextStyle(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('عودة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final myProfile = ProfileService.instance.activeProfile;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        AppDialogs.showExitConfirmationDialog(
          context,
          title: 'الانسحاب من المباراة؟',
          message: 'الخروج أثناء المباراة المباشرة سيؤدي إلى خسارتك النقاط والكؤوس. هل تريد الخروج حقاً؟',
          confirmLabel: 'تأكيد الانسحاب',
          cancelLabel: 'متابعة القتال',
          onConfirm: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
      },
      child: Scaffold(
      floatingActionButton: null,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppCustomTheme.of(context).backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main Game Content
              Column(
                children: [
                  // --- Header (Scores & Timer) - Responsive & Overflow Protected ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: Colors.black26,
                    child: Row(
                      children: [
                         // Me
                         Expanded(
                           child: Row(
                             children: [
                               AnimatedAvatarFrame(
                                 size: 42,
                                 frameKey: myProfile?.equippedFrame ?? 'frame_wood',
                                 winStreak: myProfile?.winStreak ?? 0,
                                 child: ProfileAvatar(avatarIndex: myProfile?.avatarIndex ?? 0, size: 34),
                               ),
                               const SizedBox(width: 6),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Text(
                                       myProfile?.name ?? 'أنا',
                                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                     Text(
                                       '$_myScore',
                                       style: const TextStyle(color: AppTheme.accentColor, fontSize: 16, fontWeight: FontWeight.bold),
                                     ),
                                   ],
                                 ),
                               ),
                             ],
                           ),
                         ),
                         
                         // VS / Central Timer
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10),
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: _timeLeft <= 5 ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.12),
                                   borderRadius: BorderRadius.circular(16),
                                   border: Border.all(
                                     color: _timeLeft <= 5 ? Colors.red : Colors.white30,
                                   ),
                                 ),
                                 child: Text(
                                   '$_timeLeft',
                                   style: TextStyle(
                                     color: _timeLeft <= 5 ? Colors.red : Colors.white,
                                     fontSize: 20,
                                     fontWeight: FontWeight.bold,
                                   ),
                                 ),
                               ),
                               const SizedBox(height: 2),
                               Text(
                                 'سؤال ${_currentQuestionIndex + 1}/${_questions.length}',
                                 style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'Cairo'),
                               ),
                             ],
                           ),
                         ),

                         // Opponent
                         Expanded(
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.end,
                             children: [
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.end,
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Text(
                                       widget.opponentName,
                                       style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis,
                                       textAlign: TextAlign.end,
                                     ),
                                     Text(
                                       '$_opponentScore',
                                       style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                                     ),
                                     SizedBox(
                                       width: 50,
                                       height: 3,
                                       child: LinearProgressIndicator(
                                         value: _questions.isNotEmpty ? (_opponentQuestionIndex / _questions.length) : 0,
                                         backgroundColor: Colors.white10,
                                         color: Colors.redAccent,
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                               const SizedBox(width: 6),
                               ProfileAvatar(avatarIndex: widget.opponentAvatarIndex, size: 36),
                             ],
                           ),
                         ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Progress bar
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: 1 - _progressController.value,
                        backgroundColor: Colors.white10,
                        color: _timeLeft <= 5 ? Colors.red : AppTheme.accentColor,
                        minHeight: 4,
                      );
                    },
                  ),

                  // --- Question & Options with Clean Reaction Ribbon ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Column(
                        children: [
                          _buildQuestionCard(question.questionText),
                          const SizedBox(height: 10),
                          GameTacticalPowerUpsBar(
                            question: question,
                            isAnswered: _isAnswered,
                            hiddenOptionIndices: _hiddenOptionIndices,
                            random: _rnd,
                            onInsightUsed: (newHidden) {
                              setState(() {
                                _hiddenOptionIndices.addAll(newHidden);
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          if (!widget.isBot)
                            GameReactionsRibbon(
                              onReactionSelected: _sendReaction,
                            ),
                          const SizedBox(height: 10),
                          ...List.generate(question.options.length, (i) {
                             if (_hiddenOptionIndices.contains(i)) {
                               return const SizedBox.shrink();
                             }
                             return _buildOptionButton(i, question.options[i], question.correctAnswerIndex);
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Reaction Animation Layer (positioned right near opponent avatar)
              if (_incomingReactionEmoji != null)
                Positioned(
                  top: 65,
                  right: 20,
                  child: SlideTransition(
                    position: _emojiSlideAnim,
                    child: FadeTransition(
                      opacity: _emojiFadeAnim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                        ),
                        child: Text(
                          _incomingReactionEmoji!,
                          style: const TextStyle(fontSize: 32),
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
  
  Widget _buildQuestionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.5, fontFamily: 'Cairo'),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOptionButton(int index, String text, int correctIndex) {
    final isSelected = _selectedAnswer == index;
    final isCorrect = index == correctIndex;
    
    Color color = Colors.white.withOpacity(0.05);
    Color borderColor = Colors.white.withOpacity(0.1);
    
    if (_isAnswered) {
      if (isCorrect) {
        color = Colors.green.withOpacity(0.3);
        borderColor = Colors.green;
      } else if (isSelected) {
        color = Colors.red.withOpacity(0.3);
        borderColor = Colors.red;
      }
    } else if (isSelected) {
      color = AppTheme.accentColor.withOpacity(0.3);
    }

    return GestureDetector(
      onTap: _isAnswered ? null : () => _submitAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
             Container(
               width: 30,
               height: 30,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: borderColor.withOpacity(0.3),
               ),
               child: Center(
                 child: Text(
                   String.fromCharCode(65 + index),
                   style: TextStyle(color: borderColor, fontWeight: FontWeight.bold),
                 ),
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: Text(
                 text,
                 style: const TextStyle(color: Colors.white, fontSize: 16),
               ),
             ),
             if (_isAnswered && isCorrect)
               const Icon(Icons.check_circle, color: Colors.green),
             if (_isAnswered && isSelected && !isCorrect)
               const Icon(Icons.cancel, color: Colors.red),
          ],
        ),
      ),
    );
  }
}
