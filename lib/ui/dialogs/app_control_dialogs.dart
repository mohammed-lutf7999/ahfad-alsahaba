import 'package:flutter/material.dart';

import '../../data/models/app_control_models.dart';
import 'control/announcement_popup_dialog.dart';
import 'control/ban_notice_dialog.dart';
import 'control/maintenance_gate_dialog.dart';
import 'control/update_gate_dialog.dart';

export 'control/app_control_coordinator.dart';
export 'control/maintenance_gate_dialog.dart' show MaintenanceDialogResult;

/// Backward-compatible Facade for protected, Edge-to-Edge & 360dp-safe App Control dialogs.
class AppControlDialogs {
  AppControlDialogs._();

  static Future<MaintenanceDialogResult?> showMaintenanceDialog(
    BuildContext context, {
    required AppReleaseConfig initialConfig,
    required bool isAdmin,
  }) =>
      showMaintenanceGateDialog(
        context,
        initialConfig: initialConfig,
        isAdmin: isAdmin,
      );

  static Future<bool?> showAccountBannedDialog(
    BuildContext context, {
    required PlayerPermissions initialPermissions,
  }) =>
      showAccountBannedNoticeDialog(
        context,
        initialPermissions: initialPermissions,
      );

  static Future<void> showForceUpdateDialog(
    BuildContext context, {
    required AppReleaseConfig config,
  }) =>
      showForceUpdateGateDialog(context, config: config);

  static Future<void> showOptionalUpdateDialog(
    BuildContext context, {
    required AppReleaseConfig config,
  }) =>
      showOptionalUpdatePromptDialog(context, config: config);

  static Future<bool?> showAnnouncementDialog(
    BuildContext context, {
    required AppAnnouncement announcement,
  }) =>
      showAnnouncementPopupDialog(context, announcement: announcement);
}
