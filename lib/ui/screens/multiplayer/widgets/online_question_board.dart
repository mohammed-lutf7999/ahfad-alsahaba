import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../data/models/question_model.dart';
import '../../../../data/services/app_control_service.dart';
import '../../chat/widgets/quick_phrases_bar.dart';
import 'game_reactions_ribbon.dart';
import 'game_tactical_powerups_bar.dart';

/// Displays the active question card, power-ups, reaction/quick-phrases ribbon, and 4 options.
class OnlineQuestionBoard extends StatelessWidget {
  const OnlineQuestionBoard({
    super.key,
    required this.question,
    required this.isBot,
    required this.isAnswered,
    required this.selectedAnswer,
    required this.hiddenOptionIndices,
    required this.showQuickPhrases,
    required this.random,
    required this.onInsightUsed,
    required this.onReactionSelected,
    required this.onToggleQuickPhrases,
    required this.onQuickPhraseSelected,
    required this.onOptionSelected,
  });

  final Question question;
  final bool isBot;
  final bool isAnswered;
  final int selectedAnswer;
  final Set<int> hiddenOptionIndices;
  final bool showQuickPhrases;
  final Random random;
  final void Function(Set<int> newHidden) onInsightUsed;
  final void Function(String emoji) onReactionSelected;
  final VoidCallback onToggleQuickPhrases;
  final void Function(String phrase) onQuickPhraseSelected;
  final void Function(int index) onOptionSelected;

  @override
  Widget build(BuildContext context) {
    final quickPhrasesEnabled =
        AppControlService.instance.featureFlagsNotifier.value.quickPhrases;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        children: [
          _buildQuestionCard(question.questionText),
          const SizedBox(height: 10),
          GameTacticalPowerUpsBar(
            question: question,
            isAnswered: isAnswered,
            hiddenOptionIndices: hiddenOptionIndices,
            random: random,
            onInsightUsed: onInsightUsed,
          ),
          const SizedBox(height: 8),
          if (!isBot) ...[
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                GameReactionsRibbon(onReactionSelected: onReactionSelected),
                if (quickPhrasesEnabled)
                  InkWell(
                    key: const Key('toggle_quick_phrases_btn'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: onToggleQuickPhrases,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: showQuickPhrases
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.chat_rounded,
                        size: 18,
                        color: showQuickPhrases
                            ? AppTheme.primaryDark
                            : AppTheme.accentColor,
                      ),
                    ),
                  ),
              ],
            ),
            if (showQuickPhrases && quickPhrasesEnabled) ...[
              const SizedBox(height: 6),
              QuickPhrasesBar(
                compact: true,
                onPhraseSelected: onQuickPhraseSelected,
              ),
            ],
          ],
          const SizedBox(height: 10),
          ...List.generate(question.options.length, (i) {
            if (hiddenOptionIndices.contains(i)) {
              return const SizedBox.shrink();
            }
            return _buildOptionButton(
              i,
              question.options[i],
              question.correctAnswerIndex,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          height: 1.5,
          fontFamily: 'Cairo',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOptionButton(int index, String text, int correctIndex) {
    final isSelected = selectedAnswer == index;
    final isCorrect = index == correctIndex;

    Color color = Colors.white.withValues(alpha: 0.05);
    Color borderColor = Colors.white.withValues(alpha: 0.1);

    if (isAnswered) {
      if (isCorrect) {
        color = Colors.green.withValues(alpha: 0.3);
        borderColor = Colors.green;
      } else if (isSelected) {
        color = Colors.red.withValues(alpha: 0.3);
        borderColor = Colors.red;
      }
    } else if (isSelected) {
      color = AppTheme.accentColor.withValues(alpha: 0.3);
    }

    return GestureDetector(
      onTap: isAnswered ? null : () => onOptionSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: borderColor.withValues(alpha: 0.3),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (isAnswered && isCorrect)
              const Icon(Icons.check_circle, color: Colors.green),
            if (isAnswered && isSelected && !isCorrect)
              const Icon(Icons.cancel, color: Colors.red),
          ],
        ),
      ),
    );
  }
}
