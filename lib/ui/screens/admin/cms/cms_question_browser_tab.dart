import 'package:flutter/material.dart';

import '../../../../data/models/cms_models.dart';
import '../../../../data/services/admin_service.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_level_grid_card.dart';
import 'cms_question_browser_panels.dart';

/// Tab 2 of [AdminLevelQuestionManagerScreen]:
/// Paginated cloud question browser with search/filters, single delete,
/// scoped bulk actions (show/hide/move/delete), and bundled local ID hide tool.
class CmsQuestionBrowserTab extends StatefulWidget {
  final List<DynamicQuizCategoryData> categories;
  final String selectedCategoryId;
  final ValueChanged<String> onCategoryChanged;
  final Future<void> Function() onMutated;
  final VoidCallback onJumpToPublishPack;

  const CmsQuestionBrowserTab({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onMutated,
    required this.onJumpToPublishPack,
  });

  @override
  State<CmsQuestionBrowserTab> createState() => _CmsQuestionBrowserTabState();
}

class _CmsQuestionBrowserTabState extends State<CmsQuestionBrowserTab> {
  final _searchCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _localIdCtrl = TextEditingController();
  final _bulkFromCtrl = TextEditingController();
  final _bulkToCtrl = TextEditingController();
  final _bulkTargetCtrl = TextEditingController(text: '1');

  AdminQuestionBrowserPage _pageData = const AdminQuestionBrowserPage();
  final Set<String> _selectedIds = {};
  String _visibility = 'all';
  String _bulkAction = 'hide';
  int _page = 1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPage(resetPage: true);
  }

  @override
  void didUpdateWidget(covariant CmsQuestionBrowserTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId) {
      _loadPage(resetPage: true);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _levelCtrl.dispose();
    _localIdCtrl.dispose();
    _bulkFromCtrl.dispose();
    _bulkToCtrl.dispose();
    _bulkTargetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPage({bool resetPage = false}) async {
    if (resetPage) {
      _page = 1;
      _selectedIds.clear();
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final lv = int.tryParse(_levelCtrl.text.trim());
      final res = await AdminService().browseQuizQuestions(
        categoryId: widget.selectedCategoryId,
        levelNumber: lv,
        visibility: _visibility,
        search: _searchCtrl.text.trim(),
        page: _page,
        pageSize: 25,
      );
      if (!mounted) return;
      setState(() {
        _pageData = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAdminFeedback(context, 'تعذر تحميل متصفح الأسئلة: $e', isError: true);
    }
  }

  Future<bool> _confirmDialog(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF17202E),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            body,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('تأكيد', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _deleteSingle(DynamicQuizQuestionData q) async {
    final confirmed = await _confirmDialog(
      'تأكيد حذف السؤال',
      'هل تريد حذف السؤال نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
    );
    if (!confirmed) return;
    try {
      await AdminService().deleteQuizQuestion(q.id);
      if (!mounted) return;
      _selectedIds.remove(q.id);
      showAdminFeedback(context, 'تم حذف السؤال بنجاح ✅');
      await Future.wait([_loadPage(), widget.onMutated()]);
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر حذف السؤال: $e', isError: true);
    }
  }

  Future<void> _runBulkAction() async {
    final ids = _selectedIds.toList();
    final fromLv = int.tryParse(_bulkFromCtrl.text.trim());
    final toLv = int.tryParse(_bulkToCtrl.text.trim());
    final hasRange =
        fromLv != null && toLv != null && fromLv >= 1 && toLv >= fromLv;
    if (ids.isEmpty && !hasRange) {
      showAdminFeedback(
        context,
        'حدّد سؤالاً واحداً على الأقل أو أدخل نطاق مستويات صالح.',
        isError: true,
      );
      return;
    }
    final scopeText = ids.isNotEmpty
        ? '${ids.length} سؤال محدد'
        : 'المستويات $fromLv..$toLv';
    final confirmed = await _confirmDialog(
      _bulkAction == 'delete' ? 'تأكيد الحذف الجماعي' : 'تأكيد الإجراء الجماعي',
      'هل تريد تنفيذ ($_bulkAction) على $scopeText؟',
    );
    if (!confirmed) return;
    try {
      final affected = await AdminService().bulkManageQuestions(
        categoryId: widget.selectedCategoryId,
        action: _bulkAction,
        questionIds: ids.isNotEmpty ? ids : null,
        fromLevel: ids.isEmpty ? fromLv : null,
        toLevel: ids.isEmpty ? toLv : null,
        targetLevel: _bulkAction == 'move_level'
            ? (int.tryParse(_bulkTargetCtrl.text.trim()) ?? 1)
            : null,
      );
      if (!mounted) return;
      _selectedIds.clear();
      showAdminFeedback(context, 'تم تنفيذ الإجراء على $affected سؤالاً ✅');
      await Future.wait([_loadPage(), widget.onMutated()]);
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'فشل الإجراء الجماعي: $e', isError: true);
    }
  }

  Future<void> _toggleLocalHidden(String qid, bool hide) async {
    final clean = qid.trim();
    if (clean.isEmpty) return;
    try {
      await AdminService().toggleHiddenLocalQuestion(
        categoryId: widget.selectedCategoryId,
        questionId: clean,
        hide: hide,
      );
      if (!mounted) return;
      if (hide) _localIdCtrl.clear();
      showAdminFeedback(
        context,
        hide ? 'تم إخفاء السؤال المحلي ($clean) ✅' : 'تم إظهار ($clean) ✅',
      );
      await Future.wait([_loadPage(), widget.onMutated()]);
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر تحديث السؤال المحلي: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.lightBlueAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.lightBlueAccent.withValues(alpha: 0.4),
            ),
          ),
          child: const Text(
            'ℹ️ يعرض المتصفح الأسئلة السحابية في quiz_questions. لإخفاء سؤال مدمج من المستويات 1–10 استخدم بطاقة المعرّف أدناه.',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: Colors.white,
            ),
          ),
        ),
        if (_pageData.packNeedsRepublish) ...[
          const SizedBox(height: 10),
          CmsPackRepublishBanner(onPublishTap: widget.onJumpToPublishPack),
        ],
        const SizedBox(height: 10),
        CmsBrowserFilterCard(
          totalCount: _pageData.totalCount,
          categories: widget.categories,
          selectedCategoryId: widget.selectedCategoryId,
          levelCtrl: _levelCtrl,
          searchCtrl: _searchCtrl,
          visibility: _visibility,
          isLoading: _isLoading,
          onCategoryChanged: widget.onCategoryChanged,
          onVisibilityChanged: (v) => setState(() => _visibility = v),
          onSearch: () => _loadPage(resetPage: true),
        ),
        const SizedBox(height: 10),
        CmsBrowserBulkAndLocalCards(
          selectedCount: _selectedIds.length,
          bulkAction: _bulkAction,
          bulkFromCtrl: _bulkFromCtrl,
          bulkToCtrl: _bulkToCtrl,
          bulkTargetCtrl: _bulkTargetCtrl,
          localIdCtrl: _localIdCtrl,
          hiddenLocalIds: _pageData.hiddenLocalQuestionIds,
          onBulkActionChanged: (v) => setState(() => _bulkAction = v),
          onRunBulk: _runBulkAction,
          onHideLocal: () => _toggleLocalHidden(_localIdCtrl.text.trim(), true),
          onUnhideLocal: (id) => _toggleLocalHidden(id, false),
        ),
        const SizedBox(height: 10),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_pageData.questions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'لا توجد أسئلة سحابية مطابقة.',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
              ),
            ),
          )
        else
          ..._pageData.questions.map(
            (q) => CmsBrowserQuestionTile(
              question: q,
              selected: _selectedIds.contains(q.id),
              onSelectChanged: (checked) => setState(() {
                if (checked) {
                  _selectedIds.add(q.id);
                } else {
                  _selectedIds.remove(q.id);
                }
              }),
              onDelete: () => _deleteSingle(q),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: _page > 1 && !_isLoading
                  ? () {
                      setState(() => _page -= 1);
                      _loadPage();
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: const Size(64, 36),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('السابق', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
            Expanded(
              child: Text(
                'صفحة $_page من ${_pageData.totalPages}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _page < _pageData.totalPages && !_isLoading
                  ? () {
                      setState(() => _page += 1);
                      _loadPage();
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: const Size(64, 36),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('التالي', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
