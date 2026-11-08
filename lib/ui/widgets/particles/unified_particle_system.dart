import 'dart:math' as math;
import 'package:flutter/material.dart';

/// نظام جزيئات الذهب الطافية والمتساقطة في الخلفية
/// مخصص للواجهات الرئيسية ومحاط بـ RepaintBoundary للحفاظ على أداء 60/120fps.
class AmbientGoldParticles extends StatelessWidget {
  final Animation<double> animation;
  final Color particleColor;
  final int count;

  const AmbientGoldParticles({
    super.key,
    required this.animation,
    this.particleColor = const Color(0xFFFFD700),
    this.count = 20,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _AmbientParticlePainter(
              progress: animation.value,
              color: particleColor,
              count: count,
            ),
          );
        },
      ),
    );
  }
}

class _AmbientParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  final int count;

  _AmbientParticlePainter({
    required this.progress,
    required this.color,
    required this.count,
  });

  // بذور عشوائية ثابتة للجزيئات (x, y, speed, size)
  static final List<List<double>> _cachedParticles = List.generate(40, (index) {
    final r = math.Random(index);
    return [
      r.nextDouble(), // x (0.0 .. 1.0)
      r.nextDouble(), // y (0.0 .. 1.0)
      r.nextDouble() * 0.5 + 0.5, // speed
      r.nextDouble() * 3 + 1, // size
    ];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final particlesToDraw = _cachedParticles.take(count);

    for (var p in particlesToDraw) {
      final x = p[0] * size.width;
      // y يتحرك للأسفل مع التقدم
      final double y = (p[1] + progress) % 1.0 * size.height;
      // تلاشي ناعم عند الحواف العلوية والسفلية
      final opacity = (1.0 - ((y - size.height / 2).abs() / (size.height / 2))).clamp(0.0, 1.0);

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), p[3], paint);
    }
  }

  @override
  bool shouldRepaint(_AmbientParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// جسيم النثار الاحتفالي المتطاير
class ConfettiParticle {
  double x;
  double y;
  double speed;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;
  int shape; // 0: circle, 1: rectangle, 2: star

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
  });

  /// إنشاء مجموعة عشوائية احتفالية
  static List<ConfettiParticle> generateRandom({int count = 60, List<Color>? colors}) {
    final rng = math.Random();
    final defaultColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFF6B6B), // Coral
      const Color(0xFF4ECDC4), // Teal
      const Color(0xFF45B7D1), // Sky
      const Color(0xFF96CEB4), // Sage
      const Color(0xFFFFEEAD), // Cream
      const Color(0xFFD4A5A5), // Rose
      const Color(0xFF9B59B6), // Purple
    ];
    final palette = colors ?? defaultColors;

    return List.generate(count, (_) {
      return ConfettiParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble() * -0.5,
        speed: rng.nextDouble() * 0.4 + 0.2,
        size: rng.nextDouble() * 8 + 4,
        color: palette[rng.nextInt(palette.length)],
        rotation: rng.nextDouble() * math.pi * 2,
        rotationSpeed: (rng.nextDouble() - 0.5) * 2,
        shape: rng.nextInt(3),
      );
    });
  }
}

/// رسام النثار الاحتفالي الموحد
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;
  final Size screenSize;

  ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final x = p.x * screenSize.width;
      final y = (p.y + progress * p.speed * 3) % 1.2 * screenSize.height - screenSize.height * 0.1;
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * p.rotationSpeed * math.pi * 4);

      if (p.shape == 0) {
        // Circle
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else if (p.shape == 1) {
        // Rectangle
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      } else {
        // Star
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final a = (i * 4 * math.pi / 5) - math.pi / 2;
          if (i == 0) {
            path.moveTo(math.cos(a) * p.size / 2, math.sin(a) * p.size / 2);
          } else {
            path.lineTo(math.cos(a) * p.size / 2, math.sin(a) * p.size / 2);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}

/// ودجت نثار احتفالي كامل مع RepaintBoundary جاهز للاستخدام الفوري
class CelebrationConfettiOverlay extends StatelessWidget {
  final Animation<double> animation;
  final List<ConfettiParticle> particles;
  final Size screenSize;

  const CelebrationConfettiOverlay({
    super.key,
    required this.animation,
    required this.particles,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: ConfettiPainter(
              particles: particles,
              progress: animation.value,
              screenSize: screenSize,
            ),
          );
        },
      ),
    );
  }
}
