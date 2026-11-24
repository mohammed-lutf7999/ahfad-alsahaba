import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/sound_service.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/services/app_control_service.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/royal_inbox_service.dart';
import '../../../widgets/top_notification.dart';
import '../../chat/global_chat_bottom_sheet.dart';

Future<void> showHomePlayerHubSheet(
  BuildContext context, {
  required String playerCode,
  required VoidCallback onRefresh,
}) async {
  final customTheme = AppCustomTheme.of(context);
  final unread = RoyalInboxService.instance.unreadCount;
  final control = AppControlService.instance;
  final isAdmin = control.isAdminNotifier.value;
  final isLoggedIn = AuthService().isLoggedIn;
  final flags = control.featureFlagsNotifier.value;
  final perms = control.playerPermissionsNotifier.value;
  final banned = !isAdmin && perms.isEffectivelyBannedNow;
  final inboxEnabled = isAdmin || flags.royalInbox;
  final diwanEnabled = (isAdmin || flags.diwanChat) &&
      !banned &&
      (isAdmin || !isLoggedIn || perms.canUseDiwan);
  final guildsEnabled = (isAdmin || flags.guildsArenas) &&
      !banned &&
      (isAdmin || !isLoggedIn || perms.canUseGuilds);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: customTheme.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _HubTile(
                tileKey: const Key('player_menu_inbox_tile'),
                borderColor: customTheme.sovereignAccent.withValues(alpha: 0.4),
                tileColor: customTheme.deepBackground.withValues(alpha: 0.45),
                icon: Icons.mark_email_unread_rounded,
                iconColor: customTheme.sovereignAccent,
                title: 'صندوق البريد الملكي 📬',
                subtitle: inboxEnabled
                    ? (unread > 0
                        ? 'لديك $unread رسالة غير مقروءة'
                        : 'رسائل الإدارة والهدايا والتعويضات')
                    : 'متوقف مؤقتاً للصيانة من الإدارة',
                trailing: inboxEnabled && unread > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : Icon(
                        inboxEnabled
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.lock_outline_rounded,
                        size: 15,
                        color: Colors.white54,
                      ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  SoundService().playClick();
                  if (!inboxEnabled) {
                    TopNotification.showError(
                      context,
                      'صندوق البريد الملكي متوقف مؤقتاً للصيانة ⚙️',
                    );
                    return;
                  }
                  await Navigator.pushNamed(context, AppRoutes.royalInbox);
                  if (context.mounted) onRefresh();
                },
              ),
              const SizedBox(height: 10),
              _HubTile(
                tileKey: const Key('player_menu_diwan_tile'),
                borderColor: const Color(0xFF10B981).withValues(alpha: 0.45),
                tileColor: customTheme.deepBackground.withValues(alpha: 0.42),
                icon: Icons.forum_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'ديوان الأحفاد 💬',
                subtitle: diwanEnabled
                    ? 'دردشة الفرسان المباشرة وتحدي الأعضاء'
                    : (!flags.diwanChat
                        ? 'متوقف مؤقتاً للصيانة من الإدارة'
                        : 'تم تقييد المشاركة في الديوان من الإدارة 🔒'),
                trailing: Icon(
                  diwanEnabled
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.lock_outline_rounded,
                  size: 15,
                  color: Colors.white54,
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  SoundService().playClick();
                  if (!diwanEnabled) {
                    TopNotification.showError(
                      context,
                      !flags.diwanChat
                          ? 'ديوان الأحفاد متوقف مؤقتاً للصيانة ⚙️'
                          : 'تم تقييد المشاركة في ديوان الأحفاد من الإدارة 🔒',
                    );
                    return;
                  }
                  await GlobalChatBottomSheet.show(context);
                },
              ),
              const SizedBox(height: 10),
              _HubTile(
                tileKey: const Key('player_menu_guilds_tile'),
                borderColor: Colors.amber.withValues(alpha: 0.45),
                tileColor: customTheme.deepBackground.withValues(alpha: 0.42),
                icon: Icons.shield_rounded,
                iconColor: Colors.amber,
                title: 'الكتائب والبطولات الحية 🛡️',
                subtitle: guildsEnabled
                    ? 'رايات الكتائب ومعركة الجمعة وغرف 100 مشارك'
                    : (!flags.guildsArenas
                        ? 'متوقف مؤقتاً للصيانة من الإدارة'
                        : 'تم تقييد نظام الكتائب من الإدارة 🔒'),
                trailing: Icon(
                  guildsEnabled
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.lock_outline_rounded,
                  size: 15,
                  color: Colors.white54,
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  SoundService().playClick();
                  if (!guildsEnabled) {
                    TopNotification.showError(
                      context,
                      !flags.guildsArenas
                          ? 'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً للصيانة ⚙️'
                          : 'تم تقييد نظام الكتائب على هذا الحساب من الإدارة 🔒',
                    );
                    return;
                  }
                  await Navigator.pushNamed(context, AppRoutes.guilds);
                },
              ),
              const SizedBox(height: 10),
              _HubTile(
                tileKey: const Key('player_menu_profile_tile'),
                borderColor: Colors.white.withValues(alpha: 0.16),
                tileColor: customTheme.deepBackground.withValues(alpha: 0.35),
                icon: Icons.person_rounded,
                iconColor: Colors.white70,
                title: 'ملفاتي وهويتي 👤',
                subtitle: 'إدارة الحساب وتبديل الملف • الكود: $playerCode',
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Colors.white54,
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  SoundService().playClick();
                  await Navigator.pushNamed(context, AppRoutes.profileSelector);
                  if (context.mounted) onRefresh();
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HubTile extends StatelessWidget {
  final Key tileKey;
  final Color borderColor;
  final Color tileColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _HubTile({
    required this.tileKey,
    required this.borderColor,
    required this.tileColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: tileKey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      tileColor: tileColor,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 12,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
