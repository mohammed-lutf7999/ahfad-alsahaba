import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// زر الكؤوس المتوهج مع تأثيرات أشعة الدوران والاهتزاز الدوري وشارة الإشعارات
class HomeGlowingTrophyButton extends StatefulWidget {
  final bool hasNotification;
  final int notificationCount;
  final VoidCallback onTap;

  const HomeGlowingTrophyButton({
    required this.hasNotification,
    required this.notificationCount,
    required this.onTap,
    super.key,
  });

  @override
  State<HomeGlowingTrophyButton> createState() => _HomeGlowingTrophyButtonState();
}

class _HomeGlowingTrophyButtonState extends State<HomeGlowingTrophyButton>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _wobbleController;
  late AnimationController _raysController;

  late Animation<double> _glowAnimation;
  late Animation<double> _wobbleAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Glow pulse animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Wobble animation
    _wobbleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _wobbleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.05), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.03), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0), weight: 25),
    ]).animate(CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut));

    // Rays rotation
    _raysController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Start periodic wobble
    _startPeriodicWobble();
  }

  void _startPeriodicWobble() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _wobbleController.forward(from: 0).then((_) {
          _startPeriodicWobble();
        });
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _wobbleController.dispose();
    _raysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _wobbleAnimation, _raysController]),
      builder: (context, child) {
        return Transform.rotate(
          angle: _wobbleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating rays behind
                  Transform.rotate(
                    angle: _raysController.value * math.pi * 2,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.accentColor.withValues(alpha: 0.3 * _glowAnimation.value),
                            AppTheme.accentColor.withValues(alpha: 0.1 * _glowAnimation.value),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: CustomPaint(
                        painter: _TrophyRaysPainter(
                          color: AppTheme.accentColor.withValues(alpha: 0.5 * _glowAnimation.value),
                        ),
                      ),
                    ),
                  ),

                  // Glowing background
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentColor.withValues(alpha: 0.2),
                          AppTheme.accentColor.withValues(alpha: 0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.4 * _glowAnimation.value),
                          blurRadius: 12 * _glowAnimation.value,
                          spreadRadius: 2 * _glowAnimation.value,
                        ),
                      ],
                    ),
                  ),

                  // Trophy icon with scale
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: AppTheme.accentColor,
                      size: 26,
                      shadows: [
                        Shadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),

                  // Notification badge
                  if (widget.hasNotification)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          '${widget.notificationCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// رسام الأشعة للكأس
class _TrophyRaysPainter extends CustomPainter {
  final Color color;

  _TrophyRaysPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180;
      final innerRadius = size.width * 0.3;
      final outerRadius = size.width * 0.5;

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
  bool shouldRepaint(_TrophyRaysPainter oldDelegate) => oldDelegate.color != color;
}
