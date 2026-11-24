import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../widgets/admin_ui_kit.dart';

class ReleaseMaintenanceCard extends StatelessWidget {
  final bool maintenanceMode;
  final TextEditingController titleController;
  final TextEditingController messageController;
  final ValueChanged<bool> onMaintenanceChanged;

  const ReleaseMaintenanceCard({
    super.key,
    required this.maintenanceMode,
    required this.titleController,
    required this.messageController,
    required this.onMaintenanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return AdminSectionCard(
      title: 'وضع الصيانة الطارئ',
      icon: Icons.engineering_rounded,
      accentColor: maintenanceMode ? Colors.redAccent : accent,
      child: Column(
        children: [
          SwitchListTile.adaptive(
            key: const Key('admin_maintenance_switch'),
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.redAccent,
            title: const Text(
              'تفعيل وضع الصيانة الشامل',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              maintenanceMode
                  ? 'التطبيق مغلق حالياً أمام اللاعبين (المشرف يمكنه التجاوز)'
                  : 'التطبيق متاح ويعمل بصورة طبيعية',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11.5,
              ),
            ),
            value: maintenanceMode,
            onChanged: onMaintenanceChanged,
          ),
          const SizedBox(height: 10),
          AdminTextField(
            controller: titleController,
            label: 'عنوان شاشة الصيانة',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: messageController,
            label: 'رسالة الصيانة للاعبين',
            maxLines: 3,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
        ],
      ),
    );
  }
}

class ReleaseVersionsCard extends StatelessWidget {
  final TextEditingController minVersionCtrl;
  final TextEditingController latestVersionCtrl;
  final TextEditingController latestNameCtrl;
  final TextEditingController updateUrlCtrl;
  final TextEditingController updateTitleCtrl;
  final TextEditingController updateMessageCtrl;

  const ReleaseVersionsCard({
    super.key,
    required this.minVersionCtrl,
    required this.latestVersionCtrl,
    required this.latestNameCtrl,
    required this.updateUrlCtrl,
    required this.updateTitleCtrl,
    required this.updateMessageCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: 'إصدارات المتجر والتحديث الإلزامي',
      icon: Icons.system_update_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AdminTextField(
                  controller: minVersionCtrl,
                  label: 'الحد الأدنى (إلزامي)',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1) return 'رقم صحيح >= 1';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdminTextField(
                  controller: latestVersionCtrl,
                  label: 'أحدث بناء (اختياري)',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final latest = int.tryParse(v?.trim() ?? '');
                    final minV = int.tryParse(minVersionCtrl.text.trim()) ?? 0;
                    if (latest == null || latest < 1) return 'رقم صحيح >= 1';
                    if (latest < minV) return 'يجب >= الحد الأدنى';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: latestNameCtrl,
            label: 'اسم الإصدار الأحدث (versionName)',
            hint: 'مثال: 1.0.18',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: updateUrlCtrl,
            label: 'رابط التحديث في المتجر (اختياري/سقوط)',
            keyboardType: TextInputType.url,
            validator: (v) {
              final raw = v?.trim() ?? '';
              if (raw.isEmpty) return null;
              final lower = raw.toLowerCase();
              if (!lower.startsWith('https://') &&
                  !lower.startsWith('http://')) {
                return 'يجب أن يبدأ الرابط بـ https:// أو http://';
              }
              final uri = Uri.tryParse(raw);
              if (uri == null || uri.host.trim().isEmpty) {
                return 'أدخل رابط متجر مكتمل وصحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: updateTitleCtrl,
            label: 'عنوان نافذة التحديث',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
          const SizedBox(height: 12),
          AdminTextField(
            controller: updateMessageCtrl,
            label: 'وصف التحديث ومميزاته',
            maxLines: 3,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
          ),
        ],
      ),
    );
  }
}
