import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/models/challenge_config.dart';

class ChallengeCategoryOption {
  final String id;
  final String name;
  final IconData icon;

  const ChallengeCategoryOption(this.id, this.name, this.icon);
}

class ChallengeTypeSelector extends StatelessWidget {
  final ChallengeType selectedType;
  final ValueChanged<ChallengeType> onSelect;

  const ChallengeTypeSelector({
    super.key,
    required this.selectedType,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeOptionCard(
            isSelected: selectedType == ChallengeType.bruteForce,
            icon: '🎲',
            title: 'القوة الغاشمة',
            subtitle: 'عشوائي من الكل',
            onTap: () {
              SoundService().playClick();
              onSelect(ChallengeType.bruteForce);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeOptionCard(
            isSelected: selectedType == ChallengeType.category,
            icon: '📚',
            title: 'قسم محدد',
            subtitle: 'اختر القسم',
            onTap: () {
              SoundService().playClick();
              onSelect(ChallengeType.category);
            },
          ),
        ),
      ],
    );
  }
}

class _TypeOptionCard extends StatelessWidget {
  final bool isSelected;
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeOptionCard({
    required this.isSelected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.accentColor.withValues(alpha: 0.3),
                    AppTheme.accentColor.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentColor
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.accentColor : Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChallengeCategorySelector extends StatelessWidget {
  final List<ChallengeCategoryOption> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelect;

  const ChallengeCategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = selectedCategoryId == cat.id;
        return GestureDetector(
          onTap: () {
            SoundService().playClick();
            onSelect(cat.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppTheme.accentLight, AppTheme.accentColor],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentColor
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cat.icon,
                  size: 20,
                  color:
                      isSelected ? AppTheme.primaryDark : AppTheme.accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? AppTheme.primaryDark : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChallengeQuestionCountSelector extends StatelessWidget {
  final int selectedCount;
  final ValueChanged<int> onSelect;

  const ChallengeQuestionCountSelector({
    super.key,
    required this.selectedCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [5, 10, 15, 20].map((count) {
        final isSelected = selectedCount == count;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              SoundService().playClick();
              onSelect(count);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppTheme.accentLight, AppTheme.accentColor],
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentColor
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryDark : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ChallengeSettingsPanel extends StatelessWidget {
  final bool speedMode;
  final int maxPlayers;
  final ValueChanged<bool> onSpeedModeChanged;
  final VoidCallback onDecrementPlayers;
  final VoidCallback onIncrementPlayers;

  const ChallengeSettingsPanel({
    super.key,
    required this.speedMode,
    required this.maxPlayers,
    required this.onSpeedModeChanged,
    required this.onDecrementPlayers,
    required this.onIncrementPlayers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: AppTheme.accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نقاط السرعة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'من يجيب أسرع يحصل على نقاط أكثر',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: speedMode,
                activeColor: AppTheme.accentColor,
                onChanged: onSpeedModeChanged,
              ),
            ],
          ),
          const Divider(color: Colors.white12),
          Row(
            children: [
              const Icon(Icons.people_rounded, color: AppTheme.accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الحد الأقصى للاعبين',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$maxPlayers لاعبين',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _CounterButton(Icons.remove, onDecrementPlayers),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '$maxPlayers',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  _CounterButton(Icons.add, onIncrementPlayers),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.accentColor, size: 18),
      ),
    );
  }
}
