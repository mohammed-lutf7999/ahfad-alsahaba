import 'package:flutter/material.dart';

import '../../core/date_formatters.dart';
import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/app_control_models.dart';
import '../../data/services/admin_service.dart';
import 'admin/widgets/admin_dashboard_actions_section.dart';
import 'admin/widgets/admin_dashboard_stats_section.dart';
import 'admin/widgets/admin_ui_kit.dart';

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
        : 'آخر تحديث: ${DateFormatters.formatHourMinute(_lastUpdated!)}';
    final accent = AppCustomTheme.of(context).sovereignAccent;

    return AdminScaffoldShell(
      title: 'لوحة تحكم المدير',
      subtitle: subtitle,
      isLoading: _isLoading,
      onRefresh: _loadStats,
      body: _isLoading
          ? Center(
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
            )
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminLiveStatusStrip(overview: _overview),
                    const SizedBox(height: 16),
                    AdminDashboardStatsSection(
                      overview: _overview,
                      fallbackStats: _fallbackStats,
                    ),
                    const SizedBox(height: 24),
                    AdminDashboardActionsSection(
                      releaseConfig: _overview?.releaseConfig,
                      onOpenScreen: _openAndRefresh,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
