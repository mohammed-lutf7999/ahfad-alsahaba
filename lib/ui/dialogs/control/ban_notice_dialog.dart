import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/app_control_service.dart';
import 'royal_control_dialog_shell.dart';

Future<bool?> showAccountBannedNoticeDialog(
  BuildContext context, {
  required PlayerPermissions initialPermissions,
}) {
  var currentPerms = initialPermissions;
  var checking = false;
  String? statusNote;

  String formatBanDuration(DateTime? until) {
    if (until == null) return 'المدة: حظر دائم من الإدارة';
    final local = until.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'ينتهي الحظر في: $y-$m-$d الساعة $hh:$mm';
  }

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final reason = currentPerms.banReason.trim().isNotEmpty
              ? currentPerms.banReason.trim()
              : 'مخالفة شروط وضوابط المنصة.';
          final body =
              'تم إيقاف هذا الحساب مؤقتاً أو دائماً من إدارة التطبيق.\n'
              'السبب: $reason\n'
              '${formatBanDuration(currentPerms.bannedUntil)}';
          return PopScope(
            canPop: false,
            child: RoyalControlDialogShell(
              icon: Icons.gpp_bad_rounded,
              accent: Colors.redAccent,
              badgeText: 'الحساب محظور 🚫',
              title: 'تعذر دخول الحساب حالياً',
              body: body,
              statusNote: statusNote,
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('banned_dialog_retry_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: checking
                        ? null
                        : () async {
                            SoundService().playClick();
                            setDialogState(() {
                              checking = true;
                              statusNote = 'جاري التحقق من حالة الحساب...';
                            });
                            final fresh = await AppControlService.instance
                                .syncControlState(force: true);
                            if (!dialogCtx.mounted) return;
                            if (fresh.isAdmin ||
                                !fresh.playerPermissions
                                    .isEffectivelyBannedNow) {
                              Navigator.of(dialogCtx).pop(true);
                              return;
                            }
                            setDialogState(() {
                              checking = false;
                              currentPerms = fresh.playerPermissions;
                              statusNote =
                                  'لا يزال الحظر سارياً على الحساب حالياً.';
                            });
                          },
                    icon: checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'إعادة التحقق الآن',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
