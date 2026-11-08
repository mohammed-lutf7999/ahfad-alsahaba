import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/player_level_model.dart';

/// Glassmorphic Animated XP / Glory Progress Bar using [TweenAnimationBuilder]
/// for smooth progress fill and animated XP counter.
/// Wrapped in a [RepaintBoundary] and synchronized with [AppCustomTheme].
class GloryProgressBar extends StatelessWidget {
  final PlayerLevelInfo? levelInfo;
  final int? currentXp;
  final int? requiredXp;
  final double height;
  final bool showLabels;
  final bool showRemainingHint;
  final Duration animationDuration;
  final Color? customFillColor;
  final Color? customSecondaryColor;

  const GloryProgressBar({
    super.key,
    this.levelInfo,
    this.currentXp,
    this.requiredXp,
    this.height = 12.0,
    this.showLabels = true,
    this.showRemainingHint = true,
    this.animationDuration = const Duration(milliseconds: 900),
    this.customFillColor,
    this.customSecondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme =
        Theme.of(context).extension<AppCustomTheme>() ??
        AppCustomTheme.andalusianGold;

    final resolvedCurrentXp = currentXp ?? levelInfo?.currentLevelXp ?? 0;
    final resolvedRequiredXp = math.max(
      1,
      requiredXp ?? levelInfo?.requiredLevelXp ?? 250,
    );
    final isMaxLevel =
        levelInfo != null && levelInfo!.level >= PlayerLevelInfo.maxLevel;
    final targetProgress = isMaxLevel
        ? 1.0
        : (resolvedCurrentXp / resolvedRequiredXp).clamp(0.0, 1.0);

    final primaryFill = customFillColor ?? customTheme.sovereignAccent;
    final secondaryFill = customSecondaryColor ?? customTheme.secondaryAccent;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: targetProgress),
        duration: animationDuration,
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, _) {
          final animatedCurrentXp = (animatedProgress * resolvedRequiredXp)
              .round()
              .clamp(0, resolvedRequiredXp);
          final percentInt = (animatedProgress * 100).round().clamp(0, 100);
          final remainingXp = math.max(
            0,
            resolvedRequiredXp - resolvedCurrentXp,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLabels) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: isMaxLevel
                          ? const Text(
                              'القمة الأسطورية (المستوى 100) 👑',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                height: 1.2,
                              ),
                            )
                          : Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                '$animatedCurrentXp / $resolvedRequiredXp XP',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: primaryFill.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: primaryFill.withValues(alpha: 0.55),
                          width: 0.9,
                        ),
                      ),
                      child: Text(
                        '$percentInt%',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: primaryFill,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],

              // Glassmorphic Track + Animated Glowing Fill
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(height),
                  border: Border.all(
                    color: primaryFill.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(height),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      final fillW = (maxW * animatedProgress).clamp(0.0, maxW);

                      return Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [
                          // Subtle Diagonal Shimmer Track Background
                          Container(
                            width: maxW,
                            height: height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.03),
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.white.withValues(alpha: 0.03),
                                ],
                              ),
                            ),
                          ),

                          // Active Progress Fill
                          if (fillW > 0)
                            Container(
                              width: fillW,
                              height: height,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(height),
                                gradient: LinearGradient(
                                  colors: [
                                    secondaryFill,
                                    primaryFill,
                                    Color.lerp(primaryFill, Colors.white, 0.35)!,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryFill.withValues(alpha: 0.55),
                                    blurRadius: 8,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              ),
                            ),

                          // Top Glass Specular Highlight
                          if (fillW > 4)
                            Positioned(
                              top: 1.2,
                              right: 2,
                              left: math.max(2.0, maxW - fillW + 2),
                              child: Container(
                                height: height * 0.28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.32),
                                  borderRadius: BorderRadius.circular(height),
                                ),
                              ),
                            ),

                          // Luminous Leading Glow Edge at the Fill Tip
                          if (fillW > 6 && animatedProgress < 0.995)
                            PositionedDirectional(
                              start: math.max(0.0, fillW - 5),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      blurRadius: 6,
                                      spreadRadius: 1.2,
                                    ),
                                    BoxShadow(
                                      color: primaryFill,
                                      blurRadius: 10,
                                      spreadRadius: 2.0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              if (showRemainingHint && !isMaxLevel) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'باقي $remainingXp نقطة للارتقاء للمستوى ${(levelInfo?.level ?? 1) + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (levelInfo != null)
                      Text(
                        'مكافأة الترقية: +${PlayerLevelInfo.coinRewardForLevel(levelInfo!.level + 1)} 🪙',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: primaryFill.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
