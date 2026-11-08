import 'package:flutter/material.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/player_level_model.dart';
import '../../../widgets/glory_progress_bar.dart';

/// بطاقة مستوى سُلّم طريق المجد (المستويات 1..100)
/// تتضمن لافتة المرتبة التاريخية، وزر تفعيل الإطار، وشارة الدنانير، وشريط الخبرة المباشر
class GloryLevelStepCard extends StatelessWidget {
  final int level;
  final PlayerLevelInfo currentLevelInfo;
  final String equippedFrame;
  final AppCustomTheme customTheme;
  final void Function(String frameKey, String frameName) onEquipFrame;

  const GloryLevelStepCard({
    super.key,
    required this.level,
    required this.currentLevelInfo,
    required this.equippedFrame,
    required this.customTheme,
    required this.onEquipFrame,
  });

  @override
  Widget build(BuildContext context) {
    final milestone = PlayerLevelInfo.forMilestoneLevel(level);
    final tier = PlayerLevelInfo.resolveTier(level);
    final isCompleted = level < currentLevelInfo.level;
    final isCurrent = level == currentLevelInfo.level;
    final isTierStart = level == tier.minLevel;
    final isFrameUnlocked = currentLevelInfo.level >= tier.minLevel;
    final isFrameEquipped = equippedFrame == tier.frameKey;

    final borderColor = isCurrent
        ? customTheme.sovereignAccent
        : isCompleted
            ? const Color(0xFFF3C644).withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.14);

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Major Historical Tier Header Banner (at Levels 1, 10, 20, ..., 90)
          if (isTierStart)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tier.primaryColor.withValues(alpha: 0.85),
                    tier.secondaryColor.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tier.secondaryColor.withValues(alpha: 0.9),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(tier.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مرتبة «${tier.title}» (المستويات ${tier.minLevel} - ${tier.maxLevel}) • ${tier.frameName}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (isFrameUnlocked)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: isFrameEquipped
                            ? null
                            : () => onEquipFrame(
                                  tier.frameKey,
                                  tier.frameName,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFrameEquipped
                              ? Colors.black26
                              : const Color(0xFFF3C644),
                          foregroundColor: const Color(0xFF140B29),
                          disabledBackgroundColor:
                              Colors.black.withValues(alpha: 0.35),
                          disabledForegroundColor: const Color(0xFF6EE7B7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          isFrameEquipped ? 'الإطار مُفعّل ✓' : 'تفعيل الإطار',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Individual Level Step Card (1..100)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? customTheme.surfaceCard
                  : isCompleted
                      ? customTheme.surfaceCard.withValues(alpha: 0.68)
                      : Colors.black.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: isCurrent ? 2.0 : 1.0,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: customTheme.sovereignAccent.withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Status Icon / Level Emblem
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isCompleted || isCurrent
                            ? LinearGradient(
                                colors: [tier.secondaryColor, tier.primaryColor],
                              )
                            : null,
                        color: isCompleted || isCurrent
                            ? null
                            : Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: isCompleted || isCurrent
                              ? const Color(0xFFF3C644)
                              : Colors.white24,
                          width: 1.3,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFFF3C644),
                                size: 22,
                              )
                            : isCurrent
                                ? Text(
                                    '$level',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      height: 1.1,
                                    ),
                                  )
                                : const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Colors.white54,
                                    size: 19,
                                  ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Level Title & XP Requirement
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'المستوى $level',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: isCompleted || isCurrent
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: customTheme.sovereignAccent
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'موقعك الحالي ⚔️',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: customTheme.sovereignAccent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'اللقب: ${milestone.title} • النقاط المطلوبة: ${milestone.currentLevelFloorXp} XP',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Coin Grant Badge (`L * 50`)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.16)
                            : const Color(0xFFF3C644).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : const Color(0xFFF3C644).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        isCompleted
                            ? '+${milestone.coinGrantForThisLevel} 🪙 ✓'
                            : '+${milestone.coinGrantForThisLevel} 🪙',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: isCompleted
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFF3C644),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),

                // Embedded Progress Bar on the Player's Current Level
                if (isCurrent) ...[
                  const SizedBox(height: 10),
                  GloryProgressBar(
                    levelInfo: currentLevelInfo,
                    height: 10,
                    showRemainingHint: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
