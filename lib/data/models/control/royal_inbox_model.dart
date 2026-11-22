import 'app_events_announcements_models.dart';

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
