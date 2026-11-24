import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';

class AdminLiveStatusStrip extends StatelessWidget {
  final AdminOverview? overview;

  const AdminLiveStatusStrip({super.key, required this.overview});

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final cfg = overview?.releaseConfig;
    final inMaintenance = cfg?.maintenanceMode ?? false;
    final statusColor =
        inMaintenance ? Colors.redAccent : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            inMaintenance
                ? Icons.engineering_rounded
                : Icons.verified_user_rounded,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              inMaintenance
                  ? 'وضع الصيانة مفعّل حالياً على السحابة ⚠️'
                  : 'الحالة التشغيلية: مستقرة ومتاحة ✅',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: statusColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (cfg != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: customTheme.sovereignAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'v${cfg.minVersionCode}..${cfg.latestVersionCode} • CMS#${overview?.cmsVersion ?? 1}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: customTheme.sovereignAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminDashboardStatsSection extends StatelessWidget {
  final AdminOverview? overview;
  final Map<String, dynamic> fallbackStats;

  const AdminDashboardStatsSection({
    super.key,
    required this.overview,
    required this.fallbackStats,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    final totalAccounts =
        overview?.totalAccounts ?? (fallbackStats['totalUsers'] ?? 0);
    final active24h =
        overview?.active24h ?? (fallbackStats['onlineUsers'] ?? 0);
    final directoryPlayers =
        overview?.directoryPlayers ?? (fallbackStats['directoryPlayers'] ?? 0);
    final guestPlayers =
        overview?.guestPlayers ?? (fallbackStats['guestPlayers'] ?? 0);
    final activeEvents = overview?.activeEvents ?? 0;
    final activeAnnouncements = overview?.activeAnnouncements ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'المؤشرات الحيّة',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AdminStatCard(
                key: const Key('stat_total_accounts'),
                title: 'إجمالي الحسابات',
                value: '$totalAccounts',
                icon: Icons.people_alt_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AdminStatCard(
                key: const Key('stat_active_24h'),
                title: 'نشطو آخر 24 ساعة',
                value: '$active24h',
                icon: Icons.wifi_tethering_rounded,
                color: const Color(0xFF10B981),
                isLive: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AdminStatCard(
                key: const Key('stat_directory_players'),
                title: 'دليل اللاعبين',
                value: '$directoryPlayers',
                icon: Icons.badge_rounded,
                color: const Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AdminStatCard(
                key: const Key('stat_guest_players'),
                title: 'اللاعبون الضيوف',
                value: '$guestPlayers',
                icon: Icons.person_outline_rounded,
                color: Colors.amberAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AdminStatCard(
                key: const Key('stat_active_events'),
                title: 'الأحداث النشطة',
                value: '$activeEvents',
                icon: Icons.celebration_rounded,
                color: const Color(0xFFA78BFA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AdminStatCard(
                key: const Key('stat_active_announcements'),
                title: 'الرسائل النشطة',
                value: '$activeAnnouncements',
                icon: Icons.campaign_rounded,
                color: const Color(0xFFFB7185),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AdminStatCard(
                key: const Key('stat_cms_items_summary'),
                title: 'المتجر / الأسئلة السحابية',
                value:
                    '${overview?.storeItemsCount ?? 0} / ${overview?.quizQuestionsCount ?? 0}',
                icon: Icons.storefront_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AdminStatCard(
                key: const Key('stat_ghosts_summary'),
                title: 'الأشباح (نشط/الكل)',
                value:
                    '${overview?.activeGhosts ?? 0} / ${overview?.totalGhosts ?? 0}',
                icon: Icons.auto_fix_high_rounded,
                color: const Color(0xFF38BDF8),
              ),
            ),
          ],
        ),
        if (overview != null && overview!.versionBreakdown.isNotEmpty) ...[
          const SizedBox(height: 14),
          _VersionBreakdownCard(rows: overview!.versionBreakdown),
        ],
      ],
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLive;

  const _AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (isLive) ...[
                const SizedBox(width: 6),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionBreakdownCard extends StatelessWidget {
  final List<AdminVersionBreakdown> rows;

  const _VersionBreakdownCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final total = rows.fold<int>(0, (sum, r) => sum + r.playersCount);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: customTheme.sovereignAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'توزيع نسخ التطبيق النشطة ($total لاعب)',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: customTheme.sovereignAccent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in rows.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      entry.appVersion != null
                          ? '${entry.appVersion} (b${entry.versionCode ?? "?"})'
                          : 'Build ${entry.versionCode ?? "?"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: total > 0 ? entry.playersCount / total : 0,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          customTheme.sovereignAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.playersCount}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
