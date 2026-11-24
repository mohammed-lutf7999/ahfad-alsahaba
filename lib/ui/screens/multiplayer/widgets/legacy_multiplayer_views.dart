import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../widgets/avatar_selector.dart';

class LegacyMultiplayerFinishedView extends StatelessWidget {
  final int score;
  final int correctAnswers;

  const LegacyMultiplayerFinishedView({
    super.key,
    required this.score,
    required this.correctAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🎉 أنهيت التحدي!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$score نقطة',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$correctAnswers إجابة صحيحة',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(color: AppTheme.accentColor),
                const SizedBox(height: 16),
                const Text(
                  'بانتظار انتهاء باقي اللاعبين لعرض الترتيب...',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LegacyMultiplayerHeader extends StatelessWidget {
  final List players;
  final String? localPlayerId;
  final int current;
  final int total;
  final VoidCallback onConfirmExit;

  const LegacyMultiplayerHeader({
    super.key,
    required this.players,
    required this.localPlayerId,
    required this.current,
    required this.total,
    required this.onConfirmExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                onPressed: onConfirmExit,
                tooltip: 'انسحاب',
              ),
              Text(
                'السؤال $current من $total',
                style: const TextStyle(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: players.map((player) {
                final isLocal = player.id == localPlayerId;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isLocal ? AppTheme.accentColor : Colors.white)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isLocal ? AppTheme.accentColor : Colors.white)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProfileAvatar(avatarIndex: player.avatarIndex, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${player.score}',
                        style: TextStyle(
                          color: isLocal ? AppTheme.accentColor : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class LegacyMultiplayerTimer extends StatelessWidget {
  final int timeLeft;
  final AnimationController timerController;

  const LegacyMultiplayerTimer({
    super.key,
    required this.timeLeft,
    required this.timerController,
  });

  @override
  Widget build(BuildContext context) {
    final color = timeLeft <= 5 ? Colors.red : AppTheme.accentColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '$timeLeft',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: timerController,
            builder: (context, _) => LinearProgressIndicator(
              value: 1 - timerController.value,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class LegacyMultiplayerQuestionCard extends StatelessWidget {
  final String text;

  const LegacyMultiplayerQuestionCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryLight.withValues(alpha: 0.3),
            AppTheme.primaryColor.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          height: 1.6,
          fontFamily: 'Cairo',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class LegacyMultiplayerOptionButton extends StatelessWidget {
  final int index;
  final String text;
  final int correctIndex;
  final int selectedAnswer;
  final bool isAnswered;
  final VoidCallback onSelect;

  const LegacyMultiplayerOptionButton({
    super.key,
    required this.index,
    required this.text,
    required this.correctIndex,
    required this.selectedAnswer,
    required this.isAnswered,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedAnswer == index;
    final isCorrect = index == correctIndex;

    Color bgColor;
    Color borderColor;
    IconData? icon;

    if (isAnswered) {
      if (isCorrect) {
        bgColor = Colors.green.withValues(alpha: 0.2);
        borderColor = Colors.green;
        icon = Icons.check_circle_rounded;
      } else if (isSelected && !isCorrect) {
        bgColor = Colors.red.withValues(alpha: 0.2);
        borderColor = Colors.red;
        icon = Icons.cancel_rounded;
      } else {
        bgColor = Colors.white.withValues(alpha: 0.05);
        borderColor = Colors.white.withValues(alpha: 0.1);
      }
    } else {
      bgColor = isSelected
          ? AppTheme.accentColor.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.05);
      borderColor = isSelected
          ? AppTheme.accentColor
          : Colors.white.withValues(alpha: 0.1);
    }

    return GestureDetector(
      onTap: isAnswered ? null : onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: borderColor, size: 20)
                    : Text(
                        String.fromCharCode(65 + index),
                        style: TextStyle(
                          color:
                              isSelected ? AppTheme.accentColor : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isAnswered && isCorrect
                      ? Colors.green
                      : (isAnswered && isSelected && !isCorrect
                          ? Colors.red
                          : Colors.white),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
