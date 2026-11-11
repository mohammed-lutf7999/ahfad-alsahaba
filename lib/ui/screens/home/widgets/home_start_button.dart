import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/size_config.dart';
import '../../../../core/sound_service.dart';

/// زر «ابدأ التحدي» الرئيسي مع بريق متحرك وشعاع زجاجي وانعكاسات ذهبية
class HomeStartButton extends StatefulWidget {
  final VoidCallback onTap;

  const HomeStartButton({super.key, required this.onTap});

  @override
  State<HomeStartButton> createState() => _HomeStartButtonState();
}

class _HomeStartButtonState extends State<HomeStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: GestureDetector(
        onTap: () {
          SoundService().playClick();
          widget.onTap();
        },
        child: Stack(
          children: [
            // Base Layer with Gold Gradient & Shadow
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppTheme.primaryDark,
                        size: getProportionateScreenWidth(28),
                      ),
                    ),
                    SizedBox(width: getProportionateScreenWidth(14)),
                    Text(
                      'ابدأ التحدي',
                      style: TextStyle(
                        fontSize: getProportionateScreenWidth(22),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Shimmer Effect
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      widthFactor: 0.6,
                      heightFactor: 1.0,
                      alignment: AlignmentTween(
                        begin: const Alignment(-3.5, 0.0),
                        end: const Alignment(3.5, 0.0),
                      ).evaluate(_shimmerController),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            begin: const Alignment(-0.5, -0.5),
                            end: const Alignment(1.5, 1.5),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Glass/Gloss Highlight (Top edge)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 25,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
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
