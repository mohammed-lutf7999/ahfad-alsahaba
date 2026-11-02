import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TimerWidget extends StatelessWidget {
  final int remainingTime;
  final int totalTime;
  final bool isRunning;

  const TimerWidget({super.key, required this.remainingTime, required this.totalTime, required this.isRunning});

  Color _getTimerColor() {
    final percentage = remainingTime / totalTime;
    if (percentage > 0.6) return AppTheme.accentDark;
    if (percentage > 0.3) return Colors.orange;
    return AppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppTheme.accentColor.withAlpha(80), width: 1.5),
        boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(40), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: isRunning ? 1 : 0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) => Transform.rotate(
              angle: value * 0.1,
              child: Icon(Icons.timer_rounded, color: _getTimerColor(), size: 24),
            ),
          ),
          const SizedBox(width: 10),
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: _getTimerColor()),
            duration: const Duration(milliseconds: 300),
            builder: (context, color, child) {
              // Blinking effect for last 5 seconds
              return isRunning && remainingTime <= 5 
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: 0.2),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      builder: (context, opacity, _) {
                        return Opacity(
                          opacity: (remainingTime % 2 == 0) ? opacity : 1.0,
                          child: Text('$remainingTime', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                        );
                      },
                      onEnd: () {}, 
                    )
                  : Text('$remainingTime', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color));
            },
          ),
          const SizedBox(width: 3),
          Text('ث', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class TimerProgressBar extends StatelessWidget {
  final int remainingTime;
  final int totalTime;

  const TimerProgressBar({super.key, required this.remainingTime, required this.totalTime});

  Color _getProgressColor() {
    final percentage = remainingTime / totalTime;
    if (percentage > 0.5) return AppTheme.accentColor;
    if (percentage > 0.25) return Colors.orange;
    return AppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: remainingTime / totalTime),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) => LinearProgressIndicator(
          value: value,
          backgroundColor: AppTheme.accentColor.withAlpha(40),
          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
          minHeight: 8,
        ),
      ),
    );
  }
}
