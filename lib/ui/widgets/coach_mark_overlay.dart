import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../core/app_theme.dart';

class CoachMarkOverlay extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onFinished;
  final VoidCallback onSkipped;

  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.onFinished,
    required this.onSkipped,
  });

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentIndex < widget.steps.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      widget.onFinished();
    }
  }

  CoachMarkStep get _currentStep => widget.steps[_currentIndex];

  Rect? _getRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  @override
  Widget build(BuildContext context) {
    // Determine target rect
    // If key is not found (e.g. widget not rendered yet or off screen), we might skip or show default center
    Rect? targetRect = _getRect(_currentStep.key);
    
    // Safety fallback
    targetRect ??= Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: 100, height: 100
    );

    // Add padding to rect for better visual
    final paddedRect = targetRect.inflate(16);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Hole Overlay (Animated)
          TweenAnimationBuilder<Rect?>(
            tween: RectTween(begin: paddedRect, end: paddedRect),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            builder: (context, rect, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _OverlayPainter(
                  holeRect: rect ?? paddedRect,
                  holeShape: _currentStep.shape, // We assume shape doesn't animate interpolation, hard swap is fine or we keep it same
                  opacity: 0.75,
                ),
              );
            },
          ),

          // 2. Pulse / Border Effect around the hole
          TweenAnimationBuilder<Rect?>(
             tween: RectTween(begin: paddedRect, end: paddedRect),
             duration: const Duration(milliseconds: 400),
             curve: Curves.easeInOut,
             builder: (context, rect, child) {
               if (rect == null) return const SizedBox.shrink();
               return Positioned.fromRect(
                 rect: rect.inflate(4), // Slightly larger for border
                 child: AnimatedBuilder(
                   animation: _pulseAnimation,
                   builder: (context, _) {
                     return Transform.scale(
                       scale: _pulseAnimation.value,
                       child: Container(
                         decoration: BoxDecoration(
                           shape: _currentStep.shape == BoxShape.circle 
                               ? BoxShape.circle : BoxShape.rectangle,
                           borderRadius: _currentStep.shape == BoxShape.rectangle 
                               ? BorderRadius.circular(20) : null,
                           border: Border.all(
                             color: AppTheme.accentColor.withOpacity(0.5),
                             width: 2,
                           ),
                         ),
                       ),
                     );
                   },
                 ),
               );
             },
          ),

          // 3. Tooltip / Text
          TweenAnimationBuilder<Rect?>(
            tween: RectTween(begin: paddedRect, end: paddedRect),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            builder: (context, rect, child) {
              if (rect == null) return const SizedBox.shrink();

              // Calculate best position for text (Top or Bottom)
              final screenSize = MediaQuery.of(context).size;
              final bool showBelow = rect.bottom < screenSize.height * 0.6;
              
              return Positioned(
                top: showBelow ? rect.bottom + 24 : null,
                bottom: !showBelow ? (screenSize.height - rect.top) + 24 : null,
                left: 24,
                right: 24,
                child: _buildTooltip(context, showBelow),
              );
            },
          ),
          
          // 4. Controls (Bottom)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: widget.onSkipped,
                  child: const Text('تخطي', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    _currentIndex == widget.steps.length - 1 ? 'ابدأ' : 'التالي',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(BuildContext context, bool arrowOnTop) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (arrowOnTop) ...[
          const Icon(Icons.keyboard_arrow_up_rounded, color: AppTheme.accentColor, size: 30),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFFAF9F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              Text(
                _currentStep.title,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppTheme.primaryDark,
                  fontFamily: 'Cairo', // User requested font
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentStep.description,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black87,
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (!arrowOnTop) ...[
          const SizedBox(height: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentColor, size: 30),
        ],
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect holeRect;
  final BoxShape holeShape;
  final double opacity;

  _OverlayPainter({
    required this.holeRect,
    required this.holeShape,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF001e1d).withOpacity(opacity);

    // Create a path that covers the whole screen
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create a path for the hole
    Path holePath;
    if (holeShape == BoxShape.circle) {
      holePath = Path()..addOval(holeRect);
    } else {
      holePath = Path()..addRRect(RRect.fromRectAndRadius(holeRect, const Radius.circular(16)));
    }

    // Combine difference
    final path = Path.combine(
      ui.PathOperation.difference,
      backgroundPath,
      holePath,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return holeRect != oldDelegate.holeRect || opacity != oldDelegate.opacity;
  }
}

class CoachMarkStep {
  final GlobalKey key;
  final String title;
  final String description;
  final BoxShape shape;

  CoachMarkStep({
    required this.key,
    required this.title,
    required this.description,
    this.shape = BoxShape.rectangle,
  });
}
