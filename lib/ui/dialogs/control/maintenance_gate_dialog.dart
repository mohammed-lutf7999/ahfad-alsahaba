import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/app_control_service.dart';
import 'royal_control_dialog_shell.dart';

enum MaintenanceDialogResult { resolved, adminBypass }

Future<MaintenanceDialogResult?> showMaintenanceGateDialog(
  BuildContext context, {
  required AppReleaseConfig initialConfig,
  required bool isAdmin,
}) {
  var currentConfig = initialConfig;
  var currentIsAdmin = isAdmin;
  var checking = false;
  String? statusNote;

  return showDialog<MaintenanceDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return PopScope(
            canPop: false,
            child: RoyalControlDialogShell(
              icon: Icons.engineering_rounded,
              accent: const Color(0xFFF59E0B),
              badgeText: 'وضع الصيانة المؤقت',
              title: currentConfig.maintenanceTitle,
              body: currentConfig.maintenanceMessage,
              statusNote: statusNote,
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: AppTheme.primaryDark,
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
                              statusNote = 'جاري التحقق من حالة الخادم...';
                            });
                            final fresh = await AppControlService.instance
                                .syncControlState(force: true);
                            if (!dialogCtx.mounted) return;
                            if (!fresh.releaseConfig.maintenanceMode) {
                              Navigator.of(dialogCtx).pop(
                                MaintenanceDialogResult.resolved,
                              );
                              return;
                            }
                            setDialogState(() {
                              checking = false;
                              currentConfig = fresh.releaseConfig;
                              currentIsAdmin = fresh.isAdmin;
                              statusNote =
                                  'لا تزال أعمال الصيانة جارية، يرجى المحاولة بعد قليل.';
                            });
                          },
                    icon: checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryDark,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'إعادة المحاولة الآن',
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
                if (currentIsAdmin) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentLight,
                        side: BorderSide(
                          color: AppTheme.accentColor.withValues(alpha: 0.7),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        SoundService().playClick();
                        Navigator.of(dialogCtx).pop(
                          MaintenanceDialogResult.adminBypass,
                        );
                      },
                      icon: const Icon(Icons.verified_user_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'تجاوز الصيانة (دخول المشرف)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
