import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'royal_frame_style.dart';

class RoyalAvatarFramePainter extends CustomPainter {
  final RoyalFrameStyle style;
  final double phase;
  final bool hasWinStreakAura;

  const RoyalAvatarFramePainter({
    required this.style,
    required this.phase,
    required this.hasWinStreakAura,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) * 0.90;
    final strokeWidth = size.shortestSide * style.strokeRatio;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = style.secondaryColor;
    canvas.drawCircle(center, radius, basePaint);

    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, strokeWidth * 0.24)
      ..color = style.highlightColor.withValues(alpha: 0.85);
    canvas.drawCircle(center, radius - strokeWidth * 0.44, innerRimPaint);

    if (style.hasOctagonalStar) {
      final starPoints = style.tierIndex >= 10 ? 16 : 8;
      final starPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, strokeWidth * 0.22)
        ..strokeJoin = StrokeJoin.round
        ..color = style.highlightColor.withValues(alpha: 0.75);

      final path = Path();
      final outerR = radius + strokeWidth * 0.36;
      final innerR = radius - strokeWidth * 0.18;
      final rotationOffset =
          style.tierIndex >= 9 ? phase * math.pi * 0.25 : 0.0;

      for (int i = 0; i < starPoints * 2; i++) {
        final r = i.isEven ? outerR : innerR;
        final angle =
            rotationOffset + (i * math.pi / starPoints) - (math.pi / 2);
        final pt = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, starPaint);
    }

    if (style.hasCornerGems) {
      final gemCount = style.tierIndex >= 8 ? 8 : 4;
      final gemRadius = math.max(1.8, strokeWidth * 0.34);
      final gemFill = Paint()
        ..style = PaintingStyle.fill
        ..color = style.highlightColor;
      final gemBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, strokeWidth * 0.16)
        ..color = style.primaryColor;

      for (int i = 0; i < gemCount; i++) {
        final angle = (i * 2 * math.pi / gemCount) - (math.pi / 2);
        final gemCenter = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        canvas.drawCircle(gemCenter, gemRadius, gemFill);
        canvas.drawCircle(gemCenter, gemRadius, gemBorder);
      }
    }

    if (style.hasCrownCrest && size.shortestSide >= 36) {
      final crestY = center.dy - radius - strokeWidth * 0.22;
      final crestW = strokeWidth * 1.45;
      final crestH = strokeWidth * 0.95;

      final crownPath = Path()
        ..moveTo(center.dx - crestW, crestY + crestH * 0.45)
        ..lineTo(center.dx - crestW * 0.72, crestY - crestH * 0.45)
        ..lineTo(center.dx - crestW * 0.30, crestY + crestH * 0.12)
        ..lineTo(center.dx, crestY - crestH * 0.88)
        ..lineTo(center.dx + crestW * 0.30, crestY + crestH * 0.12)
        ..lineTo(center.dx + crestW * 0.72, crestY - crestH * 0.45)
        ..lineTo(center.dx + crestW, crestY + crestH * 0.45)
        ..close();

      final crownFill = Paint()
        ..style = PaintingStyle.fill
        ..color = style.highlightColor;
      final crownStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, strokeWidth * 0.18)
        ..strokeJoin = StrokeJoin.round
        ..color = style.primaryColor;

      canvas.drawPath(crownPath, crownFill);
      canvas.drawPath(crownPath, crownStroke);
    }
  }

  @override
  bool shouldRepaint(covariant RoyalAvatarFramePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.style.frameKey != style.frameKey ||
        oldDelegate.hasWinStreakAura != hasWinStreakAura;
  }
}
