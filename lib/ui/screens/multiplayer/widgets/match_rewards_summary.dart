import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import 'rematch_action_bar.dart';

/// Renders the victory/draw/defeat emblem, trophy & coin badges, scores card,
/// and incoming rematch status banners inside [GameMatchResultDialog].
class MatchRewardsSummary extends StatelessWidget {
  const MatchRewardsSummary({
    super.key,
    required this.isWinner,
    required this.isDraw,
    required this.effectiveDelta,
    required this.totalTrophies,
    required this.coinsEarned,
    required this.shieldConsumed,
    required this.xpBannerConsumed,
    required this.isFriendly,
    required this.myScore,
    required this.opponentScore,
    required this.opponentName,
    required this.rematchState,
    required this.countdown,
  });

  final bool isWinner;
  final bool isDraw;
  final int effectiveDelta;
  final int? totalTrophies;
  final int coinsEarned;
  final bool shieldConsumed;
  final bool xpBannerConsumed;
  final bool isFriendly;
  final int myScore;
  final int opponentScore;
  final String opponentName;
  final RematchUIState rematchState;
  final int countdown;

  @override
  Widget build(BuildContext context) {
    final trophyColor = effectiveDelta >= 0 ? Colors.amber : Colors.redAccent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDraw
              ? Icons.handshake
              : (isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied),
          size: 56,
          color: isDraw
              ? Colors.blue
              : (isWinner ? AppTheme.accentColor : Colors.red),
        ),
        const SizedBox(height: 12),
        Text(
          isDraw ? 'تعادل!' : (isWinner ? '🎉 أنت الفائز!' : 'حظاً أوفر..'),
          style: TextStyle(
            color: isDraw ? Colors.blue : (isWinner ? Colors.green : Colors.red),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: trophyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: trophyColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                '${effectiveDelta >= 0 ? "+$effectiveDelta" : "$effectiveDelta"} كأساً 🏆${totalTrophies != null ? " ($totalTrophies)" : ""}',
                style: TextStyle(
                  color: effectiveDelta >= 0
                      ? Colors.amberAccent
                      : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            if (coinsEarned > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '+$coinsEarned 🪙 دنانير الفتح',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
          ],
        ),
        if (isFriendly) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.tealAccent.withValues(alpha: 0.45),
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
        if (shieldConsumed || xpBannerConsumed) ...[
          const SizedBox(height: 8),
          Text(
            shieldConsumed
                ? '🛡️ درع الحماية حمى كؤوسك وسلسلة انتصاراتك!'
                : '🚩 راية المضاعفة ضاعفت خبرتك المكتسبة (2x)!',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'أنت',
                      style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$myScore',
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 2, height: 45, color: Colors.white24),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      opponentName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Cairo',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '$opponentScore',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (rematchState == RematchUIState.receivedOffer) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.flash_on,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'الخصم يطلب إعادة النزال! (${countdown}s)',
                    style: const TextStyle(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Cairo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (rematchState == RematchUIState.opponentLeft) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.door_back_door_outlined,
                  color: Colors.white60,
                  size: 18,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'غادر الخصم شاشة النزال أو انتهى الوقت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
