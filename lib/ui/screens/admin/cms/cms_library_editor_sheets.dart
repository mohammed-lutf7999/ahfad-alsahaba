import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/cms_models.dart';
import '../../../../data/services/admin_service.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_entity_tile.dart';

Future<bool?> openCmsLibSectionEditor(
  BuildContext context, {
  DynamicLibrarySectionData? existing,
}) {
  final formKey = GlobalKey<FormState>();
  var visible = existing?.isVisible ?? true;
  var saving = false;

  return showManagedCmsEditor(
    context: context,
    initialTexts: {
      'id': existing?.id ?? '',
      'title': existing?.title ?? '',
    },
    builder: (ctx, ctrls) => StatefulBuilder(
      builder: (ctx, setModalState) => Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'قسم مكتبة جديد' : 'تعديل قسم: ${existing.title}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (existing == null)
              AdminTextField(
                controller: ctrls['id']!,
                label: 'المعرّف (مثل sahaba_stories)',
                validator: (v) =>
                    RegExp(r'^[a-z0-9_]{2,48}$').hasMatch((v ?? '').trim())
                        ? null
                        : 'استخدم أحرفاً إنجليزية صغيرة وأرقاماً و _',
              ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['title']!,
              label: 'اسم القسم',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            SwitchListTile(
              value: visible,
              onChanged: (v) => setModalState(() => visible = v),
              title: const Text(
                'مرئي في المكتبة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
            ),
            AdminPrimaryButton(
              label: 'حفظ قسم المكتبة',
              icon: Icons.save_rounded,
              isLoading: saving,
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setModalState(() => saving = true);
                try {
                  final saved = await AdminService().upsertLibrarySection(
                    id: ctrls['id']!.text.trim().toLowerCase(),
                    title: ctrls['title']!.text.trim(),
                    iconName: existing?.iconName ?? 'auto_stories_rounded',
                    colorHex: existing?.colorHex ?? '#D4AF37',
                    sortOrder: existing?.sortOrder ?? 10,
                    isVisible: visible,
                  );
                  if (!ctx.mounted) return;
                  if (saved == null) {
                    setModalState(() => saving = false);
                    showAdminFeedback(
                      ctx,
                      'لم يتم حفظ القسم؛ تحقق من الاتصال وصلاحيات المشرف.',
                      isError: true,
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                } catch (e) {
                  setModalState(() => saving = false);
                  if (!ctx.mounted) return;
                  showAdminFeedback(ctx, 'فشل الحفظ: $e', isError: true);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool?> openCmsLibItemEditor(
  BuildContext context, {
  required List<DynamicLibrarySectionData> sections,
  DynamicLibraryItemData? existing,
}) {
  if (sections.isEmpty) return Future.value(false);
  final formKey = GlobalKey<FormState>();
  var sectionId = existing?.sectionId ?? sections.first.id;
  if (!sections.any((s) => s.id == sectionId)) {
    sectionId = sections.first.id;
  }
  var visible = existing?.isVisible ?? true;
  var saving = false;

  return showManagedCmsEditor(
    context: context,
    initialTexts: {
      'title': existing?.title ?? '',
      'sub': existing?.subtitle ?? '',
      'src': existing?.sourceRef ?? '',
      'body': existing?.content ?? '',
    },
    builder: (ctx, ctrls) => StatefulBuilder(
      builder: (ctx, setModalState) => Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'بطاقة مكتبة جديدة' : 'تعديل: ${existing.title}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: sectionId,
              dropdownColor: AppCustomTheme.of(ctx).surfaceCard,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              items: sections
                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.title)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setModalState(() => sectionId = v);
              },
            ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['title']!,
              label: 'العنوان',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'العنوان مطلوب' : null,
            ),
            const SizedBox(height: 8),
            AdminTextField(controller: ctrls['sub']!, label: 'عنوان فرعي'),
            const SizedBox(height: 8),
            AdminTextField(controller: ctrls['src']!, label: 'المصدر الموثق'),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['body']!,
              label: 'المحتوى الكامل',
              maxLines: 4,
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'المحتوى مطلوب' : null,
            ),
            SwitchListTile(
              value: visible,
              onChanged: (v) => setModalState(() => visible = v),
              title: const Text(
                'مرئي في المكتبة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
            ),
            AdminPrimaryButton(
              label: 'حفظ بطاقة المكتبة',
              icon: Icons.save_rounded,
              isLoading: saving,
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setModalState(() => saving = true);
                try {
                  final saved = await AdminService().upsertLibraryItem(
                    id: existing?.id,
                    sectionId: sectionId,
                    title: ctrls['title']!.text.trim(),
                    subtitle: ctrls['sub']!.text.trim(),
                    content: ctrls['body']!.text.trim(),
                    sourceRef: ctrls['src']!.text.trim(),
                    sortOrder: existing?.sortOrder ?? 10,
                    isVisible: visible,
                  );
                  if (!ctx.mounted) return;
                  if (saved == null) {
                    setModalState(() => saving = false);
                    showAdminFeedback(
                      ctx,
                      'لم يتم حفظ البطاقة؛ تحقق من الاتصال وصلاحيات المشرف.',
                      isError: true,
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                } catch (e) {
                  setModalState(() => saving = false);
                  if (!ctx.mounted) return;
                  showAdminFeedback(ctx, 'فشل الحفظ: $e', isError: true);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
