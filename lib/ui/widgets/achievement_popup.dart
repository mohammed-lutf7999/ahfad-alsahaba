import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../data/models/achievement_model.dart';
import '../../data/services/achievement_service.dart';
import 'achievement_popup_card.dart';
import 'achievement_popup_painters.dart';

/// نافذة منبثقة فاخرة لعرض إنجاز جديد
class AchievementPopup extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismiss;

  const AchievementPopup({
    super.key,
    required this.achievement,
    required this.onDismiss,
  });

  @override
  State<AchievementPopup> createState() => _AchievementPopupState();

  static Future<void> show(
    BuildContext context,
    Achievement achievement,
  ) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Achievement',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (ctx, anim1, anim2) {
        return AchievementPopup(
          achievement: achievement,
          onDismiss: () {
            Navigator.of(ctx).pop();
            AchievementService.instance.markAsSeen(achievement.id);
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
            child: child,
          ),
        );
      },
    );
  }
}

class _AchievementPopupState extends State<AchievementPopup>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _bounceController;
  late AnimationController _confettiController;
  late AnimationController _rotateController;
  late AnimationController _pulseController;

  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _pulseAnimation;

  final List<AchievementConfettiPiece> _confetti = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    SoundService().playLevelComplete();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _iconScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 40),
    ]).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );

    _confettiController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _rotateController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initConfetti();
    _bounceController.forward();
  }

  void _initConfetti() {
    for (int i = 0; i < 50; i++) {
      _confetti.add(
        AchievementConfettiPiece(
          x: _random.nextDouble(),
          y: _random.nextDouble() * -1,
          speed: _random.nextDouble() * 0.4 + 0.2,
          size: _random.nextDouble() * 8 + 4,
          rotation: _random.nextDouble() * math.pi * 2,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
          color: [
            _rarityColor,
            _raritySecondaryColor,
            Colors.white,
            AppTheme.accentColor,
            AppTheme.accentLight,
          ][_random.nextInt(5)],
          shape: _random.nextInt(3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _bounceController.dispose();
    _confettiController.dispose();
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color get _rarityColor {
    switch (widget.achievement.rarity) {
      case AchievementRarity.common:
        return const Color(0xFFCD7F32);
      case AchievementRarity.rare:
        return const Color(0xFFC0C0C0);
      case AchievementRarity.epic:
        return AppTheme.accentColor;
      case AchievementRarity.legendary:
        return const Color(0xFF00D4FF);
    }
  }

  Color get _raritySecondaryColor {
    switch (widget.achievement.rarity) {
      case AchievementRarity.common:
        return const Color(0xFFB87333);
      case AchievementRarity.rare:
        return const Color(0xFFE8E8E8);
      case AchievementRarity.epic:
        return AppTheme.accentLight;
      case AchievementRarity.legendary:
        return const Color(0xFF7DF9FF);
    }
  }

  String get _rarityName {
    switch (widget.achievement.rarity) {
      case AchievementRarity.common:
        return '🥉 شائع';
      case AchievementRarity.rare:
        return '🥈 نادر';
      case AchievementRarity.epic:
        return '🥇 ملحمي';
      case AchievementRarity.legendary:
        return '💎 أسطوري';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return CustomPaint(
                  size: screenSize,
                  painter: AchievementConfettiPainter(
                    particles: _confetti,
                    progress: _confettiController.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _glowAnimation,
                      _bounceAnimation,
                      _iconScaleAnimation,
                      _rotateController,
                      _pulseAnimation,
                    ]),
                    builder: (context, child) {
                      return AchievementPopupCard(
                        achievement: widget.achievement,
                        rarityColor: _rarityColor,
                        raritySecondaryColor: _raritySecondaryColor,
                        rarityName: _rarityName,
                        glowValue: _glowAnimation.value,
                        bounceValue: _bounceAnimation.value,
                        iconScaleValue: _iconScaleAnimation.value,
                        rotateValue: _rotateController.value,
                        pulseValue: _pulseAnimation.value,
                        onDismiss: widget.onDismiss,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
