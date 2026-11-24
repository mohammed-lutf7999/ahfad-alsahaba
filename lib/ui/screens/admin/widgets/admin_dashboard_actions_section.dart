import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../../admin_email_screen.dart';
import '../admin_announcements_screen.dart';
import '../admin_bulk_pack_manager_screen.dart';
import '../admin_cms_manager_screen.dart';
import '../admin_events_screen.dart';
import '../admin_players_support_screen.dart';
import '../admin_release_control_screen.dart';
import '../admin_resources_screen.dart';
import '../admin_social_moderation_screen.dart';
import '../admin_telemetry_security_screen.dart';

class AdminDashboardActionsSection extends StatelessWidget {
  final AppReleaseConfig? releaseConfig;
  final ValueChanged<Widget> onOpenScreen;

  const AdminDashboardActionsSection({
    super.key,
    required this.releaseConfig,
    required this.onOpenScreen,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'أدوات الإدارة والتحكم',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_release_control'),
          title: 'الإصدارات والصيانة والمزايا',
          subtitle: 'التحديث الإلزامي، وضع الصيانة، و13 علم ميزة وتحكم ديناميكي',
          icon: Icons.tune_rounded,
          color: accent,
          onTap: () => onOpenScreen(
            AdminReleaseControlScreen(initialConfig: releaseConfig),
          ),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_social_moderation'),
          title: 'إشراف الديوان والكتائب والبطولات 🛡️',
          subtitle:
              'مراجعة البلاغات، فك الكتم، إدارة الكتائب، والإنهاء الفوري للساحات',
          icon: Icons.gavel_rounded,
          color: const Color(0xFF38BDF8),
          onTap: () => onOpenScreen(const AdminSocialModerationScreen()),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_announcements'),
          title: 'الرسائل الموجّهة والبحث',
          subtitle: 'بث جماعي أو استهداف مباشر (Google & SAH-XXXX)',
          icon: Icons.campaign_rounded,
          color: const Color(0xFFFB7185),
          onTap: () => onOpenScreen(const AdminAnnouncementsScreen()),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_events'),
          title: 'الأحداث والمواسم الديناميكية',
          subtitle: 'إطلاق وجدولة بانر الشاشة الرئيسية ومعاينته',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFFA78BFA),
          onTap: () => onOpenScreen(const AdminEventsScreen()),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_cms_manager'),
          title: 'إدارة المتجر والمحتوى (CMS)',
          subtitle: 'عناصر سوق الفرسان، المكتبة، المسابقات، وإظهار/إخفاء فوري',
          icon: Icons.store_mall_directory_rounded,
          color: accent,
          onTap: () => onOpenScreen(const AdminCmsManagerScreen()),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_bulk_packs'),
          title: 'استيراد JSON وحزم Gzip CDN 📦',
          subtitle:
              'رفع آلاف الأسئلة، المستويات المرنة (1–100)، ونمط السحب المتجدد',
          icon: Icons.archive_rounded,
          color: const Color(0xFF10B981),
          onTap: () => onOpenScreen(const AdminBulkPackManagerScreen()),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_players_support'),
          title: 'دعم اللاعبين والتعويضات',
          subtitle: 'فحص المحفظة والمقتنيات ومنح تعويض آمن بسجل تدقيق',
          icon: Icons.support_agent_rounded,
          color: const Color(0xFF10B981),
          onTap: () => onOpenScreen(const AdminPlayersSupportScreen()),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_telemetry'),
          title: 'الأشباح والتدقيق والمشرفون',
          subtitle: 'تبديل الأشباح وسجل الإجراءات وإدارة المشرفين',
          icon: Icons.security_rounded,
          color: Colors.amberAccent,
          onTap: () => onOpenScreen(const AdminTelemetrySecurityScreen()),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_resources'),
          title: 'مراقبة وإدارة موارد Supabase',
          subtitle: 'حجم القاعدة من 500MB، النشطون الآن، وتنظيف السجلات',
          icon: Icons.monitor_heart_rounded,
          color: const Color(0xFF38BDF8),
          onTap: () => onOpenScreen(const AdminResourcesScreen()),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          actionKey: const Key('admin_nav_email'),
          title: 'إرسال بريد إلكتروني',
          subtitle: 'مراسلة المستخدمين عبر البريد المسجّل',
          icon: Icons.email_rounded,
          color: const Color(0xFF38BDF8),
          onTap: () => onOpenScreen(const AdminEmailScreen()),
        ),
      ],
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final Key actionKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.actionKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.75),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
