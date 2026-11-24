import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';

class TelemetryGhostsTab extends StatelessWidget {
  final List<AdminGhostSummary> ghosts;
  final void Function(AdminGhostSummary ghost, bool nextActive) onToggleGhost;

  const TelemetryGhostsTab({
    super.key,
    required this.ghosts,
    required this.onToggleGhost,
  });

  @override
  Widget build(BuildContext context) {
    if (ghosts.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد تسجيلات أشباح بعد.',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      itemCount: ghosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final g = ghosts[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                AppCustomTheme.of(context).surfaceCard.withValues(alpha: 0.8),
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
                onChanged: (v) => onToggleGhost(g, v),
                activeColor: const Color(0xFF10B981),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TelemetryAuditTab extends StatelessWidget {
  final List<AdminAuditLogEntry> logs;

  const TelemetryAuditTab({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'سجل التدقيق فارغ حالياً.',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final log = logs[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                AppCustomTheme.of(context).surfaceCard.withValues(alpha: 0.8),
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
                log.reason.isEmpty
                    ? '${log.targetType}: ${log.targetId}'
                    : log.reason,
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
}

class TelemetryAdminsTab extends StatelessWidget {
  final AdminRosterSnapshot roster;
  final TextEditingController newAdminEmailController;
  final VoidCallback onAddAdmin;
  final ValueChanged<String> onRemoveAdmin;

  const TelemetryAdminsTab({
    super.key,
    required this.roster,
    required this.newAdminEmailController,
    required this.onAddAdmin,
    required this.onRemoveAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        if (roster.isOwner) ...[
          AdminSectionCard(
            title: 'إضافة مشرف جديد (صلاحية المالك)',
            icon: Icons.admin_panel_settings_rounded,
            child: Column(
              children: [
                AdminTextField(
                  controller: newAdminEmailController,
                  label: 'البريد الإلكتروني',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                AdminPrimaryButton(
                  label: 'إضافة كمشرف',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: onAddAdmin,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        AdminSectionCard(
          title: 'الطاقم الحالي (${roster.admins.length})',
          icon: Icons.shield_rounded,
          child: Column(
            children: [
              for (final a in roster.admins)
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
                  trailing: roster.isOwner
                      ? IconButton(
                          onPressed: () => onRemoveAdmin(a.email),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
