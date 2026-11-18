import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/chat_message_model.dart';
import '../../../widgets/avatar_selector.dart';

/// Displays a single message bubble or interactive «تحدٍ مفتوح ⚔️» card in Diwan chat.
class ChatBubbleWidget extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;
  final bool isAdmin;
  final VoidCallback? onJoinChallenge;
  final VoidCallback? onReport;
  final VoidCallback? onAdminDelete;
  final VoidCallback? onAdminMute;

  const ChatBubbleWidget({
    super.key,
    required this.message,
    required this.isMine,
    this.isAdmin = false,
    this.onJoinChallenge,
    this.onReport,
    this.onAdminDelete,
    this.onAdminMute,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final bubbleColor = message.isChallengeInvite
        ? accent.withValues(alpha: 0.14)
        : (isMine
            ? accent.withValues(alpha: 0.18)
            : customTheme.surfaceCard.withValues(alpha: 0.85));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            avatarIndex: message.avatarIndex,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: message.isChallengeInvite
                      ? accent.withValues(alpha: 0.72)
                      : (isMine
                          ? accent.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          message.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: isMine ? accent : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.userRank,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 10.5,
                        ),
                      ),
                      if (!isMine || isAdmin)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                          color: AppTheme.primaryDark,
                          onSelected: (val) {
                            if (val == 'report') onReport?.call();
                            if (val == 'delete') onAdminDelete?.call();
                            if (val == 'mute') onAdminMute?.call();
                          },
                          itemBuilder: (_) => [
                            if (!isMine)
                              const PopupMenuItem(
                                value: 'report',
                                child: Text(
                                  'إبلاغ عن مخالفة',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ),
                            if (isAdmin) ...[
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'حذف الرسالة (إداري)',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'mute',
                                child: Text(
                                  'كتم العضو 24 ساعة',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white.withValues(alpha: 0.94),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  if (message.isChallengeInvite && !isMine && onJoinChallenge != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: onJoinChallenge,
                        icon: const Icon(Icons.sports_kabaddi_rounded, size: 17),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'قبول التحدي الآن (${message.inviteRoomCode})',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: AppTheme.primaryDark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
