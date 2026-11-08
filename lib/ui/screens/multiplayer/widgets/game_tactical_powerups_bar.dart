import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/models/question_model.dart';
import '../../../../data/services/progression_service.dart';

/// شريط القدرات التكتيكية الذكية في شاشة المنافسة
/// (بصيرة القائد، درع الحماية، راية الخبرة)
class GameTacticalPowerUpsBar extends StatelessWidget {
  final Question question;
  final bool isAnswered;
  final Set<int> hiddenOptionIndices;
  final math.Random random;
  final void Function(Set<int> newHidden) onInsightUsed;

  const GameTacticalPowerUpsBar({
    super.key,
    required this.question,
    required this.isAnswered,
    required this.hiddenOptionIndices,
    required this.random,
    required this.onInsightUsed,
  });

  @override
  Widget build(BuildContext context) {
    final hasInsight = ProgressionService.instance.hasItem('powerup_insight');
    final hasShield = ProgressionService.instance.hasItem('powerup_shield');
    final hasXpBanner = ProgressionService.instance.hasItem('powerup_xp_banner');
    final isInsightDisabled =
        isAnswered || !hasInsight || hiddenOptionIndices.isNotEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 1. بصيرة القائد (Powerup Insight)
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isInsightDisabled
              ? null
              : () async {
                  final consumed = await ProgressionService.instance
                      .consumeCommanderInsight();
                  if (!consumed || !context.mounted) return;
                  SoundService().playHintUse();
                  final wrongIndices = <int>[];
                  for (int i = 0; i < question.options.length; i++) {
                    if (i != question.correctAnswerIndex) {
                      wrongIndices.add(i);
                    }
                  }
                  wrongIndices.shuffle(random);
                  final toHide = wrongIndices.length >= 2
                      ? 2
                      : (wrongIndices.length == 1 ? 1 : 0);
                  final newHidden = Set<int>.from(hiddenOptionIndices);
                  for (int i = 0; i < toHide; i++) {
                    newHidden.add(wrongIndices[i]);
                  }
                  onInsightUsed(newHidden);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isInsightDisabled
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFFFD700).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isInsightDisabled
                    ? Colors.white24
                    : const Color(0xFFFFD700),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  size: 16,
                  color: isInsightDisabled
                      ? Colors.white38
                      : const Color(0xFFFFD700),
                ),
                const SizedBox(width: 6),
                Text(
                  hasInsight ? 'بصيرة القائد (متاحة)' : 'بصيرة القائد (نفدت)',
                  style: TextStyle(
                    color: isInsightDisabled
                        ? Colors.white38
                        : const Color(0xFFFFD700),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. درع الحماية (Powerup Shield indicator)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hasShield
                ? Colors.cyan.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasShield ? Colors.cyanAccent : Colors.white12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_rounded,
                size: 15,
                color: hasShield ? Colors.cyanAccent : Colors.white38,
              ),
              const SizedBox(width: 5),
              Text(
                hasShield ? 'درع مفعل 🛡️' : 'الدرع غير مفعل',
                style: TextStyle(
                  color: hasShield ? Colors.cyanAccent : Colors.white38,
                  fontSize: 11,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),

        // 3. راية مضاعفة الخبرة (Powerup XP Banner indicator)
        if (hasXpBanner)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.purpleAccent.withValues(alpha: 0.6),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 15,
                  color: Colors.purpleAccent,
                ),
                SizedBox(width: 5),
                Text(
                  'راية 2x نشطة 🚩',
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
