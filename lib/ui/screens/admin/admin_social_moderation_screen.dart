import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import 'widgets/admin_ui_kit.dart';

/// In-App Admin Moderation Command Center for:
/// 1. Diwan reports & offensive message moderation (`diwan_reports`).
/// 2. Active muted players management & unmute (`diwan_moderation`).
/// 3. Guilds administration & live tournament arenas emergency force-finish (`guilds`, `live_quiz_sessions`).
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
      final queueFuture = AdminService().getDiwanModerationQueue(limit: 50);
      final gaFuture = AdminService().listGuildsAndArenas(limit: 50);
      final results = await Future.wait([queueFuture, gaFuture]);

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
                  color: AppCustomTheme.of(context)
                      .sovereignAccent
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppCustomTheme.of(context).sovereignAccent,
                  ),
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
                  Tab(
                    key: const Key('admin_social_moderation_tab_guilds_arenas'),
                    text: 'الكتائب والساحات',
                    icon: const Icon(Icons.groups_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildReportsTab(),
                  _buildMutedTab(),
                  _buildGuildsAndArenasTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    final reports = _diwanQueue.reports;
    if (reports.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'طابور البلاغات نظيف ✨',
        subtitle: 'لا توجد بلاغات معلقة على رسائل الديوان حالياً.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = reports[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppCustomTheme.of(context).surfaceCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${r.reportsCount} بلاغات ⚠️',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.latestReason,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.amberAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'المرسل: ${r.senderName} (${r.senderCode ?? r.senderId.substring(0, 8)})',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '"${r.content}"',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: Key('btn_dismiss_reports_${r.messageId}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => _moderateDiwanAction(
                      action: 'dismiss_reports',
                      messageId: r.messageId,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('تجاهل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                  ),
                  OutlinedButton.icon(
                    key: Key('btn_delete_report_msg_${r.messageId}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => _moderateDiwanAction(
                      action: 'delete_message',
                      messageId: r.messageId,
                      reason: 'حذف عبر إشراف الإدارة',
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('حذف الرسالة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                  ),
                  ElevatedButton.icon(
                    key: Key('btn_mute_report_user_${r.messageId}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => _moderateDiwanAction(
                      action: 'mute_user',
                      targetUserId: r.senderId,
                      muteHours: 24,
                      reason: r.latestReason,
                    ),
                    icon: const Icon(Icons.volume_off_rounded, size: 16),
                    label: const Text('كتم 24 ساعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMutedTab() {
    final muted = _diwanQueue.mutedUsers;
    if (muted.isEmpty) {
      return _buildEmptyState(
        icon: Icons.speaker_notes_rounded,
        title: 'لا يوجد لاعبون مكتومون 🕊️',
        subtitle: 'ديوان الأحفاد هادئ ولا يوجد أي لاعب مقيد بالكتم حالياً.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: muted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final u = muted[index];
        final remaining = u.mutedUntil != null
            ? u.mutedUntil!.difference(DateTime.now().toUtc())
            : Duration.zero;
        final hoursLeft = remaining.inHours;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppCustomTheme.of(context).surfaceCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.amberAccent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.volume_off_rounded, color: Colors.amberAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.displayName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'كود: ${u.playerCode ?? u.userId.substring(0, 8)} • متبقي: ${hoursLeft > 0 ? "$hoursLeft ساعة" : "أقل من ساعة"}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white60,
                        fontSize: 11.5,
                      ),
                    ),
                    if (u.reason.isNotEmpty)
                      Text(
                        'السبب: ${u.reason}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.amberAccent,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: Key('unmute_user_btn_${u.userId}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () => _moderateDiwanAction(
                  action: 'unmute_user',
                  targetUserId: u.userId,
                  reason: 'فك الكتم بقرار إداري',
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 16),
                label: const Text('فك الكتم', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuildsAndArenasTab() {
    final arenas = _guildsArenas.liveSessions;
    final guilds = _guildsArenas.guilds;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Arenas Section
          AdminSectionCard(
            title: 'ساحات البطولات الحية (${arenas.length})',
            icon: Icons.stadium_rounded,
            accentColor: const Color(0xFF38BDF8),
            child: arenas.isEmpty
                ? const Text(
                    'لا توجد ساحات بطولات حية تعمل حالياً.',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white60, fontSize: 12),
                  )
                : Column(
                    children: [
                      for (final a in arenas) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: a.isActiveOrWaiting
                                  ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                                  : Colors.white24,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'PIN: ${a.pinCode}',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          color: Color(0xFF38BDF8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: a.status == 'active'
                                              ? Colors.green
                                                  .withValues(alpha: 0.2)
                                              : Colors.amber
                                                  .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          a.status == 'active'
                                              ? 'نشطة 🟢'
                                              : 'في الانتظار ⏳',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            color: a.status == 'active'
                                                ? Colors.greenAccent
                                                : Colors.amberAccent,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${a.participantsCount} فرسان',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${a.title} • المضيف: ${a.hostName}',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (a.isActiveOrWaiting)
                                    ElevatedButton.icon(
                                      key: Key(
                                          'btn_force_finish_session_${a.id}'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () =>
                                          _moderateGuildArenaAction(
                                        action: 'force_finish_session',
                                        targetId: a.id,
                                        reason: 'إنهاء إداري فوري للساحة',
                                      ),
                                      icon: const Icon(
                                          Icons.stop_circle_rounded,
                                          size: 16),
                                      label: const Text(
                                          'إنهاء فوري وبث النتيجة',
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 11)),
                                    ),
                                  IconButton(
                                    key: Key('btn_delete_session_${a.id}'),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.white60,
                                        size: 20),
                                    tooltip: 'حذف السلسلة',
                                    onPressed: () =>
                                        _moderateGuildArenaAction(
                                      action: 'delete_session',
                                      targetId: a.id,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          // Guilds Section
          AdminSectionCard(
            title: 'كتائب الفرسان (${guilds.length})',
            icon: Icons.shield_rounded,
            accentColor: AppCustomTheme.of(context).sovereignAccent,
            child: guilds.isEmpty
                ? const Text(
                    'لا توجد كتائب مسجلة حتى الآن.',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white60, fontSize: 12),
                  )
                : Column(
                    children: [
                      for (final g in guilds) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppCustomTheme.of(context)
                                  .sovereignAccent
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      g.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${g.membersCount}/${g.maxMembers} عضو',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AppCustomTheme.of(context)
                                          .sovereignAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'القائد: ${g.leaderName} • رصيد أسبوعي: ${g.weeklyScore} • إجمالي: ${g.totalScore}',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white60,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    key: Key('btn_reset_guild_score_${g.id}'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.amberAccent,
                                      side: const BorderSide(
                                          color: Colors.amberAccent),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: () => _moderateGuildArenaAction(
                                      action: 'reset_single_guild_score',
                                      targetId: g.id,
                                      reason: 'تصفير رصيد الكتيبة إدارياً',
                                    ),
                                    icon: const Icon(Icons.restart_alt_rounded,
                                        size: 16),
                                    label: const Text('تصفير الرصيد',
                                        style: TextStyle(
                                            fontFamily: 'Cairo', fontSize: 11)),
                                  ),
                                  IconButton(
                                    key: Key('btn_delete_guild_${g.id}'),
                                    icon: const Icon(
                                        Icons.delete_forever_rounded,
                                        color: Colors.redAccent,
                                        size: 20),
                                    tooltip: 'حل الكتيبة وحذفها',
                                    onPressed: () => _moderateGuildArenaAction(
                                      action: 'delete_guild',
                                      targetId: g.id,
                                      reason: 'حل الكتيبة بقرار إداري',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white60,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
