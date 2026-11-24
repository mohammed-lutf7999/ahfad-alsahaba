import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/date_formatters.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../dynamic_event_detail_screen.dart';

class RoyalInboxMessageCard extends StatelessWidget {
  final RoyalInboxMessage item;
  final Future<void> Function(RoyalInboxMessage) onMarkRead;

  const RoyalInboxMessageCard({
    super.key,
    required this.item,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final ann = item.announcement;
    final accent = _accentFor(ann, customTheme, item.isRewardNotice);
    final hasCta = ann.ctaLabel != null &&
        ann.ctaLabel!.trim().isNotEmpty &&
        ann.ctaRoute != null &&
        ann.ctaRoute!.trim().isNotEmpty;

    return InkWell(
      onTap: () {
        SoundService().playClick();
        onMarkRead(item);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: customTheme.surfaceCard.withValues(
            alpha: item.isRead ? 0.65 : 0.94,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isRead
                ? Colors.white.withValues(alpha: 0.14)
                : accent.withValues(alpha: 0.72),
            width: item.isRead ? 1 : 1.6,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (!item.isRead) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _badgeFor(ann, item.isRewardNotice),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                if (ann.targetScope == 'single_user')
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.person_pin_rounded,
                      size: 16,
                      color: customTheme.sovereignAccent,
                    ),
                  ),
                Text(
                  DateFormatters.formatDayMonthTime(ann.createdAt),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ann.title,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 15,
                fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ann.body,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 13,
                height: 1.55,
              ),
            ),
            if (hasCta) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    SoundService().playClick();
                    await onMarkRead(item);
                    if (!context.mounted) return;
                    await AppControlVisuals.handleRouteOrUrl(
                      context,
                      ann.ctaRoute,
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    ann.ctaLabel!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      height: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _accentFor(
    AppAnnouncement ann,
    AppCustomTheme customTheme,
    bool isReward,
  ) {
    if (isReward) return const Color(0xFF10B981);
    switch (ann.messageType) {
      case AnnouncementType.mandatory:
        return Colors.redAccent;
      case AnnouncementType.admin:
        return customTheme.sovereignAccent;
      case AnnouncementType.motivational:
        return const Color(0xFF10B981);
      case AnnouncementType.normal:
        return const Color(0xFF38BDF8);
    }
  }

  String _badgeFor(AppAnnouncement ann, bool isReward) {
    if (isReward) return 'هدية وتعويض 🎁';
    switch (ann.messageType) {
      case AnnouncementType.mandatory:
        return 'إشعار إلزامي ⚠️';
      case AnnouncementType.admin:
        return 'رسالة إدارية 🛡️';
      case AnnouncementType.motivational:
        return 'تحفيزية ✨';
      case AnnouncementType.normal:
        return 'إعلان 📢';
    }
  }
}
