import 'package:flutter/material.dart';

import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/cms_models.dart';
import '../../../data/models/store_item_model.dart';
import '../../../data/services/admin_service.dart';
import 'cms/cms_library_editor_sheets.dart';
import 'cms/cms_library_tab.dart';
import 'cms/cms_quiz_editor_sheets.dart';
import 'cms/cms_quiz_tab.dart';
import 'cms/cms_store_editor_sheet.dart';
import 'cms/cms_store_tab.dart';
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

  Future<void> _reloadScope(String scope) async {
    try {
      final admin = AdminService();
      if (scope == 'store') {
        final items = await admin.listStoreItems();
        if (mounted) setState(() => _storeItems = items);
      } else if (scope == 'library') {
        final libRes = await admin.listLibraryContent();
        if (mounted) {
          setState(() {
            _libSections = libRes.sections;
            _libItems = libRes.items;
          });
        }
      } else if (scope == 'quiz') {
        final quizRes = await admin.listQuizContent(limit: 80);
        if (mounted) {
          setState(() {
            _quizCategories = quizRes.categories;
            _quizQuestions = quizRes.questions;
          });
        }
      } else {
        await _loadAll();
      }
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر تحديث القسم: $e', isError: true);
    }
  }

  String _scopeForEntityType(String entityType) {
    if (entityType == 'store_item') return 'store';
    if (entityType.startsWith('library_')) return 'library';
    if (entityType.startsWith('quiz_')) return 'quiz';
    return 'all';
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
        await _reloadScope(_scopeForEntityType(entityType));
      } else {
        showAdminFeedback(
          context,
          'تعذر تحديث حالة الظهور؛ تحقق من الاتصال وصلاحيات المشرف.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر تبديل الظهور: $e', isError: true);
    }
  }

  Future<void> _handleEditorResult(
    bool? saved,
    String successMessage, {
    required String scope,
  }) async {
    if (saved == true && mounted) {
      showAdminFeedback(context, successMessage);
      await _reloadScope(scope);
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
                        CmsStoreTab(
                          items: _storeItems,
                          filter: _storeFilter,
                          onFilterChanged: (v) =>
                              setState(() => _storeFilter = v),
                          onAddItem: () async => _handleEditorResult(
                            await openCmsStoreEditor(context),
                            'تم حفظ عنصر المتجر بنجاح ✅',
                            scope: 'store',
                          ),
                          onEditItem: (item) async => _handleEditorResult(
                            await openCmsStoreEditor(context, existing: item),
                            'تم حفظ عنصر المتجر بنجاح ✅',
                            scope: 'store',
                          ),
                          onToggleVisibility: (id, v) =>
                              _toggleVisibility('store_item', id, v),
                        ),
                        CmsLibraryTab(
                          sections: _libSections,
                          items: _libItems,
                          sectionFilter: _libSectionFilter,
                          onSectionFilterChanged: (v) =>
                              setState(() => _libSectionFilter = v),
                          onAddSection: () async => _handleEditorResult(
                            await openCmsLibSectionEditor(context),
                            'تم حفظ قسم المكتبة بنجاح ✅',
                            scope: 'library',
                          ),
                          onAddItem: () async => _handleEditorResult(
                            await openCmsLibItemEditor(
                              context,
                              sections: _libSections,
                            ),
                            'تم حفظ بطاقة المكتبة بنجاح ✅',
                            scope: 'library',
                          ),
                          onEditSection: (sec) async => _handleEditorResult(
                            await openCmsLibSectionEditor(context, existing: sec),
                            'تم حفظ قسم المكتبة بنجاح ✅',
                            scope: 'library',
                          ),
                          onEditItem: (item) async => _handleEditorResult(
                            await openCmsLibItemEditor(
                              context,
                              sections: _libSections,
                              existing: item,
                            ),
                            'تم حفظ بطاقة المكتبة بنجاح ✅',
                            scope: 'library',
                          ),
                          onToggleVisibility: _toggleVisibility,
                        ),
                        CmsQuizTab(
                          categories: _quizCategories,
                          questions: _quizQuestions,
                          categoryFilter: _quizCategoryFilter,
                          onCategoryFilterChanged: (v) =>
                              setState(() => _quizCategoryFilter = v),
                          onAddCategory: () async => _handleEditorResult(
                            await openCmsQuizCategoryEditor(context),
                            'تم حفظ قسم المسابقة بنجاح ✅',
                            scope: 'quiz',
                          ),
                          onAddQuestion: () async => _handleEditorResult(
                            await openCmsQuizQuestionEditor(
                              context,
                              categories: _quizCategories,
                            ),
                            'تم حفظ السؤال السحابي بنجاح ✅',
                            scope: 'quiz',
                          ),
                          onEditCategory: (cat) async => _handleEditorResult(
                            await openCmsQuizCategoryEditor(
                              context,
                              existing: cat,
                            ),
                            'تم حفظ قسم المسابقة بنجاح ✅',
                            scope: 'quiz',
                          ),
                          onEditQuestion: (q) async => _handleEditorResult(
                            await openCmsQuizQuestionEditor(
                              context,
                              categories: _quizCategories,
                              existing: q,
                            ),
                            'تم حفظ السؤال السحابي بنجاح ✅',
                            scope: 'quiz',
                          ),
                          onToggleVisibility: _toggleVisibility,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
