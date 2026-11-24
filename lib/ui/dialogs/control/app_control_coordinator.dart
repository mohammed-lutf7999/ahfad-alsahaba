import 'package:flutter/material.dart';

import '../../../data/models/app_control_models.dart';
import '../../../data/services/app_control_service.dart';
import '../../screens/dynamic_event_detail_screen.dart';
import '../app_control_dialogs.dart';

/// Coordinates remote gates (`Maintenance` -> `Ban` -> `Force Update` ->
/// `Announcements` -> `Optional Update`) cleanly without overlapping dialogs
/// or stalling startup.
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

      // 1.5 Account Suspension / Ban Gate (unclosable for banned non-admins)
      if (!afterMaint.isAdmin &&
          afterMaint.playerPermissions.isEffectivelyBannedNow) {
        presentedAny = true;
        await AppControlDialogs.showAccountBannedDialog(
          context,
          initialPermissions: afterMaint.playerPermissions,
        );
        if (!context.mounted) return true;
        final afterBanCheck = service.snapshot;
        if (!afterBanCheck.isAdmin &&
            afterBanCheck.playerPermissions.isEffectivelyBannedNow) {
          return true;
        }
      }

      // Re-read current snapshot in case retry inside BanDialog updated config
      final afterBan = service.snapshot;

      // 2. Force Update Gate (unclosable while versionCode < minVersionCode)
      final buildNumber = service.effectiveBuildNumber;
      if (afterBan.releaseConfig.isForceUpdateRequired(buildNumber)) {
        presentedAny = true;
        await AppControlDialogs.showForceUpdateDialog(
          context,
          config: afterBan.releaseConfig,
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
