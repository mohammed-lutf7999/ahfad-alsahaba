import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../core/app_constants.dart';
import '../../core/sound_service.dart';
import '../../core/share_service.dart';
import '../../data/models/question_model.dart';
import '../../data/models/achievement_model.dart';
import '../../data/services/achievement_service.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/particles/unified_particle_system.dart';

class ResultScreen extends StatefulWidget {
  final int correctAnswers;
  final int totalQuestions;
  final int totalScore;
  final String categoryId;
  final String levelId;
  final List<Map<String, dynamic>>? userAnswers; // Optional for backward compatibility, but we will pass it.

  const ResultScreen({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.totalScore,
    required this.categoryId,
    required this.levelId,
    this.userAnswers,
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
  late AnimationController _starWobbleController; // For star rotation
  
  // Screenshot Controller
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  late Animation<double> _scoreAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  double get percentage => widget.correctAnswers / widget.totalQuestions * 100;
  bool get isPassed => percentage >= AppConstants.passingScore;
  int get stars {
    if (percentage >= 90) return 3;
    if (percentage >= 70) return 2;
    if (percentage >= 60) return 1;
    return 0;
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
    
    // Star wobble animation (continuous rotation)
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
      _particles.add(ConfettiParticle(
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
      ));
    }
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _scoreController.forward();
    
    await Future.delayed(const Duration(milliseconds: 300));
    _starsController.forward();
    
    if (isPassed) {
      _confettiController.repeat();
      _pulseController.repeat(reverse: true);
      _starWobbleController.repeat(reverse: true); // Start wobble
    }
    
    // Check achievements after animations start
    _checkAchievements();
  }
  
  // Check and display unlocked achievements
  Future<void> _checkAchievements() async {
    final levelNumber = int.tryParse(widget.levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    
    await AchievementService.instance.checkAchievements(
      AchievementEvent.levelCompleted(
        categoryId: widget.categoryId,
        levelNumber: levelNumber,
        stars: stars,
        score: widget.totalScore,
        perfectScore: percentage >= 100,
        timeRemaining: 0, // Not tracked here
      ),
    );
    
    // Show pending achievement popups
    await Future.delayed(const Duration(milliseconds: 1500));
    await _showNextAchievementPopup();
  }
  
  Future<void> _showNextAchievementPopup() async {
    if (!mounted) return;
    
    final achievement = AchievementService.instance.popNextPendingUnlock();
    if (achievement != null) {
      await AchievementPopup.show(context, achievement);
      // Show next one after a delay
      await Future.delayed(const Duration(milliseconds: 500));
      await _showNextAchievementPopup();
    }
  }

  @override
  void dispose() {
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

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.imperialGradient,
        ),
        child: Screenshot(
          controller: _screenshotController,
          child: Container(
            decoration: _isSharing 
              ? BoxDecoration(gradient: AppTheme.imperialGradient) 
              : null, // Ensure background is captured
            child: Stack(
              children: [
                // Confetti animation
                if (isPassed)
                  CelebrationConfettiOverlay(
                    animation: _confettiController,
                    particles: _particles,
                    screenSize: MediaQuery.of(context).size,
                  ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmallScreen ? 8 : 15),
                child: Column(
                  children: [
                    // Trophy Icon
                    AnimatedBuilder(
                      animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
                      builder: (context, child) {
                        final pulseValue = isPassed ? _pulseAnimation.value : 1.0;
                        return Transform.scale(
                          scale: _scaleAnimation.value * pulseValue,
                          child: child,
                        );
                      },
                      child: _buildTrophyIcon(isSmallScreen),
                    ),

                    SizedBox(height: isSmallScreen ? 10 : 16),

                    // Title
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

                    // Stars
                    _buildStars(isSmallScreen),

                    SizedBox(height: isSmallScreen ? 12 : 20),

                    // Results Card - Takes remaining space
                    Expanded(
                      child: _buildResultsCard(isSmallScreen),
                    ),

                    SizedBox(height: isSmallScreen ? 10 : 15),
                  ],
                ),
              ),
            ),
            
            // Share Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              child: isPassed ? _buildShareButton() : const SizedBox.shrink(),
            ),
          ],
      ),
    ),
  )));
}

Widget _buildShareButton() {
  return GestureDetector(
    onTap: _captureAndShare,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: _isSharing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
              ),
            )
          : const Icon(
              Icons.share_rounded,
              color: AppTheme.accentColor,
              size: 24,
            ),
    ),
  );
}

Future<void> _captureAndShare() async {
  if (_isSharing) return;

  SoundService().playClick();

  setState(() {
    _isSharing = true;
  });

  try {
    // Capture the screenshot
    // Note: We want to capture the background too, which is handled by wrapping the Container.
    // However, we might want to hide the Share button itself during capture? 
    // Usually it's fine to show it, or we can hide it.
    // Let's keep it simple for now.
    
    // Add a small delay to ensure UI updates if needed
    await Future.delayed(const Duration(milliseconds: 100));

    final imageBytes = await _screenshotController.capture();

    if (imageBytes != null) {
      final text = "لقد حققت نتيجة ممتازة في مسابقة أحفاد الصحابة!\n"
          "النتيجة: ${widget.totalScore} نقطة\n"
          "حمل التطبيق وتحداني الآن!";
      await ShareService.shareImage(imageBytes, text);
    }
  } catch (e) {
    debugPrint("Error capturing screenshot: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("حدث خطأ أثناء المشاركة")),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSharing = false;
      });
    }
  }
}

  Widget _buildTrophyIcon(bool isSmall) {
    final size = isSmall ? 85.0 : 100.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withAlpha(120),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(color: AppTheme.accentLight, width: 2.5),
      ),
      child: Icon(
        isPassed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
        size: isSmall ? 42 : 50,
        color: AppTheme.primaryDark,
      ),
    );
  }

  Widget _buildStars(bool isSmall) {
    return AnimatedBuilder(
      animation: Listenable.merge([_starsController, _starWobbleController]),
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final isActive = index < stars;
            final delay = index * 0.15;
            final progress = ((_starsController.value - delay) / (1 - delay)).clamp(0.0, 1.0);
            
            // Offset wobble phase for each star
            final starWobble = isActive ? math.sin((_starWobbleController.value + index * 0.2) * math.pi * 2) * 0.2 : 0.0;

            return Transform.scale(
              scale: isActive ? Curves.elasticOut.transform(progress) : 0.7,
              child: Transform.rotate(
                angle: isActive ? starWobble : 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: isActive ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ) : null,
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isActive
                            ? [AppTheme.accentLight, AppTheme.accentColor, AppTheme.accentDark]
                            : [Colors.white24, Colors.white12],
                      ).createShader(bounds);
                    },
                    child: Icon(
                      isActive ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.white,
                      size: isSmall ? 40 : 48,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildResultsCard(bool isSmall) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _scoreController,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.accentColor.withAlpha(80), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score Circle
            Flexible(
              flex: 3,
              child: _buildScoreCircle(isSmall),
            ),
            
            SizedBox(height: isSmall ? 12 : 18),

            // Divider
            Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppTheme.accentColor.withAlpha(100),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            SizedBox(height: isSmall ? 12 : 18),

            // Stats Row
            _buildStatsRow(isSmall),

            SizedBox(height: isSmall ? 16 : 22),

            // Buttons
            _buildButtons(isSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCircle(bool isSmall) {
    final circleSize = isSmall ? 110.0 : 130.0;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_scoreAnimation, _pulseController]),
      builder: (context, child) {
        final pulseScale = isPassed ? 1.0 + (_pulseController.value * 0.03) : 1.0;
        
        return Transform.scale(
          scale: pulseScale,
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryDark.withOpacity(0.3),
                    border: Border.all(
                      color: AppTheme.accentColor.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
                // Progress arc
                SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: CircularProgressIndicator(
                    value: _scoreAnimation.value / 100,
                    strokeWidth: isSmall ? 10 : 12,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPassed ? AppTheme.accentColor : Colors.redAccent,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isPassed 
                            ? [AppTheme.accentLight, AppTheme.accentColor, AppTheme.accentDark]
                            : [Colors.redAccent.shade100, Colors.redAccent],
                        ).createShader(bounds);
                      },
                      child: Text(
                        '${_scoreAnimation.value.toInt()}%',
                        style: TextStyle(
                          fontSize: isSmall ? 30 : 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    Text(
                      isPassed ? 'ممتاز!' : 'حاول مجدداً',
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 13,
                        color: isPassed ? AppTheme.accentColor : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(bool isSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('${widget.correctAnswers}', 'صحيحة', Icons.check_circle_rounded, Colors.green, isSmall),
        Container(width: 1, height: isSmall ? 35 : 45, color: AppTheme.accentColor.withAlpha(50)),
        _buildStatItem('${widget.totalScore}', 'النقاط', Icons.stars_rounded, AppTheme.accentColor, isSmall),
        Container(width: 1, height: isSmall ? 35 : 45, color: AppTheme.accentColor.withAlpha(50)),
        _buildStatItem('${widget.totalQuestions - widget.correctAnswers}', 'خاطئة', Icons.cancel_rounded, Colors.red, isSmall),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color, bool isSmall) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isSmall ? 20 : 24),
        SizedBox(height: isSmall ? 4 : 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 9 : 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(bool isSmall) {
    final currentLevelNumber = int.tryParse(widget.levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final nextLevelNumber = currentLevelNumber + 1;
    final nextLevelId = 'level_$nextLevelNumber';

    return Column(
      children: [
        if (widget.userAnswers != null && widget.userAnswers!.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                SoundService().playClick();
                _showReviewDialog();
              },
              icon: Icon(Icons.visibility_rounded, size: isSmall ? 18 : 20, color: AppTheme.accentColor),
              label: Text('مراجعة الإجابات', style: TextStyle(fontSize: isSmall ? 14 : 16, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppTheme.accentColor, width: 2),
                backgroundColor: AppTheme.accentColor.withOpacity(0.1),
              ),
            ),
          ),
          SizedBox(height: isSmall ? 10 : 15),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  SoundService().playClick();
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.levels,
                    arguments: {'categoryId': widget.categoryId},
                  );
                },
                icon: Icon(Icons.grid_view_rounded, size: isSmall ? 16 : 18, color: AppTheme.accentDark),
                label: Text('المستويات', style: TextStyle(fontSize: isSmall ? 12 : 13, color: AppTheme.accentDark)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: AppTheme.accentColor.withAlpha(150), width: 1.5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AppTheme.goldGradient,
                  boxShadow: [
                    BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    SoundService().playClick();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.quiz,
                      (route) => route.settings.name == AppRoutes.home,
                      arguments: {
                        'categoryId': widget.categoryId,
                        'levelId': isPassed ? nextLevelId : widget.levelId,
                        'levelNumber': isPassed ? nextLevelNumber : currentLevelNumber,
                      },
                    );
                  },
                  icon: Icon(isPassed ? Icons.arrow_forward_rounded : Icons.refresh_rounded, size: isSmall ? 16 : 18),
                  label: Text(isPassed ? 'المستوى التالي' : 'حاول مرة أخرى', style: TextStyle(fontSize: isSmall ? 10 : 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppTheme.primaryDark,
                    padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showReviewDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Review',
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              height: MediaQuery.of(context).size.height * 0.8,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryLight,
                    AppTheme.primaryColor,
                    AppTheme.primaryDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.accentColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(26),
                          topRight: Radius.circular(26),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDark.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: AppTheme.primaryDark, size: 22),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.rate_review_rounded, color: AppTheme.primaryDark, size: 24),
                              const SizedBox(width: 10),
                              const Text(
                                'مراجعة الإجابات',
                                style: TextStyle(
                                  color: AppTheme.primaryDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.userAnswers!.length,
                        itemBuilder: (context, index) {
                          final answerData = widget.userAnswers![index];
                          final Question question = answerData['question'] as Question;
                          final int selectedIndex = answerData['selectedOptionIndex'] as int;
                          final bool isCorrect = answerData['isCorrect'] as bool;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: isCorrect 
                            ? [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.05)]
                            : [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isCorrect ? Colors.greenAccent.withOpacity(0.6) : Colors.redAccent.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isCorrect ? Colors.green : Colors.red).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Question header with number badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            textDirection: TextDirection.rtl,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  question.questionText,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...List.generate(question.options.length, (optIndex) {
                            final bool isThisSelected = optIndex == selectedIndex;
                            final bool isThisCorrect = optIndex == question.correctAnswerIndex;
                            
                            Color optionColor = Colors.white.withAlpha(150);
                            IconData? icon;
                            
                            if (isThisCorrect) {
                              optionColor = Colors.greenAccent;
                              icon = Icons.check_circle_rounded;
                            } else if (isThisSelected && !isCorrect) {
                              optionColor = Colors.redAccent;
                              icon = Icons.cancel_rounded;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isThisSelected || isThisCorrect ? optionColor.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isThisSelected || isThisCorrect ? Border.all(color: optionColor.withOpacity(0.5)) : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      question.options[optIndex],
                                      textAlign: TextAlign.right,
                                      style: TextStyle(color: optionColor, fontWeight: isThisSelected || isThisCorrect ? FontWeight.bold : FontWeight.normal),
                                    ),
                                  ),
                                  if (icon != null) ...[
                                      const SizedBox(width: 8),
                                      Icon(icon, color: optionColor, size: 20),
                                  ]
                                ],
                              ),
                            );
                          }),
                          
                          if (!isCorrect && question.explanation != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                     Expanded(child: Text('توضيح: ${question.explanation}', textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.accentColor, fontSize: 13))),
                                     const SizedBox(width: 8),
                                     const Icon(Icons.lightbulb, color: AppTheme.accentColor, size: 16),
                                  ],
                                ),
                              )
                          ],
                          
                          // Share and Copy buttons
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Copy button
                              GestureDetector(
                                onTap: () {
                                  SoundService().playClick();
                                  final formattedText = _formatQuestionForSharing(question, isCorrect);
                                  Clipboard.setData(ClipboardData(text: formattedText));
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text('تم نسخ السؤال!', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.accentColor.withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.copy_rounded, color: AppTheme.accentColor, size: 18),
                                      SizedBox(width: 6),
                                      Text('نسخ', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Share button
                              GestureDetector(
                                onTap: () async {
                                  SoundService().playClick();
                                  final formattedText = _formatQuestionForSharing(question, isCorrect);
                                  await Share.share(formattedText);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.goldGradient,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.share_rounded, color: AppTheme.primaryDark, size: 18),
                                      SizedBox(width: 6),
                                      Text('مشاركة', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                      ),
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
  
  /// Formats a question with its options for sharing
  String _formatQuestionForSharing(Question question, bool userWasCorrect) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('📚 سؤال من معركة أحفاد الصحابة');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    
    // Question text
    buffer.writeln('❓ السؤال:');
    buffer.writeln(question.questionText);
    buffer.writeln();
    
    // Options with markers
    buffer.writeln('📝 الخيارات:');
    final optionLabels = ['أ', 'ب', 'ج', 'د'];
    for (int i = 0; i < question.options.length; i++) {
      final isCorrect = i == question.correctAnswerIndex;
      final marker = isCorrect ? '✅' : '⬜';
      final label = i < optionLabels.length ? optionLabels[i] : '${i + 1}';
      buffer.writeln('$marker $label) ${question.options[i]}');
    }
    buffer.writeln();
    
    // Correct answer
    buffer.writeln('✨ الإجابة الصحيحة: ${question.options[question.correctAnswerIndex]}');
    
    // Explanation if available
    if (question.explanation != null && question.explanation!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('💡 التوضيح: ${question.explanation}');
    }
    
    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🌟 حمّل التطبيق وتعلم معنا!');
    
    return buffer.toString();
  }
}
