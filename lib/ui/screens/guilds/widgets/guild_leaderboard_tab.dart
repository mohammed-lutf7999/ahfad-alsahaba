import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/cms_icon_registry.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/guild_model.dart';

class GuildLeaderboardTab extends StatelessWidget {
  final GuildsOverviewData data;
  final ValueChanged<GuildModel> onJoinGuild;

  const GuildLeaderboardTab({
    super.key,
    required this.data,
    required this.onJoinGuild,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final board = data.leaderboard;

    if (board.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'لا توجد كتائب مسجلة بعد — كن أول قائد يؤسس راية!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: board.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final g = board[index];
        final isMine = data.myGuild?.id == g.id;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(
              alpha: isMine ? 0.94 : 0.78,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMine ? accent : Colors.white.withValues(alpha: 0.14),
              width: isMine ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    index < 3 ? accent : Colors.white.withValues(alpha: 0.12),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: index < 3 ? AppTheme.primaryDark : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                CmsIconRegistry.guildBannerIconFor(g.bannerIcon),
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${g.membersCount}/${g.maxMembers} عضو • ${g.weeklyScore} نقطة أسبوعية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.myGuild == null && !g.isFull)
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => onJoinGuild(g),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'انضمام',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
