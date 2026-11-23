import '../player_profile_model.dart';
import 'player_permissions_model.dart';

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
  final PlayerPermissions permissions;
  final Map<String, dynamic>? diwanModeration;

  const AdminPlayerDetail({
    this.userId,
    this.playerCode,
    this.directory,
    this.progress,
    this.leaderboard,
    this.inventory = const [],
    this.recentMatches = const [],
    this.permissions = const PlayerPermissions(),
    this.diwanModeration,
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

  bool get canManagePermissions => userId != null && userId!.isNotEmpty;

  factory AdminPlayerDetail.fromJson(Map<String, dynamic> json) {
    final invRaw = json['inventory'];
    final matchesRaw = json['recent_matches'];
    final permsRaw = json['permissions'];
    final diwanRaw = json['diwan_moderation'];
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
      permissions: permsRaw is Map
          ? PlayerPermissions.fromJson(Map<String, dynamic>.from(permsRaw))
          : const PlayerPermissions(),
      diwanModeration: diwanRaw is Map
          ? Map<String, dynamic>.from(diwanRaw)
          : null,
    );
  }
}
