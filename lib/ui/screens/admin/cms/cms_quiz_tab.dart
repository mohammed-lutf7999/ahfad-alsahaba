import 'package:flutter/material.dart';

import '../../../../data/models/cms_models.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_entity_tile.dart';

class CmsQuizTab extends StatelessWidget {
  final List<DynamicQuizCategoryData> categories;
  final List<DynamicQuizQuestionData> questions;
  final String categoryFilter;
  final ValueChanged<String> onCategoryFilterChanged;
  final VoidCallback onAddCategory;
  final VoidCallback onAddQuestion;
  final ValueChanged<DynamicQuizCategoryData> onEditCategory;
  final ValueChanged<DynamicQuizQuestionData> onEditQuestion;
  final void Function(String entityType, String id, bool nextVisible)
      onToggleVisibility;

  const CmsQuizTab({
    super.key,
    required this.categories,
    required this.questions,
    required this.categoryFilter,
    required this.onCategoryFilterChanged,
    required this.onAddCategory,
    required this.onAddQuestion,
    required this.onEditCategory,
    required this.onEditQuestion,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final filteredQ = categoryFilter == 'all'
        ? questions
        : questions.where((q) => q.categoryId == categoryFilter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: AdminPrimaryButton(
                label: 'قسم مسابقة جديد',
                icon: Icons.category_rounded,
                onPressed: onAddCategory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdminPrimaryButton(
                label: 'إضافة سؤال سحابي',
                icon: Icons.quiz_rounded,
                onPressed: categories.isEmpty ? null : onAddQuestion,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdminSectionCard(
          title: 'أقسام المسابقات (${categories.length})',
          icon: Icons.emoji_events_rounded,
          child: Column(
            children: [
              for (final cat in categories) ...[
                CmsEntityTile(
                  title: cat.name,
                  subtitle:
                      'ID: ${cat.id} • ${cat.totalLevels} مرحلة${cat.isLocked ? " • مقفل" : ""}',
                  badgeText: cat.isVisible ? 'مرئي' : 'مخفي',
                  isVisible: cat.isVisible,
                  onToggleVisibility: (v) =>
                      onToggleVisibility('quiz_category', cat.id, v),
                  onEdit: () => onEditCategory(cat),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdminSectionCard(
          title: 'الأسئلة السحابية (${questions.length})',
          icon: Icons.help_outline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (categories.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text(
                          'كل الأقسام',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                        ),
                        selected: categoryFilter == 'all',
                        onSelected: (_) => onCategoryFilterChanged('all'),
                      ),
                      const SizedBox(width: 6),
                      for (final cat in categories) ...[
                        ChoiceChip(
                          label: Text(
                            cat.name,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                            ),
                          ),
                          selected: categoryFilter == cat.id,
                          onSelected: (_) => onCategoryFilterChanged(cat.id),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (filteredQ.isEmpty)
                const Text(
                  'لا توجد أسئلة سحابية مطابقة.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                )
              else
                Column(
                  children: [
                    for (final q in filteredQ) ...[
                      CmsEntityTile(
                        title: q.questionText,
                        subtitle:
                            '${q.categoryId} • المستوى ${q.levelNumber} • ${q.syncScope}',
                        badgeText: q.isVisible ? 'مرئي' : 'مخفي',
                        isVisible: q.isVisible,
                        onToggleVisibility: (v) =>
                            onToggleVisibility('quiz_question', q.id, v),
                        onEdit: () => onEditQuestion(q),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
