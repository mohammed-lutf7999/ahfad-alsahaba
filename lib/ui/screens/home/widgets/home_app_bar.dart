import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/models/player_profile_model.dart';
import '../../../../data/services/app_control_service.dart';
import '../../../../data/services/royal_inbox_service.dart';
import '../../../widgets/animated_avatar_frame.dart';
import '../../../widgets/avatar_selector.dart';
import '../../../widgets/level_badge_widget.dart';
import 'home_glowing_trophy_button.dart';
import 'home_speed_dial.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PlayerProfile? profile;
  final int newAchievements;
  final GlobalKey profileKey;
  final GlobalKey achievementsKey;
  final GlobalKey challengeKey;
  final VoidCallback onOpenPlayerHub;
  final VoidCallback onRefresh;

  const HomeAppBar({
    super.key,
    required this.profile,
    required this.newAchievements,
    required this.profileKey,
    required this.achievementsKey,
    required this.challengeKey,
    required this.onOpenPlayerHub,
    required this.onRefresh,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final activeProfile = profile;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 64,
      leading: activeProfile != null
          ? GestureDetector(
              key: const Key('home_player_avatar_btn'),
              onTap: () {
                SoundService().playClick();
                onOpenPlayerHub();
              },
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable:
                      RoyalInboxService.instance.unreadCountNotifier,
                  builder: (context, unreadCount, _) {
                    final control = AppControlService.instance;
                    final showInboxBadge = unreadCount > 0 &&
                        (control.isAdminNotifier.value ||
                            control.featureFlagsNotifier.value.royalInbox);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedAvatarFrame(
                          size: 46,
                          frameKey: activeProfile.equippedFrame,
                          winStreak: activeProfile.winStreak,
                          child: ProfileAvatar(
                            avatarIndex: activeProfile.avatarIndex,
                            size: 38,
                          ),
                        ),
                        if (showInboxBadge)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            )
          : null,
      title: activeProfile != null
          ? GestureDetector(
              key: profileKey,
              onTap: () {
                SoundService().playClick();
                onOpenPlayerHub();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(
                            activeProfile.name,
                            style: const TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        LevelBadgeWidget(
                          levelInfo: activeProfile.levelInfo,
                          customTitle: activeProfile.effectiveTitle,
                          isCompact: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: AppTheme.accentLight,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${activeProfile.totalScore}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '🪙 ${activeProfile.coins}',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '💎 ${activeProfile.gems}',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
      actions: [
        HomeGlowingTrophyButton(
          key: achievementsKey,
          hasNotification: newAchievements > 0,
          notificationCount: newAchievements,
          onTap: () async {
            SoundService().playClick();
            await Navigator.pushNamed(context, AppRoutes.achievements);
            onRefresh();
          },
        ),
        HomeSpeedDial(
          challengeKey: challengeKey,
          onRefresh: onRefresh,
        ),
      ],
    );
  }
}
