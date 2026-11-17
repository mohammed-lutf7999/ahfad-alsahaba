import 'package:flutter/material.dart';

import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/app_control_models.dart';
import '../../data/services/admin_service.dart';
import 'admin/admin_announcements_screen.dart';
import 'admin/admin_cms_manager_screen.dart';
import 'admin/admin_events_screen.dart';
import 'admin/admin_players_support_screen.dart';
import 'admin/admin_release_control_screen.dart';
import 'admin/admin_telemetry_security_screen.dart';
import 'admin/widgets/admin_ui_kit.dart';
import 'admin_email_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  AdminOverview? _overview;
  Map<String, dynamic> _fallbackStats = {};
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final overview = await AdminService().getOverview();
      if (!mounted) return;
      if (overview != null) {
        setState(() {
          _overview = overview;
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });
        return;
      }
    } catch (e) {
      debugPrint('AdminDashboard getOverview notice: $e');
    }

    final stats = await AdminService().getStats();
    if (!mounted) return;
    setState(() {
      _fallbackStats = stats;
      _isLoading = false;
      _lastUpdated = DateTime.now();
    });
  }

  Future<void> _openAndRefresh(Widget screen) async {
    SoundService().playClick();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) {
      await _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _lastUpdated == null
        ? 'غرفة القيادة السحابية'
        : 'آخر تحديث: ${_formatTime(_lastUpdated!)}';

    return AdminScaffoldShell(
      title: 'لوحة تحكم المدير',
      subtitle: subtitle,
      isLoading: _isLoading,
      onRefresh: _loadStats,
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: AppCustomTheme.of(context).sovereignAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLiveStatusStrip(),
                    const SizedBox(height: 16),
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                    _buildActionsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: accent),
          const SizedBox(height: 14),
          Text(
            'جاري مزامنة غرفة القيادة...',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusStrip() {
    final customTheme = AppCustomTheme.of(context);
    final cfg = _overview?.releaseConfig;
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
                'v${cfg.minVersionCode}..${cfg.latestVersionCode} • CMS#${_overview?.cmsVersion ?? 1}',
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

  Widget _buildStatsSection() {
    final totalAccounts =
        _overview?.totalAccounts ?? (_fallbackStats['totalUsers'] ?? 0);
    final active24h =
        _overview?.active24h ?? (_fallbackStats['onlineUsers'] ?? 0);
    final directoryPlayers =
        _overview?.directoryPlayers ??
            (_fallbackStats['directoryPlayers'] ?? 0);
    final guestPlayers =
        _overview?.guestPlayers ?? (_fallbackStats['guestPlayers'] ?? 0);
    final activeEvents = _overview?.activeEvents ?? 0;
    final activeAnnouncements = _overview?.activeAnnouncements ?? 0;

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
              child: _buildStatCard(
                key: const Key('stat_total_accounts'),
                title: 'إجمالي الحسابات',
                value: '$totalAccounts',
                icon: Icons.people_alt_rounded,
                color: AppCustomTheme.of(context).sovereignAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
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
              child: _buildStatCard(
                key: const Key('stat_directory_players'),
                title: 'دليل اللاعبين',
                value: '$directoryPlayers',
                icon: Icons.badge_rounded,
                color: const Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
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
              child: _buildStatCard(
                key: const Key('stat_active_events'),
                title: 'الأحداث النشطة',
                value: '$activeEvents',
                icon: Icons.celebration_rounded,
                color: const Color(0xFFA78BFA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
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
              child: _buildStatCard(
                key: const Key('stat_cms_items_summary'),
                title: 'المتجر / الأسئلة السحابية',
                value:
                    '${_overview?.storeItemsCount ?? 0} / ${_overview?.quizQuestionsCount ?? 0}',
                icon: Icons.storefront_rounded,
                color: AppCustomTheme.of(context).sovereignAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                key: const Key('stat_ghosts_summary'),
                title: 'الأشباح (نشط/الكل)',
                value:
                    '${_overview?.activeGhosts ?? 0} / ${_overview?.totalGhosts ?? 0}',
                icon: Icons.auto_fix_high_rounded,
                color: const Color(0xFF38BDF8),
              ),
            ),
          ],
        ),
        if (_overview != null && _overview!.versionBreakdown.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildVersionBreakdownCard(_overview!.versionBreakdown),
        ],
      ],
    );
  }

  Widget _buildVersionBreakdownCard(List<AdminVersionBreakdown> rows) {
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
          for (final entry in rows.take(5)) ...[
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
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required Key key,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isLive = false,
  }) {
    final customTheme = AppCustomTheme.of(context);
    return Container(
      key: key,
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

  Widget _buildActionsSection() {
    final customTheme = AppCustomTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أدوات الإدارة والتحكم',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          key: const Key('admin_nav_release_control'),
          title: 'الإصدارات والصيانة والمزايا',
          subtitle: 'التحديث الإلزامي، وضع الصيانة، و6 أعلام ميزات',
          icon: Icons.tune_rounded,
          color: customTheme.sovereignAccent,
          onTap: () => _openAndRefresh(
            AdminReleaseControlScreen(initialConfig: _overview?.releaseConfig),
          ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          key: const Key('admin_nav_announcements'),
          title: 'الرسائل الموجّهة والبحث',
          subtitle: 'بث جماعي أو استهداف مباشر (Google & SAH-XXXX)',
          icon: Icons.campaign_rounded,
          color: const Color(0xFFFB7185),
          onTap: () => _openAndRefresh(const AdminAnnouncementsScreen()),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          key: const Key('admin_nav_events'),
          title: 'الأحداث والمواسم الديناميكية',
          subtitle: 'إطلاق وجدولة بانر الشاشة الرئيسية ومعاينته',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFFA78BFA),
          onTap: () => _openAndRefresh(const AdminEventsScreen()),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          key: const Key('admin_nav_cms_manager'),
          title: 'إدارة المتجر والمحتوى (CMS)',
          subtitle: 'عناصر سوق الفرسان، المكتبة، المسابقات، وإظهار/إخفاء فوري',
          icon: Icons.store_mall_directory_rounded,
          color: customTheme.sovereignAccent,
          onTap: () => _openAndRefresh(const AdminCmsManagerScreen()),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          key: const Key('admin_nav_players_support'),
          title: 'دعم اللاعبين والتعويضات',
          subtitle: 'فحص المحفظة والمقتنيات ومنح تعويض آمن بسجل تدقيق',
          icon: Icons.support_agent_rounded,
          color: const Color(0xFF10B981),
          onTap: () => _openAndRefresh(const AdminPlayersSupportScreen()),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          key: const Key('admin_nav_telemetry'),
          title: 'الأشباح والتدقيق والمشرفون',
          subtitle: 'تبديل الأشباح وسجل الإجراءات وإدارة المشرفين',
          icon: Icons.security_rounded,
          color: Colors.amberAccent,
          onTap: () => _openAndRefresh(const AdminTelemetrySecurityScreen()),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          key: const Key('admin_nav_email'),
          title: 'إرسال بريد إلكتروني',
          subtitle: 'مراسلة المستخدمين عبر البريد المسجّل',
          icon: Icons.email_rounded,
          color: const Color(0xFF38BDF8),
          onTap: () => _openAndRefresh(const AdminEmailScreen()),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final customTheme = AppCustomTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.75),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
