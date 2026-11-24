import 'dart:math' as math;
import 'package:flutter/material.dart';

class EmpireLegendaryBackground extends StatefulWidget {
  const EmpireLegendaryBackground({super.key});

  @override
  State<EmpireLegendaryBackground> createState() =>
      _EmpireLegendaryBackgroundState();
}

class _EmpireLegendaryBackgroundState extends State<EmpireLegendaryBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    0.5 * math.cos(_controller.value * 2 * math.pi),
                    0.5 * math.sin(_controller.value * 2 * math.pi),
                  ),
                  radius: 1.5,
                  colors: const [
                    Color(0xFF0D47A1),
                    Color(0xFF001020),
                    Color(0xFF000000),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            );
          },
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _EmpireParticlePainter(_controller, Colors.white),
          ),
        ),
      ],
    );
  }
}

class EmpireLightBackground extends StatefulWidget {
  const EmpireLightBackground({super.key});

  @override
  State<EmpireLightBackground> createState() => _EmpireLightBackgroundState();
}

class _EmpireLightBackgroundState extends State<EmpireLightBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5F5F5), Color(0xFFE0F7FA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _EmpireParticlePainter(_controller, Colors.teal),
          ),
        ),
      ],
    );
  }
}

class _EmpireParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _EmpireParticlePainter(this.animation, this.color)
      : super(repaint: animation);

  final List<Offset> _stars = List.generate(
    50,
    (index) => Offset(
      math.Random(index).nextDouble(),
      math.Random(index).nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.3);
    for (int i = 0; i < _stars.length; i++) {
      final offset = _stars[i];
      final dy = (offset.dy + animation.value * (0.2 + (i % 5) / 10)) % 1.0;
      final dx = offset.dx;
      final opacity = (math.sin(animation.value * 20 + i) + 1) / 2 * 0.5;
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        1.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
