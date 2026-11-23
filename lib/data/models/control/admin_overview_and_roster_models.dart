import 'app_release_config_model.dart';

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
