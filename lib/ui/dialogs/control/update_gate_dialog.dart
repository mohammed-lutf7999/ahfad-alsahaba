import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/app_control_service.dart';
import 'royal_control_dialog_shell.dart';

Future<void> showForceUpdateGateDialog(
  BuildContext context, {
  required AppReleaseConfig config,
}) {
  var updating = false;
  String? statusNote;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return PopScope(
            canPop: false,
            child: RoyalControlDialogShell(
              icon: Icons.system_update_rounded,
              accent: const Color(0xFFE11D48),
              badgeText: 'تحديث إلزامي — الإصدار ${config.latestVersionName}',
              title: config.updateTitle,
              body: config.updateMessage,
              statusNote: statusNote,
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: updating
                        ? null
                        : () async {
                            SoundService().playClick();
                            setDialogState(() {
                              updating = true;
                              statusNote = 'جاري التواصل مع Google Play...';
                            });
                            final outcome = await AppControlService.instance
                                .performUpdate(
                              isForced: true,
                              customStoreUrl: config.updateUrl,
                            );
                            if (!dialogCtx.mounted) return;
                            // Keep dialog OPEN regardless of outcome (including userDeniedUpdate)
                            setDialogState(() {
                              updating = false;
                              switch (outcome) {
                                case AppUpdateOutcome.cancelledByUser:
                                  statusNote =
                                      'هذا التحديث إلزامي للمتابعة؛ يرجى إتمام التحديث من المتجر.';
                                  break;
                                case AppUpdateOutcome.storeOpened:
                                  statusNote =
                                      'تم فتح صفحة التطبيق في المتجر؛ حدّث ثم أعد فتح اللعبة.';
                                  break;
                                case AppUpdateOutcome.failed:
                                  statusNote =
                                      'تعذر فتح المتجر تلقائياً؛ يرجى التحديث من متجر Google Play.';
                                  break;
                                case AppUpdateOutcome.updated:
                                  statusNote = 'جاري تثبيت التحديث الجديد...';
                                  break;
                              }
                            });
                          },
                    icon: updating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'تحديث الآن',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
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

Future<void> showOptionalUpdatePromptDialog(
  BuildContext context, {
  required AppReleaseConfig config,
}) {
  var updating = false;
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return RoyalControlDialogShell(
            icon: Icons.new_releases_rounded,
            accent: AppTheme.accentColor,
            badgeText: 'تحديث جديد ${config.latestVersionName}',
            title: config.updateTitle,
            body: config.updateMessage,
            actions: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: updating
                      ? null
                      : () async {
                          SoundService().playClick();
                          setDialogState(() => updating = true);
                          await AppControlService.instance
                              .markOptionalUpdatePrompted();
                          await AppControlService.instance.performUpdate(
                            isForced: false,
                            customStoreUrl: config.updateUrl,
                          );
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                        },
                  icon: const Icon(Icons.upgrade_rounded, size: 20),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'تحديث الآن',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () async {
                    SoundService().playClick();
                    await AppControlService.instance
                        .markOptionalUpdatePrompted();
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                  },
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'لاحقاً',
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
          );
        },
      );
    },
  );
}
