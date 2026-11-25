import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/cms_models.dart';
import '../../../../data/services/admin_service.dart';
import '../admin_bulk_pack_manager_screen.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_level_manager_tab.dart';
import 'cms_question_browser_tab.dart';

/// Mobile Admin screen for Migration 024:
/// - Tab 1: Category availability (`open`/`coming_soon`/`hidden`) & Level overrides
/// - Tab 2: Paginated cloud question browser, bulk ops & local ID hiding
class AdminLevelQuestionManagerScreen extends StatefulWidget {
  final String? initialCategoryId;
  final int initialTabIndex;

  const AdminLevelQuestionManagerScreen({
    super.key,
    this.initialCategoryId,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminLevelQuestionManagerScreen> createState() =>
      _AdminLevelQuestionManagerScreenState();
}

class _AdminLevelQuestionManagerScreenState
    extends State<AdminLevelQuestionManagerScreen> {
  bool _isLoading = true;
  List<DynamicQuizCategoryData> _categories = const [];
  String _selectedCatId = '';

  @override
  void initState() {
    super.initState();
    _selectedCatId = widget.initialCategoryId ?? '';
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final res = await AdminService().listQuizContent(limit: 1);
      if (!mounted) return;
      final cats = res.categories;
      var nextCat = _selectedCatId;
      if (nextCat.isEmpty || !cats.any((c) => c.id == nextCat)) {
        nextCat = cats.isNotEmpty ? cats.first.id : '';
      }
      setState(() {
        _categories = cats;
        _selectedCatId = nextCat;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAdminFeedback(context, 'تعذر تحميل الأقسام: $e', isError: true);
    }
  }

  void _openBulkPackPublisher() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminBulkPackManagerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return AdminScaffoldShell(
      title: 'إدارة المستويات والأسئلة',
      subtitle: 'حالة قريباً ⏳ • التحكم بالمراحل • المتصفح الجماعي',
      isLoading: _isLoading,
      onRefresh: _loadCategories,
      body: DefaultTabController(
        length: 2,
        initialIndex: widget.initialTabIndex.clamp(0, 1),
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
                  Tab(text: 'المستويات وقريباً ⏳'),
                  Tab(text: 'متصفح الأسئلة'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : TabBarView(
                      children: [
                        CmsLevelManagerTab(
                          categories: _categories,
                          selectedCategoryId: _selectedCatId,
                          onCategoryChanged: (id) =>
                              setState(() => _selectedCatId = id),
                          onMutated: _loadCategories,
                          onJumpToPublishPack: _openBulkPackPublisher,
                        ),
                        CmsQuestionBrowserTab(
                          categories: _categories,
                          selectedCategoryId: _selectedCatId,
                          onCategoryChanged: (id) =>
                              setState(() => _selectedCatId = id),
                          onMutated: _loadCategories,
                          onJumpToPublishPack: _openBulkPackPublisher,
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
