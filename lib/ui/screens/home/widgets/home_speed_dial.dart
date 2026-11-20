import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/models/app_control_models.dart';
import '../../../../data/services/app_control_service.dart';
import '../../../../data/services/auth_service.dart';
import '../../../widgets/top_notification.dart';
import '../../creative_empire_screen.dart';
import '../../global_ranking_screen.dart';
import '../../chat/global_chat_bottom_sheet.dart';
import '../../multiplayer/lobby_screen.dart';

/// القائمة العائمة السريعة في زاوية الشاشة الرئيسية
/// تضم: التحدي الأونلاين، تحدي البوت، الإعدادات، الإمبراطورية، الترتيب العالمي، وتسجيل الدخول
class HomeSpeedDial extends StatelessWidget {
  final GlobalKey? challengeKey;
  final VoidCallback onRefresh;

  const HomeSpeedDial({
    super.key,
    this.challengeKey,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppFeatureFlags>(
      valueListenable: AppControlService.instance.featureFlagsNotifier,
      builder: (context, flags, _) => ValueListenableBuilder<PlayerPermissions>(
        valueListenable: AppControlService.instance.playerPermissionsNotifier,
        builder: (context, perms, _) {
          final isAdmin = AppControlService.instance.isAdminNotifier.value;
          final isLoggedIn = AuthService().isLoggedIn;
          final banned = !isAdmin && perms.isEffectivelyBannedNow;
          final onlineAllowed =
              (isAdmin || flags.onlineMultiplayer) && !banned && (isAdmin || perms.canUseOnline);
          final inboxAllowed = isAdmin || flags.royalInbox;
          final diwanAllowed = (isAdmin || flags.diwanChat) &&
              !banned &&
              (isAdmin || !isLoggedIn || perms.canUseDiwan);
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: SpeedDial(
                key: challengeKey,
                icon: Icons.keyboard_arrow_down_rounded,
                activeIcon: Icons.close_rounded,
                iconTheme: const IconThemeData(color: AppTheme.primaryDark, size: 20),
                buttonSize: const Size(40, 40),
                childrenButtonSize: const Size(44, 44),
                backgroundColor: AppTheme.accentColor,
                activeBackgroundColor: Colors.red.shade400,
                elevation: 4,
                overlayColor: Colors.black,
                overlayOpacity: 0.3,
                spacing: 8,
                spaceBetweenChildren: 8,
                direction: SpeedDialDirection.down,
                animationDuration: const Duration(milliseconds: 150),
                tooltip: '',
                heroTag: 'speed-dial',
                children: [
                  // Online Challenge Button
                  SpeedDialChild(
                    child: Icon(
                      onlineAllowed
                          ? Icons.language_rounded
                          : Icons.lock_clock_rounded,
                      color: onlineAllowed
                          ? AppTheme.primaryDark
                          : Colors.white70,
                      size: 22,
                    ),
                    backgroundColor: onlineAllowed
                        ? const Color(0xFF00E676)
                        : Colors.blueGrey.shade700,
                    onTap: () {
                      SoundService().playClick();
                      if (!onlineAllowed) {
                        TopNotification.showError(
                          context,
                          !flags.onlineMultiplayer
                              ? 'المباريات الأونلاين متوقفة مؤقتاً للصيانة ⚙️'
                              : 'تم تقييد اللعب الأونلاين على هذا الحساب من الإدارة 🔒',
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LobbyScreen()),
                      );
                    },
                  ),

            // Challenge Button
            SpeedDialChild(
              child: const Icon(
                Icons.sports_kabaddi_rounded,
                color: AppTheme.primaryDark,
                size: 20,
              ),
              backgroundColor: AppTheme.accentColor,
              onTap: () {
                SoundService().playClick();
                Navigator.pushNamed(context, AppRoutes.challenge);
              },
            ),

            // Settings Button
            SpeedDialChild(
              child: const Icon(
                Icons.settings_rounded,
                color: AppTheme.primaryDark,
                size: 20,
              ),
              backgroundColor: AppTheme.accentLight,
              onTap: () async {
                SoundService().playClick();
                await Navigator.pushNamed(context, AppRoutes.settings);
                onRefresh();
              },
            ),

            // Creative Empire Button
            SpeedDialChild(
              child: const Icon(
                Icons.diamond_rounded,
                color: AppTheme.primaryDark,
                size: 22,
              ),
              backgroundColor: const Color(0xFFFFD700),
              onTap: () {
                SoundService().playClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreativeEmpireScreen(),
                  ),
                );
              },
            ),

            // Global Ranking Button
            SpeedDialChild(
              child: const Icon(
                Icons.public_rounded,
                color: AppTheme.primaryDark,
                size: 22,
              ),
              backgroundColor: Colors.cyanAccent,
              onTap: () {
                SoundService().playClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GlobalRankingScreen(),
                  ),
                );
              },
            ),

            SpeedDialChild(
              child: Icon(
                inboxAllowed
                    ? Icons.mark_email_unread_rounded
                    : Icons.lock_clock_rounded,
                color: inboxAllowed ? Colors.white : Colors.white70,
                size: 22,
              ),
              backgroundColor: inboxAllowed
                  ? const Color(0xFF0EA5E9)
                  : Colors.blueGrey.shade700,
              onTap: () {
                SoundService().playClick();
                if (!inboxAllowed) {
                  TopNotification.showError(
                    context,
                    'صندوق البريد الملكي متوقف مؤقتاً للصيانة ⚙️',
                  );
                  return;
                }
                Navigator.pushNamed(context, AppRoutes.royalInbox);
              },
            ),

            SpeedDialChild(
              child: Icon(
                diwanAllowed ? Icons.forum_rounded : Icons.lock_clock_rounded,
                color: diwanAllowed ? Colors.white : Colors.white70,
                size: 21,
              ),
              backgroundColor: diwanAllowed
                  ? const Color(0xFF10B981)
                  : Colors.blueGrey.shade700,
              onTap: () {
                SoundService().playClick();
                if (!diwanAllowed) {
                  TopNotification.showError(
                    context,
                    !flags.diwanChat
                        ? 'ديوان الأحفاد متوقف مؤقتاً للصيانة ⚙️'
                        : 'تم تقييد المشاركة في ديوان الأحفاد من الإدارة 🔒',
                  );
                  return;
                }
                GlobalChatBottomSheet.show(context);
              },
            ),

            // Google Sign-In / Sign-Out Button (uses local crisp icon to avoid failing SVG network request)
            SpeedDialChild(
              child: AuthService().isLoggedIn
                  ? const Icon(Icons.logout_rounded, color: Colors.white, size: 22)
                  : const Icon(
                      Icons.login_rounded,
                      color: AppTheme.primaryDark,
                      size: 22,
                    ),
              backgroundColor: AuthService().isLoggedIn
                  ? Colors.red.shade400
                  : Colors.white,
              onTap: () async {
                SoundService().playClick();
                if (AuthService().isLoggedIn) {
                  final result = await AuthService().signOut();
                  if (context.mounted) {
                    TopNotification.showWarning(
                      context,
                      'تم تسجيل الخروج بنجاح',
                    );
                    if (result.shouldNavigateToSetup) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.profileSetup,
                        (route) => false,
                        arguments: {'isFirstTime': true},
                      );
                    }
                  }
                } else {
                  final result = await AuthService().signInWithGoogle();
                  if (context.mounted) {
                    if (result.success) {
                      TopNotification.showSuccess(
                        context,
                        'مرحباً ${AuthService().userDisplayName}! 🎉',
                      );
                      onRefresh();
                    } else {
                      TopNotification.showError(
                        context,
                        result.errorMessage ?? 'حدث خطأ',
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
        },
      ),
    );
  }
}
