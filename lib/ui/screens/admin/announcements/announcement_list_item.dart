import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';

class AnnouncementListItem extends StatelessWidget {
  final AppAnnouncement announcement;
  final ValueChanged<bool> onToggleActive;

  const AnnouncementListItem({
    super.key,
    required this.announcement,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final ann = announcement;
    final badgeColor = switch (ann.messageType) {
      AnnouncementType.mandatory => Colors.redAccent,
      AnnouncementType.admin => const Color(0xFF38BDF8),
      AnnouncementType.motivational => const Color(0xFF10B981),
      AnnouncementType.normal => AppCustomTheme.of(context).sovereignAccent,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeColor.withValues(alpha: ann.isActive ? 0.5 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ann.messageType.wireName,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ann.targetScope == 'single_user'
                      ? 'موجهة: ${ann.targetPlayerCode ?? ann.targetUserId ?? 'مستخدم'}'
                      : 'للجميع',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '👁️ ${ann.receiptCount}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 11.5,
                ),
              ),
              Switch.adaptive(
                key: Key('toggle_announcement_${ann.id}'),
                value: ann.isActive,
                activeColor: badgeColor,
                onChanged: onToggleActive,
              ),
            ],
          ),
          Text(
            ann.title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ann.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          if (ann.minVersionCode != null ||
              ann.maxVersionCode != null ||
              ann.expiresAt != null ||
              (ann.ctaRoute != null && ann.ctaRoute!.isNotEmpty)) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (ann.minVersionCode != null || ann.maxVersionCode != null)
                  Text(
                    'البناء: ${ann.minVersionCode ?? 1}..${ann.maxVersionCode ?? '∞'}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 10.5,
                    ),
                  ),
                if (ann.expiresAt != null)
                  Text(
                    'ينتهي: ${formatAdminDateTime(ann.expiresAt)}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.amberAccent.withValues(alpha: 0.85),
                      fontSize: 10.5,
                    ),
                  ),
                if (ann.ctaRoute != null && ann.ctaRoute!.isNotEmpty)
                  Text(
                    'المسار: ${ann.ctaRoute}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: badgeColor.withValues(alpha: 0.9),
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
