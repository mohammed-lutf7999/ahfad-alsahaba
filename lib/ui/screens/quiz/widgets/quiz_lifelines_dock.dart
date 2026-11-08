import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/services/progression_service.dart';
import '../../../../logic/game_controller.dart';
import '../../../../logic/timer_controller.dart';

/// شريط الوسائل المساعدة السفلي في المسابقة الفردية
/// يضم 4 وسائل مساعدة: (تجميد الوقت، تخطي السؤال، حذف إجابتين 50/50، وبصيرة القائد التكتيكية)
class QuizLifelinesDock extends StatelessWidget {
  final GameController gameController;
  final TimerController timerController;
  final VoidCallback onNextQuestion;
  final VoidCallback onStateChanged;

  const QuizLifelinesDock({
    super.key,
    required this.gameController,
    required this.timerController,
    required this.onNextQuestion,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Time Freeze
            _LinearLifeline(
              icon: Icons.timer_off_rounded,
              label: 'تجميد الوقت',
              color: Colors.blueAccent,
              isUsed: gameController.hasUsedTimeFreeze,
              onTap: () {
                if (gameController.hasUsedTimeFreeze || gameController.isAnswered) return;
                SoundService().playHintUse();
                gameController.useTimeFreeze();
                timerController.pauseTimer();
                onStateChanged();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'تم تجميد الوقت لمدة 15 ثانية!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.9),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                // Auto resume after 15 seconds
                Future.delayed(const Duration(seconds: 15), () {
                  if (!gameController.isAnswered) {
                    timerController.resumeTimer();
                  }
                });
              },
            ),

            // 2. Skip Question
            _LinearLifeline(
              icon: Icons.skip_next_rounded,
              label: 'تخطي',
              color: Colors.orangeAccent,
              isUsed: gameController.hasUsedSkip,
              onTap: () {
                if (gameController.hasUsedSkip || gameController.isAnswered) return;
                SoundService().playHintUse();
                gameController.useSkip();
                onNextQuestion();
              },
            ),

            // 3. 50/50
            _LinearLifeline(
              icon: Icons.percent_rounded,
              label: '50/50',
              color: Colors.purpleAccent,
              isUsed: gameController.hasUsedFiftyFifty,
              onTap: () {
                if (gameController.hasUsedFiftyFifty || gameController.isAnswered) return;
                SoundService().playHintUse();
                gameController.useFiftyFifty();
                onStateChanged();
              },
            ),

            // 4. بصيرة القائد (Commander Insight)
            _LinearLifeline(
              icon: Icons.lightbulb_rounded,
              label: 'بصيرة القائد',
              color: const Color(0xFFFFD700),
              isUsed: !ProgressionService.instance.hasItem('powerup_insight') ||
                  gameController.hiddenOptionIndices.isNotEmpty,
              onTap: () async {
                if (gameController.isAnswered ||
                    gameController.hiddenOptionIndices.isNotEmpty) {
                  return;
                }
                if (!ProgressionService.instance.hasItem('powerup_insight')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'يمكنك اقتناء «بصيرة القائد 💡» من سوق الفرسان 🪙',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                      backgroundColor: AppTheme.primaryDark,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  return;
                }
                final consumed = await ProgressionService.instance
                    .consumeCommanderInsight();
                if (!consumed || !context.mounted) return;
                SoundService().playHintUse();
                gameController.useCommanderInsight();
                onStateChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LinearLifeline extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isUsed;
  final VoidCallback onTap;

  const _LinearLifeline({
    required this.icon,
    required this.label,
    required this.color,
    required this.isUsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isUsed
                  ? LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ])
                  : LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.9),
                        color.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: isUsed
                  ? []
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
              border: Border.all(
                color: isUsed
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isUsed ? Colors.white.withValues(alpha: 0.2) : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isUsed
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
