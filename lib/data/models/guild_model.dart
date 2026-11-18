class GuildModel {
  final String id;
  final String name;
  final String description;
  final int bannerIcon;
  final int weeklyScore;
  final int totalScore;
  final int maxMembers;
  final int membersCount;
  final String leaderId;

  const GuildModel({
    required this.id,
    required this.name,
    this.description = '',
    this.bannerIcon = 0,
    this.weeklyScore = 0,
    this.totalScore = 0,
    this.maxMembers = 30,
    this.membersCount = 1,
    this.leaderId = '',
  });

  bool get isFull => membersCount >= maxMembers;

  factory GuildModel.fromJson(Map<String, dynamic> json) {
    return GuildModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'كتيبة فرسان').toString(),
      description: (json['description'] ?? '').toString(),
      bannerIcon: (json['banner_icon'] as num?)?.toInt() ?? 0,
      weeklyScore: (json['weekly_score'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 30,
      membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
      leaderId: (json['leader_id'] ?? '').toString(),
    );
  }
}

class GuildMemberModel {
  final String guildId;
  final String userId;
  final String displayName;
  final int avatarIndex;
  final String role;
  final int weeklyContribution;

  const GuildMemberModel({
    required this.guildId,
    required this.userId,
    required this.displayName,
    this.avatarIndex = 0,
    this.role = 'عضو',
    this.weeklyContribution = 0,
  });

  factory GuildMemberModel.fromJson(Map<String, dynamic> json) {
    return GuildMemberModel(
      guildId: (json['guild_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? 'فارس').toString(),
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      role: (json['role'] ?? 'عضو').toString(),
      weeklyContribution: (json['weekly_contribution'] as num?)?.toInt() ?? 0,
    );
  }
}

class GuildsOverviewData {
  final GuildModel? myGuild;
  final List<GuildMemberModel> myMembers;
  final List<GuildModel> leaderboard;

  const GuildsOverviewData({
    this.myGuild,
    this.myMembers = const [],
    this.leaderboard = const [],
  });

  factory GuildsOverviewData.fromJson(Map<String, dynamic> json) {
    final myGuildRaw = json['my_guild'];
    final membersRaw = (json['my_members'] as List?) ?? const [];
    final boardRaw = (json['leaderboard'] as List?) ?? const [];
    return GuildsOverviewData(
      myGuild: myGuildRaw is Map
          ? GuildModel.fromJson(Map<String, dynamic>.from(myGuildRaw))
          : null,
      myMembers: membersRaw
          .whereType<Map>()
          .map((e) => GuildMemberModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      leaderboard: boardRaw
          .whereType<Map>()
          .map((e) => GuildModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
