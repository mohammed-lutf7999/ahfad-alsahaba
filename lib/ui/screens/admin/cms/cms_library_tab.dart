import 'package:flutter/material.dart';

import '../../../../data/models/cms_models.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_entity_tile.dart';

class CmsLibraryTab extends StatelessWidget {
  final List<DynamicLibrarySectionData> sections;
  final List<DynamicLibraryItemData> items;
  final String sectionFilter;
  final ValueChanged<String> onSectionFilterChanged;
  final VoidCallback onAddSection;
  final VoidCallback onAddItem;
  final ValueChanged<DynamicLibrarySectionData> onEditSection;
  final ValueChanged<DynamicLibraryItemData> onEditItem;
  final void Function(String entityType, String id, bool nextVisible)
      onToggleVisibility;

  const CmsLibraryTab({
    super.key,
    required this.sections,
    required this.items,
    required this.sectionFilter,
    required this.onSectionFilterChanged,
    required this.onAddSection,
    required this.onAddItem,
    required this.onEditSection,
    required this.onEditItem,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final filteredLib = sectionFilter == 'all'
        ? items
        : items.where((i) => i.sectionId == sectionFilter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: AdminPrimaryButton(
                label: 'قسم مكتبة جديد',
                icon: Icons.create_new_folder_rounded,
                onPressed: onAddSection,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdminPrimaryButton(
                label: 'مقال / قصة جديدة',
                icon: Icons.post_add_rounded,
                onPressed: sections.isEmpty ? null : onAddItem,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdminSectionCard(
          title: 'أقسام المكتبة (${sections.length})',
          icon: Icons.folder_copy_rounded,
          child: Column(
            children: [
              for (final sec in sections) ...[
                CmsEntityTile(
                  title: sec.title,
                  subtitle: 'ID: ${sec.id} • الترتيب: ${sec.sortOrder}',
                  badgeText: sec.isVisible ? 'مرئي' : 'مخفي',
                  isVisible: sec.isVisible,
                  onToggleVisibility: (v) =>
                      onToggleVisibility('library_section', sec.id, v),
                  onEdit: () => onEditSection(sec),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdminSectionCard(
          title: 'بطاقات المكتبة السحابية (${items.length})',
          icon: Icons.auto_stories_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sections.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text(
                          'الكل',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                        ),
                        selected: sectionFilter == 'all',
                        onSelected: (_) => onSectionFilterChanged('all'),
                      ),
                      const SizedBox(width: 6),
                      for (final sec in sections) ...[
                        ChoiceChip(
                          label: Text(
                            sec.title,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                            ),
                          ),
                          selected: sectionFilter == sec.id,
                          onSelected: (_) => onSectionFilterChanged(sec.id),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (filteredLib.isEmpty)
                const Text(
                  'لا توجد عناصر مكتبة مطابقة.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                )
              else
                Column(
                  children: [
                    for (final item in filteredLib) ...[
                      CmsEntityTile(
                        title: item.title,
                        subtitle:
                            '${item.sectionId}${item.subtitle.isNotEmpty ? " • ${item.subtitle}" : ""}',
                        badgeText: item.isVisible ? 'مرئي' : 'مخفي',
                        isVisible: item.isVisible,
                        onToggleVisibility: (v) =>
                            onToggleVisibility('library_item', item.id, v),
                        onEdit: () => onEditItem(item),
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
