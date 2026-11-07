import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/player_level_model.dart';

/// Visual specification for each of the 10 Royal Avatar Frames (`frame_wood` .. `frame_diamond`).
class RoyalFrameStyle {
  final String frameKey;
  final String name;
  final int tierIndex; // 1..10
  final Color primaryColor;
  final Color secondaryColor;
  final Color highlightColor;
  final bool hasOctagonalStar;
  final bool hasCornerGems;
  final bool hasCrownCrest;
  final double strokeRatio;

  const RoyalFrameStyle({
    required this.frameKey,
    required this.name,
    required this.tierIndex,
    required this.primaryColor,
    required this.secondaryColor,
    required this.highlightColor,
    this.hasOctagonalStar = false,
    this.hasCornerGems = false,
    this.hasCrownCrest = false,
    this.strokeRatio = 0.085,
  });

  static const Map<String, RoyalFrameStyle> styles = {
    'frame_wood': RoyalFrameStyle(
      frameKey: 'frame_wood',
      name: 'الإطار الخشبي العتيق',
      tierIndex: 1,
      primaryColor: Color(0xFF78350F),
      secondaryColor: Color(0xFFB45309),
      highlightColor: Color(0xFFFDE68A),
      strokeRatio: 0.075,
    ),
    'frame_copper': RoyalFrameStyle(
      frameKey: 'frame_copper',
      name: 'الإطار النحاسي المنقوش',
      tierIndex: 2,
      primaryColor: Color(0xFF9A3412),
      secondaryColor: Color(0xFFD97706),
      highlightColor: Color(0xFFFED7AA),
      hasCornerGems: true,
      strokeRatio: 0.08,
    ),
    'frame_bronze': RoyalFrameStyle(
      frameKey: 'frame_bronze',
      name: 'الإطار البرونزي المذهب',
      tierIndex: 3,
      primaryColor: Color(0xFF92400E),
      secondaryColor: Color(0xFFF59E0B),
      highlightColor: Color(0xFFFEF3C7),
      hasOctagonalStar: true,
      strokeRatio: 0.085,
    ),
    'frame_silver': RoyalFrameStyle(
      frameKey: 'frame_silver',
      name: 'الإطار الفضي الدمشقي',
      tierIndex: 4,
      primaryColor: Color(0xFF475569),
      secondaryColor: Color(0xFFCBD5E1),
      highlightColor: Color(0xFFFFFFFF),
      hasOctagonalStar: true,
      hasCornerGems: true,
      strokeRatio: 0.088,
    ),
    'frame_gold': RoyalFrameStyle(
      frameKey: 'frame_gold',
      name: 'الإطار الذهبي الموحد',
      tierIndex: 5,
      primaryColor: Color(0xFFB45309),
      secondaryColor: Color(0xFFF3C644),
      highlightColor: Color(0xFFFFFBEB),
      hasOctagonalStar: true,
      hasCornerGems: true,
      strokeRatio: 0.092,
    ),
    'frame_emerald': RoyalFrameStyle(
      frameKey: 'frame_emerald',
      name: 'الإطار الزمردي الملكي',
      tierIndex: 6,
      primaryColor: Color(0xFF065F46),
      secondaryColor: Color(0xFF10B981),
      highlightColor: Color(0xFFA7F3D0),
      hasOctagonalStar: true,
      hasCornerGems: true,
      strokeRatio: 0.095,
    ),
    'frame_ruby': RoyalFrameStyle(
      frameKey: 'frame_ruby',
      name: 'الإطار الياقوتي المشرق',
      tierIndex: 7,
      primaryColor: Color(0xFF9F1239),
      secondaryColor: Color(0xFFF43F5E),
      highlightColor: Color(0xFFFECDD3),
      hasOctagonalStar: true,
      hasCornerGems: true,
      hasCrownCrest: true,
      strokeRatio: 0.098,
    ),
    'frame_sapphire': RoyalFrameStyle(
      frameKey: 'frame_sapphire',
      name: 'الإطار اللازوردي السلطاني',
      tierIndex: 8,
      primaryColor: Color(0xFF1E40AF),
      secondaryColor: Color(0xFF38BDF8),
      highlightColor: Color(0xFFE0F2FE),
      hasOctagonalStar: true,
      hasCornerGems: true,
      hasCrownCrest: true,
      strokeRatio: 0.10,
    ),
    'frame_platinum': RoyalFrameStyle(
      frameKey: 'frame_platinum',
      name: 'الإطار البلاتيني المتوهج',
      tierIndex: 9,
      primaryColor: Color(0xFF5B21B6),
      secondaryColor: Color(0xFFC084FC),
      highlightColor: Color(0xFFFAF5FF),
      hasOctagonalStar: true,
      hasCornerGems: true,
      hasCrownCrest: true,
      strokeRatio: 0.105,
    ),
    'frame_diamond': RoyalFrameStyle(
      frameKey: 'frame_diamond',
      name: 'الإطار الماسي الأندلسي المشع',
      tierIndex: 10,
      primaryColor: Color(0xFF0284C7),
      secondaryColor: Color(0xFF38BDF8),
      highlightColor: Color(0xFFFFFFFF),
      hasOctagonalStar: true,
      hasCornerGems: true,
      hasCrownCrest: true,
      strokeRatio: 0.11,
    ),
  };

  /// Resolves a [RoyalFrameStyle] from [frameKey] or [level] (1..100).
  static RoyalFrameStyle resolve({String? frameKey, int? level}) {
    if (frameKey != null && styles.containsKey(frameKey)) {
      return styles[frameKey]!;
    }
    if (level != null) {
      final tier = PlayerLevelInfo.resolveTier(level);
      if (styles.containsKey(tier.frameKey)) {
        return styles[tier.frameKey]!;
      }
    }
    return styles['frame_wood']!;
  }
}

/// Procedural Royal Avatar Frame with Andalusian geometry, `ShaderMask` metallic sweep,
/// and Win Streak Aura (`winStreak >= 3`).
/// Wrapped in a [RepaintBoundary] for 60/120fps performance.
class AnimatedAvatarFrame extends StatefulWidget {
  final Widget child;
  final double size;
  final String? frameKey;
  final int? level;
  final int winStreak;
  final bool animate;
  final bool showStreakBadge;

  const AnimatedAvatarFrame({
    super.key,
    required this.child,
    this.size = 64.0,
    this.frameKey,
    this.level,
    this.winStreak = 0,
    this.animate = true,
    this.showStreakBadge = true,
  });

  @override
  State<AnimatedAvatarFrame> createState() => _AnimatedAvatarFrameState();
}

class _AnimatedAvatarFrameState extends State<AnimatedAvatarFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedAvatarFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = RoyalFrameStyle.resolve(
      frameKey: widget.frameKey,
      level: widget.level,
    );
    final hasWinStreakAura = widget.winStreak >= 3;
    final outerSize = widget.size;
    final avatarSize = outerSize * (1.0 - style.strokeRatio * 2.15);

    return RepaintBoundary(
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, cachedAvatar) {
            final phase = _controller.value;
            final pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. Win Streak Glowing Aura (when winStreak >= 3)
                if (hasWinStreakAura)
                  Container(
                    width: outerSize * (1.04 + 0.05 * pulse),
                    height: outerSize * (1.04 + 0.05 * pulse),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.35 + 0.25 * pulse),
                          blurRadius: outerSize * 0.22,
                          spreadRadius: outerSize * 0.04,
                        ),
                        BoxShadow(
                          color: const Color(0xFFF43F5E)
                              .withValues(alpha: 0.22 + 0.18 * pulse),
                          blurRadius: outerSize * 0.32,
                          spreadRadius: outerSize * 0.02,
                        ),
                      ],
                    ),
                  ),

                // 2. Ambient Tier Glow for Gold+ frames (Tier >= 5)
                if (style.tierIndex >= 5)
                  Container(
                    width: outerSize * 0.94,
                    height: outerSize * 0.94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: style.secondaryColor
                              .withValues(alpha: 0.22 + 0.16 * pulse),
                          blurRadius: outerSize * 0.18,
                          spreadRadius: outerSize * 0.02,
                        ),
                      ],
                    ),
                  ),

                // 3. Inner Clipped Avatar Child
                SizedBox(
                  width: avatarSize,
                  height: avatarSize,
                  child: ClipOval(
                    child: cachedAvatar,
                  ),
                ),

                // 4. Procedural Andalusian Frame with ShaderMask Sweep
                ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (bounds) {
                    final angle = phase * math.pi * 2;
                    return SweepGradient(
                      center: Alignment.center,
                      transform: GradientRotation(angle),
                      colors: [
                        style.primaryColor,
                        style.secondaryColor,
                        style.highlightColor,
                        style.secondaryColor,
                        style.primaryColor,
                      ],
                      stops: const [0.0, 0.30, 0.50, 0.70, 1.0],
                    ).createShader(bounds);
                  },
                  child: CustomPaint(
                    size: Size.square(outerSize),
                    painter: _RoyalAvatarFramePainter(
                      style: style,
                      phase: phase,
                      hasWinStreakAura: hasWinStreakAura,
                    ),
                  ),
                ),

                // 5. Win Streak Flame Pill (for compact/medium/large sizes when enabled)
                if (hasWinStreakAura &&
                    widget.showStreakBadge &&
                    outerSize >= 44)
                  Positioned(
                    bottom: -outerSize * 0.06,
                    right: -outerSize * 0.04,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: math.max(5.0, outerSize * 0.09),
                        vertical: math.max(1.5, outerSize * 0.025),
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFE11D48)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFFFFBEB),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE11D48).withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: math.max(10.0, outerSize * 0.17),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${widget.winStreak}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: math.max(9.0, outerSize * 0.15),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _RoyalAvatarFramePainter extends CustomPainter {
  final RoyalFrameStyle style;
  final double phase;
  final bool hasWinStreakAura;

  _RoyalAvatarFramePainter({
    required this.style,
    required this.phase,
    required this.hasWinStreakAura,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) * 0.90;
    final strokeWidth = size.shortestSide * style.strokeRatio;

    // 1. Base Outer Bevel Ring
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = style.secondaryColor;
    canvas.drawCircle(center, radius, basePaint);

    // 2. Inner Golden/Metallic Rim
    final innerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, strokeWidth * 0.24)
      ..color = style.highlightColor.withValues(alpha: 0.85);
    canvas.drawCircle(center, radius - strokeWidth * 0.44, innerRimPaint);

    // 3. Octagonal Andalusian Star Filigree (for Tier >= 3)
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

    // 4. Corner Jewel Nodes (8 Andalusian Bosses around the ring)
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

    // 5. Royal Crown Crest at Top (for Ruby, Sapphire, Platinum, Diamond: Tier >= 7)
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
  bool shouldRepaint(covariant _RoyalAvatarFramePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.style.frameKey != style.frameKey ||
        oldDelegate.hasWinStreakAura != hasWinStreakAura;
  }
}
