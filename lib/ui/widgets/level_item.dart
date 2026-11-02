import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/models/level_model.dart';

class LevelItem extends StatefulWidget {
  final Level level;
  final VoidCallback onTap;

  const LevelItem({super.key, required this.level, required this.onTap});

  @override
  State<LevelItem> createState() => _LevelItemState();
}

class _LevelItemState extends State<LevelItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 100), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Widget> _buildStars() {
    return List.generate(3, (index) {
      final isActive = index < widget.level.stars;
      return Icon(
        isActive ? Icons.star_rounded : Icons.star_border_rounded,
        color: isActive ? AppTheme.accentColor : Colors.grey.shade400,
        size: 16,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.level.isLocked;
    final isCompleted = widget.level.isCompleted;

    return GestureDetector(
      onTapDown: isLocked ? null : (_) => _animationController.forward(),
      onTapUp: isLocked
          ? null
          : (_) {
              _animationController.reverse();
              widget.onTap();
            },
      onTapCancel: isLocked ? null : () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isLocked ? AppTheme.cardColor.withAlpha(200) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? AppTheme.accentColor
                  : (isLocked ? Colors.grey.shade300 : AppTheme.accentColor.withAlpha(80)),
              width: isCompleted ? 1.5 : 1,
            ),
            boxShadow: isLocked
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.accentColor.withAlpha(30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Level Number Circle (Smaller)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isLocked
                        ? null
                        : (isCompleted
                            ? AppTheme.goldGradient
                            : LinearGradient(colors: [
                                AppTheme.primaryLight,
                                AppTheme.primaryColor
                              ])),
                    color: isLocked ? Colors.grey.shade400 : null,
                    shape: BoxShape.circle,
                    boxShadow: isLocked
                        ? null
                        : [
                            BoxShadow(
                              color: isCompleted
                                  ? AppTheme.accentColor.withAlpha(80)
                                  : AppTheme.primaryColor.withAlpha(60),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                  child: Center(
                    child: isLocked
                        ? const Icon(Icons.lock_rounded,
                            color: Colors.white, size: 20)
                        : (isCompleted
                            ? const Icon(Icons.check_rounded,
                                color: AppTheme.primaryDark, size: 24)
                            : Text(
                                '${widget.level.levelNumber}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              )),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,//محاذات العناصر في بطاقات المستويات 
                    children: [
                      Text(
                        widget.level.title,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isLocked
                              ? Colors.grey.shade500
                              : AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          if (isCompleted) ...[
                             Row(children: _buildStars()),
                             const SizedBox(width: 8),
                             Container(width: 1, height: 12, color: Colors.grey.shade300),
                             const SizedBox(width: 8),
                          ],
                          Text(
                            '${widget.level.totalQuestions} أسئلة',
                            style: TextStyle(
                              fontSize: 11,
                              color: isLocked
                                  ? Colors.grey.shade400
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_back_ios_rounded,
                    color: isLocked ? Colors.grey.shade300 : AppTheme.accentColor,
                    size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
