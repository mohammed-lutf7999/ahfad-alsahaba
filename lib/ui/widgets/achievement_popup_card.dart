import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../data/models/achievement_model.dart';
import 'achievement_popup_painters.dart';

class AchievementPopupCard extends StatelessWidget {
  final Achievement achievement;
  final Color rarityColor;
  final Color raritySecondaryColor;
  final String rarityName;
  final double glowValue;
  final double bounceValue;
  final double iconScaleValue;
  final double rotateValue;
  final double pulseValue;
  final VoidCallback onDismiss;

  const AchievementPopupCard({
    super.key,
    required this.achievement,
    required this.rarityColor,
    required this.raritySecondaryColor,
    required this.rarityName,
    required this.glowValue,
    required this.bounceValue,
    required this.iconScaleValue,
    required this.rotateValue,
    required this.pulseValue,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: bounceValue,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.all(20),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: -30,
              child: Transform.rotate(
                angle: rotateValue * math.pi * 2,
                child: CustomPaint(
                  size: const Size(200, 200),
                  painter: AchievementRaysPainter(color: rarityColor),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 50),
              padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryLight.withValues(alpha: 0.95),
                    AppTheme.primaryColor,
                    AppTheme.primaryDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: rarityColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withValues(alpha: 0.4 * glowValue),
                    blurRadius: 40 * glowValue,
                    spreadRadius: 15 * glowValue,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        raritySecondaryColor,
                        Colors.white,
                        rarityColor,
                        Colors.white,
                        raritySecondaryColor,
                      ],
                      stops: [
                        0.0,
                        0.25 + (glowValue * 0.1),
                        0.5,
                        0.75 - (glowValue * 0.1),
                        1.0,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      '✨ إنجـــاز جديــد! ✨',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rarityColor.withValues(alpha: 0.3),
                          raritySecondaryColor.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: rarityColor.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: rarityColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      rarityName,
                      style: TextStyle(
                        color: rarityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, raritySecondaryColor],
                    ).createShader(bounds),
                    child: Text(
                      achievement.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 80,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          rarityColor,
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Transform.scale(
                    scale: pulseValue,
                    child: GestureDetector(
                      onTap: () {
                        SoundService().playClick();
                        onDismiss();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              raritySecondaryColor,
                              rarityColor,
                              rarityColor.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: rarityColor.withValues(alpha: 0.5),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.1),
                              blurRadius: 5,
                              spreadRadius: -2,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'رائـــع!',
                                style: TextStyle(
                                  color: achievement.rarity ==
                                          AchievementRarity.legendary
                                      ? Colors.black
                                      : AppTheme.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('🎉', style: TextStyle(fontSize: 24)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Transform.scale(
                scale: iconScaleValue,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        raritySecondaryColor,
                        rarityColor,
                        rarityColor.withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.6 * glowValue),
                        blurRadius: 25,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      achievement.icon,
                      style: const TextStyle(fontSize: 55),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
