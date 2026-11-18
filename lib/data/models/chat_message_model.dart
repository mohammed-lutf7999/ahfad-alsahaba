/// Curated polite chivalric phrases shared inside Versus & Online matches.
class QuickChivalricPhrases {
  QuickChivalricPhrases._();

  static const List<String> all = [
    'السلام عليكم ورحمة الله',
    'تحدٍ مبارك وبالتوفيق يا أخي',
    'ما شاء الله، إجابة ذكية!',
    'جزاك الله خيراً، جولة ممتعة',
  ];
}

class ChatMessageModel {
  final String id;
  final String userId;
  final String? playerCode;
  final String displayName;
  final int avatarIndex;
  final String userRank;
  final String content;
  final String channel;
  final String messageKind; // 'text' | 'challenge_invite'
  final String? inviteRoomCode;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.userId,
    this.playerCode,
    required this.displayName,
    this.avatarIndex = 0,
    this.userRank = 'فارس',
    required this.content,
    this.channel = 'global',
    this.messageKind = 'text',
    this.inviteRoomCode,
    required this.createdAt,
  });

  bool get isChallengeInvite =>
      messageKind == 'challenge_invite' &&
      inviteRoomCode != null &&
      inviteRoomCode!.trim().length == 6;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      playerCode: json['player_code']?.toString(),
      displayName: (json['display_name'] ?? 'فارس').toString(),
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      userRank: (json['user_rank'] ?? 'فارس').toString(),
      content: (json['content'] ?? '').toString(),
      channel: (json['channel'] ?? 'global').toString(),
      messageKind: (json['message_kind'] ?? 'text').toString(),
      inviteRoomCode: json['invite_room_code']?.toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'player_code': playerCode,
        'display_name': displayName,
        'avatar_index': avatarIndex,
        'user_rank': userRank,
        'content': content,
        'channel': channel,
        'message_kind': messageKind,
        'invite_room_code': inviteRoomCode,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
