import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/models/question_model.dart';

class QuizReviewQuestionCard extends StatelessWidget {
  final int index;
  final Question question;
  final int selectedIndex;
  final bool isCorrect;
  final BuildContext hostContext;

  const QuizReviewQuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.selectedIndex,
    required this.isCorrect,
    required this.hostContext,
  });

  static String formatQuestionForSharing(Question question) {
    final buffer = StringBuffer();
    buffer.writeln('📚 سؤال من معركة أحفاد الصحابة');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('❓ السؤال:');
    buffer.writeln(question.questionText);
    buffer.writeln();
    buffer.writeln('📝 الخيارات:');
    for (int i = 0; i < question.options.length; i++) {
      if (i == question.correctAnswerIndex) {
        buffer.writeln('✅ ${question.options[i]} (الإجابة الصحيحة)');
      } else {
        buffer.writeln('⚪ ${question.options[i]}');
      }
    }
    if (question.explanation != null && question.explanation!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('💡 فائدة: ${question.explanation}');
    }
    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🌟 حمّل التطبيق وتعلم معنا!');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isCorrect
              ? [
                  Colors.green.withValues(alpha: 0.15),
                  Colors.green.withValues(alpha: 0.05),
                ]
              : [
                  Colors.red.withValues(alpha: 0.15),
                  Colors.red.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCorrect
              ? Colors.greenAccent.withValues(alpha: 0.6)
              : Colors.redAccent.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.questionText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(question.options.length, (optIndex) {
            final isThisSelected = optIndex == selectedIndex;
            final isThisCorrect = optIndex == question.correctAnswerIndex;

            Color optionColor = Colors.white.withValues(alpha: 0.6);
            IconData? icon;
            if (isThisCorrect) {
              optionColor = Colors.greenAccent;
              icon = Icons.check_circle_rounded;
            } else if (isThisSelected && !isCorrect) {
              optionColor = Colors.redAccent;
              icon = Icons.cancel_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isThisSelected || isThisCorrect
                    ? optionColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isThisSelected || isThisCorrect
                    ? Border.all(color: optionColor.withValues(alpha: 0.5))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      question.options[optIndex],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: optionColor,
                        fontWeight: isThisSelected || isThisCorrect
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: optionColor, size: 20),
                  ],
                ],
              ),
            );
          }),
          if (!isCorrect && question.explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      'توضيح: ${question.explanation}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.lightbulb,
                    color: AppTheme.accentColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  SoundService().playClick();
                  final formatted = formatQuestionForSharing(question);
                  Clipboard.setData(ClipboardData(text: formatted));
                  ScaffoldMessenger.of(hostContext).showSnackBar(
                    SnackBar(
                      content: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'تم نسخ السؤال!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        color: AppTheme.accentColor,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'نسخ',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  SoundService().playClick();
                  final formatted = formatQuestionForSharing(question);
                  await SharePlus.instance.share(ShareParams(text: formatted));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        color: AppTheme.primaryDark,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'مشاركة',
                        style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
