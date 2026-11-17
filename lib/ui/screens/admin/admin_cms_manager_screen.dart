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

  List<DynamicQuizCategoryData> _quizCategories = const [];
  List<DynamicQuizQuestionData> _quizQuestions = const [];

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
          child: _libItems.isEmpty
              ? const Text(
                  'لا توجد عناصر مكتبة مضافة سحابياً بعد.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                )
              : Column(
                  children: [
                    for (final item in _libItems) ...[
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
          child: _quizQuestions.isEmpty
              ? const Text(
                  'لا توجد أسئلة سحابية مضافة بعد.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                )
              : Column(
                  children: [
                    for (final q in _quizQuestions) ...[
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
                ),
        ),
      ],
    );
  }

  Future<void> _openStoreEditor({StoreItemModel? existing}) async {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final coinsCtrl =
        TextEditingController(text: '${existing?.priceCoins ?? 500}');
    final gemsCtrl =
        TextEditingController(text: '${existing?.priceGems ?? 0}');
    final minLvlCtrl =
        TextEditingController(text: '${existing?.minLevel ?? 1}');
    var cat = existing?.category ?? StoreItemCategory.title;
    var isVisible = existing?.isVisible ?? true;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppCustomTheme.of(context).deepBackground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
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
                        controller: idCtrl,
                        label: 'المعرّف البرمجي (مثل title_sahaba_hero)',
                        validator: (v) =>
                            RegExp(r'^[a-z0-9_]{3,64}$').hasMatch((v ?? '').trim())
                                ? null
                                : 'استخدم أحرفاً إنجليزية صغيرة وأرقاماً و _ (3..64)',
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<StoreItemCategory>(
                      value: cat,
                      dropdownColor: AppCustomTheme.of(context).surfaceCard,
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: StoreItemCategory.title, child: Text('لقب')),
                        DropdownMenuItem(value: StoreItemCategory.theme, child: Text('ثيم')),
                        DropdownMenuItem(value: StoreItemCategory.frame, child: Text('إطار')),
                        DropdownMenuItem(value: StoreItemCategory.powerup, child: Text('قدرة')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => cat = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    AdminTextField(
                      controller: titleCtrl,
                      label: 'الاسم المعروض',
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
                    ),
                    const SizedBox(height: 8),
                    AdminTextField(
                      controller: descCtrl,
                      label: 'الوصف',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AdminTextField(
                            controller: coinsCtrl,
                            label: 'دنانير',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AdminTextField(
                            controller: gemsCtrl,
                            label: 'ياقوت',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AdminTextField(
                            controller: minLvlCtrl,
                            label: 'مستوى',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
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
                          await AdminService().upsertStoreItem(
                            id: idCtrl.text.trim().toLowerCase(),
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            category: cat,
                            priceCoins: int.tryParse(coinsCtrl.text.trim()) ?? 0,
                            priceGems: int.tryParse(gemsCtrl.text.trim()) ?? 0,
                            minLevel: int.tryParse(minLvlCtrl.text.trim()) ?? 1,
                            assetKey: existing?.assetKey ?? '',
                            isVisible: isVisible,
                            metadata: existing?.metadata ?? const {},
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _loadAll();
                        } catch (e) {
                          setModalState(() => saving = false);
                          if (!mounted) return;
                          showAdminFeedback(context, 'فشل الحفظ: $e', isError: true);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    idCtrl.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    coinsCtrl.dispose();
    gemsCtrl.dispose();
    minLvlCtrl.dispose();
  }

  Future<void> _openLibSectionEditor({DynamicLibrarySectionData? existing}) async {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    var visible = existing?.isVisible ?? true;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppCustomTheme.of(context).deepBackground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
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
                      controller: idCtrl,
                      label: 'المعرّف (مثل sahaba_stories)',
                      validator: (v) =>
                          RegExp(r'^[a-z0-9_]{2,48}$').hasMatch((v ?? '').trim())
                              ? null
                              : 'استخدم أحرفاً إنجليزية صغيرة وأرقاماً و _',
                    ),
                  const SizedBox(height: 8),
                  AdminTextField(
                    controller: titleCtrl,
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
                          id: idCtrl.text.trim().toLowerCase(),
                          title: titleCtrl.text.trim(),
                          iconName: existing?.iconName ?? 'auto_stories_rounded',
                          colorHex: existing?.colorHex ?? '#D4AF37',
                          sortOrder: existing?.sortOrder ?? 10,
                          isVisible: visible,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _loadAll();
                      } catch (e) {
                        setModalState(() => saving = false);
                        if (!mounted) return;
                        showAdminFeedback(context, 'فشل الحفظ: $e', isError: true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    idCtrl.dispose();
    titleCtrl.dispose();
  }

  Future<void> _openLibItemEditor({DynamicLibraryItemData? existing}) async {
    final formKey = GlobalKey<FormState>();
    var sectionId = existing?.sectionId ?? _libSections.first.id;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final srcCtrl = TextEditingController(text: existing?.sourceRef ?? '');
    final bodyCtrl = TextEditingController(text: existing?.content ?? '');
    var visible = existing?.isVisible ?? true;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppCustomTheme.of(context).deepBackground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
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
                      dropdownColor: AppCustomTheme.of(context).surfaceCard,
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                      items: _libSections
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.title),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => sectionId = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    AdminTextField(
                      controller: titleCtrl,
                      label: 'العنوان',
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'العنوان مطلوب' : null,
                    ),
                    const SizedBox(height: 8),
                    AdminTextField(controller: subCtrl, label: 'عنوان فرعي'),
                    const SizedBox(height: 8),
                    AdminTextField(controller: srcCtrl, label: 'المصدر الموثق'),
                    const SizedBox(height: 8),
                    AdminTextField(
                      controller: bodyCtrl,
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
                            title: titleCtrl.text.trim(),
                            subtitle: subCtrl.text.trim(),
                            content: bodyCtrl.text.trim(),
                            sourceRef: srcCtrl.text.trim(),
                            sortOrder: existing?.sortOrder ?? 10,
                            isVisible: visible,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _loadAll();
                        } catch (e) {
                          setModalState(() => saving = false);
                          if (!mounted) return;
                          showAdminFeedback(context, 'فشل الحفظ: $e', isError: true);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    titleCtrl.dispose();
    subCtrl.dispose();
    srcCtrl.dispose();
    bodyCtrl.dispose();
  }

  Future<void> _openQuizCategoryEditor({DynamicQuizCategoryData? existing}) async {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final levelsCtrl =
        TextEditingController(text: '${existing?.totalLevels ?? 10}');
    var visible = existing?.isVisible ?? true;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppCustomTheme.of(context).deepBackground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
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
                      controller: idCtrl,
                      label: 'المعرّف (مثل tabieen)',
                      validator: (v) =>
                          RegExp(r'^[a-z0-9_]{2,48}$').hasMatch((v ?? '').trim())
                              ? null
                              : 'استخدم أحرفاً إنجليزية صغيرة وأرقاماً و _',
                    ),
                  const SizedBox(height: 8),
                  AdminTextField(
                    controller: nameCtrl,
                    label: 'اسم القسم',
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  AdminTextField(
                    controller: levelsCtrl,
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
                          id: idCtrl.text.trim().toLowerCase(),
                          name: nameCtrl.text.trim(),
                          totalLevels:
                              (int.tryParse(levelsCtrl.text.trim()) ?? 10)
                                  .clamp(1, 100),
                          iconName: existing?.iconName ?? 'quiz_rounded',
                          colorHex: existing?.colorHex ?? '#1B5E20',
                          sortOrder: existing?.sortOrder ?? 10,
                          isVisible: visible,
                          isLocked: existing?.isLocked ?? false,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _loadAll();
                      } catch (e) {
                        setModalState(() => saving = false);
                        if (!mounted) return;
                        showAdminFeedback(context, 'فشل الحفظ: $e', isError: true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    idCtrl.dispose();
    nameCtrl.dispose();
    levelsCtrl.dispose();
  }

  Future<void> _openQuizQuestionEditor({DynamicQuizQuestionData? existing}) async {
    final formKey = GlobalKey<FormState>();
    var catId = existing?.categoryId ?? _quizCategories.first.id;
    final lvlCtrl =
        TextEditingController(text: '${existing?.levelNumber ?? 1}');
    final qCtrl = TextEditingController(text: existing?.questionText ?? '');
    final opts = existing?.options ?? const ['', '', '', ''];
    final o0 = TextEditingController(text: opts.isNotEmpty ? opts[0] : '');
    final o1 = TextEditingController(text: opts.length > 1 ? opts[1] : '');
    final o2 = TextEditingController(text: opts.length > 2 ? opts[2] : '');
    final o3 = TextEditingController(text: opts.length > 3 ? opts[3] : '');
    final expCtrl = TextEditingController(text: existing?.explanation ?? '');
    var correctIdx = existing?.correctIndex ?? 0;
    var visible = existing?.isVisible ?? true;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppCustomTheme.of(context).deepBackground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
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
                            dropdownColor: AppCustomTheme.of(context).surfaceCard,
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
                            controller: lvlCtrl,
                            label: 'المستوى',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AdminTextField(
                      controller: qCtrl,
                      label: 'نص السؤال',
                      maxLines: 2,
                      validator: (v) =>
                          (v ?? '').trim().length < 3 ? 'السؤال مطلوب' : null,
                    ),
                    const SizedBox(height: 8),
                    AdminTextField(
                      controller: o0,
                      label: 'الخيار الأول (0)',
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 6),
                    AdminTextField(
                      controller: o1,
                      label: 'الخيار الثاني (1)',
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 6),
                    AdminTextField(
                      controller: o2,
                      label: 'الخيار الثالث (2)',
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 6),
                    AdminTextField(
                      controller: o3,
                      label: 'الخيار الرابع (3)',
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: correctIdx.clamp(0, 3),
                      dropdownColor: AppCustomTheme.of(context).surfaceCard,
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
                    AdminTextField(
                      controller: expCtrl,
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
                                (int.tryParse(lvlCtrl.text.trim()) ?? 1)
                                    .clamp(1, 100),
                            questionText: qCtrl.text.trim(),
                            options: [
                              o0.text.trim(),
                              o1.text.trim(),
                              o2.text.trim(),
                              o3.text.trim(),
                            ],
                            correctIndex: correctIdx,
                            explanation: expCtrl.text.trim(),
                            syncScope: existing?.syncScope ?? 'solo_only',
                            sortOrder: existing?.sortOrder ?? 10,
                            isVisible: visible,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _loadAll();
                        } catch (e) {
                          setModalState(() => saving = false);
                          if (!mounted) return;
                          showAdminFeedback(context, 'فشل الحفظ: $e', isError: true);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    lvlCtrl.dispose();
    qCtrl.dispose();
    o0.dispose();
    o1.dispose();
    o2.dispose();
    o3.dispose();
    expCtrl.dispose();
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
