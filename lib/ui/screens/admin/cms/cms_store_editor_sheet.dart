import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/store_item_model.dart';
import '../../../../data/services/admin_service.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_entity_tile.dart';

const List<({String name, String hex, Color color})> _accentColorPresets = [
  (name: 'ذهبي', hex: '#F3C644', color: Color(0xFFF3C644)),
  (name: 'زمردي', hex: '#10B981', color: Color(0xFF10B981)),
  (name: 'سماوي', hex: '#38BDF8', color: Color(0xFF38BDF8)),
  (name: 'عقيقي', hex: '#F43F5E', color: Color(0xFFF43F5E)),
  (name: 'بنفسجي', hex: '#A78BFA', color: Color(0xFFA78BFA)),
  (name: 'برونزي', hex: '#D97706', color: Color(0xFFD97706)),
];

const List<({String name, String deep, String surface})> _themeBgPresets = [
  (name: 'ليلي ملكي', deep: '#1A0B2E', surface: '#24143D'),
  (name: 'واحة خضراء', deep: '#062B22', surface: '#0B3A2E'),
  (name: 'كحلي عميق', deep: '#0F172A', surface: '#1E293B'),
  (name: 'ياقوتي داكن', deep: '#2A0A18', surface: '#450A1F'),
];

Future<bool?> openCmsStoreEditor(
  BuildContext context, {
  StoreItemModel? existing,
}) {
  final formKey = GlobalKey<FormState>();
  var cat = existing?.category ?? StoreItemCategory.title;
  var isVisible = existing?.isVisible ?? true;
  var saving = false;
  final initialAccentHex =
      (existing?.metadata['sovereignAccent'] ??
              existing?.metadata['previewColor'] ??
              existing?.metadata['secondaryColor'] ??
              '#F3C644')
          .toString()
          .toUpperCase();
  var selectedAccentHex =
      _accentColorPresets.any((p) => p.hex == initialAccentHex)
          ? initialAccentHex
          : _accentColorPresets.first.hex;
  var selectedBgPresetIdx = 0;

  return showManagedCmsEditor(
    context: context,
    initialTexts: {
      'id': existing?.id ?? '',
      'title': existing?.title ?? '',
      'desc': existing?.description ?? '',
      'coins': '${existing?.priceCoins ?? 500}',
      'gems': '${existing?.priceGems ?? 0}',
      'minLvl': '${existing?.minLevel ?? 1}',
    },
    builder: (ctx, ctrls) => StatefulBuilder(
      builder: (ctx, setModalState) => Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'عنصر متجر جديد' : 'تعديل: ${existing.title}',
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
                label: 'المعرّف البرمجي (مثل title_sahaba_hero)',
                validator: (v) =>
                    RegExp(r'^[a-z0-9_]{3,64}$').hasMatch((v ?? '').trim())
                        ? null
                        : 'استخدم أحرفاً إنجليزية صغيرة وأرقاماً و _ (3..64)',
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<StoreItemCategory>(
              value: cat,
              dropdownColor: AppCustomTheme.of(ctx).surfaceCard,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              items: const [
                DropdownMenuItem(value: StoreItemCategory.title, child: Text('لقب')),
                DropdownMenuItem(value: StoreItemCategory.theme, child: Text('ثيم')),
                DropdownMenuItem(value: StoreItemCategory.frame, child: Text('إطار')),
                DropdownMenuItem(value: StoreItemCategory.powerup, child: Text('قدرة')),
              ],
              onChanged: existing != null
                  ? null
                  : (v) {
                      if (v != null) setModalState(() => cat = v);
                    },
            ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['title']!,
              label: 'الاسم المعروض',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 8),
            AdminTextField(
              controller: ctrls['desc']!,
              label: 'الوصف',
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AdminTextField(
                    controller: ctrls['coins']!,
                    label: 'دنانير',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminTextField(
                    controller: ctrls['gems']!,
                    label: 'ياقوت',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminTextField(
                    controller: ctrls['minLvl']!,
                    label: 'مستوى',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'اللون الملكي للعنصر:',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final preset in _accentColorPresets)
                  ChoiceChip(
                    label: Text(
                      preset.name,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                    ),
                    avatar: CircleAvatar(backgroundColor: preset.color, radius: 8),
                    selected: selectedAccentHex == preset.hex,
                    onSelected: (_) =>
                        setModalState(() => selectedAccentHex = preset.hex),
                  ),
              ],
            ),
            if (cat == StoreItemCategory.theme) ...[
              const SizedBox(height: 8),
              const Text(
                'خلفية الثيم الملكي:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (var idx = 0; idx < _themeBgPresets.length; idx++)
                    ChoiceChip(
                      label: Text(
                        _themeBgPresets[idx].name,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                      ),
                      selected: selectedBgPresetIdx == idx,
                      onSelected: (_) =>
                          setModalState(() => selectedBgPresetIdx = idx),
                    ),
                ],
              ),
            ],
            SwitchListTile(
              value: isVisible,
              onChanged: (v) => setModalState(() => isVisible = v),
              title: const Text(
                'مرئي في المتجر',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
            ),
            AdminPrimaryButton(
              label: 'حفظ العنصر',
              icon: Icons.save_rounded,
              isLoading: saving,
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                setModalState(() => saving = true);
                try {
                  final nextMeta = <String, dynamic>{
                    ...(existing?.metadata ?? const {}),
                    'previewColor': selectedAccentHex,
                    'sovereignAccent': selectedAccentHex,
                  };
                  if (cat == StoreItemCategory.theme) {
                    final bg = _themeBgPresets[selectedBgPresetIdx];
                    nextMeta['deepBackground'] =
                        existing?.metadata['deepBackground'] ?? bg.deep;
                    nextMeta['surfaceCard'] =
                        existing?.metadata['surfaceCard'] ?? bg.surface;
                    nextMeta['secondaryAccent'] =
                        existing?.metadata['secondaryAccent'] ??
                            selectedAccentHex;
                  } else if (cat == StoreItemCategory.frame) {
                    nextMeta['secondaryColor'] = selectedAccentHex;
                    nextMeta['primaryColor'] =
                        existing?.metadata['primaryColor'] ?? '#1A0F2E';
                    nextMeta['highlightColor'] = selectedAccentHex;
                  }
                  await AdminService().upsertStoreItem(
                    id: ctrls['id']!.text.trim().toLowerCase(),
                    title: ctrls['title']!.text.trim(),
                    description: ctrls['desc']!.text.trim(),
                    category: cat,
                    priceCoins: int.tryParse(ctrls['coins']!.text.trim()) ?? 0,
                    priceGems: int.tryParse(ctrls['gems']!.text.trim()) ?? 0,
                    minLevel: int.tryParse(ctrls['minLvl']!.text.trim()) ?? 1,
                    assetKey: existing?.assetKey ?? '',
                    isVisible: isVisible,
                    metadata: nextMeta,
                  );
                  if (!ctx.mounted) return;
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
