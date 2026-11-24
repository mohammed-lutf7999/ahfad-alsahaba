import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/cms_icon_registry.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/guild_model.dart';
import '../../../widgets/avatar_selector.dart';
import 'live_arena_quick_card.dart';

class MyGuildTab extends StatelessWidget {
  final GuildsOverviewData data;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenCreateDialog;
  final VoidCallback onLeaveGuild;
  final ValueChanged<String> onHostDenied;

  const MyGuildTab({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onOpenCreateDialog,
    required this.onLeaveGuild,
    required this.onHostDenied,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final myGuild = data.myGuild;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          LiveArenaQuickCard(onHostDenied: onHostDenied),
          const SizedBox(height: 14),
          if (myGuild == null)
            _buildEmptyGuildCard(customTheme, accent)
          else ...[
            _buildActiveGuildCard(customTheme, accent, myGuild),
            const SizedBox(height: 14),
            Text(
              'أعضاء الكتيبة (${data.myMembers.length})',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: accent,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final m in data.myMembers)
              _buildMemberTile(customTheme, accent, m),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyGuildCard(AppCustomTheme customTheme, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'لست منضماً لكتيبة بعد',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: accent,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'أسّس رايتك الخاصة أو انضم لكتيبة من تصنيف «معركة الجمعة» لتوحيد نقاطكم كل أسبوع.',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('open_create_guild_btn'),
              onPressed: onOpenCreateDialog,
              icon: const Icon(Icons.add_moderator_rounded, size: 18),
              label: const Text(
                'تأسيس كتيبة جديدة 🛡️',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  height: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.primaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGuildCard(
    AppCustomTheme customTheme,
    Color accent,
    GuildModel myGuild,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CmsIconRegistry.guildBannerIconFor(myGuild.bannerIcon),
                  color: accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      myGuild.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'الأعضاء: ${myGuild.membersCount}/${myGuild.maxMembers} • نقاط الأسبوع: ${myGuild.weeklyScore}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (myGuild.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              myGuild.description,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (myGuild.membersCount / myGuild.maxMembers).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onLeaveGuild,
            icon: const Icon(
              Icons.exit_to_app_rounded,
              size: 16,
              color: Colors.redAccent,
            ),
            label: const Text(
              'مغادرة الكتيبة',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    AppCustomTheme customTheme,
    Color accent,
    GuildMemberModel m,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          ProfileAvatar(avatarIndex: m.avatarIndex, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  m.role,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${m.weeklyContribution} ⭐',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF10B981),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
