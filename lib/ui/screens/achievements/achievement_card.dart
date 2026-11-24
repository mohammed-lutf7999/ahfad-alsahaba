import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/date_formatters.dart';
import '../../../data/models/achievement_model.dart';
import '../../../data/services/achievement_service.dart';

class AchievementCard extends StatelessWidget {
  final AchievementWithProgress achievementWithProgress;

  const AchievementCard({
    super.key,
    required this.achievementWithProgress,
  });

  Color get _rarityColor {
    switch (achievementWithProgress.achievement.rarity) {
      case AchievementRarity.common:
        return const Color(0xFFCD7F32);
      case AchievementRarity.rare:
        return const Color(0xFFC0C0C0);
      case AchievementRarity.epic:
        return AppTheme.accentColor;
      case AchievementRarity.legendary:
        return const Color(0xFFB9F2FF);
    }
  }

  String get _rarityName {
    switch (achievementWithProgress.achievement.rarity) {
      case AchievementRarity.common:
        return 'شائع';
      case AchievementRarity.rare:
        return 'نادر';
      case AchievementRarity.epic:
        return 'ملحمي';
      case AchievementRarity.legendary:
        return 'أسطوري';
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievement = achievementWithProgress.achievement;
    final isUnlocked = achievementWithProgress.isUnlocked;
    final progress = achievementWithProgress.progressPercent;
    final currentValue = achievementWithProgress.progress.currentValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isUnlocked
              ? [
                  _rarityColor.withValues(alpha: 0.2),
                  _rarityColor.withValues(alpha: 0.05),
                ]
              : [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? _rarityColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: _rarityColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  textDirection: TextDirection.rtl,
                  children: [
                    Flexible(
                      child: Text(
                        achievement.isSecret && !isUnlocked
                            ? '???'
                            : achievement.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _rarityColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _rarityName,
                          style: TextStyle(
                            color: _rarityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.isSecret && !isUnlocked
                      ? 'إنجاز سري'
                      : achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.white.withValues(alpha: isUnlocked ? 0.7 : 0.4),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Text(
                      '${achievement.targetValue}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerRight,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _rarityColor.withValues(alpha: 0.5),
                                  _rarityColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currentValue',
                      style: TextStyle(
                        fontSize: 11,
                        color: isUnlocked
                            ? _rarityColor
                            : Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isUnlocked &&
                    achievementWithProgress.progress.unlockedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'تم الفتح: ${DateFormatters.formatShortDate(achievementWithProgress.progress.unlockedAt!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _rarityColor.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? _rarityColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isUnlocked
                    ? _rarityColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: _rarityColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isUnlocked || !achievement.isSecret
                  ? Text(
                      achievement.icon,
                      style: TextStyle(
                        fontSize: 28,
                        color: isUnlocked ? null : Colors.grey,
                      ),
                    )
                  : Icon(
                      Icons.lock_rounded,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
