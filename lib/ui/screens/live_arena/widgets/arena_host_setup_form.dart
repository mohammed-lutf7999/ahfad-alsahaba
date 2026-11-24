import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/services/cms_cache_service.dart';

const List<({String id, String name, int totalLevels})> _builtInArenaCategories =
    [
  (id: AppConstants.quranCategory, name: 'القرآن الكريم', totalLevels: 10),
  (id: AppConstants.hadithCategory, name: 'الحديث الشريف', totalLevels: 10),
  (id: AppConstants.seerahCategory, name: 'السيرة النبوية', totalLevels: 10),
  (id: AppConstants.fiqhCategory, name: 'الفقه', totalLevels: 10),
  (id: AppConstants.historyCategory, name: 'التاريخ الإسلامي', totalLevels: 10),
  (id: AppConstants.aqeedahCategory, name: 'العقيدة', totalLevels: 10),
];

List<({String id, String name, int totalLevels})> getAvailableArenaCategories() {
  final map = <String, ({String id, String name, int totalLevels})>{
    for (final c in _builtInArenaCategories) c.id: c,
  };
  final cmsCats = CmsCacheService.instance.snapshot.quizCategories.values
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  for (final cat in cmsCats) {
    if (!cat.isVisible) {
      map.remove(cat.id);
      continue;
    }
    map[cat.id] = (
      id: cat.id,
      name: cat.name.trim().isEmpty ? cat.id : cat.name.trim(),
      totalLevels: cat.totalLevels.clamp(1, 50),
    );
  }
  return map.values.toList();
}

class ArenaHostSetupForm extends StatelessWidget {
  final TextEditingController titleController;
  final String categoryId;
  final int selectedLevel;
  final int questionCount;
  final bool isBusy;
  final String? error;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<int> onLevelChanged;
  final ValueChanged<int> onQuestionCountChanged;
  final VoidCallback onCreateSession;

  const ArenaHostSetupForm({
    super.key,
    required this.titleController,
    required this.categoryId,
    required this.selectedLevel,
    required this.questionCount,
    required this.isBusy,
    required this.error,
    required this.onCategoryChanged,
    required this.onLevelChanged,
    required this.onQuestionCountChanged,
    required this.onCreateSession,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final categories = getAvailableArenaCategories();
    final safeCategoryId = categories.any((c) => c.id == categoryId)
        ? categoryId
        : (categories.isNotEmpty
            ? categories.first.id
            : AppConstants.quranCategory);
    final selectedCat = categories.firstWhere(
      (c) => c.id == safeCategoryId,
      orElse: () => (id: safeCategoryId, name: safeCategoryId, totalLevels: 10),
    );
    final maxLevels = selectedCat.totalLevels.clamp(1, 50);
    final safeLevel = selectedLevel > maxLevels ? 0 : selectedLevel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'أنشئ بطولة حية لفصلك أو مسجدك (حتى 100 مشارك برمز PIN فوري)',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('host_arena_title_input'),
            controller: titleController,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'عنوان البطولة',
              labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('host_category_dropdown'),
            value: safeCategoryId,
            isExpanded: true,
            dropdownColor: AppTheme.primaryDark,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'مجال الأسئلة (يشمل أقسام السحابة)',
              labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
            ),
            items: [
              for (final cat in categories)
                DropdownMenuItem(
                  value: cat.id,
                  child: Text(cat.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) onCategoryChanged(v);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  key: const Key('host_level_dropdown'),
                  value: safeLevel,
                  isExpanded: true,
                  dropdownColor: AppTheme.primaryDark,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المستوى',
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text(
                        'مختلط (كل المستويات)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (var lv = 1; lv <= maxLevels; lv++)
                      DropdownMenuItem(
                        value: lv,
                        child: Text(
                          'المستوى $lv',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) onLevelChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  key: const Key('host_count_dropdown'),
                  value: questionCount,
                  isExpanded: true,
                  dropdownColor: AppTheme.primaryDark,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'عدد الأسئلة',
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 5,
                      child: Text('5 أسئلة', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 8,
                      child: Text('8 أسئلة', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 10,
                      child: Text('10 أسئلة', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onQuestionCountChanged(v);
                  },
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.amberAccent,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('host_create_arena_btn'),
              onPressed: isBusy ? null : onCreateSession,
              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: const Text(
                'إطلاق غرفة البطولة وإصدار PIN',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  height: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.primaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
