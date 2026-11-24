import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/local/shared_prefs_service.dart';
import '../../../data/models/player_profile_model.dart';
import '../../widgets/avatar_selector.dart';

class SettingsProfileCard extends StatelessWidget {
  final PlayerProfile profile;
  final VoidCallback onProfileUpdated;

  const SettingsProfileCard({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final playerCode = profile.playerCode.trim().isNotEmpty
        ? profile.playerCode.trim()
        : (SharedPrefsService.getDevicePlayerCode() ?? 'SAH-0000');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentColor.withValues(alpha: 0.15),
            AppTheme.accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              ProfileAvatar(avatarIndex: profile.avatarIndex, size: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${profile.totalScore}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.stars_rounded,
                          color: AppTheme.accentColor,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${profile.highScore}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: AppTheme.accentLight,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(
                  Icons.badge_outlined,
                  color: AppTheme.accentColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'كود اللاعب:',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    playerCode,
                    key: const Key('settings_player_code_text'),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppTheme.accentLight,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                  ),
                ),
                InkWell(
                  key: const Key('settings_copy_player_code_btn'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    SoundService().playClick();
                    await Clipboard.setData(ClipboardData(text: playerCode));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم نسخ كود اللاعب: $playerCode ✅'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.accentColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: AppTheme.accentColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'نسخ',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    SoundService().playClick();
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.profileSelector,
                    );
                    onProfileUpdated();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'تبديل السجل',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    SoundService().playClick();
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.profileSetup,
                      arguments: {'existingProfile': profile},
                    );
                    onProfileUpdated();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            color: AppTheme.primaryDark,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'تعديل',
                            style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
