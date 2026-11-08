import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// مقياس النسبة المئوية الدائري المتحرك مع وميض النبض
class ResultScoreGauge extends StatelessWidget {
  final Animation<double> scoreAnimation;
  final Animation<double>? pulseAnimation;
  final bool isPassed;
  final bool isSmall;

  const ResultScoreGauge({
    super.key,
    required this.scoreAnimation,
    this.pulseAnimation,
    required this.isPassed,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final circleSize = isSmall ? 110.0 : 130.0;
    final listenables = <Listenable>[scoreAnimation];
    if (pulseAnimation != null) listenables.add(pulseAnimation!);

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, child) {
        final pulseScale = isPassed && pulseAnimation != null
            ? 1.0 + (pulseAnimation!.value * 0.03)
            : 1.0;

        return Transform.scale(
          scale: pulseScale,
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryDark.withValues(alpha: 0.3),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                ),

                // Progress arc
                SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: CircularProgressIndicator(
                    value: scoreAnimation.value / 100,
                    strokeWidth: isSmall ? 10 : 12,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPassed ? AppTheme.accentColor : Colors.redAccent,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),

                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isPassed
                              ? [
                                  AppTheme.accentLight,
                                  AppTheme.accentColor,
                                  AppTheme.accentDark,
                                ]
                              : [Colors.redAccent.shade100, Colors.redAccent],
                        ).createShader(bounds);
                      },
                      child: Text(
                        '${scoreAnimation.value.toInt()}%',
                        style: TextStyle(
                          fontSize: isSmall ? 30 : 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    Text(
                      isPassed ? 'ممتاز!' : 'حاول مجدداً',
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 13,
                        color: isPassed ? AppTheme.accentColor : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
