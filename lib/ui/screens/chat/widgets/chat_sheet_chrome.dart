import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/theme/app_custom_theme.dart';

Future<String?> showChatReportReasonDialog(BuildContext context) {
  const reasons = <String>[
    'ألفاظ غير لائقة',
    'رابط أو إعلان مخالف',
    'إزعاج وتكرار/سبام',
  ];
  return showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppTheme.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'سبب الإبلاغ عن الرسالة 🛡️',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final reason in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(reason),
                  child: Text(
                    reason,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white60),
            ),
          ),
        ],
      ),
    ),
  );
}

class ChatSheetHeader extends StatelessWidget {
  final bool showChallengeButton;
  final bool isSending;
  final VoidCallback onChallenge;
  final VoidCallback onClose;

  const ChatSheetHeader({
    super.key,
    required this.showChallengeButton,
    required this.isSending,
    required this.onChallenge,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Icon(Icons.forum_rounded, color: accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ديوان الأحفاد 💬',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: accent,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'تواصل راقٍ وتحديات سريعة (تُحفظ 24 ساعة)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (showChallengeButton)
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                key: const Key('diwan_challenge_btn'),
                onPressed: isSending ? null : onChallenge,
                icon: const Icon(Icons.sports_kabaddi_rounded, size: 15),
                label: const Text(
                  'تحدّاني',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
