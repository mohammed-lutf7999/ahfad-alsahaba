import '../../models/app_control_models.dart';

/// Pure snapshot sanitizer and structural equality comparator for [AppControlService].
class AppControlSnapshotDiffer {
  AppControlSnapshotDiffer._();

  static AppControlSnapshot sanitizeForNow({
    required AppControlSnapshot raw,
    required DateTime nowUtc,
    required Set<String> seenAnnouncementIds,
    required int buildCode,
  }) {
    final filteredAnnouncements = raw.announcements
        .where(
          (a) =>
              a.id.isNotEmpty &&
              a.isActive &&
              !a.isExpiredAt(nowUtc) &&
              !seenAnnouncementIds.contains(a.id) &&
              a.matchesVersion(buildCode),
        )
        .toList();

    final event = raw.activeEvent;
    final eventNotExpired = event != null &&
        event.isActive &&
        (event.endsAt == null || nowUtc.isBefore(event.endsAt!.toUtc()));

    return AppControlSnapshot(
      configVersion: raw.configVersion,
      cmsVersion: raw.cmsVersion,
      isAdmin: raw.isAdmin,
      playerPermissions: raw.playerPermissions,
      releaseConfig: raw.releaseConfig,
      activeEvent: eventNotExpired ? event : null,
      announcements: filteredAnnouncements,
      syncedAt: raw.syncedAt,
    );
  }

  static bool sameReleaseConfig(AppReleaseConfig a, AppReleaseConfig b) {
    return a.platform == b.platform &&
        a.minVersionCode == b.minVersionCode &&
        a.latestVersionCode == b.latestVersionCode &&
        a.latestVersionName == b.latestVersionName &&
        a.updateTitle == b.updateTitle &&
        a.updateMessage == b.updateMessage &&
        a.updateUrl == b.updateUrl &&
        a.maintenanceMode == b.maintenanceMode &&
        a.maintenanceTitle == b.maintenanceTitle &&
        a.maintenanceMessage == b.maintenanceMessage &&
        a.configVersion == b.configVersion &&
        a.cmsVersion == b.cmsVersion &&
        a.updatedAt == b.updatedAt &&
        sameBoolMaps(a.featureFlags.toJson(), b.featureFlags.toJson());
  }

  static bool sameBoolMaps(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool sameAnnouncements(
    List<AppAnnouncement> a,
    List<AppAnnouncement> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].body != b[i].body ||
          a[i].messageType != b[i].messageType ||
          a[i].isDismissible != b[i].isDismissible) {
        return false;
      }
    }
    return true;
  }

  static bool samePlayerPermissions(PlayerPermissions a, PlayerPermissions b) {
    return a.isBanned == b.isBanned &&
        a.bannedUntil == b.bannedUntil &&
        a.banReason == b.banReason &&
        a.isDiwanMuted == b.isDiwanMuted &&
        a.diwanMutedUntil == b.diwanMutedUntil &&
        a.diwanMuteReason == b.diwanMuteReason &&
        a.canUseOnline == b.canUseOnline &&
        a.canUseDiwan == b.canUseDiwan &&
        a.canUseGuilds == b.canUseGuilds &&
        a.canHostLiveArenas == b.canHostLiveArenas &&
        a.effectiveCanHostLiveArenas == b.effectiveCanHostLiveArenas &&
        a.notes == b.notes;
  }
}
