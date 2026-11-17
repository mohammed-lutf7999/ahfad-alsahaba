import 'package:flutter/material.dart';

import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/cms_models.dart';
import '../../../data/models/store_item_model.dart';
import '../../../data/services/admin_service.dart';
import 'widgets/admin_ui_kit.dart';

/// In-app Dynamic CMS Manager for Store items, Library content & Quiz bank.
class AdminCmsManagerScreen extends StatefulWidget {
  const AdminCmsManagerScreen({super.key});

  @override
  State<AdminCmsManagerScreen> createState() => _AdminCmsManagerScreenState();
}

class _AdminCmsManagerScreenState extends State<AdminCmsManagerScreen> {
  bool _isLoading = true;
  List<StoreItemModel> _storeItems = const [];
  String _storeFilter = 'all';

  List<DynamicLibrarySectionData> _libSections = const [];
  List<DynamicLibraryItemData> _libItems = const [];
  String _libSectionFilter = 'all';

  List<DynamicQuizCategoryData> _quizCategories = const [];
  List<DynamicQuizQuestionData> _quizQuestions = const [];
  String _quizCategoryFilter = 'all';

  static const List<({String name, String hex, Color color})> _accentColorPresets = [
    (name: 'ذهبي', hex: '#F3C644', color: Color(0xFFF3C644)),
    (name: 'زمردي', hex: '#10B981', color: Color(0xFF10B981)),
    (name: 'سماوي', hex: '#38BDF8', color: Color(0xFF38BDF8)),
    (name: 'عقيقي', hex: '#F43F5E', color: Color(0xFFF43F5E)),
    (name: 'بنفسجي', hex: '#A78BFA', color: Color(0xFFA78BFA)),
    (name: 'برونزي', hex: '#D97706', color: Color(0xFFD97706)),
  ];

  static const List<({String name, String deep, String surface})> _themeBgPresets = [
    (name: 'ليلي ملكي', deep: '#1A0B2E', surface: '#24143D'),
    (name: 'واحة خضراء', deep: '#062B22', surface: '#0B3A2E'),
    (name: 'كحلي عميق', deep: '#0F172A', surface: '#1E293B'),
    (name: 'ياقوتي داكن', deep: '#2A0A18', surface: '#450A1F'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final admin = AdminService();
      final results = await Future.wait<dynamic>([
        admin.listStoreItems(),
        admin.listLibraryContent(),
        admin.listQuizContent(limit: 80),
      ]);
      if (!mounted) return;
      final libRes = results[1] as ({
        List<DynamicLibrarySectionData> sections,
        List<DynamicLibraryItemData> items,
      });
      final quizRes = results[2] as ({
        List<DynamicQuizCategoryData> categories,
        List<DynamicQuizQuestionData> questions,
      });
      setState(() {
        _storeItems = results[0] as List<StoreItemModel>;
        _libSections = libRes.sections;
        _libItems = libRes.items;
        _quizCategories = quizRes.categories;
        _quizQuestions = quizRes.questions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAdminFeedback(context, 'تعذر تحميل بيانات المحتوى: $e', isError: true);
    }
  }

  Future<void> _toggleVisibility(
    String entityType,
    String id,
    bool nextVisible,
  ) async {
    try {
      final ok = await AdminService().setContentVisibility(
        entityType: entityType,
        id: id,
        isVisible: nextVisible,
      );
      if (!mounted) return;
      if (ok) {
        showAdminFeedback(
          context,
          nextVisible ? 'تم إظهار العنصر للجميع ✅' : 'تم إخفاء العنصر بأمان 👁️‍🗨️',
        );
        await _loadAll();
      }
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر تبديل الظهور: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return AdminScaffoldShell(
      title: 'إدارة المتجر والمحتوى',
      subtitle: 'تعديل وإظهار/إخفاء العناصر والمكتبة والمسابقات',
      isLoading: _isLoading,
      onRefresh: _loadAll,
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TabBar(
                indicatorColor: accent,
                labelColor: accent,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
                tabs: const [
                  Tab(text: 'المتجر CMS'),
                  Tab(text: 'المكتبة'),
                  Tab(text: 'المسابقات'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : TabBarView(
                      children: [
                        _buildStoreTab(),
                        _buildLibraryTab(),
                        _buildQuizTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreTab() {
    final filtered = _storeFilter == 'all'
        ? _storeItems
        : _storeItems.where((i) => i.category.name == _storeFilter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        AdminPrimaryButton(
          label: 'إضافة عنصر متجر جديد',
          icon: Icons.add_business_rounded,
          onPressed: () => _openStoreEditor(),
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
                  selected: _storeFilter == entry.$1,
                  onSelected: (_) => setState(() => _storeFilter = entry.$1),
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
            _CmsEntityTile(
              title: item.title,
              subtitle:
                  '${item.category.name} • ${item.priceGems > 0 ? "💎 ${item.priceGems}" : "🪙 ${item.priceCoins}"} • م${item.minLevel}',
              badgeText: item.isVisible ? 'مرئي' : 'مخفي',
              isVisible: item.isVisible,
              onToggleVisibility: (v) =>
                  _toggleVisibility('store_item', item.id, v),
              onEdit: () => _openStoreEditor(existing: item),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildLibraryTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: AdminPrimaryButton(
                label: 'قسم مكتبة جديد',
                icon: Icons.create_new_folder_rounded,
                onPressed: () => _openLibSectionEditor(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdminPrimaryButton(
                label: 'مقال / قصة جديدة',
                icon: Icons.post_add_rounded,
                onPressed: _libSections.isEmpty ? null : () => _openLibItemEditor(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdminSectionCard(
          title: 'أقسام المكتبة (${_libSections.length})',
          icon: Icons.folder_copy_rounded,
          child: Column(
            children: [
              for (final sec in _libSections) ...[
                _CmsEntityTile(
                  title: sec.title,
                  subtitle: 'ID: ${sec.id} • الترتيب: ${sec.sortOrder}',
                  badgeText: sec.isVisible ? 'مرئي' : 'مخفي',
                  isVisible: sec.isVisible,
                  onToggleVisibility: (v) =>
                      _toggleVisibility('library_section', sec.id, v),
                  onEdit: () => _openLibSectionEditor(existing: sec),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdminSectionCard(
          title: 'بطاقات المكتبة السحابية (${_libItems.length})',
          icon: Icons.auto_stories_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_libSections.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('الكل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                        selected: _libSectionFilter == 'all',
                        onSelected: (_) => setState(() => _libSectionFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      for (final sec in _libSections) ...[
                        ChoiceChip(
                          label: Text(sec.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                          selected: _libSectionFilter == sec.id,
                          onSelected: (_) => setState(() => _libSectionFilter = sec.id),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Builder(builder: (_) {
                final filteredLib = _libSectionFilter == 'all'
                    ? _libItems
                    : _libItems.where((i) => i.sectionId == _libSectionFilter).toList();
                if (filteredLib.isEmpty) {
                  return const Text(
                    'لا توجد عناصر مكتبة مطابقة.',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                  );
                }
                return Column(
                  children: [
                    for (final item in filteredLib) ...[
                      _CmsEntityTile(
                        title: item.title,
                        subtitle:
                            '${item.sectionId}${item.subtitle.isNotEmpty ? " • ${item.subtitle}" : ""}',
                        badgeText: item.isVisible ? 'مرئي' : 'مخفي',
                        isVisible: item.isVisible,
                        onToggleVisibility: (v) =>
                            _toggleVisibility('library_item', item.id, v),
                        onEdit: () => _openLibItemEditor(existing: item),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: AdminPrimaryButton(
                label: 'قسم مسابقة جديد',
                icon: Icons.category_rounded,
                onPressed: () => _openQuizCategoryEditor(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdminPrimaryButton(
                label: 'إضافة سؤال سحابي',
                icon: Icons.quiz_rounded,
                onPressed:
                    _quizCategories.isEmpty ? null : () => _openQuizQuestionEditor(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdminSectionCard(
          title: 'أقسام المسابقات (${_quizCategories.length})',
          icon: Icons.emoji_events_rounded,
          child: Column(
            children: [
              for (final cat in _quizCategories) ...[
                _CmsEntityTile(
                  title: cat.name,
                  subtitle:
                      'ID: ${cat.id} • ${cat.totalLevels} مرحلة${cat.isLocked ? " • مقفل" : ""}',
                  badgeText: cat.isVisible ? 'مرئي' : 'مخفي',
                  isVisible: cat.isVisible,
                  onToggleVisibility: (v) =>
                      _toggleVisibility('quiz_category', cat.id, v),
                  onEdit: () => _openQuizCategoryEditor(existing: cat),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdminSectionCard(
          title: 'الأسئلة السحابية (${_quizQuestions.length})',
          icon: Icons.help_outline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_quizCategories.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('كل الأقسام', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                        selected: _quizCategoryFilter == 'all',
                        onSelected: (_) => setState(() => _quizCategoryFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      for (final cat in _quizCategories) ...[
                        ChoiceChip(
                          label: Text(cat.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                          selected: _quizCategoryFilter == cat.id,
                          onSelected: (_) => setState(() => _quizCategoryFilter = cat.id),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Builder(builder: (_) {
                final filteredQ = _quizCategoryFilter == 'all'
                    ? _quizQuestions
                    : _quizQuestions.where((q) => q.categoryId == _quizCategoryFilter).toList();
                if (filteredQ.isEmpty) {
                  return const Text(
                    'لا توجد أسئلة سحابية مطابقة.',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                  );
                }
                return Column(
                  children: [
                    for (final q in filteredQ) ...[
                      _CmsEntityTile(
                        title: q.questionText,
                        subtitle:
                            '${q.categoryId} • المستوى ${q.levelNumber} • ${q.syncScope}',
                        badgeText: q.isVisible ? 'مرئي' : 'مخفي',
                        isVisible: q.isVisible,
                        onToggleVisibility: (v) =>
                            _toggleVisibility('quiz_question', q.id, v),
                        onEdit: () => _openQuizQuestionEditor(existing: q),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool?> _showManagedEditor({
    required Map<String, String> initialTexts,
    required Widget Function(
      BuildContext sheetCtx,
      Map<String, TextEditingController> ctrls,
    ) builder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppCustomTheme.of(context).deepBackground,
      builder: (_) => _ManagedEditorSheet(
        initialTexts: initialTexts,
        builder: builder,
      ),
    );
  }

  Future<void> _openStoreEditor({StoreItemModel? existing}) async {
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
    var selectedAccentHex = _accentColorPresets.any((p) => p.hex == initialAccentHex)
        ? initialAccentHex
        : _accentColorPresets.first.hex;
    var selectedBgPresetIdx = 0;

    final saved = await _showManagedEditor(
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
    if (saved == true && mounted) {
      showAdminFeedback(context, 'تم حفظ عنصر المتجر بنجاح ✅');
      await _loadAll();
    }
  }

  Future<void> _openLibSectionEditor({DynamicLibrarySectionData? existing}) async {
    final formKey = GlobalKey<FormState>();
    var visible = existing?.isVisible ?? true;
    var saving = false;

    final saved = await _showManagedEditor(
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
                    await AdminService().upsertLibrarySection(
                      id: ctrls['id']!.text.trim().toLowerCase(),
                      title: ctrls['title']!.text.trim(),
                      iconName: existing?.iconName ?? 'auto_stories_rounded',
                      colorHex: existing?.colorHex ?? '#D4AF37',
                      sortOrder: existing?.sortOrder ?? 10,
                      isVisible: visible,
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
    if (saved == true && mounted) {
      showAdminFeedback(context, 'تم حفظ قسم المكتبة بنجاح ✅');
      await _loadAll();
    }
  }

  Future<void> _openLibItemEditor({DynamicLibraryItemData? existing}) async {
    if (_libSections.isEmpty) return;
    final formKey = GlobalKey<FormState>();
    var sectionId = existing?.sectionId ?? _libSections.first.id;
    if (!_libSections.any((s) => s.id == sectionId)) {
      sectionId = _libSections.first.id;
    }
    var visible = existing?.isVisible ?? true;
    var saving = false;

    final saved = await _showManagedEditor(
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
                items: _libSections
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
                    await AdminService().upsertLibraryItem(
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
    if (saved == true && mounted) {
      showAdminFeedback(context, 'تم حفظ بطاقة المكتبة بنجاح ✅');
      await _loadAll();
    }
  }

  Future<void> _openQuizCategoryEditor({DynamicQuizCategoryData? existing}) async {
    final formKey = GlobalKey<FormState>();
    var visible = existing?.isVisible ?? true;
    var saving = false;

    final saved = await _showManagedEditor(
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
                    await AdminService().upsertQuizCategory(
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
    if (saved == true && mounted) {
      showAdminFeedback(context, 'تم حفظ قسم المسابقة بنجاح ✅');
      await _loadAll();
    }
  }

  Future<void> _openQuizQuestionEditor({DynamicQuizQuestionData? existing}) async {
    if (_quizCategories.isEmpty) return;
    final formKey = GlobalKey<FormState>();
    var catId = existing?.categoryId ?? _quizCategories.first.id;
    if (!_quizCategories.any((c) => c.id == catId)) {
      catId = _quizCategories.first.id;
    }
    var syncScope = existing?.syncScope ?? 'solo_only';
    final opts = existing?.options ?? const ['', '', '', ''];
    var correctIdx = existing?.correctIndex ?? 0;
    var visible = existing?.isVisible ?? true;
    var saving = false;

    final saved = await _showManagedEditor(
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
                      items: _quizCategories
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
                    await AdminService().upsertQuizQuestion(
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
    if (saved == true && mounted) {
      showAdminFeedback(context, 'تم حفظ السؤال السحابي بنجاح ✅');
      await _loadAll();
    }
  }
}

/// Owns modal [TextEditingController] instances so they are only disposed AFTER
/// the bottom-sheet exit transition unmounts from the widget tree.
class _ManagedEditorSheet extends StatefulWidget {
  final Map<String, String> initialTexts;
  final Widget Function(
    BuildContext context,
    Map<String, TextEditingController> ctrls,
  ) builder;

  const _ManagedEditorSheet({
    required this.initialTexts,
    required this.builder,
  });

  @override
  State<_ManagedEditorSheet> createState() => _ManagedEditorSheetState();
}

class _ManagedEditorSheetState extends State<_ManagedEditorSheet> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final entry in widget.initialTexts.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: widget.builder(context, _ctrls),
        ),
      ),
    );
  }
}

class _CmsEntityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final bool isVisible;
  final ValueChanged<bool> onToggleVisibility;
  final VoidCallback onEdit;

  const _CmsEntityTile({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final statusColor =
        isVisible ? const Color(0xFF10B981) : const Color(0xFFFB7185);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isVisible ? customTheme.sovereignAccent : statusColor)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'تعديل',
            icon: Icon(
              Icons.edit_rounded,
              color: customTheme.sovereignAccent,
              size: 19,
            ),
          ),
          Switch(
            value: isVisible,
            onChanged: onToggleVisibility,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}
