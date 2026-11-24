import 'package:flutter/material.dart';

import '../../../../data/models/store_item_model.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_entity_tile.dart';

class CmsStoreTab extends StatelessWidget {
  final List<StoreItemModel> items;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onAddItem;
  final ValueChanged<StoreItemModel> onEditItem;
  final void Function(String id, bool nextVisible) onToggleVisibility;

  const CmsStoreTab({
    super.key,
    required this.items,
    required this.filter,
    required this.onFilterChanged,
    required this.onAddItem,
    required this.onEditItem,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = filter == 'all'
        ? items
        : items.where((i) => i.category.name == filter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        AdminPrimaryButton(
          label: 'إضافة عنصر متجر جديد',
          icon: Icons.add_business_rounded,
          onPressed: onAddItem,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const [
                ('all', 'الكل'),
                ('title', 'الألقاب'),
                ('theme', 'الثيمات'),
                ('frame', 'الأطر'),
                ('powerup', 'القدرات'),
              ]) ...[
                ChoiceChip(
                  label: Text(
                    entry.$2,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                  selected: filter == entry.$1,
                  onSelected: (_) => onFilterChanged(entry.$1),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Text(
            'لا توجد عناصر متجر مسجّلة في هذا التصنيف.',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
          )
        else
          for (final item in filtered) ...[
            CmsEntityTile(
              title: item.title,
              subtitle:
                  '${item.category.name} • ${item.priceGems > 0 ? "💎 ${item.priceGems}" : "🪙 ${item.priceCoins}"} • م${item.minLevel}',
              badgeText: item.isVisible ? 'مرئي' : 'مخفي',
              isVisible: item.isVisible,
              onToggleVisibility: (v) => onToggleVisibility(item.id, v),
              onEdit: () => onEditItem(item),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}
