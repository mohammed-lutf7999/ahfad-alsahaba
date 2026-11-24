import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../../core/app_constants.dart';
import '../../core/app_theme.dart';
import '../../core/share_service.dart';
import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/achievement_model.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/progression_service.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/particles/unified_particle_system.dart';
import 'result/widgets/result_celebration_header.dart';
import 'result/widgets/result_summary_card.dart';

class ResultScreen extends StatefulWidget {
  final int correctAnswers;
  final int totalQuestions;
  final int totalScore;
  final String categoryId;
  final String levelId;
  final int? levelNumber;
  final List<Map<String, dynamic>>? userAnswers;
  final ProgressionSnapshot? preProgressionSnapshot;

  const ResultScreen({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.totalScore,
    required this.categoryId,
    required this.levelId,
    this.levelNumber,
    this.userAnswers,
    this.preProgressionSnapshot,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _scoreController;
  late AnimationController _pulseController;
  late AnimationController _starsController;
  late AnimationController _starWobbleController;

  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  late Animation<double> _scoreAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();
  final List<Timer> _pendingTimers = [];
  final List<Completer<bool>> _pendingDelayCompleters = [];

  double get percentage => widget.totalQuestions > 0
      ? widget.correctAnswers / widget.totalQuestions * 100
      : 0.0;
  bool get isPassed => percentage >= AppConstants.passingScore;
  int get stars => AppConstants.calculateStars(percentage);

  int get effectiveLevelNumber {
    if (widget.levelNumber != null) return widget.levelNumber!;
    final tail = int.tryParse(widget.levelId.split('_').last);
    if (tail != null) return tail;
    return int.tryParse(widget.levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
  }

  @override
  void initState() {
    super.initState();
    _initializeConfetti();

    _confettiController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _starsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _starWobbleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scoreAnimation = Tween<double>(begin: 0, end: percentage).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.elasticOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  void _initializeConfetti() {
    for (int i = 0; i < 40; i++) {
      _particles.add(
        ConfettiParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble() * -1,
          speed: _random.nextDouble() * 0.4 + 0.2,
          size: _random.nextDouble() * 6 + 3,
          color: [
            AppTheme.accentColor,
            AppTheme.accentLight,
            AppTheme.accentDark,
            Colors.white,
          ][_random.nextInt(4)],
          rotation: _random.nextDouble() * math.pi * 2,
          rotationSpeed: _random.nextDouble() * 0.1 - 0.05,
          shape: _random.nextInt(3),
        ),
      );
    }
  }

  Future<bool> _cancellableDelay(Duration duration) {
    final completer = Completer<bool>();
    _pendingDelayCompleters.add(completer);
    late final Timer timer;
    timer = Timer(duration, () {
      _pendingTimers.remove(timer);
      _pendingDelayCompleters.remove(completer);
      if (!completer.isCompleted) completer.complete(true);
    });
    _pendingTimers.add(timer);
    return completer.future;
  }

  void _startAnimations() async {
    if (!await _cancellableDelay(const Duration(milliseconds: 150)) ||
        !mounted) {
      return;
    }
    _scoreController.forward();

    if (!await _cancellableDelay(const Duration(milliseconds: 300)) ||
        !mounted) {
      return;
    }
    _starsController.forward();

    if (isPassed) {
      _confettiController.repeat();
      _pulseController.repeat(reverse: true);
      _starWobbleController.repeat(reverse: true);
    }

    _runPostResultChecks();
  }

  Future<void> _runPostResultChecks() async {
    final snapshot = widget.preProgressionSnapshot;
    if (snapshot != null) {
      if (!await _cancellableDelay(const Duration(milliseconds: 600)) ||
          !mounted) {
        return;
      }
      await ProgressionService.instance.checkAndTriggerCelebrations(
        context,
        before: snapshot,
      );
    }

    if (!mounted) return;
    await _checkAchievements();
  }

  Future<void> _checkAchievements() async {
    if (!mounted) return;
    await AchievementService.instance.checkAchievements(
      AchievementEvent.levelCompleted(
        categoryId: widget.categoryId,
        levelNumber: effectiveLevelNumber,
        stars: stars,
        score: widget.totalScore,
        perfectScore: percentage >= 100,
        timeRemaining: 0,
      ),
    );

    if (!await _cancellableDelay(const Duration(milliseconds: 900)) ||
        !mounted) {
      return;
    }
    await _showNextAchievementPopup();
  }

  Future<void> _showNextAchievementPopup() async {
    if (!mounted) return;
    final achievement = AchievementService.instance.popNextPendingUnlock();
    if (achievement != null) {
      await AchievementPopup.show(context, achievement);
      if (!await _cancellableDelay(const Duration(milliseconds: 500)) ||
          !mounted) {
        return;
      }
      await _showNextAchievementPopup();
    }
  }

  Future<void> _captureAndShare() async {
    if (_isSharing) return;
    SoundService().playClick();
    setState(() => _isSharing = true);

    try {
      if (!await _cancellableDelay(const Duration(milliseconds: 100)) ||
          !mounted) {
        return;
      }
      final imageBytes = await _screenshotController.capture();
      if (imageBytes != null) {
        final text =
            'لقد حققت نتيجة ممتازة في مسابقة أحفاد الصحابة!\n'
            'النتيجة: ${widget.totalScore} نقطة\n'
            'حمل التطبيق وتحداني الآن!';
        await ShareService.shareImage(imageBytes, text);
      }
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء المشاركة')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  void dispose() {
    for (final timer in List<Timer>.from(_pendingTimers)) {
      timer.cancel();
    }
    _pendingTimers.clear();
    for (final completer
        in List<Completer<bool>>.from(_pendingDelayCompleters)) {
      if (!completer.isCompleted) completer.complete(false);
    }
    _pendingDelayCompleters.clear();
    _confettiController.dispose();
    _scoreController.dispose();
    _pulseController.dispose();
    _starsController.dispose();
    _starWobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final backgroundGradient = AppCustomTheme.of(context).backgroundGradient;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Screenshot(
          controller: _screenshotController,
          child: Container(
            decoration:
                _isSharing ? BoxDecoration(gradient: backgroundGradient) : null,
            child: Stack(
              children: [
                if (isPassed)
                  RepaintBoundary(
                    child: CelebrationConfettiOverlay(
                      animation: _confettiController,
                      particles: _particles,
                      screenSize: MediaQuery.of(context).size,
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: isSmallScreen ? 8 : 15,
                    ),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge(
                            [_scaleAnimation, _pulseAnimation],
                          ),
                          builder: (context, child) {
                            final pulseValue =
                                isPassed ? _pulseAnimation.value : 1.0;
                            return Transform.scale(
                              scale: _scaleAnimation.value * pulseValue,
                              child: child,
                            );
                          },
                          child: ResultTrophyIcon(
                            isPassed: isPassed,
                            isSmall: isSmallScreen,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 16),
                        FadeTransition(
                          opacity: _scoreController,
                          child: Text(
                            isPassed ? 'مبارك! 🏆' : 'حاول مرة أخرى 💪',
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: isSmallScreen ? 26 : 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        ResultStarsRow(
                          starsController: _starsController,
                          starWobbleController: _starWobbleController,
                          stars: stars,
                          isSmall: isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 20),
                        Expanded(
                          child: ResultSummaryCard(
                            scoreController: _scoreController,
                            scoreAnimation: _scoreAnimation,
                            pulseController: _pulseController,
                            correctAnswers: widget.correctAnswers,
                            totalQuestions: widget.totalQuestions,
                            totalScore: widget.totalScore,
                            categoryId: widget.categoryId,
                            currentLevelNumber: effectiveLevelNumber,
                            isPassed: isPassed,
                            isSmall: isSmallScreen,
                            userAnswers: widget.userAnswers,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 15),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 10,
                  left: MediaQuery.paddingOf(context).left + 16,
                  child: isPassed
                      ? ResultShareButton(
                          isSharing: _isSharing,
                          onTap: _captureAndShare,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
