import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/size_config.dart';
import '../../../widgets/particles/unified_particle_system.dart';

/// الشعار الرئيسي التفاعلي مع أشعة الشمس وجزيئات الذهب الطافية والنبض الحي
class HomeLogoWithEffects extends StatefulWidget {
  final double? customSize;

  const HomeLogoWithEffects({super.key, this.customSize});

  @override
  State<HomeLogoWithEffects> createState() => _HomeLogoWithEffectsState();
}

class _HomeLogoWithEffectsState extends State<HomeLogoWithEffects>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;

  // Interaction state
  double _scale = 1.0;
  double _intensity = 1.0;

  @override
  void initState() {
    super.initState();
    // Breathing/Pulse Animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Solar Rays Rotation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Particles Animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.95;
      _intensity = 2.0;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
      _intensity = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
      _intensity = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.customSize ?? getProportionateScreenWidth(130);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Solar Rays (Background)
              RotationTransition(
                turns: _rotationController,
                child: _SolarRays(size: size),
              ),

              // 2. Gold Particles (Falling/Floating)
              Positioned.fill(
                child: AmbientGoldParticles(animation: _particleController),
              ),

              // 3. Main Logo with Breathing Glow
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glowValue = _pulseController.value;
                  final double innerSize = size * 0.66;
                  return Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.goldGradient,
                      boxShadow: [
                        // Bloom/Glow Effect
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.4 * _intensity),
                          blurRadius: (30 + (20 * glowValue * _intensity)) * (size / 180),
                          spreadRadius: 5 + (10 * glowValue),
                        ),
                        // Inner "Hot" Glow
                        BoxShadow(
                          color: Colors.orangeAccent.withValues(alpha: 0.3 * _intensity),
                          blurRadius: 15,
                          spreadRadius: -2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: innerSize,
                          width: innerSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 4. Interaction Flash (Overlay)
              AnimatedOpacity(
                opacity: _intensity > 1.0 ? 0.3 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: size * 0.66,
                  height: size * 0.66,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolarRays extends StatelessWidget {
  final double size;
  const _SolarRays({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SolarRaysPainter(),
    );
  }
}

class _SolarRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withValues(alpha: 0.3), // Gold
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));

    // Draw background glow
    canvas.drawCircle(center, size.width / 2, paint);

    // Draw Rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * (math.pi / 180);
      final start = center;
      final end = Offset(
        center.dx + (size.width / 2) * math.cos(angle),
        center.dy + (size.height / 2) * math.sin(angle),
      );
      canvas.drawLine(start, end, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
