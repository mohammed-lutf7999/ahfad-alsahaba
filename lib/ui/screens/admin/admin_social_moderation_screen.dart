import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import 'moderation/diwan_reports_tab.dart';
import 'moderation/guilds_arenas_mod_tab.dart';
import 'moderation/muted_users_tab.dart';
import 'widgets/admin_ui_kit.dart';

/// In-App Admin Moderation Command Center for:
/// 1. Diwan reports & offensive message moderation (`diwan_reports`).
/// 2. Active muted players management & unmute (`diwan_moderation`).
/// 3. Guilds administration & live tournament arenas emergency force-finish.
class AdminSocialModerationScreen extends StatefulWidget {
  const AdminSocialModerationScreen({super.key});

  @override
  State<AdminSocialModerationScreen> createState() =>
      _AdminSocialModerationScreenState();
}

class _AdminSocialModerationScreenState
    extends State<AdminSocialModerationScreen> {
  bool _isLoading = true;
  AdminDiwanModerationQueue _diwanQueue = const AdminDiwanModerationQueue();
  AdminGuildsAndArenasSnapshot _guildsArenas =
      const AdminGuildsAndArenasSnapshot();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        AdminService().getDiwanModerationQueue(limit: 50),
        AdminService().listGuildsAndArenas(limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _diwanQueue = results[0] as AdminDiwanModerationQueue;
        _guildsArenas = results[1] as AdminGuildsAndArenasSnapshot;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAdminFeedback(
        context,
        'تعذر تحديث طابور الإشراف: $e',
        isError: true,
      );
    }
  }

  Future<void> _moderateDiwanAction({
    required String action,
    String? messageId,
    String? targetUserId,
    int muteHours = 24,
    String reason = '',
  }) async {
    SoundService().playClick();
    try {
      final res = await AdminService().moderateDiwan(
        action: action,
        messageId: messageId,
        targetUserId: targetUserId,
        muteHours: muteHours,
        reason: reason,
      );
      if (!mounted) return;
      if (res != null) {
        showAdminFeedback(context, 'تم تنفيذ الإجراء بنجاح ✅');
        await _loadAll();
      } else {
        showAdminFeedback(context, 'فشل تنفيذ الإجراء', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'خطأ أثناء تنفيذ الإشراف: $e', isError: true);
      }
    }
  }

  Future<void> _moderateGuildArenaAction({
    required String action,
    required String targetId,
    String reason = '',
  }) async {
    SoundService().playClick();
    try {
      final res = await AdminService().moderateGuildOrArena(
        action: action,
        targetId: targetId,
        reason: reason,
      );
      if (!mounted) return;
      if (res != null) {
        showAdminFeedback(context, 'تم تنفيذ الإجراء وتحديث الحالة ✅');
        await _loadAll();
      } else {
        showAdminFeedback(context, 'فشل تنفيذ الإجراء', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'خطأ أثناء الإجراء: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return DefaultTabController(
      length: 3,
      child: AdminScaffoldShell(
        title: 'إشراف الديوان والكتائب',
        subtitle:
            '${_diwanQueue.reports.length} بلاغات • ${_diwanQueue.mutedUsers.length} مكتومين • ${_guildsArenas.liveSessions.length} ساحات',
        isLoading: _isLoading,
        onRefresh: _loadAll,
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                ),
                tabs: [
                  Tab(
                    key: const Key('admin_social_moderation_tab_reports'),
                    text: 'البلاغات (${_diwanQueue.reports.length})',
                    icon: const Icon(Icons.report_problem_rounded, size: 18),
                  ),
                  Tab(
                    key: const Key('admin_social_moderation_tab_muted'),
                    text: 'المكتومون (${_diwanQueue.mutedUsers.length})',
                    icon: const Icon(Icons.volume_off_rounded, size: 18),
                  ),
                  const Tab(
                    key: Key('admin_social_moderation_tab_guilds_arenas'),
                    text: 'الكتائب والساحات',
                    icon: Icon(Icons.groups_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  DiwanReportsTab(
                    reports: _diwanQueue.reports,
                    onModerateDiwan: _moderateDiwanAction,
                  ),
                  MutedUsersTab(
                    mutedUsers: _diwanQueue.mutedUsers,
                    onUnmuteUser: (uid) => _moderateDiwanAction(
                      action: 'unmute_user',
                      targetUserId: uid,
                      reason: 'فك الكتم بقرار إداري',
                    ),
                  ),
                  GuildsArenasModTab(
                    arenas: _guildsArenas.liveSessions,
                    guilds: _guildsArenas.guilds,
                    onModerateGuildArena: _moderateGuildArenaAction,
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
