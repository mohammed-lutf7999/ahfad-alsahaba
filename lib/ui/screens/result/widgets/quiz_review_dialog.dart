import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../data/models/question_model.dart';
import 'quiz_review_question_card.dart';

/// نافذة مراجعة الأسئلة والإجابات التفصيلية بعد انتهاء الاختبار
class QuizReviewDialog {
  static void show(
    BuildContext context, {
    required List<Map<String, dynamic>> userAnswers,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Review',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: LayoutBuilder(
                builder: (context, safeConstraints) {
                  final double cappedMaxWidth =
                      safeConstraints.maxWidth.clamp(0.0, 440.0);
                  final double dialogWidth =
                      (safeConstraints.maxWidth * 0.96).clamp(
                    cappedMaxWidth < 260.0 ? cappedMaxWidth : 260.0,
                    cappedMaxWidth,
                  );
                  final double cappedMaxHeight =
                      safeConstraints.maxHeight.clamp(0.0, 680.0);
                  final double dialogHeight =
                      (safeConstraints.maxHeight * 0.90).clamp(
                    cappedMaxHeight < 320.0 ? cappedMaxHeight : 320.0,
                    cappedMaxHeight,
                  );
                  return Center(
                    child: Container(
                      width: dialogWidth,
                      height: dialogHeight,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryLight,
                            AppTheme.primaryColor,
                            AppTheme.primaryDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border:
                            Border.all(color: AppTheme.accentColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor.withValues(alpha: 0.35),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: const BoxDecoration(
                                gradient: AppTheme.goldGradient,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(26),
                                  topRight: Radius.circular(26),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryDark
                                            .withValues(alpha: 0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: AppTheme.primaryDark,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.rate_review_rounded,
                                            color: AppTheme.primaryDark,
                                            size: 24,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'مراجعة الإجابات',
                                            style: TextStyle(
                                              color: AppTheme.primaryDark,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: userAnswers.length,
                                itemBuilder: (context, index) {
                                  final answerData = userAnswers[index];
                                  return QuizReviewQuestionCard(
                                    index: index,
                                    question:
                                        answerData['question'] as Question,
                                    selectedIndex:
                                        answerData['selectedOptionIndex']
                                            as int,
                                    isCorrect: answerData['isCorrect'] as bool,
                                    hostContext: ctx,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
