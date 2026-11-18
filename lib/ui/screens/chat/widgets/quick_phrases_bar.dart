import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/chat_message_model.dart';

/// Compact horizontal bar of respectful chivalric quick phrases for
/// `VersusScreen` and `OnlineGameScreen`. Zero extra DB or socket cost.
class QuickPhrasesBar extends StatelessWidget {
  final ValueChanged<String> onPhraseSelected;
  final bool compact;

  const QuickPhrasesBar({
    super.key,
    required this.onPhraseSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return SizedBox(
      height: compact ? 36 : 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: QuickChivalricPhrases.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final phrase = QuickChivalricPhrases.all[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onPhraseSelected(phrase),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.48),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 13, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      phrase,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.94),
                        fontSize: compact ? 11.5 : 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
