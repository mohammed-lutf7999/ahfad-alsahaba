import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import 'result_action_buttons.dart';
import 'result_score_gauge.dart';
import 'result_stats_row.dart';

class ResultSummaryCard extends StatelessWidget {
  final AnimationController scoreController;
  final Animation<double> scoreAnimation;
  final AnimationController pulseController;
  final int correctAnswers;
  final int totalQuestions;
  final int totalScore;
  final String categoryId;
  final int currentLevelNumber;
  final bool isPassed;
  final bool isSmall;
  final List<Map<String, dynamic>>? userAnswers;

  const ResultSummaryCard({
    super.key,
    required this.scoreController,
    required this.scoreAnimation,
    required this.pulseController,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.totalScore,
    required this.categoryId,
    required this.currentLevelNumber,
    required this.isPassed,
    required this.isSmall,
    this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: scoreController, curve: Curves.easeOutCubic),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.accentColor.withAlpha(80),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ResultScoreGauge(
                    scoreAnimation: scoreAnimation,
                    pulseAnimation: pulseController,
                    isPassed: isPassed,
                    isSmall: isSmall,
                  ),
                  SizedBox(height: isSmall ? 12 : 18),
                  Container(
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppTheme.accentColor.withAlpha(100),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isSmall ? 12 : 18),
                  ResultStatsRow(
                    correctAnswers: correctAnswers,
                    totalQuestions: totalQuestions,
                    totalScore: totalScore,
                    isSmall: isSmall,
                  ),
                  SizedBox(height: isSmall ? 16 : 22),
                  ResultActionButtons(
                    categoryId: categoryId,
                    currentLevelNumber: currentLevelNumber,
                    isPassed: isPassed,
                    isSmall: isSmall,
                    userAnswers: userAnswers,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResultShareButton extends StatelessWidget {
  final bool isSharing;
  final VoidCallback onTap;

  const ResultShareButton({
    super.key,
    required this.isSharing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: isSharing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                ),
              )
            : const Icon(
                Icons.share_rounded,
                color: AppTheme.accentColor,
                size: 24,
              ),
      ),
    );
  }
}
