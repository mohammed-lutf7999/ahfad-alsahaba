import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// شريط تفصيلي لإحصائيات الإجابات (صحيحة / النقاط / خاطئة)
class ResultStatsRow extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;
  final int totalScore;
  final bool isSmall;

  const ResultStatsRow({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.totalScore,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final wrongAnswers = totalQuestions - correctAnswers;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          '$correctAnswers',
          'صحيحة',
          Icons.check_circle_rounded,
          Colors.green,
          isSmall,
        ),
        Container(
          width: 1,
          height: isSmall ? 35 : 45,
          color: AppTheme.accentColor.withValues(alpha: 0.3),
        ),
        _buildStatItem(
          '$totalScore',
          'النقاط',
          Icons.stars_rounded,
          AppTheme.accentColor,
          isSmall,
        ),
        Container(
          width: 1,
          height: isSmall ? 35 : 45,
          color: AppTheme.accentColor.withValues(alpha: 0.3),
        ),
        _buildStatItem(
          '$wrongAnswers',
          'خاطئة',
          Icons.cancel_rounded,
          Colors.red,
          isSmall,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isSmall,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isSmall ? 20 : 24),
        SizedBox(height: isSmall ? 4 : 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 10 : 11,
            color: Colors.grey.shade400,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}
