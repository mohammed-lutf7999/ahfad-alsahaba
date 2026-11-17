import 'package:flutter/material.dart';

import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
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

  Future<void> _toggleGhost(AdminGhostSummary ghost, bool nextActive) async {
    try {
      final ok = await AdminService().toggleGhost(ghost.id, nextActive);
      if (!mounted) return;
      if (ok) {
        showAdminFeedback(
          context,
          nextActive ? 'تم تفعيل الشبح ✅' : 'تم إيقاف الشبح ⏸️',
        );
        await _loadAll();
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
      _newAdminEmailCtrl.clear();
      setState(() {
        if (updated != null) _roster = updated;
      });
      showAdminFeedback(context, 'تمت إضافة المشرف بنجاح ✅');
      await _loadAll();
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
      setState(() {
        if (updated != null) _roster = updated;
      });
      showAdminFeedback(context, 'تمت إزالة المشرف ✅');
      await _loadAll();
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
                        _buildGhostsTab(),
                        _buildAuditTab(),
                        _buildAdminsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostsTab() {
    if (_ghosts.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد تسجيلات أشباح بعد.',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      itemCount: _ghosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final g = _ghosts[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppCustomTheme.of(context).surfaceCard.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${g.isHuman ? "👤" : "🤖"} ${g.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'م${g.playerLevel} • 🏆 ${g.trophies} • استخدامات: ${g.useCount}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white60,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: g.isActive,
                onChanged: (v) => _toggleGhost(g, v),
                activeColor: const Color(0xFF10B981),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditTab() {
    if (_logs.isEmpty) {
      return const Center(
        child: Text(
          'سجل التدقيق فارغ حالياً.',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final log = _logs[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppCustomTheme.of(context).surfaceCard.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log.action,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppCustomTheme.of(context).sovereignAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    formatAdminDateTime(log.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                log.reason.isEmpty ? '${log.targetType}: ${log.targetId}' : log.reason,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 12.5,
                ),
              ),
              Text(
                '${log.adminEmail ?? "system"} • ${log.targetType}:${log.targetId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white60,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        if (_roster.isOwner) ...[
          AdminSectionCard(
            title: 'إضافة مشرف جديد (صلاحية المالك)',
            icon: Icons.admin_panel_settings_rounded,
            child: Column(
              children: [
                AdminTextField(
                  controller: _newAdminEmailCtrl,
                  label: 'البريد الإلكتروني',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                AdminPrimaryButton(
                  label: 'إضافة كمشرف',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _addAdmin,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        AdminSectionCard(
          title: 'الطاقم الحالي (${_roster.admins.length})',
          icon: Icons.shield_rounded,
          child: Column(
            children: [
              for (final a in _roster.admins) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    a.email,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    a.isOwner ? 'المالك (owner)' : 'مشرف (admin)',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: a.isOwner ? Colors.amberAccent : Colors.white60,
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: _roster.isOwner
                      ? IconButton(
                          onPressed: () => _removeAdmin(a.email),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
