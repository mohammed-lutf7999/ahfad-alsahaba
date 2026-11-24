import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import 'resources/resource_cleanup_card.dart';
import 'resources/resource_metrics_cards.dart';
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
      if (result == null) {
        showAdminFeedback(
          context,
          'تعذر تنفيذ التنظيف؛ تحقق من الاتصال وصلاحيات المشرف.',
          isError: true,
        );
        return;
      }
      final deleted = result['deleted_count'] ?? 0;
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
    final accent = AppCustomTheme.of(context).sovereignAccent;
    final h = _health;

    return AdminScaffoldShell(
      title: 'مراقبة وإدارة الموارد 🎛️',
      subtitle: 'حجم قاعدة البيانات والنشاط الحي وتنظيف السجلات',
      isLoading: _isLoading,
      onRefresh: _loadHealth,
      body: RefreshIndicator(
        onRefresh: _loadHealth,
        color: accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (_error != null) ...[
              ResourceGlassCard(
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
            ResourceStorageCard(health: h),
            const SizedBox(height: 14),
            ResourceActivityCard(health: h),
            const SizedBox(height: 14),
            ResourceCleanupCard(
              health: h,
              isCleaning: _isCleaning,
              onRunCleanup: _runCleanup,
            ),
            const SizedBox(height: 14),
            ResourceTablesCard(health: h),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openStudioUsage,
                icon: Icon(
                  Icons.open_in_new_rounded,
                  color: accent,
                  size: 18,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'فتح مؤشرات Realtime وEgress في Supabase Studio',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  side: BorderSide(color: accent.withValues(alpha: 0.55)),
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
}
