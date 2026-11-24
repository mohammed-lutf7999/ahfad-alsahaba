import 'dart:math' as math;
import 'package:flutter/material.dart';

class GoldParticle {
  final double angle;
  final double speed;
  final double radius;
  final double phaseOffset;
  final bool isStar;

  const GoldParticle({
    required this.angle,
    required this.speed,
    required this.radius,
    required this.phaseOffset,
    required this.isStar,
  });

  factory GoldParticle.random(math.Random rng) {
    return GoldParticle(
      angle: rng.nextDouble() * math.pi * 2,
      speed: 0.4 + rng.nextDouble() * 0.8,
      radius: 2.0 + rng.nextDouble() * 3.8,
      phaseOffset: rng.nextDouble(),
      isStar: rng.nextBool(),
    );
  }
}

class AndalusianParticlePainter extends CustomPainter {
  final List<GoldParticle> particles;
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  const AndalusianParticlePainter({
    required this.particles,
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final maxDist = size.shortestSide * 0.68;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final localT = (progress * p.speed + p.phaseOffset) % 1.0;
      final dist = 24.0 + localT * maxDist;
      final alpha = (1.0 - localT).clamp(0.0, 1.0);

      final pos = Offset(
        center.dx + dist * math.cos(p.angle),
        center.dy + dist * math.sin(p.angle) - (localT * 18.0),
      );

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = (i.isEven ? const Color(0xFFF3C644) : primaryColor)
            .withValues(alpha: alpha * 0.85);

      if (p.isStar) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(localT * math.pi);
        final r = p.radius;
        final starPath = Path()
          ..moveTo(0, -r * 1.4)
          ..lineTo(r * 0.45, -r * 0.45)
          ..lineTo(r * 1.4, 0)
          ..lineTo(r * 0.45, r * 0.45)
          ..lineTo(0, r * 1.4)
          ..lineTo(-r * 0.45, r * 0.45)
          ..lineTo(-r * 1.4, 0)
          ..lineTo(-r * 0.45, -r * 0.45)
          ..close();
        canvas.drawPath(starPath, paint);
        canvas.restore();
      } else {
        canvas.drawCircle(pos, p.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AndalusianParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
