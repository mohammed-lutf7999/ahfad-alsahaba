import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../logic/timer_controller.dart';
import '../../../widgets/timer_widget.dart';

class QuizHeader extends StatelessWidget {
  final AnimationController successController;
  final TimerController timerController;
  final int lives;
  final int score;
  final int currentQuestionNumber;
  final int totalQuestions;
  final int levelNumber;
  final double progress;
  final VoidCallback onExitTap;

  const QuizHeader({
    super.key,
    required this.successController,
    required this.timerController,
    required this.lives,
    required this.score,
    required this.currentQuestionNumber,
    required this.totalQuestions,
    required this.levelNumber,
    required this.progress,
    required this.onExitTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: successController,
      builder: (context, child) {
        final glow = successController.value * 5;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(
                  AppTheme.primaryLight,
                  AppTheme.accentColor,
                  successController.value * 0.3,
                )!
                    .withAlpha(200),
                Color.lerp(
                  AppTheme.primaryColor,
                  AppTheme.accentDark,
                  successController.value * 0.3,
                )!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.accentColor
                  .withAlpha(60 + (100 * successController.value).toInt()),
              width: 1.5 + successController.value,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor
                    .withAlpha(40 + (50 * successController.value).toInt()),
                blurRadius: 15 + glow,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onExitTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.accentColor.withAlpha(40),
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final isActive = index < lives;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ShatteringHeart(isActive: isActive),
                      );
                    }),
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Transform.scale(
                    scale: 0.85,
                    child: ListenableBuilder(
                      listenable: timerController,
                      builder: (context, _) => TimerWidget(
                        remainingTime: timerController.remainingTime,
                        totalTime: timerController.totalTime,
                        isRunning: timerController.isRunning,
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedBuilder(
                    animation: successController,
                    builder: (context, child) {
                      final glow = successController.value * 10;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentColor.withAlpha(
                                80 + (100 * successController.value).toInt(),
                              ),
                              blurRadius: 8 + glow,
                              spreadRadius: successController.value * 3,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              color: AppTheme.primaryDark,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$score',
                              style: const TextStyle(
                                color: AppTheme.primaryDark,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              Text(
                'السؤال $currentQuestionNumber/$totalQuestions',
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 12,
                ),
              ),
              Text(
                'المستوى $levelNumber',
                style: const TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.black26,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accentColor,
                  ),
                  minHeight: 6,
                ),
                if (successController.isAnimating)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        return Transform.translate(
                          offset: Offset(
                            constraints.maxWidth *
                                (successController.value - 1),
                            0,
                          ),
                          child: Container(
                            width: constraints.maxWidth / 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ShatteringHeart extends StatefulWidget {
  final bool isActive;

  const ShatteringHeart({super.key, required this.isActive});

  @override
  State<ShatteringHeart> createState() => _ShatteringHeartState();
}

class _ShatteringHeartState extends State<ShatteringHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant ShatteringHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _controller.forward();
    } else if (!oldWidget.isActive && widget.isActive) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isActive) {
      return const Icon(
        Icons.favorite_rounded,
        color: Color(0xFFFFD700),
        size: 24,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0 && !widget.isActive) {
          return Icon(
            Icons.favorite_border_rounded,
            color: Colors.grey.withValues(alpha: 0.5),
            size: 24,
          );
        }

        final shakeDirection = math.sin(_controller.value * math.pi * 8);
        final offset = Offset(
          (2 * (0.5 - (0.5 - _controller.value).abs())) * 5 * shakeDirection,
          0,
        );

        return Transform.translate(
          offset: _controller.isAnimating ? offset : Offset.zero,
          child: Opacity(
            opacity: 1.0 - _controller.value,
            child: const Icon(
              Icons.heart_broken_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}
