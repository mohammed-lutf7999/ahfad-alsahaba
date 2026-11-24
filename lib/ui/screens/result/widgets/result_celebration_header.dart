import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

class ResultTrophyIcon extends StatelessWidget {
  final bool isPassed;
  final bool isSmall;

  const ResultTrophyIcon({
    super.key,
    required this.isPassed,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSmall ? 85.0 : 100.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withAlpha(120),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(color: AppTheme.accentLight, width: 2.5),
      ),
      child: Icon(
        isPassed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
        size: isSmall ? 42 : 50,
        color: AppTheme.primaryDark,
      ),
    );
  }
}

class ResultStarsRow extends StatelessWidget {
  final AnimationController starsController;
  final AnimationController starWobbleController;
  final int stars;
  final bool isSmall;

  const ResultStarsRow({
    super.key,
    required this.starsController,
    required this.starWobbleController,
    required this.stars,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([starsController, starWobbleController]),
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final isActive = index < stars;
            final delay = index * 0.15;
            final progress =
                ((starsController.value - delay) / (1 - delay)).clamp(0.0, 1.0);
            final starWobble = isActive
                ? math.sin(
                      (starWobbleController.value + index * 0.2) * math.pi * 2,
                    ) *
                    0.2
                : 0.0;

            return Transform.scale(
              scale: isActive ? Curves.elasticOut.transform(progress) : 0.7,
              child: Transform.rotate(
                angle: isActive ? starWobble : 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: isActive
                      ? BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentColor.withValues(alpha: 0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                      : null,
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isActive
                            ? [
                                AppTheme.accentLight,
                                AppTheme.accentColor,
                                AppTheme.accentDark,
                              ]
                            : [Colors.white24, Colors.white12],
                      ).createShader(bounds);
                    },
                    child: Icon(
                      isActive ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.white,
                      size: isSmall ? 40 : 48,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
