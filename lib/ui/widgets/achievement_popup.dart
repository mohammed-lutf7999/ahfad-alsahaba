import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../data/models/achievement_model.dart';
import '../../data/services/achievement_service.dart';

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

  /// عرض نافذة الإنجاز
  static Future<void> show(BuildContext context, Achievement achievement) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Achievement',
      barrierColor: Colors.black.withOpacity(0.85),
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
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.elasticOut,
            ),
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
  
  final List<_ConfettiPiece> _confetti = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    
    // Play sound
    SoundService().playLevelComplete();
    
    // Continuous glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    // Bounce in animation
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    
    // Icon scale with bounce
    _iconScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));
    
    // Confetti animation
    _confettiController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    // Rotation for decorative elements
    _rotateController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    // Pulse animation for button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Initialize confetti
    _initConfetti();
    
    // Start bounce animation
    _bounceController.forward();
  }

  void _initConfetti() {
    for (int i = 0; i < 50; i++) {
      _confetti.add(_ConfettiPiece(
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
      ));
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
        return const Color(0xFFCD7F32); // Bronze
      case AchievementRarity.rare:
        return const Color(0xFFC0C0C0); // Silver
      case AchievementRarity.epic:
        return AppTheme.accentColor; // Gold
      case AchievementRarity.legendary:
        return const Color(0xFF00D4FF); // Diamond Blue
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
          // Confetti layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                size: screenSize,
                painter: _ConfettiPainter(
                  particles: _confetti,
                  progress: _confettiController.value,
                ),
              );
            },
          ),
          
          // Main popup
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _glowAnimation, 
                _bounceAnimation, 
                _iconScaleAnimation,
                _rotateController,
                _pulseAnimation,
              ]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _bounceAnimation.value,
                  child: Container(
                    width: 320,
                    margin: const EdgeInsets.all(20),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        // Rotating rays behind
                        Positioned(
                          top: -30,
                          child: Transform.rotate(
                            angle: _rotateController.value * math.pi * 2,
                            child: CustomPaint(
                              size: const Size(200, 200),
                              painter: _RaysPainter(color: _rarityColor),
                            ),
                          ),
                        ),
                        
                        // Main card
                        Container(
                          margin: const EdgeInsets.only(top: 50),
                          padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.primaryLight.withOpacity(0.95),
                                AppTheme.primaryColor,
                                AppTheme.primaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: _rarityColor,
                              width: 3,
                            ),
                            boxShadow: [
                              // Outer glow
                              BoxShadow(
                                color: _rarityColor.withOpacity(0.4 * _glowAnimation.value),
                                blurRadius: 40 * _glowAnimation.value,
                                spreadRadius: 15 * _glowAnimation.value,
                              ),
                              // Inner shadow
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Sparkle header
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    _raritySecondaryColor,
                                    Colors.white,
                                    _rarityColor,
                                    Colors.white,
                                    _raritySecondaryColor,
                                  ],
                                  stops: [
                                    0.0,
                                    0.25 + (_glowAnimation.value * 0.1),
                                    0.5,
                                    0.75 - (_glowAnimation.value * 0.1),
                                    1.0,
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  '✨ إنجـــاز جديــد! ✨',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Cairo',
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Rarity badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _rarityColor.withOpacity(0.3),
                                      _raritySecondaryColor.withOpacity(0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: _rarityColor.withOpacity(0.6),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _rarityColor.withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _rarityName,
                                  style: TextStyle(
                                    color: _rarityColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Title with gradient
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.white, _raritySecondaryColor],
                                ).createShader(bounds),
                                child: Text(
                                  widget.achievement.title,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Cairo',
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Decorative divider
                              Container(
                                width: 80,
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      _rarityColor,
                                      Colors.transparent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Description
                              Text(
                                widget.achievement.description,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.85),
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 28),
                              
                              // Animated button
                              Transform.scale(
                                scale: _pulseAnimation.value,
                                child: GestureDetector(
                                  onTap: () {
                                    SoundService().playClick();
                                    widget.onDismiss();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          _raritySecondaryColor,
                                          _rarityColor,
                                          _rarityColor.withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _rarityColor.withOpacity(0.5),
                                          blurRadius: 15,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.1),
                                          blurRadius: 5,
                                          spreadRadius: -2,
                                          offset: const Offset(0, -2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'رائـــع!',
                                          style: TextStyle(
                                            color: widget.achievement.rarity == AchievementRarity.legendary 
                                                ? Colors.black 
                                                : AppTheme.primaryDark,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            fontFamily: 'Cairo',
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text('🎉', style: TextStyle(fontSize: 24)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Floating icon
                        Positioned(
                          top: 0,
                          child: Transform.scale(
                            scale: _iconScaleAnimation.value,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _raritySecondaryColor,
                                    _rarityColor,
                                    _rarityColor.withOpacity(0.8),
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _rarityColor.withOpacity(0.6 * _glowAnimation.value),
                                    blurRadius: 25,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  widget.achievement.icon,
                                  style: const TextStyle(fontSize: 55),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Confetti Painter
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final y = ((p.y + progress * p.speed * 3) % 1.3) * size.height;
      final x = p.x * size.width + math.sin(progress * math.pi * 4 + p.rotation) * 30;
      final rotation = p.rotation + progress * p.rotationSpeed * math.pi * 4;
      
      final opacity = y < size.height * 0.1 
          ? y / (size.height * 0.1)
          : y > size.height * 0.9 
              ? (size.height - y) / (size.height * 0.1)
              : 1.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      switch (p.shape) {
        case 0: // Circle
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case 1: // Square
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            paint,
          );
          break;
        case 2: // Star shape
          final path = Path();
          for (int i = 0; i < 5; i++) {
            final angle = (i * 144 - 90) * math.pi / 180;
            final point = Offset(
              math.cos(angle) * p.size / 2,
              math.sin(angle) * p.size / 2,
            );
            if (i == 0) {
              path.moveTo(point.dx, point.dy);
            } else {
              path.lineTo(point.dx, point.dy);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}

// Rays Painter
class _RaysPainter extends CustomPainter {
  final Color color;

  _RaysPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final innerRadius = size.width * 0.25;
      final outerRadius = size.width * 0.5;
      
      paint.shader = RadialGradient(
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));

      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * innerRadius,
          center.dy + math.sin(angle) * innerRadius,
        ),
        Offset(
          center.dx + math.cos(angle) * outerRadius,
          center.dy + math.sin(angle) * outerRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}

class _ConfettiPiece {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final Color color;
  final int shape;

  _ConfettiPiece({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.shape,
  });
}
