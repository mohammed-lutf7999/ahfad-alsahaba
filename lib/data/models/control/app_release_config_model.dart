import '../../../core/app_constants.dart';
import 'app_events_announcements_models.dart';
import 'app_feature_flags_model.dart';
import 'player_permissions_model.dart';

/// Release, maintenance, and feature-flag configuration pulled from `app_release_config`.
class AppReleaseConfig {
  final String platform;
  final int minVersionCode;
  final int latestVersionCode;
  final String latestVersionName;
  final String updateTitle;
  final String updateMessage;
  final String updateUrl;
  final bool maintenanceMode;
  final String maintenanceTitle;
  final String maintenanceMessage;
  final AppFeatureFlags featureFlags;
  final int configVersion;
  final int cmsVersion;
  final DateTime? updatedAt;

  const AppReleaseConfig({
    this.platform = 'android',
    this.minVersionCode = 1,
    this.latestVersionCode = AppConstants.appBuildNumber,
    this.latestVersionName = AppConstants.appVersion,
    this.updateTitle = 'تحديث جديد متاح',
    this.updateMessage =
        'أضفنا تحسينات ومحتوى جديداً لتجربة أفضل. حدّث التطبيق الآن.',
    this.updateUrl = AppConstants.playStoreWebUrl,
    this.maintenanceMode = false,
    this.maintenanceTitle = 'صيانة وتحسينات مؤقتة',
    this.maintenanceMessage =
        'نعمل الآن على ترقية الخوادم وإضافة أسئلة جديدة. نعود قريباً بإذن الله.',
    this.featureFlags = const AppFeatureFlags(),
    this.configVersion = 1,
    this.cmsVersion = 1,
    this.updatedAt,
  });

  bool isForceUpdateRequired(int currentVersionCode) =>
      currentVersionCode > 0 && currentVersionCode < minVersionCode;

  bool isOptionalUpdateAvailable(int currentVersionCode) =>
      !isForceUpdateRequired(currentVersionCode) &&
      currentVersionCode > 0 &&
      currentVersionCode < latestVersionCode;

  factory AppReleaseConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const AppReleaseConfig();
    final flagsRaw = json['feature_flags'];
    return AppReleaseConfig(
      platform: (json['platform'] as String?) ?? 'android',
      minVersionCode: (json['min_version_code'] as num?)?.toInt() ?? 1,
      latestVersionCode: (json['latest_version_code'] as num?)?.toInt() ??
          AppConstants.appBuildNumber,
      latestVersionName:
          (json['latest_version_name'] as String?) ?? AppConstants.appVersion,
      updateTitle: (json['update_title'] as String?) ?? 'تحديث جديد متاح',
      updateMessage: (json['update_message'] as String?) ??
          'أضفنا تحسينات ومحتوى جديداً لتجربة أفضل. حدّث التطبيق الآن.',
      updateUrl: (json['update_url'] as String?) ?? AppConstants.playStoreWebUrl,
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceTitle:
          (json['maintenance_title'] as String?) ?? 'صيانة وتحسينات مؤقتة',
      maintenanceMessage: (json['maintenance_message'] as String?) ??
          'نعمل الآن على ترقية الخوادم وإضافة أسئلة جديدة. نعود قريباً بإذن الله.',
      featureFlags: flagsRaw is Map
          ? AppFeatureFlags.fromJson(Map<String, dynamic>.from(flagsRaw))
          : const AppFeatureFlags(),
      configVersion: (json['config_version'] as num?)?.toInt() ?? 1,
      cmsVersion: (json['cms_version'] as num?)?.toInt() ?? 1,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'min_version_code': minVersionCode,
        'latest_version_code': latestVersionCode,
        'latest_version_name': latestVersionName,
        'update_title': updateTitle,
        'update_message': updateMessage,
        'update_url': updateUrl,
        'maintenance_mode': maintenanceMode,
        'maintenance_title': maintenanceTitle,
        'maintenance_message': maintenanceMessage,
        'feature_flags': featureFlags.toJson(),
        'config_version': configVersion,
        'cms_version': cmsVersion,
        'updated_at': updatedAt?.toIso8601String(),
      };
}

/// Locally cached complete snapshot hydrated at 0ms on app startup.
class AppControlSnapshot {
  final int configVersion;
  final int cmsVersion;
  final bool isAdmin;
  final PlayerPermissions playerPermissions;
  final AppReleaseConfig releaseConfig;
  final AppDynamicEvent? activeEvent;
  final List<AppAnnouncement> announcements;
  final DateTime? syncedAt;

  const AppControlSnapshot({
    this.configVersion = 0,
    this.cmsVersion = 1,
    this.isAdmin = false,
    this.playerPermissions = const PlayerPermissions(),
    this.releaseConfig = const AppReleaseConfig(),
    this.activeEvent,
    this.announcements = const [],
    this.syncedAt,
  });

  factory AppControlSnapshot.defaults() => const AppControlSnapshot();

  factory AppControlSnapshot.fromJson(Map<String, dynamic> json) {
    final releaseRaw = json['release_config'];
    final eventRaw = json['active_event'];
    final annRaw = json['announcements'];
    final permsRaw = json['player_permissions'];
    final parsedRelease = releaseRaw is Map
        ? AppReleaseConfig.fromJson(Map<String, dynamic>.from(releaseRaw))
        : const AppReleaseConfig();
    return AppControlSnapshot(
      configVersion: (json['config_version'] as num?)?.toInt() ?? 0,
      cmsVersion:
          (json['cms_version'] as num?)?.toInt() ?? parsedRelease.cmsVersion,
      isAdmin: json['is_admin'] as bool? ?? false,
      playerPermissions: permsRaw is Map
          ? PlayerPermissions.fromJson(Map<String, dynamic>.from(permsRaw))
          : const PlayerPermissions(),
      releaseConfig: parsedRelease,
      activeEvent: eventRaw is Map
          ? AppDynamicEvent.fromJson(Map<String, dynamic>.from(eventRaw))
          : null,
      announcements: annRaw is List
          ? annRaw
              .whereType<Map>()
              .map((m) => AppAnnouncement.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString())
          : null,
    );
  }

  AppControlSnapshot copyWith({
    int? configVersion,
    int? cmsVersion,
    bool? isAdmin,
    PlayerPermissions? playerPermissions,
    AppReleaseConfig? releaseConfig,
    AppDynamicEvent? activeEvent,
    bool clearActiveEvent = false,
    List<AppAnnouncement>? announcements,
    DateTime? syncedAt,
  }) {
    return AppControlSnapshot(
      configVersion: configVersion ?? this.configVersion,
      cmsVersion: cmsVersion ?? this.cmsVersion,
      isAdmin: isAdmin ?? this.isAdmin,
      playerPermissions: playerPermissions ?? this.playerPermissions,
      releaseConfig: releaseConfig ?? this.releaseConfig,
      activeEvent: clearActiveEvent ? null : (activeEvent ?? this.activeEvent),
      announcements: announcements ?? this.announcements,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'config_version': configVersion,
        'cms_version': cmsVersion,
        'is_admin': isAdmin,
        'player_permissions': playerPermissions.toJson(),
        'release_config': releaseConfig.toJson(),
        'active_event': activeEvent?.toJson(),
        'announcements': announcements.map((a) => a.toJson()).toList(),
        'synced_at': syncedAt?.toIso8601String(),
      };
}
