import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/app_control_service.dart';
import 'royal_control_dialog_shell.dart';

class _AnnouncementStyle {
  final IconData icon;
  final Color accent;
  final Color ctaForeground;
  final String badgeLabel;

  const _AnnouncementStyle({
    required this.icon,
    required this.accent,
    required this.ctaForeground,
    required this.badgeLabel,
  });
}

_AnnouncementStyle _styleForAnnouncement(AppAnnouncement ann) {
  switch (ann.messageType) {
    case AnnouncementType.mandatory:
      return const _AnnouncementStyle(
        icon: Icons.gpp_maybe_rounded,
        accent: Color(0xFFE11D48),
        ctaForeground: Colors.white,
        badgeLabel: 'إشعار إلزامي ⚠️',
      );
    case AnnouncementType.admin:
      return const _AnnouncementStyle(
        icon: Icons.admin_panel_settings_rounded,
        accent: AppTheme.accentColor,
        ctaForeground: AppTheme.primaryDark,
        badgeLabel: 'رسالة إدارية 🛡️',
      );
    case AnnouncementType.motivational:
      return const _AnnouncementStyle(
        icon: Icons.auto_awesome_rounded,
        accent: Color(0xFF10B981),
        ctaForeground: Colors.white,
        badgeLabel: 'رسالة تحفيزية ✨',
      );
    case AnnouncementType.normal:
      return const _AnnouncementStyle(
        icon: Icons.notifications_active_rounded,
        accent: Color(0xFF38BDF8),
        ctaForeground: AppTheme.primaryDark,
        badgeLabel: 'إشعار 📢',
      );
  }
}

Future<bool?> showAnnouncementPopupDialog(
  BuildContext context, {
  required AppAnnouncement announcement,
}) {
  final style = _styleForAnnouncement(announcement);
  final isLocked = announcement.requiresBlockingGate;
  final hasCta = announcement.ctaLabel != null &&
      announcement.ctaLabel!.trim().isNotEmpty &&
      announcement.ctaRoute != null &&
      announcement.ctaRoute!.trim().isNotEmpty;

  return showDialog<bool>(
    context: context,
    barrierDismissible: !isLocked,
    builder: (dialogCtx) {
      var acknowledged = false;

      Future<void> acknowledgeAndClose({bool runCta = false}) async {
        if (acknowledged) return;
        acknowledged = true;
        SoundService().playClick();
        await AppControlService.instance.markAnnouncementSeen(announcement);
        if (!dialogCtx.mounted) return;
        Navigator.of(dialogCtx).pop(runCta && hasCta);
      }

      return PopScope(
        canPop: !isLocked,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && !isLocked && !acknowledged) {
            acknowledged = true;
            unawaited(
              AppControlService.instance.markAnnouncementSeen(announcement),
            );
          }
        },
        child: RoyalControlDialogShell(
          icon: style.icon,
          accent: style.accent,
          badgeText: announcement.targetScope == 'single_user'
              ? '${style.badgeLabel} • موجهة لك'
              : style.badgeLabel,
          title: announcement.title,
          body: announcement.body,
          actions: [
            if (hasCta) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: style.accent,
                    foregroundColor: style.ctaForeground,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => acknowledgeAndClose(runCta: true),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      announcement.ctaLabel!,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: hasCta
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => acknowledgeAndClose(runCta: false),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isLocked ? 'فهمت وأوافق' : 'حسناً',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: style.accent,
                        foregroundColor: style.ctaForeground,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => acknowledgeAndClose(runCta: false),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isLocked ? 'فهمت وأوافق' : 'حسناً',
                          style: const TextStyle(
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
}
