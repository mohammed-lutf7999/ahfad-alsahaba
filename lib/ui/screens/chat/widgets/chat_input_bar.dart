import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/services/app_control_service.dart';

/// Reusable input bar for Diwan & future Guild/Friend Chat (Plan 17).
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isAuthenticated;
  final bool isSending;
  final VoidCallback onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isAuthenticated,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;

    if (!isAuthenticated) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: customTheme.surfaceCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: accent, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'سجّل دخولك بحساب Google من القائمة للمشاركة في الديوان وتحدي الفرسان',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final control = AppControlService.instance;
    final isAdmin = control.isAdminNotifier.value;
    final perms = control.playerPermissionsNotifier.value;
    if (!isAdmin && (!perms.canUseDiwan || perms.isEffectivelyDiwanMutedNow)) {
      final isMuted = perms.isEffectivelyDiwanMutedNow;
      final until = perms.diwanMutedUntil?.toLocal();
      final untilLabel = until != null
          ? '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')} '
            '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}'
          : null;
      final reasonText = perms.diwanMuteReason.trim();
      final statusMessage = !perms.canUseDiwan
          ? 'تم تقييد المشاركة في ديوان الأحفاد على هذا الحساب من الإدارة.'
          : 'تم كتم مشاركتك في الديوان مؤقتاً'
            '${reasonText.isNotEmpty ? ' ($reasonText)' : ''}'
            '${untilLabel != null ? ' — ينتهي: $untilLabel' : ''}.';
      return Container(
        key: const Key('diwan_muted_status_bar'),
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(
              isMuted ? Icons.volume_off_rounded : Icons.block_rounded,
              color: Colors.amberAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusMessage,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('diwan_message_input'),
              controller: controller,
              maxLength: 250,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'اكتب تحية أو رسالة مهذبة...',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: customTheme.surfaceCard.withValues(alpha: 0.85),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.35)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.35)),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 46,
            width: 48,
            child: ElevatedButton(
              key: const Key('diwan_send_btn'),
              onPressed: isSending ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.primaryDark,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
