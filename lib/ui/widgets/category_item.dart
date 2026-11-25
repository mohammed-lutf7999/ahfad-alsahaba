import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/models/category_model.dart';

class CategoryItem extends StatefulWidget {
  final Category category;
  final VoidCallback onTap;

  const CategoryItem({super.key, required this.category, required this.onTap});

  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isComingSoon = widget.category.isComingSoon;
    final bool isLocked = !isComingSoon && widget.category.isLocked;
    final bool isRestricted = isComingSoon || isLocked;
    final int unlocked =
        widget.category.unlockedLevels.clamp(0, widget.category.totalLevels);
    final int locked =
        (widget.category.totalLevels - unlocked).clamp(0, widget.category.totalLevels);

    return GestureDetector(
      onTapDown: isLocked ? null : (_) => _animationController.forward(),
      onTapUp: (_) {
        if (!isLocked) {
          _animationController.reverse();
        }
        widget.onTap();
      },
      onTapCancel: isLocked ? null : () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Opacity(
          opacity: isLocked ? 0.68 : (isComingSoon ? 0.92 : 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isComingSoon
                    ? const [Color(0xFF283549), Color(0xFF162032)]
                    : (isLocked
                        ? [
                            AppTheme.primaryLight.withValues(alpha: 0.72),
                            AppTheme.primaryDark,
                          ]
                        : [AppTheme.primaryLight, AppTheme.primaryColor]),
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isComingSoon
                    ? AppTheme.accentColor.withValues(alpha: 0.72)
                    : (isLocked
                        ? Colors.white.withValues(alpha: 0.28)
                        : AppTheme.accentColor.withAlpha(100)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isLocked ? Colors.black : AppTheme.accentColor)
                      .withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isLocked ? Colors.white : AppTheme.accentColor)
                          .withAlpha(20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: isRestricted ? null : AppTheme.goldGradient,
                          color: isComingSoon
                              ? AppTheme.accentColor.withValues(alpha: 0.2)
                              : (isLocked
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : null),
                          shape: BoxShape.circle,
                          boxShadow: isRestricted
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppTheme.accentColor.withAlpha(80),
                                    blurRadius: 8,
                                  ),
                                ],
                        ),
                        child: Icon(
                          isComingSoon
                              ? Icons.hourglass_top_rounded
                              : (isLocked
                                  ? Icons.lock_rounded
                                  : widget.category.icon),
                          color: isComingSoon
                              ? AppTheme.accentLight
                              : (isLocked
                                  ? Colors.white70
                                  : AppTheme.primaryDark),
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.category.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (isComingSoon)
                        _buildStatusChip(
                          Icons.hourglass_top_rounded,
                          'قريباً ⏳',
                          AppTheme.accentLight,
                        )
                      else if (isLocked)
                        _buildStatusChip(
                          Icons.lock_rounded,
                          'مقفل مؤقتاً',
                          Colors.amberAccent,
                        )
                      else ...[
                        // Progress Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatusChip(
                              Icons.lock_open_rounded,
                              '$unlocked',
                              AppTheme.successColor,
                            ),
                            _buildStatusChip(
                              Icons.lock_rounded,
                              '$locked',
                              Colors.white.withAlpha(150),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: widget.category.progressPercentage,
                            backgroundColor: Colors.white.withAlpha(30),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.accentColor,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withAlpha(40), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
