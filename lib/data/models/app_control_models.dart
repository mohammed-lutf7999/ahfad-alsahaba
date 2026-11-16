import '../models/player_profile_model.dart';
import '../../core/app_constants.dart';

/// Feature toggles controlled remotely via `app_release_config.feature_flags`.
class AppFeatureFlags {
  final bool onlineMultiplayer;
  final bool ghostMatches;
  final bool privateRooms;
  final bool knightsStore;
  final bool showEventBanner;
  final bool dailyChallenges;
  final Map<String, bool> rawFlags;

  const AppFeatureFlags({
    this.onlineMultiplayer = true,
    this.ghostMatches = true,
    this.privateRooms = true,
    this.knightsStore = true,
    this.showEventBanner = true,
    this.dailyChallenges = true,
    this.rawFlags = const {
      'online_multiplayer': true,
      'ghost_matches': true,
      'private_rooms': true,
      'knights_store': true,
      'show_event_banner': true,
      'daily_challenges': true,
    },
  });

  factory AppFeatureFlags.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const AppFeatureFlags();
    final map = <String, bool>{};
    for (final entry in json.entries) {
      final v = entry.value;
      if (v is bool) {
        map[entry.key] = v;
      } else if (v is String) {
        map[entry.key] = v.toLowerCase() == 'true';
      }
    }
    return AppFeatureFlags(
      onlineMultiplayer: map['online_multiplayer'] ?? true,
      ghostMatches: map['ghost_matches'] ?? true,
      privateRooms: map['private_rooms'] ?? true,
      knightsStore: map['knights_store'] ?? true,
      showEventBanner: map['show_event_banner'] ?? true,
      dailyChallenges: map['daily_challenges'] ?? true,
      rawFlags: map.isEmpty ? const AppFeatureFlags().rawFlags : map,
    );
  }

  bool isEnabled(String key, {bool defaultValue = true}) =>
      rawFlags[key] ?? defaultValue;

  Map<String, dynamic> toJson() => {
        ...rawFlags,
        'online_multiplayer': onlineMultiplayer,
        'ghost_matches': ghostMatches,
        'private_rooms': privateRooms,
        'knights_store': knightsStore,
        'show_event_banner': showEventBanner,
        'daily_challenges': dailyChallenges,
      };
}

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

enum DynamicEventActionType {
  openEventScreen('open_event_screen'),
  navigateRoute('navigate_route'),
  openUrl('open_url'),
  none('none');

  final String wireName;
  const DynamicEventActionType(this.wireName);

  static DynamicEventActionType fromWire(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? 'open_event_screen';
    return DynamicEventActionType.values.firstWhere(
      (e) => e.wireName == normalized,
      orElse: () => DynamicEventActionType.openEventScreen,
    );
  }
}

/// Cloud-controlled event displayed as a banner on HomeScreen and opened in-app.
class AppDynamicEvent {
  final String id;
  final String badgeText;
  final String title;
  final String subtitle;
  final String body;
  final String ctaLabel;
  final DynamicEventActionType actionType;
  final String actionTarget;
  final String themeColorHex;
  final String iconName;
  final int priority;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? updatedAt;

  const AppDynamicEvent({
    required this.id,
    this.badgeText = 'حدث نشط',
    required this.title,
    this.subtitle = '',
    this.body = '',
    this.ctaLabel = 'اكتشف الآن',
    this.actionType = DynamicEventActionType.openEventScreen,
    this.actionTarget = '',
    this.themeColorHex = '#D4AF37',
    this.iconName = 'auto_awesome',
    this.priority = 100,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    this.updatedAt,
  });

  bool isCurrentlyActiveAt(DateTime nowUtc) {
    if (!isActive) return false;
    if (startsAt != null && nowUtc.isBefore(startsAt!.toUtc())) return false;
    if (endsAt != null && !nowUtc.isBefore(endsAt!.toUtc())) return false;
    return true;
  }

  factory AppDynamicEvent.fromJson(Map<String, dynamic> json) {
    return AppDynamicEvent(
      id: json['id']?.toString() ?? '',
      badgeText: (json['badge_text'] as String?) ?? 'حدث نشط',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      ctaLabel: (json['cta_label'] as String?) ?? 'اكتشف الآن',
      actionType:
          DynamicEventActionType.fromWire(json['action_type'] as String?),
      actionTarget: (json['action_target'] as String?) ?? '',
      themeColorHex: (json['theme_color_hex'] as String?) ?? '#D4AF37',
      iconName: (json['icon_name'] as String?) ?? 'auto_awesome',
      priority: (json['priority'] as num?)?.toInt() ?? 100,
      isActive: json['is_active'] as bool? ?? true,
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'badge_text': badgeText,
        'title': title,
        'subtitle': subtitle,
        'body': body,
        'cta_label': ctaLabel,
        'action_type': actionType.wireName,
        'action_target': actionTarget,
        'theme_color_hex': themeColorHex,
        'icon_name': iconName,
        'priority': priority,
        'is_active': isActive,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

enum AnnouncementType {
  normal('normal'),
  mandatory('mandatory'),
  admin('admin'),
  motivational('motivational');

  final String wireName;
  const AnnouncementType(this.wireName);

  static AnnouncementType fromWire(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? 'normal';
    return AnnouncementType.values.firstWhere(
      (t) => t.wireName == normalized,
      orElse: () => AnnouncementType.normal,
    );
  }
}

/// Admin announcement or direct targeted player message.
class AppAnnouncement {
  final String id;
  final String title;
  final String body;
  final AnnouncementType messageType;
  final String targetScope;
  final String? targetUserId;
  final String? targetPlayerCode;
  final String? ctaLabel;
  final String? ctaRoute;
  final bool isDismissible;
  final bool isActive;
  final int? minVersionCode;
  final int? maxVersionCode;
  final int receiptCount;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    this.messageType = AnnouncementType.normal,
    this.targetScope = 'all',
    this.targetUserId,
    this.targetPlayerCode,
    this.ctaLabel,
    this.ctaRoute,
    this.isDismissible = true,
    this.isActive = true,
    this.minVersionCode,
    this.maxVersionCode,
    this.receiptCount = 0,
    this.expiresAt,
    this.createdAt,
  });

  bool get requiresBlockingGate =>
      messageType == AnnouncementType.mandatory || !isDismissible;

  bool isExpiredAt(DateTime nowUtc) =>
      expiresAt != null && !nowUtc.isBefore(expiresAt!.toUtc());

  bool matchesVersion(int versionCode) {
    if (versionCode <= 0) return true;
    if (minVersionCode != null && versionCode < minVersionCode!) return false;
    if (maxVersionCode != null && versionCode > maxVersionCode!) return false;
    return true;
  }

  AppAnnouncement copyWith({
    String? id,
    String? title,
    String? body,
    AnnouncementType? messageType,
    String? targetScope,
    String? targetUserId,
    String? targetPlayerCode,
    String? ctaLabel,
    String? ctaRoute,
    bool? isDismissible,
    bool? isActive,
    int? minVersionCode,
    int? maxVersionCode,
    int? receiptCount,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return AppAnnouncement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      messageType: messageType ?? this.messageType,
      targetScope: targetScope ?? this.targetScope,
      targetUserId: targetUserId ?? this.targetUserId,
      targetPlayerCode: targetPlayerCode ?? this.targetPlayerCode,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      ctaRoute: ctaRoute ?? this.ctaRoute,
      isDismissible: isDismissible ?? this.isDismissible,
      isActive: isActive ?? this.isActive,
      minVersionCode: minVersionCode ?? this.minVersionCode,
      maxVersionCode: maxVersionCode ?? this.maxVersionCode,
      receiptCount: receiptCount ?? this.receiptCount,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppAnnouncement.fromJson(Map<String, dynamic> json) {
    return AppAnnouncement(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      messageType:
          AnnouncementType.fromWire(json['message_type'] as String?),
      targetScope: (json['target_scope'] as String?) ?? 'all',
      targetUserId: json['target_user_id']?.toString(),
      targetPlayerCode: json['target_player_code'] as String?,
      ctaLabel: json['cta_label'] as String?,
      ctaRoute: json['cta_route'] as String?,
      isDismissible: json['is_dismissible'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      minVersionCode: (json['min_version_code'] as num?)?.toInt(),
      maxVersionCode: (json['max_version_code'] as num?)?.toInt(),
      receiptCount: (json['receipt_count'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'message_type': messageType.wireName,
        'target_scope': targetScope,
        'target_user_id': targetUserId,
        'target_player_code': targetPlayerCode,
        'cta_label': ctaLabel,
        'cta_route': ctaRoute,
        'is_dismissible': isDismissible,
        'is_active': isActive,
        'min_version_code': minVersionCode,
        'max_version_code': maxVersionCode,
        'receipt_count': receiptCount,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}

/// Locally cached complete snapshot hydrated at 0ms on app startup.
class AppControlSnapshot {
  final int configVersion;
  final int cmsVersion;
  final bool isAdmin;
  final AppReleaseConfig releaseConfig;
  final AppDynamicEvent? activeEvent;
  final List<AppAnnouncement> announcements;
  final DateTime? syncedAt;

  const AppControlSnapshot({
    this.configVersion = 0,
    this.cmsVersion = 1,
    this.isAdmin = false,
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
    final parsedRelease = releaseRaw is Map
        ? AppReleaseConfig.fromJson(Map<String, dynamic>.from(releaseRaw))
        : const AppReleaseConfig();
    return AppControlSnapshot(
      configVersion: (json['config_version'] as num?)?.toInt() ?? 0,
      cmsVersion:
          (json['cms_version'] as num?)?.toInt() ?? parsedRelease.cmsVersion,
      isAdmin: json['is_admin'] as bool? ?? false,
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
        'release_config': releaseConfig.toJson(),
        'active_event': activeEvent?.toJson(),
        'announcements': announcements.map((a) => a.toJson()).toList(),
        'synced_at': syncedAt?.toIso8601String(),
      };
}

/// Overview statistics shown at the top of the Admin Dashboard (in-app & web).
class AdminOverview {
  final int totalAccounts;
  final int directoryPlayers;
  final int guestPlayers;
  final int active24h;
  final int activeEvents;
  final int activeAnnouncements;
  final AppReleaseConfig releaseConfig;

  const AdminOverview({
    this.totalAccounts = 0,
    this.directoryPlayers = 0,
    this.guestPlayers = 0,
    this.active24h = 0,
    this.activeEvents = 0,
    this.activeAnnouncements = 0,
    this.releaseConfig = const AppReleaseConfig(),
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    final rcRaw = json['release_config'];
    return AdminOverview(
      totalAccounts: (json['total_accounts'] as num?)?.toInt() ?? 0,
      directoryPlayers: (json['directory_players'] as num?)?.toInt() ?? 0,
      guestPlayers: (json['guest_players'] as num?)?.toInt() ?? 0,
      active24h: (json['active_24h'] as num?)?.toInt() ?? 0,
      activeEvents: (json['active_events'] as num?)?.toInt() ?? 0,
      activeAnnouncements:
          (json['active_announcements'] as num?)?.toInt() ?? 0,
      releaseConfig: rcRaw is Map
          ? AppReleaseConfig.fromJson(Map<String, dynamic>.from(rcRaw))
          : const AppReleaseConfig(),
    );
  }
}

/// Result row from `admin_search_users` spanning both Google accounts & SAH-XXXX guests.
class AdminPlayerSearchResult {
  final String? userId;
  final String? playerCode;
  final String displayName;
  final String? email;
  final int trophies;
  final int playerLevel;
  final int totalScore;
  final String? platform;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final bool isGuest;

  const AdminPlayerSearchResult({
    this.userId,
    this.playerCode,
    required this.displayName,
    this.email,
    this.trophies = 1000,
    this.playerLevel = 1,
    this.totalScore = 0,
    this.platform,
    this.appVersion,
    this.lastSeenAt,
    this.isGuest = false,
  });

  bool get isTargetable =>
      (userId != null && userId!.isNotEmpty) ||
      PlayerProfile.isValidPlayerCode(playerCode);

  factory AdminPlayerSearchResult.fromJson(Map<String, dynamic> json) {
    return AdminPlayerSearchResult(
      userId: json['user_id']?.toString(),
      playerCode: json['player_code'] as String?,
      displayName: (json['display_name'] as String?) ?? 'لاعب',
      email: json['email'] as String?,
      trophies: (json['trophies'] as num?)?.toInt() ?? 1000,
      playerLevel: (json['player_level'] as num?)?.toInt() ?? 1,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      platform: json['platform'] as String?,
      appVersion: json['app_version'] as String?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())
          : null,
      isGuest: json['is_guest'] as bool? ?? false,
    );
  }
}

