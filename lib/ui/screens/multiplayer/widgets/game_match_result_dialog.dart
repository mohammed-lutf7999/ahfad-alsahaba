import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';

/// نافذة نتيجة المباراة النهائية في المنافسات المباشرة
class GameMatchResultDialog {
  static void show(
    BuildContext context, {
    required bool isWinner,
    required bool isDraw,
    required int effectiveDelta,
    int? totalTrophies,
    int coinsEarned = 0,
    bool shieldConsumed = false,
    bool xpBannerConsumed = false,
    required int myScore,
    required int opponentScore,
    required String opponentName,
    required VoidCallback onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'انتهت المباراة!',
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              isDraw
                  ? Icons.handshake
                  : (isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied),
              size: 60,
              color: isDraw
                  ? Colors.blue
                  : (isWinner ? AppTheme.accentColor : Colors.red),
            ),
            const SizedBox(height: 16),

            // Result Title
            Text(
              isDraw ? 'تعادل!' : (isWinner ? '🎉 أنت الفائز!' : 'حظاً أوفر..'),
              style: TextStyle(
                color: isDraw
                    ? Colors.blue
                    : (isWinner ? Colors.green : Colors.red),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 10),

            // Trophies and Coins badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: (effectiveDelta >= 0 ? Colors.amber : Colors.redAccent)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (effectiveDelta >= 0 ? Colors.amber : Colors.redAccent)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${effectiveDelta >= 0 ? "+$effectiveDelta" : "$effectiveDelta"} 🏆 الكؤوس${totalTrophies != null ? " ($totalTrophies)" : ""}',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
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
            const SizedBox(height: 16),

            // Scores comparison card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // My Score
                  Column(
                    children: [
                      const Text(
                        'أنت',
                        style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
                      ),
                      Text(
                        '$myScore',
                        style: const TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  Container(
                    width: 2,
                    height: 50,
                    color: Colors.white24,
                  ),

                  // Opponent Score
                  Column(
                    children: [
                      Text(
                        opponentName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        '$opponentScore',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.primaryDark,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                SoundService().playClick();
                Navigator.of(context).pop();
                onDismiss();
              },
              child: const Text(
                'العودة للرئيسية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
