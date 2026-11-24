import 'dart:math' as math;
import 'package:flutter/material.dart';

class AchievementConfettiPiece {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final Color color;
  final int shape;

  const AchievementConfettiPiece({
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

class AchievementConfettiPainter extends CustomPainter {
  final List<AchievementConfettiPiece> particles;
  final double progress;
  final Paint _paint = Paint()..style = PaintingStyle.fill;
  final Path _starPath = Path();

  AchievementConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = ((p.y + progress * p.speed * 3) % 1.3) * size.height;
      final x =
          p.x * size.width + math.sin(progress * math.pi * 4 + p.rotation) * 30;
      final rotation = p.rotation + progress * p.rotationSpeed * math.pi * 4;

      final opacity = y < size.height * 0.1
          ? y / (size.height * 0.1)
          : y > size.height * 0.9
              ? (size.height - y) / (size.height * 0.1)
              : 1.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      _paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      switch (p.shape) {
        case 0:
          canvas.drawCircle(Offset.zero, p.size / 2, _paint);
          break;
        case 1:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            _paint,
          );
          break;
        case 2:
          _starPath.reset();
          for (int i = 0; i < 5; i++) {
            final angle = (i * 144 - 90) * math.pi / 180;
            final point = Offset(
              math.cos(angle) * p.size / 2,
              math.sin(angle) * p.size / 2,
            );
            if (i == 0) {
              _starPath.moveTo(point.dx, point.dy);
            } else {
              _starPath.lineTo(point.dx, point.dy);
            }
          }
          _starPath.close();
          canvas.drawPath(_starPath, _paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(AchievementConfettiPainter oldDelegate) => true;
}

class AchievementRaysPainter extends CustomPainter {
  final Color color;

  const AchievementRaysPainter({required this.color});

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
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.0),
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
  bool shouldRepaint(AchievementRaysPainter oldDelegate) => false;
}
