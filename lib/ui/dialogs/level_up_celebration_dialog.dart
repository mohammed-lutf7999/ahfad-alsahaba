import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/sound_service.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../data/models/player_level_model.dart';
import '../../data/services/progression_service.dart';
import '../widgets/animated_avatar_frame.dart';
import '../widgets/level_badge_widget.dart';

/// Epic Level-Up Celebration Dialog featuring an Andalusian Golden Particle System,
/// Dual Heavy Haptic Feedback, Human Vocal Fanfare (`SoundService().playRankUp()`),
/// and Royal Frame & Coin Grant presentation.
class LevelUpCelebrationDialog extends StatefulWidget {
  final LevelUpTransition transition;
  final VoidCallback? onShare;
  final bool triggerSensoryOnOpen;

  const LevelUpCelebrationDialog({
    super.key,
    required this.transition,
    this.onShare,
    this.triggerSensoryOnOpen = true,
  });

  /// Convenience factory when only a [PlayerLevelInfo] is provided.
  factory LevelUpCelebrationDialog.fromLevelInfo({
    Key? key,
    required PlayerLevelInfo newLevel,
    int? oldLevelNumber,
    VoidCallback? onShare,
    bool triggerSensoryOnOpen = true,
  }) {
    final prevLvl = (oldLevelNumber ?? (newLevel.level - 1)).clamp(1, 100);
    final oldInfo = PlayerLevelInfo.forMilestoneLevel(prevLvl);
    final coins = PlayerLevelInfo.totalCoinsGrantedBetweenLevels(
      prevLvl,
      newLevel.level,
    );
    return LevelUpCelebrationDialog(
      key: key,
      transition: LevelUpTransition(
        oldLevel: oldInfo,
        newLevel: newLevel,
        coinsAwarded: coins > 0
            ? coins
            : PlayerLevelInfo.coinRewardForLevel(newLevel.level),
        isNewTitleUnlocked: oldInfo.title != newLevel.title,
      ),
      onShare: onShare,
      triggerSensoryOnOpen: triggerSensoryOnOpen,
    );
  }

  /// Triggers the dual heavy haptic pulse, plays `rank_up.mp3` (respecting mute settings),
  /// and displays the [LevelUpCelebrationDialog].
  static Future<void> show(
    BuildContext context, {
    required LevelUpTransition transition,
    VoidCallback? onShare,
  }) async {
    await triggerSensoryEffect();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (_) => LevelUpCelebrationDialog(
        transition: transition,
        onShare: onShare,
        triggerSensoryOnOpen: false,
      ),
    );
  }

  /// Executes the synchronized sensory celebration (Double Heavy Haptic + RankUp Audio).
  static Future<void> triggerSensoryEffect() async {
    try {
      if (SharedPrefsService.getVibrationEnabled()) {
        unawaited(HapticFeedback.heavyImpact());
        Future<void>.delayed(const Duration(milliseconds: 150), () {
          try {
            HapticFeedback.heavyImpact();
          } catch (_) {}
        });
      }
    } catch (_) {}

    try {
      await SoundService().playRankUp();
    } catch (_) {}
  }

  @override
  State<LevelUpCelebrationDialog> createState() =>
      _LevelUpCelebrationDialogState();
}

class _LevelUpCelebrationDialogState extends State<LevelUpCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particleController;
  late final List<_GoldParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.transition.newLevel.level * 97);
    _particles = List.generate(36, (index) => _GoldParticle.random(rng));

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    if (widget.triggerSensoryOnOpen) {
      unawaited(LevelUpCelebrationDialog.triggerSensoryEffect());
    }
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    if (widget.onShare != null) {
      widget.onShare!();
      return;
    }
    final lvl = widget.transition.newLevel;
    final shareText =
        '⚔️ بحمد الله ارتقيت إلى المستوى ${lvl.level} ونلت لقب «${lvl.title}» في معركة أحفاد الصحابة! هل تستطيع منافستي في ميادين المعرفة؟ 👑';
    try {
      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final newLevel = widget.transition.newLevel;
    final oldLevel = widget.transition.oldLevel;
    final primary = newLevel.badgeColor;
    final secondary = newLevel.secondaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: RepaintBoundary(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Andalusian Golden Particle System Layer
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _particleController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _AndalusianParticlePainter(
                          particles: _particles,
                          progress: _particleController.value,
                          primaryColor: secondary,
                          secondaryColor: primary,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. Royal Glassmorphic Celebration Card
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF140B29).withValues(alpha: 0.96),
                      Color.lerp(const Color(0xFF0A192F), primary, 0.28)!
                          .withValues(alpha: 0.96),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: secondary.withValues(alpha: 0.85),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: secondary.withValues(alpha: 0.35),
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
                          color: secondary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: secondary.withValues(alpha: 0.65),
                          ),
                        ),
                        child: const Text(
                          '✨ ارتقاء أسطوري في مدارج المجد ✨',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFFF3C644),
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Animated Avatar Frame Preview with Level Number inside
                      AnimatedAvatarFrame(
                        frameKey: newLevel.frameKey,
                        level: newLevel.level,
                        size: 96,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                secondary.withValues(alpha: 0.9),
                                primary,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  newLevel.tierIcon,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                Text(
                                  '${newLevel.level}',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    height: 1.05,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Level Transition Title
                      Text(
                        'بلغت المستوى ${newLevel.level}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'من المستوى ${oldLevel.level} ⬅ إلى المستوى ${newLevel.level}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Historical Title Badge
                      LevelBadgeWidget(
                        levelInfo: newLevel,
                        isCompact: false,
                      ),

                      if (widget.transition.isNewTitleUnlocked) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            '🎉 فُتح لقب وإطار ملكي جديد: «${newLevel.frameName}»',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Color(0xFF6EE7B7),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Coin Grant Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF3C644).withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              color: Color(0xFFF3C644),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'منحة الترقية: +${widget.transition.coinsAwarded} دينار فتح 🪙',
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
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons (Strictly following AGENT.md Rule 6: vertical padding 8)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3C644),
                            foregroundColor: const Color(0xFF140B29),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.bolt_rounded, size: 20),
                          label: const Text(
                            'متابعة المسيرة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _handleShare,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: secondary.withValues(alpha: 0.75),
                              width: 1.3,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text(
                            'مشاركة الفخر 📲',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
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

class _GoldParticle {
  final double angle;
  final double speed;
  final double radius;
  final double phaseOffset;
  final bool isStar;

  const _GoldParticle({
    required this.angle,
    required this.speed,
    required this.radius,
    required this.phaseOffset,
    required this.isStar,
  });

  factory _GoldParticle.random(math.Random rng) {
    return _GoldParticle(
      angle: rng.nextDouble() * math.pi * 2,
      speed: 0.4 + rng.nextDouble() * 0.8,
      radius: 2.0 + rng.nextDouble() * 3.8,
      phaseOffset: rng.nextDouble(),
      isStar: rng.nextBool(),
    );
  }
}

class _AndalusianParticlePainter extends CustomPainter {
  final List<_GoldParticle> particles;
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _AndalusianParticlePainter({
    required this.particles,
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final maxDist = size.shortestSide * 0.68;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final localT = (progress * p.speed + p.phaseOffset) % 1.0;
      final dist = 24.0 + localT * maxDist;
      final alpha = (1.0 - localT).clamp(0.0, 1.0);

      final pos = Offset(
        center.dx + dist * math.cos(p.angle),
        center.dy + dist * math.sin(p.angle) - (localT * 18.0),
      );

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = (i.isEven ? const Color(0xFFF3C644) : primaryColor)
            .withValues(alpha: alpha * 0.85);

      if (p.isStar) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(localT * math.pi);
        final r = p.radius;
        final starPath = Path()
          ..moveTo(0, -r * 1.4)
          ..lineTo(r * 0.45, -r * 0.45)
          ..lineTo(r * 1.4, 0)
          ..lineTo(r * 0.45, r * 0.45)
          ..lineTo(0, r * 1.4)
          ..lineTo(-r * 0.45, r * 0.45)
          ..lineTo(-r * 1.4, 0)
          ..lineTo(-r * 0.45, -r * 0.45)
          ..close();
        canvas.drawPath(starPath, paint);
        canvas.restore();
      } else {
        canvas.drawCircle(pos, p.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AndalusianParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

