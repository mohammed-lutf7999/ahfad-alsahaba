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
  final bool royalInbox;
  final bool liveAnnouncementPing;
  final bool wiseTeacherMode;
  final bool diwanChat;
  final bool guildsArenas;
  final Map<String, bool> rawFlags;

  const AppFeatureFlags({
    this.onlineMultiplayer = true,
    this.ghostMatches = true,
    this.privateRooms = true,
    this.knightsStore = true,
    this.showEventBanner = true,
    this.dailyChallenges = true,
    this.royalInbox = true,
    this.liveAnnouncementPing = true,
    this.wiseTeacherMode = true,
    this.diwanChat = false,
    this.guildsArenas = false,
    this.rawFlags = const {
      'online_multiplayer': true,
      'ghost_matches': true,
      'private_rooms': true,
      'knights_store': true,
      'show_event_banner': true,
      'daily_challenges': true,
      'royal_inbox': true,
      'live_announcement_ping': true,
      'wise_teacher_mode': true,
      'diwan_chat': false,
      'guilds_arenas': false,
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
      royalInbox: map['royal_inbox'] ?? true,
      liveAnnouncementPing: map['live_announcement_ping'] ?? true,
      wiseTeacherMode: map['wise_teacher_mode'] ?? true,
      diwanChat: map['diwan_chat'] ?? false,
      guildsArenas: map['guilds_arenas'] ?? false,
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
        'royal_inbox': royalInbox,
        'live_announcement_ping': liveAnnouncementPing,
        'wise_teacher_mode': wiseTeacherMode,
        'diwan_chat': diwanChat,
        'guilds_arenas': guildsArenas,
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

/// Version adoption distribution entry returned inside `AdminOverview`.
class AdminVersionBreakdown {
  final int? versionCode;
  final String? appVersion;
  final int playersCount;

  const AdminVersionBreakdown({
    this.versionCode,
    this.appVersion,
    this.playersCount = 0,
  });

  factory AdminVersionBreakdown.fromJson(Map<String, dynamic> json) {
    return AdminVersionBreakdown(
      versionCode: (json['version_code'] as num?)?.toInt(),
      appVersion: json['app_version'] as String?,
      playersCount: (json['players_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Overview statistics shown at the top of the Admin Dashboard (in-app & web).
class AdminOverview {
  final int totalAccounts;
  final int directoryPlayers;
  final int guestPlayers;
  final int active24h;
  final int activeEvents;
  final int activeAnnouncements;
  final int cmsVersion;
  final int storeItemsCount;
  final int libraryItemsCount;
  final int quizQuestionsCount;
  final int totalGhosts;
  final int activeGhosts;
  final int humanGhosts;
  final List<AdminVersionBreakdown> versionBreakdown;
  final AppReleaseConfig releaseConfig;

  const AdminOverview({
    this.totalAccounts = 0,
    this.directoryPlayers = 0,
    this.guestPlayers = 0,
    this.active24h = 0,
    this.activeEvents = 0,
    this.activeAnnouncements = 0,
    this.cmsVersion = 1,
    this.storeItemsCount = 0,
    this.libraryItemsCount = 0,
    this.quizQuestionsCount = 0,
    this.totalGhosts = 0,
    this.activeGhosts = 0,
    this.humanGhosts = 0,
    this.versionBreakdown = const [],
    this.releaseConfig = const AppReleaseConfig(),
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    final rcRaw = json['release_config'];
    final vbRaw = json['version_breakdown'];
    final parsedBreakdown = <AdminVersionBreakdown>[];
    if (vbRaw is List) {
      for (final entry in vbRaw) {
        if (entry is Map) {
          parsedBreakdown.add(
            AdminVersionBreakdown.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    return AdminOverview(
      totalAccounts: (json['total_accounts'] as num?)?.toInt() ?? 0,
      directoryPlayers: (json['directory_players'] as num?)?.toInt() ?? 0,
      guestPlayers: (json['guest_players'] as num?)?.toInt() ?? 0,
      active24h: (json['active_24h'] as num?)?.toInt() ?? 0,
      activeEvents: (json['active_events'] as num?)?.toInt() ?? 0,
      activeAnnouncements:
          (json['active_announcements'] as num?)?.toInt() ?? 0,
      cmsVersion: (json['cms_version'] as num?)?.toInt() ?? 1,
      storeItemsCount: (json['store_items_count'] as num?)?.toInt() ?? 0,
      libraryItemsCount: (json['library_items_count'] as num?)?.toInt() ?? 0,
      quizQuestionsCount: (json['quiz_questions_count'] as num?)?.toInt() ?? 0,
      totalGhosts: (json['total_ghosts'] as num?)?.toInt() ?? 0,
      activeGhosts: (json['active_ghosts'] as num?)?.toInt() ?? 0,
      humanGhosts: (json['human_ghosts'] as num?)?.toInt() ?? 0,
      versionBreakdown: List<AdminVersionBreakdown>.unmodifiable(parsedBreakdown),
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

/// Owned store item snapshot returned inside `AdminPlayerDetail`.
class AdminPlayerInventoryItem {
  final String itemId;
  final String title;
  final String? category;
  final bool isVisible;
  final DateTime? purchasedAt;

  const AdminPlayerInventoryItem({
    required this.itemId,
    required this.title,
    this.category,
    this.isVisible = true,
    this.purchasedAt,
  });

  factory AdminPlayerInventoryItem.fromJson(Map<String, dynamic> json) {
    return AdminPlayerInventoryItem(
      itemId: (json['item_id'] ?? '').toString(),
      title: (json['title'] ?? json['item_id'] ?? '').toString(),
      category: json['category']?.toString(),
      isVisible: json['is_visible'] as bool? ?? true,
      purchasedAt: json['purchased_at'] != null
          ? DateTime.tryParse(json['purchased_at'].toString())
          : null,
    );
  }
}

/// Recent match summary returned inside `AdminPlayerDetail`.
class AdminPlayerMatchRecord {
  final String id;
  final String status;
  final String? winnerId;
  final bool isGhostMatch;
  final bool isFriendly;
  final int myScore;
  final DateTime? createdAt;

  const AdminPlayerMatchRecord({
    required this.id,
    required this.status,
    this.winnerId,
    this.isGhostMatch = false,
    this.isFriendly = false,
    this.myScore = 0,
    this.createdAt,
  });

  factory AdminPlayerMatchRecord.fromJson(Map<String, dynamic> json) {
    return AdminPlayerMatchRecord(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      winnerId: json['winner_id']?.toString(),
      isGhostMatch: json['is_ghost_match'] as bool? ?? false,
      isFriendly: json['is_friendly'] as bool? ?? false,
      myScore: (json['my_score'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Comprehensive support dossier returned by `admin_get_player_detail`.
class AdminPlayerDetail {
  final String? userId;
  final String? playerCode;
  final Map<String, dynamic>? directory;
  final Map<String, dynamic>? progress;
  final Map<String, dynamic>? leaderboard;
  final List<AdminPlayerInventoryItem> inventory;
  final List<AdminPlayerMatchRecord> recentMatches;

  const AdminPlayerDetail({
    this.userId,
    this.playerCode,
    this.directory,
    this.progress,
    this.leaderboard,
    this.inventory = const [],
    this.recentMatches = const [],
  });

  String get displayName =>
      (directory?['display_name'] ?? leaderboard?['display_name'] ?? 'لاعب')
          .toString();

  int get coins => (progress?['coins'] as num?)?.toInt() ?? 0;
  int get gems => (progress?['gems'] as num?)?.toInt() ?? 0;
  int get totalScore =>
      (progress?['total_score'] as num?)?.toInt() ??
      (leaderboard?['score'] as num?)?.toInt() ??
      0;
  int get playerLevel =>
      (progress?['player_level'] as num?)?.toInt() ??
      (leaderboard?['player_level'] as num?)?.toInt() ??
      1;
  int get trophies =>
      (leaderboard?['trophies'] as num?)?.toInt() ??
      (directory?['trophies'] as num?)?.toInt() ??
      1000;
  int get winStreak => (progress?['win_streak'] as num?)?.toInt() ?? 0;

  bool get canReceiveCompensation =>
      userId != null && userId!.isNotEmpty && progress != null;

  factory AdminPlayerDetail.fromJson(Map<String, dynamic> json) {
    final invRaw = json['inventory'];
    final matchesRaw = json['recent_matches'];
    return AdminPlayerDetail(
      userId: json['user_id']?.toString(),
      playerCode: json['player_code']?.toString(),
      directory: json['directory'] is Map
          ? Map<String, dynamic>.from(json['directory'] as Map)
          : null,
      progress: json['progress'] is Map
          ? Map<String, dynamic>.from(json['progress'] as Map)
          : null,
      leaderboard: json['leaderboard'] is Map
          ? Map<String, dynamic>.from(json['leaderboard'] as Map)
          : null,
      inventory: invRaw is List
          ? invRaw
              .whereType<Map>()
              .map((e) =>
                  AdminPlayerInventoryItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      recentMatches: matchesRaw is List
          ? matchesRaw
              .whereType<Map>()
              .map((e) =>
                  AdminPlayerMatchRecord.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

/// Ghost recording telemetry entry from `admin_list_ghosts`.
class AdminGhostSummary {
  final String id;
  final String? userId;
  final String displayName;
  final int playerLevel;
  final int trophies;
  final int totalScore;
  final int useCount;
  final bool isActive;
  final bool isHuman;
  final DateTime? createdAt;

  const AdminGhostSummary({
    required this.id,
    this.userId,
    required this.displayName,
    this.playerLevel = 1,
    this.trophies = 1000,
    this.totalScore = 0,
    this.useCount = 0,
    this.isActive = true,
    this.isHuman = false,
    this.createdAt,
  });

  factory AdminGhostSummary.fromJson(Map<String, dynamic> json) {
    return AdminGhostSummary(
      id: (json['id'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      displayName: (json['display_name'] ?? 'شبح').toString(),
      playerLevel: (json['player_level'] as num?)?.toInt() ?? 1,
      trophies: (json['trophies'] as num?)?.toInt() ?? 1000,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      useCount: (json['use_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isHuman: json['is_human'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Immutable admin action log row returned by `admin_list_audit_logs`.
class AdminAuditLogEntry {
  final String id;
  final String? adminEmail;
  final String action;
  final String targetType;
  final String targetId;
  final String reason;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  const AdminAuditLogEntry({
    required this.id,
    this.adminEmail,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.reason = '',
    this.details = const {},
    this.createdAt,
  });

  factory AdminAuditLogEntry.fromJson(Map<String, dynamic> json) {
    final detRaw = json['details'];
    return AdminAuditLogEntry(
      id: (json['id'] ?? '').toString(),
      adminEmail: json['admin_email']?.toString(),
      action: (json['action'] ?? '').toString(),
      targetType: (json['target_type'] ?? '').toString(),
      targetId: (json['target_id'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      details: detRaw is Map
          ? Map<String, dynamic>.from(detRaw)
          : const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Admin account entry from `admin_list_admins`.
class AdminRosterEntry {
  final String email;
  final String role;
  final DateTime? createdAt;

  const AdminRosterEntry({
    required this.email,
    this.role = 'admin',
    this.createdAt,
  });

  bool get isOwner => role.trim().toLowerCase() == 'owner';

  factory AdminRosterEntry.fromJson(Map<String, dynamic> json) {
    return AdminRosterEntry(
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'admin').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Owner role flag + admin roster returned by `admin_list_admins`.
class AdminRosterSnapshot {
  final bool isOwner;
  final List<AdminRosterEntry> admins;

  const AdminRosterSnapshot({
    this.isOwner = false,
    this.admins = const [],
  });

  factory AdminRosterSnapshot.fromJson(Map<String, dynamic> json) {
    final rawList = json['admins'];
    return AdminRosterSnapshot(
      isOwner: json['is_owner'] as bool? ?? false,
      admins: rawList is List
          ? rawList
              .whereType<Map>()
              .map((e) =>
                  AdminRosterEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

/// Player Inbox message returned by `get_player_inbox` (archived + unread).
class RoyalInboxMessage {
  final AppAnnouncement announcement;
  final bool isRead;
  final bool isRewardNotice;

  const RoyalInboxMessage({
    required this.announcement,
    this.isRead = false,
    this.isRewardNotice = false,
  });

  RoyalInboxMessage copyWith({
    AppAnnouncement? announcement,
    bool? isRead,
    bool? isRewardNotice,
  }) {
    return RoyalInboxMessage(
      announcement: announcement ?? this.announcement,
      isRead: isRead ?? this.isRead,
      isRewardNotice: isRewardNotice ?? this.isRewardNotice,
    );
  }

  factory RoyalInboxMessage.fromJson(Map<String, dynamic> json) {
    final ann = AppAnnouncement.fromJson(json);
    final isReward = json['is_reward_notice'] as bool? ??
        (ann.title.contains('🎁') ||
            ann.title.contains('تعويض') ||
            ann.title.contains('هدية'));
    return RoyalInboxMessage(
      announcement: ann,
      isRead: json['is_read'] as bool? ?? false,
      isRewardNotice: isReward,
    );
  }

  Map<String, dynamic> toJson() => {
        ...announcement.toJson(),
        'is_read': isRead,
        'is_reward_notice': isRewardNotice,
      };
}

/// Table storage breakdown item returned by `admin_get_resource_health`.
class AdminTableMetric {
  final String tableName;
  final int sizeBytes;
  final int rowEstimate;

  const AdminTableMetric({
    required this.tableName,
    this.sizeBytes = 0,
    this.rowEstimate = 0,
  });

  double get sizeMb => sizeBytes / (1024 * 1024);

  factory AdminTableMetric.fromJson(Map<String, dynamic> json) {
    return AdminTableMetric(
      tableName: (json['table_name'] ?? '').toString(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      rowEstimate: (json['row_estimate'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Real PostgreSQL resource & live-activity snapshot from `admin_get_resource_health`.
class AdminResourceHealth {
  final int dbSizeBytes;
  final int dbLimitBytes;
  final double dbUsagePercent;
  final int activeMatchesNow;
  final int activePlayers5m;
  final int activePlayers60m;
  final int activePlayers24h;
  final int totalDirectoryPlayers;
  final int cleanableOldMatches;
  final int cleanableExpiredReceipts;
  final List<AdminTableMetric> tables;
  final DateTime? measuredAt;

  const AdminResourceHealth({
    this.dbSizeBytes = 0,
    this.dbLimitBytes = 524288000,
    this.dbUsagePercent = 0,
    this.activeMatchesNow = 0,
    this.activePlayers5m = 0,
    this.activePlayers60m = 0,
    this.activePlayers24h = 0,
    this.totalDirectoryPlayers = 0,
    this.cleanableOldMatches = 0,
    this.cleanableExpiredReceipts = 0,
    this.tables = const [],
    this.measuredAt,
  });

  double get dbSizeMb => dbSizeBytes / (1024 * 1024);
  double get dbLimitMb => dbLimitBytes / (1024 * 1024);

  factory AdminResourceHealth.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'];
    return AdminResourceHealth(
      dbSizeBytes: (json['db_size_bytes'] as num?)?.toInt() ?? 0,
      dbLimitBytes: (json['db_limit_bytes'] as num?)?.toInt() ?? 524288000,
      dbUsagePercent: (json['db_usage_percent'] as num?)?.toDouble() ?? 0.0,
      activeMatchesNow: (json['active_matches_now'] as num?)?.toInt() ?? 0,
      activePlayers5m: (json['active_players_5m'] as num?)?.toInt() ?? 0,
      activePlayers60m: (json['active_players_60m'] as num?)?.toInt() ?? 0,
      activePlayers24h: (json['active_players_24h'] as num?)?.toInt() ?? 0,
      totalDirectoryPlayers:
          (json['total_directory_players'] as num?)?.toInt() ?? 0,
      cleanableOldMatches:
          (json['cleanable_old_matches'] as num?)?.toInt() ?? 0,
      cleanableExpiredReceipts:
          (json['cleanable_expired_receipts'] as num?)?.toInt() ?? 0,
      tables: rawTables is List
          ? rawTables
              .whereType<Map>()
              .map((e) =>
                  AdminTableMetric.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      measuredAt: json['measured_at'] != null
          ? DateTime.tryParse(json['measured_at'].toString())
          : null,
    );
  }
}

