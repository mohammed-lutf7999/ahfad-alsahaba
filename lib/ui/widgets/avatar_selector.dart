import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';

// Preset avatar configurations (icon + background color)
const List<Map<String, dynamic>> avatarPresets = [
  {'icon': Icons.mosque_rounded, 'color': Color(0xFF1B5E20), 'label': 'المسجد'},
  {'icon': Icons.menu_book_rounded, 'color': Color(0xFF0D47A1), 'label': 'القرآن'},
  {'icon': Icons.auto_awesome, 'color': Color(0xFF4A148C), 'label': 'النجم'},
  {'icon': Icons.emoji_events_rounded, 'color': Color(0xFFBF360C), 'label': 'الكأس'},
  {'icon': Icons.school_rounded, 'color': Color(0xFF006064), 'label': 'العالم'},
  {'icon': Icons.diamond_rounded, 'color': Color(0xFF311B92), 'label': 'الجوهرة'},
  {'icon': Icons.brightness_3_rounded, 'color': Color(0xFF1A237E), 'label': 'الهلال'},
  {'icon': Icons.favorite_rounded, 'color': Color(0xFFC62828), 'label': 'القلب'},
];

/// Get avatar widget by index
Widget getAvatarWidget(int index, {double size = 50}) {
  if (index < 0 || index >= avatarPresets.length) {
    index = 0;
  }
  final preset = avatarPresets[index];
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: preset['color'] as Color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: (preset['color'] as Color).withOpacity(0.4),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Icon(
      preset['icon'] as IconData,
      color: Colors.white,
      size: size * 0.55,
    ),
  );
}

/// Widget for selecting avatar from preset options
class AvatarSelector extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showLabel;

  const AvatarSelector({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.showLabel = true,
  });

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          const Text(
            'اختر صورتك الرمزية',
            style: TextStyle(
              color: AppTheme.accentColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: avatarPresets.length,
          itemBuilder: (context, index) {
            final isSelected = widget.selectedIndex == index;
            final preset = avatarPresets[index];
            
            return GestureDetector(
              onTap: () {
                SoundService().playClick();
                widget.onSelected(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: preset['color'] as Color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.accentColor : Colors.transparent,
                    width: isSelected ? 3 : 0,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppTheme.accentColor.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        preset['icon'] as IconData,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Large avatar display widget
class ProfileAvatar extends StatelessWidget {
  final int avatarIndex;
  final double size;
  final VoidCallback? onTap;
  final bool showEditIcon;

  const ProfileAvatar({
    super.key,
    required this.avatarIndex,
    this.size = 80,
    this.onTap,
    this.showEditIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          getAvatarWidget(avatarIndex, size: size),
          if (showEditIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryDark, width: 2),
                ),
                child: Icon(
                  Icons.edit,
                  color: AppTheme.primaryDark,
                  size: size * 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
