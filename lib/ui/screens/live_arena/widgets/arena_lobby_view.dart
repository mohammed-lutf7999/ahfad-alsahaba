import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/question_model.dart';

class ArenaPinEntryCard extends StatelessWidget {
  final TextEditingController pinController;
  final bool isBusy;
  final String? error;
  final VoidCallback onJoin;

  const ArenaPinEntryCard({
    super.key,
    required this.pinController,
    required this.isBusy,
    required this.error,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'أدخل رمز البطولة المكون من 5 أرقام',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('student_arena_pin_input'),
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
            decoration: const InputDecoration(
              hintText: '12345',
              hintStyle: TextStyle(color: Colors.white24),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.amberAccent,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('student_join_arena_btn'),
              onPressed: isBusy ? null : onJoin,
              icon: const Icon(Icons.login_rounded),
              label: const Text(
                'انضمام فوري للبطولة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.primaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ArenaWaitingLobbyCard extends StatelessWidget {
  final String title;

  const ArenaWaitingLobbyCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_top_rounded, color: accent, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: accent,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أنت جاهز! في انتظار ضغط المعلم على «ابدأ البطولة»...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white70,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class ArenaLiveQuestionView extends StatelessWidget {
  final int questionIndex;
  final Question question;
  final bool answered;
  final int? selectedOption;
  final ValueChanged<int> onAnswerOption;

  const ArenaLiveQuestionView({
    super.key,
    required this.questionIndex,
    required this.question,
    required this.answered,
    required this.selectedOption,
    required this.onAnswerOption,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Text(
            'السؤال ${questionIndex + 1}: ${question.questionText}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: answered ? null : () => onAnswerOption(i),
                style: ElevatedButton.styleFrom(
                  backgroundColor: answered && selectedOption == i
                      ? (i == question.correctAnswerIndex
                          ? const Color(0xFF10B981)
                          : Colors.redAccent)
                      : customTheme.surfaceCard,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  side: BorderSide(color: accent.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    question.options[i],
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
