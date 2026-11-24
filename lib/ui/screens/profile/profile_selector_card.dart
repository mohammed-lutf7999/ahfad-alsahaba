import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../data/models/player_profile_model.dart';
import '../../widgets/avatar_selector.dart';

class ProfileSelectorCard extends StatelessWidget {
  final PlayerProfile profile;
  final bool isActive;
  final int index;
  final Animation<double> animController;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProfileSelectorCard({
    super.key,
    required this.profile,
    required this.isActive,
    required this.index,
    required this.animController,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animController,
      builder: (context, child) {
        final delay = index * 0.1;
        final progress =
            ((animController.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 30 * (1 - progress)),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.cardGradient : null,
            color:
                isActive ? null : AppTheme.primaryColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppTheme.accentColor
                  : AppTheme.accentColor.withValues(alpha: 0.2),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Stack(
                  children: [
                    ProfileAvatar(avatarIndex: profile.avatarIndex, size: 60),
                    if (isActive)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          color: isActive ? AppTheme.accentColor : Colors.white,
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
                              color: isActive
                                  ? AppTheme.accentLight
                                  : Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.stars_rounded,
                            color:
                                isActive ? AppTheme.accentColor : Colors.white54,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      tooltip: 'تعديل',
                    ),
                    if (!isActive)
                      IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_rounded,
                          color: Colors.redAccent.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        tooltip: 'حذف',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
