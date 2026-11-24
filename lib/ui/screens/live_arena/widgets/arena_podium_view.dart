import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/live_session_model.dart';

class ArenaPodiumView extends StatelessWidget {
  final bool isFinished;
  final List<LiveParticipantModel> board;

  const ArenaPodiumView({
    super.key,
    required this.isFinished,
    required this.board,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isFinished
              ? 'انتهت البطولة — الترتيب النهائي 🏆'
              : 'جارٍ مزامنة أسئلة البطولة...',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: accent,
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < board.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: customTheme.surfaceCard.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Text(
                  '#${i + 1}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    board[i].displayName,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${board[i].score} ⭐',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ArenaMidRoundRevealCard extends StatelessWidget {
  final List<LiveParticipantModel> board;
  final String? myUserId;

  const ArenaMidRoundRevealCard({
    super.key,
    required this.board,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final myRankIdx =
        myUserId == null ? -1 : board.indexWhere((p) => p.userId == myUserId);

    return Container(
      key: const Key('student_mid_round_reveal_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الترتيب المرحلي المباشر 🏆',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: accent,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (myRankIdx >= 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Text(
                'مرتبتك الحالية: #${myRankIdx + 1} — نقاطك: ${board[myRankIdx].score} ⭐',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (board.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'جارٍ تحديث لوحة الصدارة...',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
              ),
            )
          else
            for (var i = 0; i < board.length && i < 10; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (myUserId != null && board[i].userId == myUserId)
                      ? accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (myUserId != null && board[i].userId == myUserId)
                        ? accent
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '#${i + 1}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        board[i].displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${board[i].score} ⭐',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          const Text(
            'في انتظار طرح السؤال التالي من المعلم...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
