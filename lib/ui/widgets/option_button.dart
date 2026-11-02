import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class OptionButton extends StatefulWidget {
  final String text;
  final int index;
  final bool isSelected;
  final bool isCorrect;
  final bool isAnswered;
  final VoidCallback onTap;

  const OptionButton({super.key, required this.text, required this.index, required this.isSelected, required this.isCorrect, required this.isAnswered, required this.onTap});

  @override
  State<OptionButton> createState() => _OptionButtonState();
}

class _OptionButtonState extends State<OptionButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 100), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    if (!widget.isAnswered) return widget.isSelected ? AppTheme.accentColor.withAlpha(25) : AppTheme.cardColor;
    if (widget.isCorrect) return AppTheme.successColor.withAlpha(25);
    if (widget.isSelected && !widget.isCorrect) return AppTheme.errorColor.withAlpha(25);
    return AppTheme.cardColor;
  }

  Color _getBorderColor() {
    if (!widget.isAnswered) return widget.isSelected ? AppTheme.accentColor : AppTheme.accentColor.withAlpha(40);
    if (widget.isCorrect) return AppTheme.successColor;
    if (widget.isSelected && !widget.isCorrect) return AppTheme.errorColor;
    return AppTheme.accentColor.withAlpha(40);
  }

  IconData? _getIcon() {
    if (!widget.isAnswered) return null;
    if (widget.isCorrect) return Icons.check_rounded;
    if (widget.isSelected && !widget.isCorrect) return Icons.close_rounded;
    return null;
  }

  String _getOptionLetter() {
    switch (widget.index) {
      case 0: return 'أ';
      case 1: return 'ب';
      case 2: return 'ج';
      case 3: return 'د';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isAnswered ? null : (_) => _animationController.forward(),
      onTapUp: widget.isAnswered ? null : (_) { _animationController.reverse(); widget.onTap(); },
      onTapCancel: widget.isAnswered ? null : () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _getBorderColor(), width: 1.5),
            boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(15), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: widget.isAnswered
                      ? (widget.isCorrect ? const LinearGradient(colors: [AppTheme.successColor, Color(0xFF66BB6A)]) 
                          : (widget.isSelected ? const LinearGradient(colors: [AppTheme.errorColor, Color(0xFFEF5350)]) : null))
                      : (widget.isSelected ? AppTheme.goldGradient : null),
                  color: widget.isAnswered ? null : (widget.isSelected ? null : AppTheme.accentColor.withAlpha(20)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _getIcon() != null
                      ? Icon(_getIcon(), color: Colors.white, size: 20)
                      : Text(_getOptionLetter(), style: TextStyle(
                          color: widget.isSelected ? AppTheme.primaryDark : AppTheme.accentDark,
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.text, textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, // Reduced font weight slightly
                    color: widget.isAnswered
                        ? (widget.isCorrect ? AppTheme.successColor : (widget.isSelected ? AppTheme.errorColor : AppTheme.textPrimary))
                        : AppTheme.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
