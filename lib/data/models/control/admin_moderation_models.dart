/// Aggregated report row from `admin_list_diwan_moderation_queue`.
class AdminDiwanReport {
  final String messageId;
  final String senderId;
  final String senderName;
  final String? senderCode;
  final String content;
  final String channel;
  final int reportsCount;
  final String latestReason;
  final DateTime? latestReportedAt;

  const AdminDiwanReport({
    required this.messageId,
    required this.senderId,
    this.senderName = 'فارس',
    this.senderCode,
    required this.content,
    this.channel = 'global',
    this.reportsCount = 1,
    this.latestReason = 'مخالفة آداب الديوان',
    this.latestReportedAt,
  });

  factory AdminDiwanReport.fromJson(Map<String, dynamic> json) {
    return AdminDiwanReport(
      messageId: (json['message_id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? '').toString(),
      senderName: (json['sender_name'] ?? 'فارس').toString(),
      senderCode: json['sender_code']?.toString(),
      content: (json['content'] ?? '').toString(),
      channel: (json['channel'] ?? 'global').toString(),
      reportsCount: (json['reports_count'] as num?)?.toInt() ?? 1,
      latestReason: (json['latest_reason'] ?? 'مخالفة آداب الديوان').toString(),
      latestReportedAt: json['latest_reported_at'] != null
          ? DateTime.tryParse(json['latest_reported_at'].toString())
          : null,
    );
  }
}

/// Active muted user row from `admin_list_diwan_moderation_queue`.
class AdminMutedUser {
  final String userId;
  final String displayName;
  final String? playerCode;
  final DateTime? mutedUntil;
  final String reason;

  const AdminMutedUser({
    required this.userId,
    this.displayName = 'لاعب',
    this.playerCode,
    this.mutedUntil,
    this.reason = '',
  });

  factory AdminMutedUser.fromJson(Map<String, dynamic> json) {
    return AdminMutedUser(
      userId: (json['user_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? 'لاعب').toString(),
      playerCode: json['player_code']?.toString(),
      mutedUntil: json['muted_until'] != null
          ? DateTime.tryParse(json['muted_until'].toString())
          : null,
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

/// Recent Diwan message preview returned inside `admin_list_diwan_moderation_queue`.
class AdminDiwanMessagePreview {
  final String id;
  final String userId;
  final String? playerCode;
  final String displayName;
  final String userRank;
  final String content;
  final String channel;
  final DateTime? createdAt;

  const AdminDiwanMessagePreview({
    required this.id,
    required this.userId,
    this.playerCode,
    this.displayName = 'فارس',
    this.userRank = 'فارس',
    required this.content,
    this.channel = 'global',
    this.createdAt,
  });

  factory AdminDiwanMessagePreview.fromJson(Map<String, dynamic> json) {
    return AdminDiwanMessagePreview(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      playerCode: json['player_code']?.toString(),
      displayName: (json['display_name'] ?? 'فارس').toString(),
      userRank: (json['user_rank'] ?? 'فارس').toString(),
      content: (json['content'] ?? '').toString(),
      channel: (json['channel'] ?? 'global').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Full Diwan moderation snapshot returned by `admin_list_diwan_moderation_queue`.
class AdminDiwanModerationQueue {
  final List<AdminDiwanReport> reports;
  final List<AdminMutedUser> mutedUsers;
  final List<AdminDiwanMessagePreview> recentMessages;

  const AdminDiwanModerationQueue({
    this.reports = const [],
    this.mutedUsers = const [],
    this.recentMessages = const [],
  });

  factory AdminDiwanModerationQueue.fromJson(Map<String, dynamic> json) {
    final repRaw = json['reports'];
    final mutRaw = json['muted_users'];
    final recRaw = json['recent_messages'];
    return AdminDiwanModerationQueue(
      reports: repRaw is List
          ? repRaw
              .whereType<Map>()
              .map((e) => AdminDiwanReport.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      mutedUsers: mutRaw is List
          ? mutRaw
              .whereType<Map>()
              .map((e) => AdminMutedUser.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      recentMessages: recRaw is List
          ? recRaw
              .whereType<Map>()
              .map((e) =>
                  AdminDiwanMessagePreview.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

/// Guild summary row returned by `admin_list_guilds_and_arenas`.
class AdminGuildSummary {
  final String id;
  final String name;
  final String description;
  final int bannerIcon;
  final int weeklyScore;
  final int totalScore;
  final int membersCount;
  final int maxMembers;
  final String leaderId;
  final String leaderName;
  final DateTime? createdAt;

  const AdminGuildSummary({
    required this.id,
    required this.name,
    this.description = '',
    this.bannerIcon = 0,
    this.weeklyScore = 0,
    this.totalScore = 0,
    this.membersCount = 1,
    this.maxMembers = 30,
    this.leaderId = '',
    this.leaderName = 'قائد',
    this.createdAt,
  });

  factory AdminGuildSummary.fromJson(Map<String, dynamic> json) {
    return AdminGuildSummary(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      bannerIcon: (json['banner_icon'] as num?)?.toInt() ?? 0,
      weeklyScore: (json['weekly_score'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      membersCount: (json['members_count'] as num?)?.toInt() ?? 1,
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 30,
      leaderId: (json['leader_id'] ?? '').toString(),
      leaderName: (json['leader_name'] ?? 'قائد').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Live tournament session summary row returned by `admin_list_guilds_and_arenas`.
class AdminLiveSessionSummary {
  final String id;
  final String pinCode;
  final String title;
  final String categoryId;
  final String hostId;
  final String hostName;
  final String status;
  final int currentQuestionIndex;
  final int participantsCount;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const AdminLiveSessionSummary({
    required this.id,
    required this.pinCode,
    required this.title,
    this.categoryId = 'quran',
    this.hostId = '',
    this.hostName = 'مضيف',
    this.status = 'waiting',
    this.currentQuestionIndex = 0,
    this.participantsCount = 0,
    this.expiresAt,
    this.createdAt,
  });

  bool get isActiveOrWaiting => status == 'waiting' || status == 'active';

  factory AdminLiveSessionSummary.fromJson(Map<String, dynamic> json) {
    return AdminLiveSessionSummary(
      id: (json['id'] ?? '').toString(),
      pinCode: (json['pin_code'] ?? '').toString(),
      title: (json['title'] ?? 'بطولة الفرسان').toString(),
      categoryId: (json['category_id'] ?? 'quran').toString(),
      hostId: (json['host_id'] ?? '').toString(),
      hostName: (json['host_name'] ?? 'مضيف').toString(),
      status: (json['status'] ?? 'waiting').toString(),
      currentQuestionIndex:
          (json['current_question_index'] as num?)?.toInt() ?? 0,
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Combined Guilds & Live Arenas moderation snapshot from `admin_list_guilds_and_arenas`.
class AdminGuildsAndArenasSnapshot {
  final List<AdminGuildSummary> guilds;
  final List<AdminLiveSessionSummary> liveSessions;

  const AdminGuildsAndArenasSnapshot({
    this.guilds = const [],
    this.liveSessions = const [],
  });

  factory AdminGuildsAndArenasSnapshot.fromJson(Map<String, dynamic> json) {
    final gRaw = json['guilds'];
    final sRaw = json['live_sessions'];
    return AdminGuildsAndArenasSnapshot(
      guilds: gRaw is List
          ? gRaw
              .whereType<Map>()
              .map((e) => AdminGuildSummary.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      liveSessions: sRaw is List
          ? sRaw
              .whereType<Map>()
              .map((e) =>
                  AdminLiveSessionSummary.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
