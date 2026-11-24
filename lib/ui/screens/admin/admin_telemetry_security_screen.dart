import 'package:flutter/material.dart';

import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import 'telemetry/telemetry_tabs.dart';
import 'widgets/admin_ui_kit.dart';

/// In-app Telemetry, Ghost Monitor, Audit Logs & Owner-Only Admins Roster screen.
class AdminTelemetrySecurityScreen extends StatefulWidget {
  const AdminTelemetrySecurityScreen({super.key});

  @override
  State<AdminTelemetrySecurityScreen> createState() =>
      _AdminTelemetrySecurityScreenState();
}

class _AdminTelemetrySecurityScreenState
    extends State<AdminTelemetrySecurityScreen> {
  final _newAdminEmailCtrl = TextEditingController();
  bool _isLoading = true;
  List<AdminGhostSummary> _ghosts = const [];
  List<AdminAuditLogEntry> _logs = const [];
  AdminRosterSnapshot _roster = const AdminRosterSnapshot();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _newAdminEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final admin = AdminService();
      final res = await Future.wait<dynamic>([
        admin.listGhosts(limit: 40),
        admin.listAuditLogs(limit: 50),
        admin.listAdmins(),
      ]);
      if (!mounted) return;
      setState(() {
        _ghosts = res[0] as List<AdminGhostSummary>;
        _logs = res[1] as List<AdminAuditLogEntry>;
        _roster = (res[2] as AdminRosterSnapshot?) ?? const AdminRosterSnapshot();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAdminFeedback(context, 'تعذر تحميل بيانات الرقابة: $e', isError: true);
    }
  }

  Future<void> _reloadGhostsAndAudit() async {
    try {
      final admin = AdminService();
      final res = await Future.wait<dynamic>([
        admin.listGhosts(limit: 40),
        admin.listAuditLogs(limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _ghosts = res[0] as List<AdminGhostSummary>;
        _logs = res[1] as List<AdminAuditLogEntry>;
      });
    } catch (e) {
      debugPrint('AdminTelemetry reload ghosts/audit failed: $e');
    }
  }

  Future<void> _reloadAuditOnly() async {
    try {
      final logs = await AdminService().listAuditLogs(limit: 50);
      if (mounted) setState(() => _logs = logs);
    } catch (e) {
      debugPrint('AdminTelemetry reload audit failed: $e');
    }
  }

  Future<void> _toggleGhost(AdminGhostSummary ghost, bool nextActive) async {
    try {
      final ok = await AdminService().toggleGhost(ghost.id, nextActive);
      if (!mounted) return;
      if (ok) {
        showAdminFeedback(
          context,
          nextActive ? 'تم تفعيل الشبح ✅' : 'تم إيقاف الشبح ⏸️',
        );
        await _reloadGhostsAndAudit();
      } else {
        showAdminFeedback(
          context,
          'تعذر تحديث حالة الشبح؛ تحقق من الاتصال وصلاحيات المشرف.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر تحديث الشبح: $e', isError: true);
    }
  }

  Future<void> _addAdmin() async {
    final email = _newAdminEmailCtrl.text.trim().toLowerCase();
    if (!email.contains('@')) {
      showAdminFeedback(context, 'أدخل بريداً إلكترونياً صالحاً.', isError: true);
      return;
    }
    try {
      final updated = await AdminService().manageAdmin(
        action: 'add',
        email: email,
        role: 'admin',
      );
      if (!mounted) return;
      if (updated == null) {
        showAdminFeedback(
          context,
          'تعذر إضافة المشرف؛ تحقق من صلاحيات المالك والاتصال.',
          isError: true,
        );
        return;
      }
      _newAdminEmailCtrl.clear();
      setState(() => _roster = updated);
      showAdminFeedback(context, 'تمت إضافة المشرف بنجاح ✅');
      await _reloadAuditOnly();
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر إضافة المشرف: $e', isError: true);
    }
  }

  Future<void> _removeAdmin(String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppCustomTheme.of(context).surfaceCard,
          title: const Text(
            'تأكيد إزالة مشرف',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
          content: Text(
            'هل تريد سحب صلاحيات الإشراف من:\n$email؟',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'إزالة الصلاحية',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      final updated = await AdminService().manageAdmin(
        action: 'remove',
        email: email,
      );
      if (!mounted) return;
      if (updated == null) {
        showAdminFeedback(
          context,
          'تعذر إزالة المشرف؛ تحقق من صلاحيات المالك والاتصال.',
          isError: true,
        );
        return;
      }
      setState(() => _roster = updated);
      showAdminFeedback(context, 'تمت إزالة المشرف ✅');
      await _reloadAuditOnly();
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر إزالة المشرف: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return AdminScaffoldShell(
      title: 'الأشباح والتدقيق والمشرفون',
      subtitle: 'مراقبة الأشباح وسجل الإجراءات وصلاحيات الإدارة',
      isLoading: _isLoading,
      onRefresh: _loadAll,
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TabBar(
                indicatorColor: accent,
                labelColor: accent,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
                tabs: const [
                  Tab(text: 'الأشباح'),
                  Tab(text: 'التدقيق'),
                  Tab(text: 'المشرفون'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : TabBarView(
                      children: [
                        TelemetryGhostsTab(
                          ghosts: _ghosts,
                          onToggleGhost: _toggleGhost,
                        ),
                        TelemetryAuditTab(logs: _logs),
                        TelemetryAdminsTab(
                          roster: _roster,
                          newAdminEmailController: _newAdminEmailCtrl,
                          onAddAdmin: _addAdmin,
                          onRemoveAdmin: _removeAdmin,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
