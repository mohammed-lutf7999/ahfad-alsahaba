import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/cms_models.dart';
import '../../../../data/services/admin/admin_cms_quiz_mixin.dart';
import '../../../../data/services/cms_cache_service.dart';
import '../widgets/admin_ui_kit.dart';

const List<({String id, String name})> builtInBulkQuizCategories = [
  (id: 'quran', name: 'القرآن الكريم'),
  (id: 'hadith', name: 'الحديث الشريف'),
  (id: 'fiqh', name: 'الفقه الإسلامي'),
  (id: 'seerah', name: 'السيرة النبوية'),
  (id: 'history', name: 'التاريخ الإسلامي'),
  (id: 'aqeedah', name: 'العقيدة الإسلامية'),
];

List<DynamicQuizCategoryData> buildBulkCategoriesFromCache() {
  final map = <String, DynamicQuizCategoryData>{
    for (final d in builtInBulkQuizCategories)
      d.id: DynamicQuizCategoryData(id: d.id, name: d.name),
  };
  for (final entry
      in CmsCacheService.instance.snapshot.quizCategories.entries) {
    map[entry.key] = entry.value;
  }
  return map.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

List<DynamicQuizCategoryData> applyPublishedPackVersion(
  List<DynamicQuizCategoryData> categories,
  AdminGzipPackPublishResult res,
) {
  return categories.map((c) {
    if (c.id != res.categoryId) return c;
    return DynamicQuizCategoryData(
      id: c.id,
      name: c.name,
      description: c.description,
      iconName: c.iconName,
      colorHex: c.colorHex,
      totalLevels: c.totalLevels,
      questionsPerLevel: c.questionsPerLevel,
      levelDrawMode: c.levelDrawMode,
      packVersion: res.packVersion,
      packStoragePath: res.storagePath,
      sortOrder: c.sortOrder,
      isVisible: c.isVisible,
      isLocked: c.isLocked,
      cmsRevision: c.cmsRevision,
    );
  }).toList();
}

class BulkCategoryConfigCard extends StatelessWidget {
  final bool isNewCategoryMode;
  final bool isBusy;
  final List<DynamicQuizCategoryData> categories;
  final String selectedCategoryId;
  final String drawMode;
  final TextEditingController newCatIdCtrl;
  final TextEditingController newCatNameCtrl;
  final TextEditingController newCatDescCtrl;
  final TextEditingController newCatColorCtrl;
  final TextEditingController totalLevelsCtrl;
  final TextEditingController qPerLevelCtrl;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onDrawModeChanged;

  const BulkCategoryConfigCard({
    super.key,
    required this.isNewCategoryMode,
    required this.isBusy,
    required this.categories,
    required this.selectedCategoryId,
    required this.drawMode,
    required this.newCatIdCtrl,
    required this.newCatNameCtrl,
    required this.newCatDescCtrl,
    required this.newCatColorCtrl,
    required this.totalLevelsCtrl,
    required this.qPerLevelCtrl,
    required this.onModeChanged,
    required this.onCategorySelected,
    required this.onDrawModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: '1. القسم المستهدف وإعدادات المستويات',
      icon: Icons.layers_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text(
                  'قسم موجود',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text(
                  'قسم جديد',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
            ],
            selected: {isNewCategoryMode},
            onSelectionChanged:
                isBusy ? null : (sel) => onModeChanged(sel.first),
          ),
          const SizedBox(height: 12),
          if (!isNewCategoryMode)
            DropdownButtonFormField<String>(
              key: const Key('bulk_existing_category_dropdown'),
              isExpanded: true,
              value: categories.any((c) => c.id == selectedCategoryId)
                  ? selectedCategoryId
                  : (categories.isNotEmpty ? categories.first.id : null),
              dropdownColor: AppCustomTheme.of(context).surfaceCard,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                labelText: 'اختر القسم',
                labelStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                ),
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(
                        '${c.name} (${c.id}) — v${c.packVersion}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isBusy
                  ? null
                  : (v) {
                      if (v != null) onCategorySelected(v);
                    },
            )
          else ...[
            AdminTextField(
              controller: newCatIdCtrl,
              label: 'معرّف القسم الجديد (إنجليزي صغير مثل: ghazawat)',
            ),
            const SizedBox(height: 10),
            AdminTextField(
              controller: newCatNameCtrl,
              label: 'اسم القسم العربي',
            ),
            const SizedBox(height: 10),
            AdminTextField(
              controller: newCatDescCtrl,
              label: 'وصف مختصر للقسم',
            ),
            const SizedBox(height: 10),
            AdminTextField(
              controller: newCatColorCtrl,
              label: 'لون القسم (Hex مثل #1B5E20)',
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminTextField(
                  controller: totalLevelsCtrl,
                  label: 'المستويات (1–100)',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminTextField(
                  controller: qPerLevelCtrl,
                  label: 'الأسئلة/مستوى',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('bulk_draw_mode_dropdown'),
            isExpanded: true,
            value: drawMode,
            dropdownColor: AppCustomTheme.of(context).surfaceCard,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
            ),
            decoration: const InputDecoration(
              labelText: 'نمط السحب',
              labelStyle: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white70,
              ),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'fixed',
                child: Text(
                  'ثابت (fixed)',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
              DropdownMenuItem(
                value: 'rotating_pool',
                child: Text(
                  'وعاء متجدد تلقائياً (rotating_pool)',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
            onChanged: isBusy
                ? null
                : (v) {
                    if (v != null) onDrawModeChanged(v);
                  },
          ),
        ],
      ),
    );
  }
}
