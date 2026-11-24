import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import 'resource_metrics_cards.dart';

class ResourceCleanupCard extends StatelessWidget {
  final AdminResourceHealth? health;
  final bool isCleaning;
  final void Function({
    required String action,
    required String title,
    required String description,
  }) onRunCleanup;

  const ResourceCleanupCard({
    super.key,
    required this.health,
    required this.isCleaning,
    required this.onRunCleanup,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return ResourceGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ResourceSectionHeader(
            title: 'تنظيف السجلات وتوفير المساحة',
            icon: Icons.cleaning_services_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              key: const Key('cleanup_matches_btn'),
              onPressed: isCleaning
                  ? null
                  : () => onRunCleanup(
                        action: 'finished_matches',
                        title: 'تنظيف المباريات القديمة',
                        description:
                            'سيتم حذف المباريات المنتهية الأقدم من 30 يوماً (مع الحفاظ التام على الأشباح المسجلة ونقاط اللاعبين).',
                      ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'تنظيف مباريات +30 يوماً (${health?.cleanableOldMatches ?? 0})',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.primaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildOutlinedAction(
            key: const Key('cleanup_receipts_btn'),
            icon: Icons.mark_email_read_outlined,
            color: Colors.amberAccent,
            label:
                'تنظيف إيصالات منتهية (${health?.cleanableExpiredReceipts ?? 0})',
            action: 'expired_receipts',
            title: 'تنظيف إيصالات الإعلانات المنتهية',
            description:
                'سيتم حذف إيصالات القراءة الخاصة بالإعلانات المنتهية أو المتوقفة منذ أكثر من 30 يوماً.',
          ),
          const SizedBox(height: 8),
          _buildOutlinedAction(
            key: const Key('cleanup_sessions_btn'),
            icon: Icons.cast_for_education_rounded,
            color: const Color(0xFF38BDF8),
            label: 'تنظيف جلسات البطولات المنتهية',
            action: 'expired_live_sessions',
            title: 'تنظيف جلسات البطولات المنتهية',
            description:
                'سيتم حذف غرف البطولات الحية المنتهية الصلاحية أو المكتملة لتحرير المساحة.',
          ),
          const SizedBox(height: 8),
          _buildOutlinedAction(
            key: const Key('cleanup_chat_btn'),
            icon: Icons.forum_outlined,
            color: const Color(0xFF10B981),
            label: 'تنظيف رسائل الديوان (+24 ساعة)',
            action: 'old_chat_messages',
            title: 'تنظيف رسائل الديوان الأقدم من 24 ساعة',
            description:
                'سيتم حذف رسائل الديوان التي مرّ عليها أكثر من 24 ساعة.',
          ),
          const SizedBox(height: 8),
          _buildOutlinedAction(
            key: const Key('reset_guild_week_btn'),
            icon: Icons.shield_moon_outlined,
            color: Colors.amberAccent,
            label: 'تصفير أسبوع معركة الجمعة للكتائب',
            action: 'reset_guild_week',
            title: 'تصفير نقاط أسبوع معركة الجمعة الكبرى',
            description:
                'سيتم بدء أسبوع تنافسي جديد للكتائب (تصفير النقاط الأسبوعية فقط مع بقاء النقاط التراكمية الكلية كما هي).',
          ),
        ],
      ),
    );
  }

  Widget _buildOutlinedAction({
    required Key key,
    required IconData icon,
    required Color color,
    required String label,
    required String action,
    required String title,
    required String description,
  }) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        key: key,
        onPressed: isCleaning
            ? null
            : () => onRunCleanup(
                  action: action,
                  title: title,
                  description: description,
                ),
        icon: Icon(icon, size: 18, color: color),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              height: 1.2,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
