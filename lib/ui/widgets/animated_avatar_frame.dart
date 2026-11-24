import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'avatar_frame/royal_avatar_frame_painter.dart';
import 'avatar_frame/royal_frame_style.dart';

export 'avatar_frame/royal_frame_style.dart';

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
    if (widget.animate) _controller.repeat();
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
                SizedBox(
                  width: avatarSize,
                  height: avatarSize,
                  child: ClipOval(child: cachedAvatar),
                ),
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
                    painter: RoyalAvatarFramePainter(
                      style: style,
                      phase: phase,
                      hasWinStreakAura: hasWinStreakAura,
                    ),
                  ),
                ),
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
