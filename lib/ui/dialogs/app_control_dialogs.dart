import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/app_control_models.dart';
import '../../data/services/app_control_service.dart';
import '../screens/dynamic_event_detail_screen.dart';

enum MaintenanceDialogResult { resolved, adminBypass }

/// Coordinates remote gates (`Maintenance` -> `Force Update` -> `Announcements`
/// -> `Optional Update`) cleanly without overlapping dialogs or stalling startup.
class AppControlCoordinator {
  static final AppControlCoordinator instance = AppControlCoordinator._internal();
  AppControlCoordinator._internal();

  bool _isDialogOpen = false;
  bool _adminMaintenanceBypassed = false;
  bool _appReadyForGates = false;

  bool get isDialogOpen => _isDialogOpen;
  bool get isAdminMaintenanceBypassed => _adminMaintenanceBypassed;
  bool get isAppReadyForGates => _appReadyForGates;

  void markAppReadyForGates() {
    _appReadyForGates = true;
  }

  @visibleForTesting
  void resetForTesting() {
    _isDialogOpen = false;
    _adminMaintenanceBypassed = false;
    _appReadyForGates = false;
  }

  /// Syncs control state (respecting 15m TTL & cache) and presents the highest-priority
  /// gate/dialog if needed. Returns `true` when at least one modal was presented
  /// (so callers like [HomeScreen] can defer overlapping tutorials cleanly).
  Future<bool> checkAndPresent(
    BuildContext context, {
    bool force = false,
    bool allowOptionalUpdate = true,
  }) async {
    if (_isDialogOpen || !context.mounted) {
      return _isDialogOpen;
    }

    _isDialogOpen = true;
    bool presentedAny = false;

    try {
      final service = AppControlService.instance;
      final snap = await service.syncControlState(force: force);
      service.refreshTimedVisualState();

      if (!context.mounted) return presentedAny;

      // 1. Maintenance Mode Gate (highest priority)
      if (!snap.releaseConfig.maintenanceMode) {
        _adminMaintenanceBypassed = false;
      } else if (!(snap.isAdmin && _adminMaintenanceBypassed)) {
        presentedAny = true;
        final result = await AppControlDialogs.showMaintenanceDialog(
          context,
          initialConfig: snap.releaseConfig,
          isAdmin: snap.isAdmin,
        );
        if (result == MaintenanceDialogResult.adminBypass) {
          _adminMaintenanceBypassed = true;
        }
        if (!context.mounted) return presentedAny;
      }

      // Re-read current snapshot in case retry inside MaintenanceDialog updated it
      final afterMaint = service.snapshot;
      if (afterMaint.releaseConfig.maintenanceMode &&
          !(afterMaint.isAdmin && _adminMaintenanceBypassed)) {
        return true;
      }

      // 2. Force Update Gate (unclosable while versionCode < minVersionCode)
      final buildNumber = service.effectiveBuildNumber;
      if (afterMaint.releaseConfig.isForceUpdateRequired(buildNumber)) {
        presentedAny = true;
        await AppControlDialogs.showForceUpdateDialog(
          context,
          config: afterMaint.releaseConfig,
        );
        return true;
      }

      // 3. Unread Targeted & Global Announcements (sequential, no overlap)
      final pending = List<AppAnnouncement>.from(
        service.pendingAnnouncementsNotifier.value,
      );
      for (final ann in pending) {
        if (!context.mounted) break;
        presentedAny = true;
        final triggeredCta = await AppControlDialogs.showAnnouncementDialog(
          context,
          announcement: ann,
        );
        if (triggeredCta == true &&
            ann.ctaRoute != null &&
            ann.ctaRoute!.trim().isNotEmpty &&
            context.mounted) {
          await AppControlVisuals.handleRouteOrUrl(context, ann.ctaRoute);
        }
      }

      if (!context.mounted) return presentedAny;

      // 4. Optional Update Prompt (max once per 24h)
      if (allowOptionalUpdate &&
          service.shouldPromptOptionalUpdate(currentVersionCode: buildNumber)) {
        presentedAny = true;
        await AppControlDialogs.showOptionalUpdateDialog(
          context,
          config: service.snapshot.releaseConfig,
        );
      }

      return presentedAny;
    } finally {
      _isDialogOpen = false;
    }
  }
}

/// Protected, Edge-to-Edge & 360dp-safe dialogs for App Control & Announcements.
class AppControlDialogs {
  AppControlDialogs._();

  static Future<MaintenanceDialogResult?> showMaintenanceDialog(
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
              child: _RoyalControlDialogShell(
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

  static Future<void> showForceUpdateDialog(
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
              child: _RoyalControlDialogShell(
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

  static Future<void> showOptionalUpdateDialog(
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
            return _RoyalControlDialogShell(
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

  static Future<bool?> showAnnouncementDialog(
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
          child: _RoyalControlDialogShell(
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

  static _AnnouncementStyle _styleForAnnouncement(AppAnnouncement ann) {
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
}

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

class _RoyalControlDialogShell extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String badgeText;
  final String title;
  final String body;
  final String? statusNote;
  final List<Widget> actions;

  const _RoyalControlDialogShell({
    required this.icon,
    required this.accent,
    required this.badgeText,
    required this.title,
    required this.body,
    this.statusNote,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return SafeArea(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: (constraints.maxHeight - 32).clamp(260.0, 680.0),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: customTheme.deepBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withValues(alpha: 0.18),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Icon(icon, color: accent, size: 30),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  badgeText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 13.5,
                                fontFamily: 'Cairo',
                                height: 1.65,
                              ),
                            ),
                            if (statusNote != null &&
                                statusNote!.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  statusNote!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            ...actions,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
