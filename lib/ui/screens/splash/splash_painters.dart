import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashPalette {
  static const Color imperialGold = Color(0xFFD4AF37);
  static const Color lightGold = Color(0xFFF5D76E);
  static const Color darkGold = Color(0xFFB8960C);
}

class Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final y = (particle.y + progress * particle.speed) % 1.0;
      _paint.color = SplashPalette.imperialGold
          .withAlpha((particle.opacity * 255).toInt());

      canvas.drawCircle(
        Offset(particle.x * size.width, y * size.height),
        particle.size,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class IslamicPatternPainter extends CustomPainter {
  final Color color;

  IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        paint,
      );
    }

    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * i / 5, paint);
    }

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 8;
      final point = Offset(
        center.dx + math.cos(angle) * radius * 0.9,
        center.dy + math.sin(angle) * radius * 0.9,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(IslamicPatternPainter oldDelegate) => false;
}

class CornerOrnamentPainter extends CustomPainter {
  final Color color;

  CornerOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(0, 0, size.width * 0.8, 0);
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(0, 0, size.width * 0.6, 0);
    path.moveTo(0, size.height * 0.4);
    path.quadraticBezierTo(0, 0, size.width * 0.4, 0);
    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(0, 0, size.width * 0.2, 0);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = color.withAlpha(100)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.12), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.08), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.22), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 0.35), 2, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.05), 2, dotPaint);
  }

  @override
  bool shouldRepaint(CornerOrnamentPainter oldDelegate) => false;
}
