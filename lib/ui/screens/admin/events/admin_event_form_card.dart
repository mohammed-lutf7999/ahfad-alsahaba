import 'package:flutter/material.dart';

import '../../../../core/app_routes.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../../dynamic_event_detail_screen.dart';
import '../widgets/admin_ui_kit.dart';

class AdminEventFormCard extends StatelessWidget {
  static const List<String> colorPresets = [
    '#D4AF37',
    '#10B981',
    '#E11D48',
    '#3B82F6',
    '#8B5CF6',
  ];

  static const List<String> iconPresets = [
    'auto_awesome',
    'mosque',
    'stars',
    'celebration',
    'military_tech',
    'emoji_events',
    'campaign',
    'bolt',
    'castle',
    'menu_book',
    'shield',
  ];

  final bool isEditing;
  final bool isSaving;
  final TextEditingController badgeCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController subtitleCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController ctaLabelCtrl;
  final TextEditingController actionTargetCtrl;
  final TextEditingController colorHexCtrl;
  final TextEditingController priorityCtrl;
  final DynamicEventActionType actionType;
  final String iconName;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final VoidCallback onResetForm;
  final VoidCallback onPreviewFieldChanged;
  final ValueChanged<DynamicEventActionType> onActionTypeChanged;
  final ValueChanged<String> onColorPresetSelected;
  final ValueChanged<String> onIconSelected;
  final VoidCallback onPickStart;
  final VoidCallback onClearStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClearEnd;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSave;

  const AdminEventFormCard({
    super.key,
    required this.isEditing,
    required this.isSaving,
    required this.badgeCtrl,
    required this.titleCtrl,
    required this.subtitleCtrl,
    required this.bodyCtrl,
    required this.ctaLabelCtrl,
    required this.actionTargetCtrl,
    required this.colorHexCtrl,
    required this.priorityCtrl,
    required this.actionType,
    required this.iconName,
    required this.isActive,
    required this.startsAt,
    required this.endsAt,
    required this.onResetForm,
    required this.onPreviewFieldChanged,
    required this.onActionTypeChanged,
    required this.onColorPresetSelected,
    required this.onIconSelected,
    required this.onPickStart,
    required this.onClearStart,
    required this.onPickEnd,
    required this.onClearEnd,
    required this.onActiveChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return AdminSectionCard(
      title: isEditing ? 'تعديل الحدث المحدد' : 'إنشاء حدث ديناميكي جديد',
      icon: Icons.auto_awesome_rounded,
      trailing: isEditing
          ? TextButton(
              onPressed: onResetForm,
              child: const Text(
                'إلغاء التعديل',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AdminTextField(
                  controller: badgeCtrl,
                  label: 'نص الشارة',
                  onChanged: (_) => onPreviewFieldChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminTextField(
                  controller: priorityCtrl,
                  label: 'الأولوية',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: titleCtrl,
            label: 'عنوان الحدث',
            onChanged: (_) => onPreviewFieldChanged(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: subtitleCtrl,
            label: 'العنوان الفرعي (اختياري)',
            onChanged: (_) => onPreviewFieldChanged(),
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: bodyCtrl,
            label: 'النص التفصيلي في صفحة الحدث',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Text(
            'نوع الإجراء عند الضغط',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionTypeChip(
                DynamicEventActionType.openEventScreen,
                'فتح صفحة الحدث',
              ),
              _buildActionTypeChip(
                DynamicEventActionType.navigateRoute,
                'مسار داخلي',
              ),
              _buildActionTypeChip(
                DynamicEventActionType.openUrl,
                'رابط خارجي',
              ),
              _buildActionTypeChip(DynamicEventActionType.none, 'عرض فقط'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminTextField(
                  controller: ctaLabelCtrl,
                  label: 'نص الزر',
                  onChanged: (_) => onPreviewFieldChanged(),
                ),
              ),
              if (actionType != DynamicEventActionType.none) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: AdminTextField(
                    controller: actionTargetCtrl,
                    label: 'الهدف (مسار أو URL)',
                    hint: actionType == DynamicEventActionType.openUrl
                        ? 'https://example.com'
                        : AppRoutes.challenge,
                    validator: (v) {
                      final raw = v?.trim() ?? '';
                      if ((actionType == DynamicEventActionType.navigateRoute ||
                              actionType == DynamicEventActionType.openUrl) &&
                          raw.isEmpty) {
                        return 'أدخل المسار أو الرابط';
                      }
                      if (actionType == DynamicEventActionType.openUrl &&
                          raw.isNotEmpty &&
                          !raw.toLowerCase().startsWith('http://') &&
                          !raw.toLowerCase().startsWith('https://')) {
                        return 'يجب أن يبدأ بـ https://';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: colorHexCtrl,
            label: 'اللون السداسي (Hex)',
            onChanged: (_) => onPreviewFieldChanged(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: colorPresets.map((hex) {
              final c = AppControlVisuals.parseHexColor(
                hex,
                customTheme.sovereignAccent,
              );
              final selected = colorHexCtrl.text.trim().toUpperCase() == hex;
              return GestureDetector(
                onTap: () => onColorPresetSelected(hex),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.white24,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'أيقونة الحدث',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: iconPresets.map((iconKey) {
              final selected = iconName == iconKey;
              return ChoiceChip(
                label: Icon(
                  AppControlVisuals.iconForName(iconKey),
                  size: 18,
                  color:
                      selected ? customTheme.sovereignAccent : Colors.white70,
                ),
                selected: selected,
                onSelected: (_) => onIconSelected(iconKey),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildSchedulePickerRow(
            context: context,
            label: 'يبدأ في:',
            value: startsAt,
            onPick: onPickStart,
            onClear: onClearStart,
          ),
          const SizedBox(height: 8),
          _buildSchedulePickerRow(
            context: context,
            label: 'ينتهي في:',
            value: endsAt,
            onPick: onPickEnd,
            onClear: onClearEnd,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeColor: customTheme.sovereignAccent,
            title: const Text(
              'تفعيل الحدث (Active)',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            value: isActive,
            onChanged: onActiveChanged,
          ),
          const SizedBox(height: 10),
          AdminPrimaryButton(
            key: const Key('admin_save_event_btn'),
            label: isEditing ? 'حفظ تعديلات الحدث ✅' : 'نشر الحدث الآن 🎉',
            icon: Icons.event_available_rounded,
            isLoading: isSaving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTypeChip(DynamicEventActionType type, String label) {
    return ChoiceChip(
      key: Key('event_action_${type.wireName}'),
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
      ),
      selected: actionType == type,
      onSelected: (_) => onActionTypeChanged(type),
    );
  }

  Widget _buildSchedulePickerRow({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: onPick,
            icon: const Icon(Icons.schedule_rounded, size: 17),
            label: Text(
              '$label ${formatAdminDateTime(value)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
      ],
    );
  }
}
