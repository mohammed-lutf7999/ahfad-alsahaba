import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/sound_service.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../data/models/player_level_model.dart';
import '../../data/services/progression_service.dart';
import 'celebration/andalusian_particle_painter.dart';
import 'celebration/level_up_card_content.dart';

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
  late final List<GoldParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.transition.newLevel.level * 97);
    _particles = List.generate(36, (index) => GoldParticle.random(rng));

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
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _particleController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: AndalusianParticlePainter(
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
              LevelUpCardContent(
                transition: widget.transition,
                onContinue: () => Navigator.of(context).pop(),
                onShare: _handleShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
