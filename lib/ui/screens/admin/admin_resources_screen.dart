import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import 'widgets/admin_ui_kit.dart';

/// شاشة مراقبة وإدارة موارد قاعدة بيانات Supabase والنشاط الحي وتنظيف البيانات القديمة.
class AdminResourcesScreen extends StatefulWidget {
  const AdminResourcesScreen({super.key});

  @override
  State<AdminResourcesScreen> createState() => _AdminResourcesScreenState();
}

class _AdminResourcesScreenState extends State<AdminResourcesScreen> {
  static const String _studioUsageUrl =
      'https://supabase.com/dashboard/project/khatzzpqxaiwuoodgcst/settings/billing/usage';

  bool _isLoading = true;
  bool _isCleaning = false;
  AdminResourceHealth? _health;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  Future<void> _loadHealth() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final res = await AdminService().getResourceHealth();
      if (!mounted) return;
      setState(() {
        _health = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر جلب مؤشرات الموارد: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _runCleanup({
    required String action,
    required String title,
    required String description,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            description,
            style: const TextStyle(fontFamily: 'Cairo', height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: AppTheme.primaryDark,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'تنفيذ التنظيف',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCleaning = true);
    try {
      final result = await AdminService().cleanupStaleResources(
        action: action,
        olderThanDays: 30,
      );
      if (!mounted) return;
      final deleted = result?['deleted_count'] ?? 0;
      showAdminFeedback(context, 'تم تنظيف $deleted سجل قديم بنجاح ✅');
      await _loadHealth();
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'فشل التنظيف: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _openStudioUsage() async {
    SoundService().playClick();
    final uri = Uri.tryParse(_studioUsageUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final h = _health;

    return AdminScaffoldShell(
      title: 'مراقبة وإدارة الموارد 🎛️',
      subtitle: 'حجم قاعدة البيانات والنشاط الحي وتنظيف السجلات',
      isLoading: _isLoading,
      onRefresh: _loadHealth,
      body: RefreshIndicator(
        onRefresh: _loadHealth,
        color: customTheme.sovereignAccent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (_error != null) ...[
              _GlassCard(
                borderColor: Colors.redAccent.withValues(alpha: 0.6),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildStorageCard(h, customTheme),
            const SizedBox(height: 14),
            _buildActivityCard(h, customTheme),
            const SizedBox(height: 14),
            _buildCleanupCard(h, customTheme),
            const SizedBox(height: 14),
            _buildTablesCard(h, customTheme),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openStudioUsage,
                icon: Icon(
                  Icons.open_in_new_rounded,
                  color: customTheme.sovereignAccent,
                  size: 18,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'فتح مؤشرات Realtime وEgress في Supabase Studio',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: customTheme.sovereignAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  side: BorderSide(
                    color: customTheme.sovereignAccent.withValues(alpha: 0.55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(
    AdminResourceHealth? h,
    AppCustomTheme customTheme,
  ) {
    final pct = (h?.dbUsagePercent ?? 0).clamp(0.0, 100.0);
    final statusColor = pct >= 80
        ? Colors.redAccent
        : (pct >= 60 ? Colors.amberAccent : const Color(0xFF10B981));
    final usedMb = (h?.dbSizeMb ?? 0).toStringAsFixed(1);
    final limitMb = (h?.dbLimitMb ?? 500).toStringAsFixed(0);

    return _GlassCard(
      borderColor: statusColor.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.storage_rounded, color: statusColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'سعة قاعدة البيانات (Free Plan)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: statusColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$usedMb MB مستخدم من أصل $limitMb MB المتاحة في الخطة المجانية',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    AdminResourceHealth? h,
    AppCustomTheme customTheme,
  ) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'النشاط الحي في قاعدة البيانات',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  'تحديات الآن',
                  '${h?.activeMatchesNow ?? 0}',
                  const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  'نشطون (5د)',
                  '${h?.activePlayers5m ?? 0}',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  'نشطون (24س)',
                  '${h?.activePlayers24h ?? 0}',
                  customTheme.sovereignAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ملاحظة: عداد اتصالات WebSocket اللحظية (حد 200) وEgress يُتابعان من لوحة Supabase Studio مباشرة.',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupCard(
    AdminResourceHealth? h,
    AppCustomTheme customTheme,
  ) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'تنظيف السجلات وتوفير المساحة',
            icon: Icons.cleaning_services_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              key: const Key('cleanup_matches_btn'),
              onPressed: _isCleaning
                  ? null
                  : () => _runCleanup(
                        action: 'finished_matches',
                        title: 'تنظيف المباريات القديمة',
                        description:
                            'سيتم حذف المباريات المنتهية الأقدم من 30 يوماً (مع الحفاظ التام على الأشباح المسجلة ونقاط اللاعبين).',
                      ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'تنظيف مباريات +30 يوماً (${h?.cleanableOldMatches ?? 0})',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: customTheme.sovereignAccent,
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
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              key: const Key('cleanup_receipts_btn'),
              onPressed: _isCleaning
                  ? null
                  : () => _runCleanup(
                        action: 'expired_receipts',
                        title: 'تنظيف إيصالات الإعلانات المنتهية',
                        description:
                            'سيتم حذف إيصالات القراءة الخاصة بالإعلانات المنتهية أو المتوقفة منذ أكثر من 30 يوماً.',
                      ),
              icon: const Icon(
                Icons.mark_email_read_outlined,
                size: 18,
                color: Colors.amberAccent,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'تنظيف إيصالات منتهية (${h?.cleanableExpiredReceipts ?? 0})',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                side: BorderSide(
                  color: Colors.amberAccent.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablesCard(
    AdminResourceHealth? h,
    AppCustomTheme customTheme,
  ) {
    final tables = h?.tables ?? const [];
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'أكبر الجداول استهلاكاً للمساحة',
            icon: Icons.table_chart_rounded,
          ),
          const SizedBox(height: 10),
          if (tables.isEmpty)
            const Text(
              'لا توجد بيانات جداول بعد.',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white60),
            )
          else
            for (final t in tables)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.tableName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${t.rowEstimate} صف',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: customTheme.sovereignAccent.withValues(
                          alpha: 0.16,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${t.sizeMb.toStringAsFixed(2)} MB',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: customTheme.sovereignAccent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _GlassCard({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ??
              customTheme.sovereignAccent.withValues(alpha: 0.42),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: accent,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
