import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';

/// شريط التنقل السفلي الفاخر المخصص «خماسية الفرسان الإمبراطورية»
/// جزيرة زجاجية عائمة متوافقة كلياً مع محرك الثيمات الأربعة
class RoyalBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Key? libraryKey;
  final Key? challengeKey;

  const RoyalBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.libraryKey,
    this.challengeKey,
  });

  @override
  State<RoyalBottomNavBar> createState() => _RoyalBottomNavBarState();
}

class _RoyalBottomNavBarState extends State<RoyalBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 78,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // 1. The Floating Frosted Glass Dock
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: customTheme.deepBackground.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: customTheme.sovereignAccent.withValues(alpha: 0.38),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: customTheme.sovereignAccent.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Tab 0: الرئيسية (Home)
                        _buildNavItem(
                          index: 0,
                          label: 'الرئيسية',
                          icon: Icons.castle_rounded,
                          customTheme: customTheme,
                        ),

                        // Tab 1: المكتبة (Library / Campaigns)
                        _buildNavItem(
                          index: 1,
                          label: 'المكتبة',
                          icon: Icons.menu_book_rounded,
                          customTheme: customTheme,
                          key: widget.libraryKey,
                        ),

                        // Gap for Center Elevated Button
                        const SizedBox(width: 58),

                        // Tab 3: طريق المجد (Glory Road)
                        _buildNavItem(
                          index: 3,
                          label: 'المجد',
                          icon: Icons.military_tech_rounded,
                          customTheme: customTheme,
                        ),

                        // Tab 4: سوق الفرسان (Store)
                        _buildNavItem(
                          index: 4,
                          label: 'المتجر',
                          icon: Icons.storefront_rounded,
                          customTheme: customTheme,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. The Center Raised Chivalric Crest (Tab 2: التحدي المباشر / الميدان)
            Positioned(
              bottom: 12,
              child: GestureDetector(
                key: widget.challengeKey,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  SoundService().playClick();
                  widget.onTap(2);
                },
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              customTheme.sovereignAccent,
                              customTheme.secondaryAccent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: customTheme.sovereignAccent.withValues(alpha: 0.45),
                              blurRadius: 18,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.sports_kabaddi_rounded,
                            size: 28,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required AppCustomTheme customTheme,
    Key? key,
  }) {
    final bool isSelected = widget.currentIndex == index;

    return Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          SoundService().playClick();
          widget.onTap(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  size: isSelected ? 23 : 21,
                  color: isSelected
                      ? customTheme.sovereignAccent
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? customTheme.sovereignAccent
                      : Colors.white.withValues(alpha: 0.5),
                  fontFamily: 'Cairo',
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
