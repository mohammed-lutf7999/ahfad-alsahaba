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
    int locked = widget.category.totalLevels - widget.category.unlockedLevels;
    
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) { _animationController.reverse(); widget.onTap(); },
      onTapCancel: () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.primaryLight, AppTheme.primaryColor]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentColor.withAlpha(100), width: 1.5),
            boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(40), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentColor.withAlpha(20))),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 8)],
                      ),
                      child: Icon(widget.category.icon, color: AppTheme.primaryDark, size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.category.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Progress Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatusChip(Icons.lock_open_rounded, '${widget.category.unlockedLevels}', AppTheme.successColor),
                        _buildStatusChip(Icons.lock_rounded, '$locked', Colors.white.withAlpha(150)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.category.progressPercentage,
                        backgroundColor: Colors.white.withAlpha(30),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
