import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../data/services/app_control_service.dart';
import '../../chat/widgets/quick_phrases_bar.dart';

/// Dedicated central VS + countdown + quick-phrases band between the two player halves.
class VersusCountdownBadge extends StatelessWidget {
  const VersusCountdownBadge({
    super.key,
    required this.vsScale,
    required this.bothReady,
    required this.waitingForOpponent,
    required this.countdown,
    required this.isFriendly,
    required this.opponentName,
    required this.activeQuickPhrase,
    required this.phraseIsMine,
    required this.onQuickPhraseSelected,
  });

  final Animation<double> vsScale;
  final bool bothReady;
  final bool waitingForOpponent;
  final int countdown;
  final bool isFriendly;
  final String opponentName;
  final String? activeQuickPhrase;
  final bool phraseIsMine;
  final void Function(String phrase) onQuickPhraseSelected;

  @override
  Widget build(BuildContext context) {
    final quickPhrasesEnabled =
        AppControlService.instance.featureFlagsNotifier.value.quickPhrases;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: const Border.symmetric(
          horizontal: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: vsScale,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      color: AppTheme.primaryDark,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (bothReady)
                Text(
                  '$countdown',
                  style: const TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                )
              else if (waitingForOpponent)
                const Flexible(
                  child: Text(
                    'في انتظار تأكيد الخصم...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
            ],
          ),
          if (activeQuickPhrase != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: phraseIsMine
                    ? AppTheme.accentColor.withValues(alpha: 0.18)
                    : Colors.black54,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.65),
                ),
              ),
              child: Text(
                phraseIsMine
                    ? 'أنت: $activeQuickPhrase'
                    : '$opponentName: $activeQuickPhrase',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (quickPhrasesEnabled) ...[
            const SizedBox(height: 8),
            QuickPhrasesBar(
              compact: true,
              onPhraseSelected: onQuickPhraseSelected,
            ),
          ],
          if (isFriendly) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.tealAccent.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'مباراة ودية — الكؤوس والدروع محمية 🛡️',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
