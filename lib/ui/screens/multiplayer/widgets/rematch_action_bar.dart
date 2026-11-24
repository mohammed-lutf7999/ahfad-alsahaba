import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

enum RematchUIState {
  idle,
  waitingForOpponent,
  receivedOffer,
  launchingMatch,
  opponentLeft,
}

/// Action buttons bar for [GameMatchResultDialog] handling all [RematchUIState] states.
class RematchActionBar extends StatelessWidget {
  const RematchActionBar({
    super.key,
    required this.rematchState,
    required this.countdown,
    required this.isGhost,
    required this.onAcceptRematch,
    required this.onRequestRematch,
    required this.onLeave,
  });

  final RematchUIState rematchState;
  final int countdown;
  final bool isGhost;
  final VoidCallback onAcceptRematch;
  final VoidCallback onRequestRematch;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (rematchState == RematchUIState.receivedOffer) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onAcceptRematch,
                icon: const Icon(Icons.sports_kabaddi, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'قبول النزال ⚔️',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Cairo',
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onLeave,
                child: const Text(
                  'انسحاب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (rematchState == RematchUIState.launchingMatch) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            foregroundColor: AppTheme.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryDark,
                ),
              ),
              SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'جاري تجهيز ساحة المعركة...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: AppTheme.primaryDark,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rematchState == RematchUIState.waitingForOpponent)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.8),
                foregroundColor: AppTheme.primaryDark,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: null,
              icon: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryDark,
                ),
              ),
              label: Text(
                'بانتظار رد الخصم (${countdown}s)...',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Cairo',
                  height: 1.2,
                ),
              ),
            ),
          )
        else if (rematchState != RematchUIState.opponentLeft)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.primaryDark,
                elevation: 3,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onRequestRematch,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: Text(
                isGhost ? 'مباراة جديدة ⚔️' : 'طلب إعادة النزال ⚔️',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                  height: 1.2,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onLeave,
            child: const Text(
              'العودة للرئيسية',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Cairo',
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
