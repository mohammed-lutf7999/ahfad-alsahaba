import 'package:flutter/material.dart';

import '../../../../data/models/cms_models.dart';
import '../widgets/admin_ui_kit.dart';

/// Shared compact dark RTL [InputDecoration] for CMS level & question controls.
InputDecoration cmsAdminInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      fontFamily: 'Cairo',
      color: Colors.white70,
      fontSize: 12.5,
    ),
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.24),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFF3C644), width: 1.4),
    ),
  );
}

/// Warning banner displayed when cloud question changes have not been
/// republished to the Gzip CDN Storage bucket yet.
class CmsPackRepublishBanner extends StatelessWidget {
  final VoidCallback onPublishTap;

  const CmsPackRepublishBanner({
    super.key,
    required this.onPublishTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '⚠️ الحزمة بحاجة لإعادة نشر Gzip CDN بعد التعديلات الأخيرة.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.amberAccent,
              ),
            ),
          ),
          TextButton(
            onPressed: onPublishTap,
            child: const Text(
              'نشر الآن',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive level pills grid (`1..totalLevels`) for 1-tap cycling between
/// `open` 🟢 → `coming_soon` ⏳ → `hidden` 🚫.
class CmsLevelPillsGridCard extends StatelessWidget {
  final DynamicQuizCategoryData category;
  final bool isBusy;
  final void Function(int levelNumber, String nextStatus) onCycleLevel;

  const CmsLevelPillsGridCard({
    super.key,
    required this.category,
    required this.isBusy,
    required this.onCycleLevel,
  });

  Color _pillColor(CategoryAvailabilityStatus status) {
    switch (status) {
      case CategoryAvailabilityStatus.comingSoon:
        return Colors.amber;
      case CategoryAvailabilityStatus.hidden:
        return Colors.redAccent;
      case CategoryAvailabilityStatus.open:
        return Colors.greenAccent;
    }
  }

  String _pillIcon(CategoryAvailabilityStatus status) {
    switch (status) {
      case CategoryAvailabilityStatus.comingSoon:
        return '⏳';
      case CategoryAvailabilityStatus.hidden:
        return '🚫';
      case CategoryAvailabilityStatus.open:
        return '🟢';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: 'شبكة المستويات (اضغط للتبديل السريع)',
      icon: Icons.grid_view_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var lv = 1; lv <= category.totalLevels; lv++)
            Builder(
              builder: (_) {
                final st = category.overrideForLevel(lv)?.status ??
                    CategoryAvailabilityStatus.open;
                final col = _pillColor(st);
                final next = st == CategoryAvailabilityStatus.open
                    ? 'coming_soon'
                    : st == CategoryAvailabilityStatus.comingSoon
                        ? 'hidden'
                        : 'open';
                return InkWell(
                  onTap: isBusy ? null : () => onCycleLevel(lv, next),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 66,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: col.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$lv',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: col,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _pillIcon(st),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Compact cloud question row card with multi-select checkbox & delete icon.
class CmsBrowserQuestionTile extends StatelessWidget {
  final DynamicQuizQuestionData question;
  final bool selected;
  final ValueChanged<bool> onSelectChanged;
  final VoidCallback onDelete;

  const CmsBrowserQuestionTile({
    super.key,
    required this.question,
    required this.selected,
    required this.onSelectChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (v) => onSelectChanged(v == true),
                ),
                Expanded(
                  child: Text(
                    '${question.categoryId} • م${question.levelNumber} • ${question.isVisible ? "مرئي" : "مخفي"}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: question.isVisible
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف السؤال',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            Text(
              question.questionText,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
