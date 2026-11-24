import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';

class GuildsArenasModTab extends StatelessWidget {
  final List<AdminLiveSessionSummary> arenas;
  final List<AdminGuildSummary> guilds;
  final void Function({
    required String action,
    required String targetId,
    String reason,
  }) onModerateGuildArena;

  const GuildsArenasModTab({
    super.key,
    required this.arenas,
    required this.guilds,
    required this.onModerateGuildArena,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionCard(
            title: 'ساحات البطولات الحية (${arenas.length})',
            icon: Icons.stadium_rounded,
            accentColor: const Color(0xFF38BDF8),
            child: arenas.isEmpty
                ? const Text(
                    'لا توجد ساحات بطولات حية تعمل حالياً.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  )
                : Column(
                    children: [
                      for (final a in arenas) _buildArenaTile(a),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          AdminSectionCard(
            title: 'كتائب الفرسان (${guilds.length})',
            icon: Icons.shield_rounded,
            accentColor: accent,
            child: guilds.isEmpty
                ? const Text(
                    'لا توجد كتائب مسجلة حتى الآن.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  )
                : Column(
                    children: [
                      for (final g in guilds) _buildGuildTile(g, accent),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildArenaTile(AdminLiveSessionSummary a) {
    return Container(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: a.status == 'active'
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      a.status == 'active' ? 'نشطة 🟢' : 'في الانتظار ⏳',
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
                  key: Key('btn_force_finish_session_${a.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  onPressed: () => onModerateGuildArena(
                    action: 'force_finish_session',
                    targetId: a.id,
                    reason: 'إنهاء إداري فوري للساحة',
                  ),
                  icon: const Icon(Icons.stop_circle_rounded, size: 16),
                  label: const Text(
                    'إنهاء فوري وبث النتيجة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
                  ),
                ),
              IconButton(
                key: Key('btn_delete_session_${a.id}'),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white60,
                  size: 20,
                ),
                tooltip: 'حذف السلسلة',
                onPressed: () => onModerateGuildArena(
                  action: 'delete_session',
                  targetId: a.id,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuildTile(AdminGuildSummary g, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
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
                  color: accent,
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
                  side: const BorderSide(color: Colors.amberAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: () => onModerateGuildArena(
                  action: 'reset_single_guild_score',
                  targetId: g.id,
                  reason: 'تصفير رصيد الكتيبة إدارياً',
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text(
                  'تصفير الرصيد',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
                ),
              ),
              IconButton(
                key: Key('btn_delete_guild_${g.id}'),
                icon: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                tooltip: 'حل الكتيبة وحذفها',
                onPressed: () => onModerateGuildArena(
                  action: 'delete_guild',
                  targetId: g.id,
                  reason: 'حل الكتيبة بقرار إداري',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
