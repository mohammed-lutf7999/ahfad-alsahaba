import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'splash_painters.dart';

class SplashLogoWidget extends StatelessWidget {
  const SplashLogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SplashPalette.lightGold,
            SplashPalette.imperialGold,
            SplashPalette.darkGold,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: SplashPalette.imperialGold.withAlpha(150),
            blurRadius: 50,
            spreadRadius: 15,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
        border: Border.all(color: SplashPalette.lightGold, width: 4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(60), width: 2),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
          ),
          ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 100,
              height: 100,
              cacheWidth: 256,
              cacheHeight: 256,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

class SplashAppNameBlock extends StatelessWidget {
  final Animation<double> shimmerAnimation;

  const SplashAppNameBlock({super.key, required this.shimmerAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                SplashPalette.lightGold,
                Colors.white,
                SplashPalette.lightGold,
              ],
              stops: [
                (shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                shimmerAnimation.value.clamp(0.0, 1.0),
                (shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Column(
        children: [
          Text(
            'معركة أحفاد الصحابة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha(80),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
                Shadow(
                  color: SplashPalette.imperialGold.withAlpha(80),
                  offset: Offset.zero,
                  blurRadius: 25,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SplashPalette.imperialGold.withAlpha(0),
                  SplashPalette.imperialGold.withAlpha(50),
                  SplashPalette.imperialGold.withAlpha(0),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '─── تحدي العُظماء ───',
              style: TextStyle(
                color: SplashPalette.imperialGold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withAlpha(60),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashSubtitleCapsule extends StatelessWidget {
  const SplashSubtitleCapsule({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withAlpha(0),
            Colors.white.withAlpha(20),
            Colors.white.withAlpha(0),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: SplashPalette.imperialGold.withAlpha(50),
          width: 1,
        ),
      ),
      child: Text(
        'اكتشف قوة المعرفة الإسلامية',
        style: TextStyle(
          color: Colors.white.withAlpha(220),
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class SplashLoadingIndicator extends StatelessWidget {
  final Animation<double> rotationAnimation;
  final Animation<double> pulseAnimation;

  const SplashLoadingIndicator({
    super.key,
    required this.rotationAnimation,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 55,
      height: 55,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: rotationAnimation.value * math.pi * 2,
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SplashPalette.imperialGold.withAlpha(50),
                      width: 2,
                    ),
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        SplashPalette.imperialGold.withAlpha(180),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 14 * pulseAnimation.value,
                height: 14 * pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      SplashPalette.lightGold,
                      SplashPalette.imperialGold,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SplashPalette.imperialGold.withAlpha(150),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SplashCornerOrnament extends StatelessWidget {
  final Alignment alignment;
  final Animation<double> fadeAnimation;
  final bool flip;
  final bool flipVertical;

  const SplashCornerOrnament({
    super.key,
    required this.alignment,
    required this.fadeAnimation,
    this.flip = false,
    this.flipVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: alignment == Alignment.topLeft || alignment == Alignment.topRight
          ? 0
          : null,
      bottom: alignment == Alignment.bottomLeft ||
              alignment == Alignment.bottomRight
          ? 0
          : null,
      left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
          ? 0
          : null,
      right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
          ? 0
          : null,
      child: AnimatedBuilder(
        animation: fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: fadeAnimation.value * 0.5,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                flip ? -1.0 : 1.0,
                flipVertical ? -1.0 : 1.0,
                1.0,
              ),
              child: CustomPaint(
                painter: CornerOrnamentPainter(
                  color: SplashPalette.imperialGold,
                ),
                size: const Size(120, 120),
              ),
            ),
          );
        },
      ),
    );
  }
}
