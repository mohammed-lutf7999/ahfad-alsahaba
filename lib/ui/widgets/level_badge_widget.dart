import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/player_level_model.dart';

/// Displays the player's Level (`1..100`), Historical Title, and Tier Icon
/// in an Andalusian octagonal star emblem & royal pill.
///
/// Supports:
/// - `isCompact: true` for Leaderboard rows & compact headers.
/// - `isCompact: false` for Home Screen, Profile & Glory Road headers.
class LevelBadgeWidget extends StatelessWidget {
  final PlayerLevelInfo? levelInfo;
  final int level;
  final String? customTitle;
  final bool isCompact;
  final bool showTitle;
  final VoidCallback? onTap;

  const LevelBadgeWidget({
    super.key,
    this.levelInfo,
    this.level = 1,
    this.customTitle,
    this.isCompact = false,
    this.showTitle = true,
    this.onTap,
  });

  /// Resolves [LevelTierDefinition] and display attributes whether [levelInfo] or [level] was passed.
  ({
    int level,
    String title,
    Color primaryColor,
    Color secondaryColor,
    IconData icon,
  }) _resolveData() {
    if (levelInfo != null) {
      return (
        level: levelInfo!.level,
        title: customTitle ?? levelInfo!.title,
        primaryColor: levelInfo!.badgeColor,
        secondaryColor: levelInfo!.secondaryColor,
        icon: levelInfo!.tierIcon,
      );
    }
    final clamped = level.clamp(1, PlayerLevelInfo.maxLevel);
    final tier = PlayerLevelInfo.resolveTier(clamped);
    return (
      level: clamped,
      title: customTitle ?? tier.title,
      primaryColor: tier.primaryColor,
      secondaryColor: tier.secondaryColor,
      icon: tier.icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _resolveData();

    final content = isCompact
        ? _buildCompactBadge(data)
        : _buildFullBadge(data);

    return RepaintBoundary(
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: content,
              ),
            )
          : content,
    );
  }

  Widget _buildCompactBadge(
    ({
      int level,
      String title,
      Color primaryColor,
      Color secondaryColor,
      IconData icon,
    }) data,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            data.primaryColor.withValues(alpha: 0.88),
            data.secondaryColor.withValues(alpha: 0.72),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: data.secondaryColor.withValues(alpha: 0.9),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: data.primaryColor.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'م.${data.level}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                height: 1.2,
              ),
            ),
          ),
          if (showTitle) ...[
            const SizedBox(width: 5),
            Icon(
              data.icon,
              size: 12,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullBadge(
    ({
      int level,
      String title,
      Color primaryColor,
      Color secondaryColor,
      IconData icon,
    }) data,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A192F).withValues(alpha: 0.92),
            data.primaryColor.withValues(alpha: 0.45),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: data.secondaryColor.withValues(alpha: 0.85),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: data.secondaryColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Andalusian 8-Pointed Star Level Emblem
          SizedBox(
            width: 30,
            height: 30,
            child: CustomPaint(
              painter: _AndalusianStarEmblemPainter(
                primaryColor: data.primaryColor,
                secondaryColor: data.secondaryColor,
              ),
              child: Center(
                child: Text(
                  '${data.level}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
          if (showTitle) ...[
            const SizedBox(width: 8),
            Icon(
              data.icon,
              size: 15,
              color: data.secondaryColor,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'المستوى ${data.level}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: data.secondaryColor.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _AndalusianStarEmblemPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _AndalusianStarEmblemPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide * 0.48;
    final innerR = size.shortestSide * 0.37;
    const points = 8;

    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / points) - (math.pi / 2);
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

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [secondaryColor, primaryColor],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.85);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _AndalusianStarEmblemPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
