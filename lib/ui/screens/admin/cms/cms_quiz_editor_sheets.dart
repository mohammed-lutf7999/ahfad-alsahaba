import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/cms_models.dart';
import '../../../../data/services/admin_service.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_entity_tile.dart';

Future<bool?> openCmsQuizCategoryEditor(
  BuildContext context, {
  DynamicQuizCategoryData? existing,
}) {
  final formKey = GlobalKey<FormState>();
  var visible = existing?.isVisible ?? true;
  var saving = false;

  return showManagedCmsEditor(
    context: context,
    initialTexts: {
      'id': existing?.id ?? '',
      'name': existing?.name ?? '',
      'levels': '${existing?.totalLevels ?? 10}',
    },
    builder: (ctx, ctrls) => StatefulBuilder(
      builder: (ctx, setModalState) => Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'قسم مسابقة جديد' : 'تعديل: ${existing.name}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (existing == null)
              AdminTextField(
                controller: ctrls['id']!,
                label: 'المعرّف (مثل tabieen)',
                validator: (v) =>
                    RegExp(r'^[a-z0-9_]{2,48}$').hasMatch((v ?? '').trim())
                        ? null
                        : 'استخدم أحرفاً إنجليزية صغيرة وأرقاماً و _',
              ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['name']!,
              label: 'اسم القسم',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['levels']!,
              label: 'عدد المراحل (1..100)',
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              value: visible,
              onChanged: (v) => setModalState(() => visible = v),
              title: const Text(
                'مرئي للاعبين',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
            ),
            AdminPrimaryButton(
              label: 'حفظ قسم المسابقة',
              icon: Icons.save_rounded,
              isLoading: saving,
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setModalState(() => saving = true);
                try {
                  final saved = await AdminService().upsertQuizCategory(
                    id: ctrls['id']!.text.trim().toLowerCase(),
                    name: ctrls['name']!.text.trim(),
                    totalLevels:
                        (int.tryParse(ctrls['levels']!.text.trim()) ?? 10)
                            .clamp(1, 100),
                    iconName: existing?.iconName ?? 'quiz_rounded',
                    colorHex: existing?.colorHex ?? '#1B5E20',
                    sortOrder: existing?.sortOrder ?? 10,
                    isVisible: visible,
                    isLocked: existing?.isLocked ?? false,
                  );
                  if (!ctx.mounted) return;
                  if (saved == null) {
                    setModalState(() => saving = false);
                    showAdminFeedback(
                      ctx,
                      'لم يتم حفظ قسم المسابقة؛ تحقق من الاتصال وصلاحيات المشرف.',
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

Future<bool?> openCmsQuizQuestionEditor(
  BuildContext context, {
  required List<DynamicQuizCategoryData> categories,
  DynamicQuizQuestionData? existing,
}) {
  if (categories.isEmpty) return Future.value(false);
  final formKey = GlobalKey<FormState>();
  var catId = existing?.categoryId ?? categories.first.id;
  if (!categories.any((c) => c.id == catId)) {
    catId = categories.first.id;
  }
  var syncScope = existing?.syncScope ?? 'solo_only';
  final opts = existing?.options ?? const ['', '', '', ''];
  var correctIdx = existing?.correctIndex ?? 0;
  var visible = existing?.isVisible ?? true;
  var saving = false;

  return showManagedCmsEditor(
    context: context,
    initialTexts: {
      'lvl': '${existing?.levelNumber ?? 1}',
      'q': existing?.questionText ?? '',
      'o0': opts.isNotEmpty ? opts[0] : '',
      'o1': opts.length > 1 ? opts[1] : '',
      'o2': opts.length > 2 ? opts[2] : '',
      'o3': opts.length > 3 ? opts[3] : '',
      'exp': existing?.explanation ?? '',
    },
    builder: (ctx, ctrls) => StatefulBuilder(
      builder: (ctx, setModalState) => Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'سؤال سحابي جديد' : 'تعديل السؤال',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: catId,
                    dropdownColor: AppCustomTheme.of(ctx).surfaceCard,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => catId = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminTextField(
                    controller: ctrls['lvl']!,
                    label: 'المستوى',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['q']!,
              label: 'نص السؤال',
              maxLines: 2,
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'السؤال مطلوب' : null,
            ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['o0']!,
              label: 'الخيار الأول (0)',
              validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 6),
            AdminTextField(
              controller: ctrls['o1']!,
              label: 'الخيار الثاني (1)',
              validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 6),
            AdminTextField(
              controller: ctrls['o2']!,
              label: 'الخيار الثالث (2)',
              validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 6),
            AdminTextField(
              controller: ctrls['o3']!,
              label: 'الخيار الرابع (3)',
              validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: correctIdx.clamp(0, 3),
              dropdownColor: AppCustomTheme.of(ctx).surfaceCard,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              items: const [
                DropdownMenuItem(value: 0, child: Text('الإجابة: الخيار 0')),
                DropdownMenuItem(value: 1, child: Text('الإجابة: الخيار 1')),
                DropdownMenuItem(value: 2, child: Text('الإجابة: الخيار 2')),
                DropdownMenuItem(value: 3, child: Text('الإجابة: الخيار 3')),
              ],
              onChanged: (v) {
                if (v != null) setModalState(() => correctIdx = v);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: syncScope,
              dropdownColor: AppCustomTheme.of(ctx).surfaceCard,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: 'solo_only',
                  child: Text('نطاق: فردي فقط (الأكثر أماناً)'),
                ),
                DropdownMenuItem(
                  value: 'all_with_fallback',
                  child: Text('نطاق: شامل (فردي + أونلاين)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setModalState(() => syncScope = v);
              },
            ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['exp']!,
              label: 'الشرح والمصدر',
              maxLines: 2,
            ),
            SwitchListTile(
              value: visible,
              onChanged: (v) => setModalState(() => visible = v),
              title: const Text(
                'مرئي بالمسابقة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
            ),
            AdminPrimaryButton(
              label: 'حفظ السؤال السحابي',
              icon: Icons.save_rounded,
              isLoading: saving,
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setModalState(() => saving = true);
                try {
                  final saved = await AdminService().upsertQuizQuestion(
                    id: existing?.id,
                    categoryId: catId,
                    levelNumber:
                        (int.tryParse(ctrls['lvl']!.text.trim()) ?? 1)
                            .clamp(1, 100),
                    questionText: ctrls['q']!.text.trim(),
                    options: [
                      ctrls['o0']!.text.trim(),
                      ctrls['o1']!.text.trim(),
                      ctrls['o2']!.text.trim(),
                      ctrls['o3']!.text.trim(),
                    ],
                    correctIndex: correctIdx,
                    explanation: ctrls['exp']!.text.trim(),
                    syncScope: syncScope,
                    sortOrder: existing?.sortOrder ?? 10,
                    isVisible: visible,
                  );
                  if (!ctx.mounted) return;
                  if (saved == null) {
                    setModalState(() => saving = false);
                    showAdminFeedback(
                      ctx,
                      'لم يتم حفظ السؤال؛ تحقق من الاتصال وصلاحيات المشرف.',
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
