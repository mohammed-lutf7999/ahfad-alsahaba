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
