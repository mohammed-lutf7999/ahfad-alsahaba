import 'package:flutter/material.dart';

import '../../../../core/sound_service.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../widgets/admin_ui_kit.dart';

class ReleaseFeatureFlagsCard extends StatelessWidget {
  final Map<String, bool> flags;
  final void Function(String key, bool value) onFlagChanged;

  const ReleaseFeatureFlagsCard({
    super.key,
    required this.flags,
    required this.onFlagChanged,
  });

  static const List<({String key, String title, String subtitle})> _flagSpecs =
      [
    (
      key: 'online_multiplayer',
      title: 'المباريات الأونلاين السريعة',
      subtitle: 'تفعيل أو إيقاف الميدان المباشر',
    ),
    (
      key: 'ghost_matches',
      title: 'محرك معارك الأشباح المسجّلة',
      subtitle: 'السقوط للبوت المحلي فقط عند الإيقاف',
    ),
    (
      key: 'private_rooms',
      title: 'غرف التحدي الخاصة',
      subtitle: 'إتاحة أو قفل غرف الأصدقاء السداسية',
    ),
    (
      key: 'knights_store',
      title: 'سوق الفرسان (المتجر)',
      subtitle: 'فتح أو إغلاق تبويب وشاشات المتجر',
    ),
    (
      key: 'show_event_banner',
      title: 'بانر الأحداث الديناميكية',
      subtitle: 'إظهار أو إخفاء شريط الفعاليات في الرئيسية',
    ),
    (
      key: 'daily_challenges',
      title: 'التحدي اليومي المتجدد 🌟',
      subtitle: 'إظهار بطاقة الجولة اليومية في قائمة التحدي',
    ),
    (
      key: 'royal_inbox',
      title: 'صندوق البريد الملكي 📬',
      subtitle: 'تفعيل أو إيقاف صندوق الرسائل والهدايا للاعبين',
    ),
    (
      key: 'live_announcement_ping',
      title: 'النبضة اللحظية للرسائل ⚡',
      subtitle: 'إيقاظ فوري (<1ث) للمتصلين أو إيقافه لتوفير WebSockets',
    ),
    (
      key: 'wise_teacher_mode',
      title: 'وضع المعلم الحكيم 🧠',
      subtitle: 'التحكم المركزي بميزة مراجعة الأخطاء والإضاءة التاريخية',
    ),
    (
      key: 'diwan_chat',
      title: 'ديوان الأحفاد (الدردشة الحية) 💬',
      subtitle: 'فتح أو إيقاف غرفة التواصل الجماعي وتحديات الديوان',
    ),
    (
      key: 'guilds_arenas',
      title: 'الكتائب والبطولات الجماعية 🛡️',
      subtitle: 'تفعيل أو إيقاف نظام الكتائب وغرف البطولات الحية',
    ),
    (
      key: 'quick_phrases',
      title: 'عبارات الفرسان السريعة في النزالات 💬',
      subtitle: 'إتاحة إرسال واستقبال عبارات الفروسية في المعارك',
    ),
    (
      key: 'live_arena_host_restricted',
      title: 'حصر إنشاء البطولات الحية بالمعلمين والمشرفين 🎓',
      subtitle: 'قصر زر إنشاء البطولة على المشرفين أو المعلمين المفوّضين',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return AdminSectionCard(
      title: 'أعلام التحكم الفوري بالمزايا (Feature Flags)',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          for (final spec in _flagSpecs)
            SwitchListTile.adaptive(
              key: Key('flag_${spec.key}'),
              contentPadding: EdgeInsets.zero,
              activeColor: accent,
              title: Text(
                spec.title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                spec.subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11.5,
                ),
              ),
              value: flags[spec.key] ?? true,
              onChanged: (val) {
                SoundService().playClick();
                onFlagChanged(spec.key, val);
              },
            ),
        ],
      ),
    );
  }
}
