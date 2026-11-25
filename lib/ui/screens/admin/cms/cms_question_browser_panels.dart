import 'package:flutter/material.dart';

import '../../../../data/models/cms_models.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_level_grid_card.dart';

/// Filter controls card for [CmsQuestionBrowserTab].
class CmsBrowserFilterCard extends StatelessWidget {
  final int totalCount;
  final List<DynamicQuizCategoryData> categories;
  final String selectedCategoryId;
  final TextEditingController levelCtrl;
  final TextEditingController searchCtrl;
  final String visibility;
  final bool isLoading;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onSearch;

  const CmsBrowserFilterCard({
    super.key,
    required this.totalCount,
    required this.categories,
    required this.selectedCategoryId,
    required this.levelCtrl,
    required this.searchCtrl,
    required this.visibility,
    required this.isLoading,
    required this.onCategoryChanged,
    required this.onVisibilityChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final activeCat = categories.any((c) => c.id == selectedCategoryId)
        ? selectedCategoryId
        : (categories.isNotEmpty ? categories.first.id : null);

    return AdminSectionCard(
      title: 'تصفية الأسئلة السحابية ($totalCount)',
      icon: Icons.search_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: activeCat,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF17202E),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 12.5,
                  ),
                  decoration: cmsAdminInputDecoration('القسم'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) onCategoryChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: levelCtrl,
                  keyboardType: TextInputType.number,
                  style:
                      const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                  decoration: cmsAdminInputDecoration('المستوى'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: visibility,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF17202E),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 12.5,
                  ),
                  decoration: cmsAdminInputDecoration('الحالة'),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('الكل', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'visible',
                      child: Text('المرئية', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'hidden',
                      child: Text('المخفية', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onVisibilityChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: searchCtrl,
                  style:
                      const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                  decoration: cmsAdminInputDecoration('بحث في النص...'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AdminPrimaryButton(
            label: 'بحث وتحديث',
            icon: Icons.refresh_rounded,
            isLoading: isLoading,
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}

/// Bulk management + bundled local question ID hiding controls.
class CmsBrowserBulkAndLocalCards extends StatelessWidget {
  final int selectedCount;
  final String bulkAction;
  final bool isBusy;
  final TextEditingController bulkFromCtrl;
  final TextEditingController bulkToCtrl;
  final TextEditingController bulkTargetCtrl;
  final TextEditingController localIdCtrl;
  final List<String> hiddenLocalIds;
  final ValueChanged<String> onBulkActionChanged;
  final VoidCallback onSelectPage;
  final VoidCallback onClearSelection;
  final VoidCallback onRunBulk;
  final VoidCallback onHideLocal;
  final ValueChanged<String> onUnhideLocal;

  const CmsBrowserBulkAndLocalCards({
    super.key,
    required this.selectedCount,
    required this.bulkAction,
    required this.isBusy,
    required this.bulkFromCtrl,
    required this.bulkToCtrl,
    required this.bulkTargetCtrl,
    required this.localIdCtrl,
    required this.hiddenLocalIds,
    required this.onBulkActionChanged,
    required this.onSelectPage,
    required this.onClearSelection,
    required this.onRunBulk,
    required this.onHideLocal,
    required this.onUnhideLocal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdminSectionCard(
          title: 'إجراءات جماعية (المحدد: $selectedCount)',
          icon: Icons.bolt_rounded,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: bulkAction,
                isExpanded: true,
                dropdownColor: const Color(0xFF17202E),
                style:
                    const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: cmsAdminInputDecoration('الإجراء'),
                items: const [
                  DropdownMenuItem(
                    value: 'hide',
                    child: Text('إخفاء (hide)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'show',
                    child: Text('إظهار (show)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'move_level',
                    child: Text(
                      'نقل لمستوى (move_level)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'delete',
                    child: Text(
                      'حذف نهائي (delete)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onBulkActionChanged(v);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: bulkFromCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                      decoration: cmsAdminInputDecoration('من م'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: bulkToCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                      decoration: cmsAdminInputDecoration('إلى م'),
                    ),
                  ),
                  if (bulkAction == 'move_level') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: bulkTargetCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                        ),
                        decoration: cmsAdminInputDecoration('الهدف'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isBusy ? null : onSelectPage,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'تحديد الصفحة',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isBusy ? null : onClearSelection,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'إلغاء التحديد',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AdminPrimaryButton(
                label: 'تنفيذ الإجراء الجماعي',
                icon: Icons.playlist_add_check_rounded,
                isLoading: isBusy,
                onPressed: isBusy ? null : onRunBulk,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AdminSectionCard(
          title: 'إخفاء/إظهار سؤال محلي بالمعرّف (${hiddenLocalIds.length})',
          icon: Icons.shield_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: localIdCtrl,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                      decoration: cmsAdminInputDecoration('مثال: q1_1 أو a1_3'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isBusy ? null : onHideLocal,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'إخفاء',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                ],
              ),
              if (hiddenLocalIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in hiddenLocalIds)
                      InputChip(
                        label: Text(
                          id,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                          ),
                        ),
                        onDeleted: isBusy ? null : () => onUnhideLocal(id),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
