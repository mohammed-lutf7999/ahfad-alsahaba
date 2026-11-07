import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/arena_model.dart';
import '../../data/services/progression_service.dart';
import 'level_up_celebration_dialog.dart';

/// Epic Arena Promotion Dialog displayed when a player crosses a trophy threshold
/// into a higher Historic Competitive Arena (Arenas 1..6).
class ArenaPromotionDialog extends StatefulWidget {
  final ArenaPromotionTransition transition;
  final bool triggerSensoryOnOpen;

  const ArenaPromotionDialog({
    super.key,
    required this.transition,
    this.triggerSensoryOnOpen = true,
  });

  /// Convenience factory from a target [ArenaModel].
  factory ArenaPromotionDialog.fromArena({
    Key? key,
    required ArenaModel newArena,
    ArenaModel? oldArena,
    int? currentTrophies,
    bool triggerSensoryOnOpen = true,
  }) {
    final prevArena = oldArena ?? ArenaModel.allArenas.first;
    return ArenaPromotionDialog(
      key: key,
      transition: ArenaPromotionTransition(
        oldArena: prevArena,
        newArena: newArena,
        currentTrophies: currentTrophies ?? newArena.minTrophies,
      ),
      triggerSensoryOnOpen: triggerSensoryOnOpen,
    );
  }

  /// Triggers sensory celebration (Double Heavy Haptic + RankUp Audio) and opens [ArenaPromotionDialog].
  static Future<void> show(
    BuildContext context, {
    required ArenaPromotionTransition transition,
  }) async {
    await LevelUpCelebrationDialog.triggerSensoryEffect();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (_) => ArenaPromotionDialog(
        transition: transition,
        triggerSensoryOnOpen: false,
      ),
    );
  }

  @override
  State<ArenaPromotionDialog> createState() => _ArenaPromotionDialogState();
}

class _ArenaPromotionDialogState extends State<ArenaPromotionDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();

    if (widget.triggerSensoryOnOpen) {
      unawaited(LevelUpCelebrationDialog.triggerSensoryEffect());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newArena = widget.transition.newArena;
    final oldArena = widget.transition.oldArena;
    final accent = newArena.accentColor;
    final secondary = newArena.secondaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: RepaintBoundary(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Sovereign Arena Particle & Rays Painter
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ArenaPromotionRaysPainter(
                          progress: _controller.value,
                          accentColor: accent,
                          secondaryColor: secondary,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. Main Promotion Card
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF120924).withValues(alpha: 0.96),
                      Color.lerp(const Color(0xFF0A192F), secondary, 0.38)!
                          .withValues(alpha: 0.96),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.88),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.65),
                          ),
                        ),
                        child: Text(
                          '⚔️ فتح ميدان تنافسي جديد (الميدان ${newArena.id}) ⚔️',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Arena Shield Emblem
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [accent, secondary],
                          ),
                          border: Border.all(
                            color: const Color(0xFFF3C644),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.55),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          newArena.icon,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Congratulatory Message & Arena Name
                      const Text(
                        'مبارك أيها الفارس!',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Color(0xFFF3C644),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        newArena.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 23,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        newArena.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Coin Multiplier Upgrade Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.36),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  color: Color(0xFFF3C644),
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'مضاعف غنائم الدنانير: ${newArena.coinMultiplier}x 🪙',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Color(0xFFF3C644),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ارتفع من ${oldArena.coinMultiplier}x (${oldArena.name}) إلى ${newArena.coinMultiplier}x (${widget.transition.currentTrophies} 🏆)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Button (Rule 6: vertical padding 8)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.shield_rounded, size: 20),
                          label: const Text(
                            'دخول الميدان بعزة ⚔️',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaPromotionRaysPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final Color secondaryColor;

  _ArenaPromotionRaysPainter({
    required this.progress,
    required this.accentColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);
    final radius = size.shortestSide * 0.65;
    const count = 16;

    for (int i = 0; i < count; i++) {
      final angle = (progress * math.pi * 2) + (i * math.pi * 2 / count);
      final localT = ((progress + i / count) % 1.0);
      final dist = 28.0 + localT * radius;
      final pt = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );
      final paint = Paint()
        ..color = (i.isEven ? accentColor : const Color(0xFFF3C644))
            .withValues(alpha: (1.0 - localT) * 0.8);
      canvas.drawCircle(pt, 2.8 + (1.0 - localT) * 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaPromotionRaysPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

