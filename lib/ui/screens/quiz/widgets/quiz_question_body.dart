import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../data/models/question_model.dart';
import '../../../widgets/option_button.dart';
import '../../../widgets/question_card.dart';

class QuizQuestionBody extends StatelessWidget {
  final Question question;
  final int questionNumber;
  final int totalQuestions;
  final bool isAnswered;
  final int? selectedAnswerIndex;
  final List<int> hiddenOptionIndices;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final ValueChanged<int> onSelectOption;

  const QuizQuestionBody({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.isAnswered,
    required this.selectedAnswerIndex,
    required this.hiddenOptionIndices,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.onSelectOption,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: Column(
            children: [
              QuestionCard(
                questionText: question.questionText,
                questionNumber: questionNumber,
                totalQuestions: totalQuestions,
              ),
              const SizedBox(height: 8),
              if (isAnswered && question.explanation != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(
                        Icons.lightbulb_rounded,
                        color: AppTheme.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.explanation!,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!(isAnswered && question.explanation != null))
                const SizedBox(height: 8),
              ...List.generate(question.options.length, (index) {
                if (hiddenOptionIndices.contains(index)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OptionButton(
                    text: question.options[index],
                    index: index,
                    isSelected: selectedAnswerIndex == index,
                    isCorrect: index == question.correctAnswerIndex,
                    isAnswered: isAnswered,
                    onTap: () => onSelectOption(index),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
