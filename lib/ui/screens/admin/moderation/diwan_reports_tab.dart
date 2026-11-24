import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';

class ModerationEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ModerationEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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

class DiwanReportsTab extends StatelessWidget {
  final List<AdminDiwanReport> reports;
  final void Function({
    required String action,
    String? messageId,
    String? targetUserId,
    int muteHours,
    String reason,
  }) onModerateDiwan;

  const DiwanReportsTab({
    super.key,
    required this.reports,
    required this.onModerateDiwan,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const ModerationEmptyState(
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
            color:
                AppCustomTheme.of(context).surfaceCard.withValues(alpha: 0.85),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => onModerateDiwan(
                      action: 'dismiss_reports',
                      messageId: r.messageId,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text(
                      'تجاهل',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: Key('btn_delete_report_msg_${r.messageId}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => onModerateDiwan(
                      action: 'delete_message',
                      messageId: r.messageId,
                      reason: 'حذف عبر إشراف الإدارة',
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text(
                      'حذف الرسالة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                    ),
                  ),
                  ElevatedButton.icon(
                    key: Key('btn_mute_report_user_${r.messageId}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => onModerateDiwan(
                      action: 'mute_user',
                      targetUserId: r.senderId,
                      muteHours: 24,
                      reason: r.latestReason,
                    ),
                    icon: const Icon(Icons.volume_off_rounded, size: 16),
                    label: const Text(
                      'كتم 24 ساعة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
