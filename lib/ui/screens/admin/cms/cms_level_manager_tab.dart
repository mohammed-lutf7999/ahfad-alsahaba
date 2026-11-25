import 'package:flutter/material.dart';

import '../../../../data/models/cms_models.dart';
import '../../../../data/services/admin_service.dart';
import '../widgets/admin_ui_kit.dart';
import 'cms_level_grid_card.dart';

/// Tab 1 of [AdminLevelQuestionManagerScreen]:
/// Controls category availability (`open` / `coming_soon` / `hidden`),
/// level-range overrides (`from..to`), and 1-tap interactive level pills.
class CmsLevelManagerTab extends StatefulWidget {
  final List<DynamicQuizCategoryData> categories;
  final String selectedCategoryId;
  final ValueChanged<String> onCategoryChanged;
  final Future<void> Function() onMutated;
  final VoidCallback onJumpToPublishPack;

  const CmsLevelManagerTab({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onMutated,
    required this.onJumpToPublishPack,
  });

  @override
  State<CmsLevelManagerTab> createState() => _CmsLevelManagerTabState();
}

class _CmsLevelManagerTabState extends State<CmsLevelManagerTab> {
  final _catMsgCtrl = TextEditingController();
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController(text: '10');
  final _rangeMsgCtrl = TextEditingController();

  String _catStatus = 'open';
  String _rangeStatus = 'coming_soon';
  bool _isBusy = false;
  String? _hydratedFingerprint;

  DynamicQuizCategoryData? get _selectedCategory {
    if (widget.categories.isEmpty) return null;
    for (final c in widget.categories) {
      if (c.id == widget.selectedCategoryId) return c;
    }
    return widget.categories.first;
  }

  @override
  void initState() {
    super.initState();
    _hydrateFromCategory(force: true);
  }

  @override
  void didUpdateWidget(covariant CmsLevelManagerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId ||
        oldWidget.categories != widget.categories) {
      _hydrateFromCategory(
        force: oldWidget.selectedCategoryId != widget.selectedCategoryId,
      );
    }
  }

  void _hydrateFromCategory({bool force = false}) {
    final cat = _selectedCategory;
    if (cat == null) return;
    final fp =
        '${cat.id}|${cat.availabilityStatus}|${cat.comingSoonMessage}|${cat.totalLevels}';
    if (!force && _hydratedFingerprint == fp) return;
    _hydratedFingerprint = fp;
    _catStatus = cat.availabilityStatus;
    _catMsgCtrl.text = cat.comingSoonMessage;
    _toCtrl.text = '${cat.totalLevels}';
  }

  @override
  void dispose() {
    _catMsgCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _rangeMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCategoryAvailability() async {
    final cat = _selectedCategory;
    if (cat == null || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      final updated = await AdminService().upsertCategoryAvailability(
        categoryId: cat.id,
        availabilityStatus: _catStatus,
        comingSoonMessage: _catMsgCtrl.text.trim(),
      );
      if (!mounted) return;
      if (updated == null) {
        showAdminFeedback(
          context,
          'تعذر حفظ حالة القسم؛ تحقق من الاتصال وصلاحيات المشرف.',
          isError: true,
        );
        return;
      }
      showAdminFeedback(context, 'تم تحديث حالة قسم «${cat.name}» بنجاح ✅');
      await widget.onMutated();
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر تحديث حالة القسم: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _applyRangeOverride({
    required int fromLevel,
    required int toLevel,
    required String status,
    required String message,
  }) async {
    final cat = _selectedCategory;
    if (cat == null || _isBusy) return;
    if (fromLevel < 1 || toLevel < fromLevel || toLevel > 100) {
      showAdminFeedback(
        context,
        'أدخل نطاقاً صحيحاً بين 1 و 100 (من <= إلى)',
        isError: true,
      );
      return;
    }
    setState(() => _isBusy = true);
    try {
      final updated = await AdminService().bulkSetLevelOverrides(
        categoryId: cat.id,
        fromLevel: fromLevel,
        toLevel: toLevel,
        status: status,
        message: message,
      );
      if (!mounted) return;
      if (updated == null) {
        showAdminFeedback(
          context,
          'تعذر تحديث المستويات؛ تحقق من الاتصال وصلاحيات المشرف.',
          isError: true,
        );
        return;
      }
      showAdminFeedback(
        context,
        'تم تحديث المستويات $fromLevel..$toLevel ← ($status) ✅',
      );
      await widget.onMutated();
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر تحديث المستويات: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _selectedCategory;
    if (cat == null) {
      return const Center(
        child: Text(
          'لا توجد أقسام مسابقات متاحة.',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('lvl_cat_${cat.id}'),
          value: cat.id,
          isExpanded: true,
          dropdownColor: const Color(0xFF17202E),
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
          decoration: cmsAdminInputDecoration('اختر القسم المستهدف'),
          items: [
            for (final c in widget.categories)
              DropdownMenuItem(
                value: c.id,
                child: Text(
                  '${c.name} (${c.totalLevels} م)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) widget.onCategoryChanged(v);
          },
        ),
        if (cat.packNeedsRepublish) ...[
          const SizedBox(height: 10),
          CmsPackRepublishBanner(onPublishTap: widget.onJumpToPublishPack),
        ],
        const SizedBox(height: 12),
        AdminSectionCard(
          title: 'حالة توفر القسم بالكامل',
          icon: Icons.hourglass_top_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('lvl_cat_status_${cat.id}_$_catStatus'),
                value: _catStatus,
                isExpanded: true,
                dropdownColor: const Color(0xFF17202E),
                style:
                    const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: cmsAdminInputDecoration('حالة القسم'),
                items: const [
                  DropdownMenuItem(
                    value: 'open',
                    child: Text('🟢 مفتوح للعب', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'coming_soon',
                    child: Text(
                      '⏳ قريباً (Coming Soon)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'hidden',
                    child: Text(
                      '🚫 مخفي تماماً',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _catStatus = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _catMsgCtrl,
                maxLength: 180,
                style:
                    const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: cmsAdminInputDecoration(
                  'رسالة تشويقية (اختياري عند قريباً)',
                ),
              ),
              const SizedBox(height: 12),
              AdminPrimaryButton(
                label: 'حفظ حالة القسم',
                icon: Icons.save_rounded,
                isLoading: _isBusy,
                onPressed: _saveCategoryAvailability,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminSectionCard(
          title: 'تحديث نطاق مستويات (1..100)',
          icon: Icons.tune_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fromCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                      decoration: cmsAdminInputDecoration('من مستوى'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _toCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                      decoration: cmsAdminInputDecoration('إلى مستوى'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('lvl_range_status_$_rangeStatus'),
                value: _rangeStatus,
                isExpanded: true,
                dropdownColor: const Color(0xFF17202E),
                style:
                    const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: cmsAdminInputDecoration('الحالة المطلوبة'),
                items: const [
                  DropdownMenuItem(
                    value: 'open',
                    child: Text('🟢 مفتوح', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'coming_soon',
                    child: Text('⏳ قريباً', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'hidden',
                    child: Text('🚫 مخفي', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _rangeStatus = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _rangeMsgCtrl,
                maxLength: 160,
                style:
                    const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: cmsAdminInputDecoration(
                  'رسالة تشويقية للمستويات (اختياري)',
                ),
              ),
              const SizedBox(height: 12),
              AdminPrimaryButton(
                label: 'تطبيق على النطاق المحدد',
                icon: Icons.layers_rounded,
                isLoading: _isBusy,
                onPressed: () {
                  final fromLv = int.tryParse(_fromCtrl.text.trim()) ?? 0;
                  final toLv = int.tryParse(_toCtrl.text.trim()) ?? 0;
                  _applyRangeOverride(
                    fromLevel: fromLv,
                    toLevel: toLv,
                    status: _rangeStatus,
                    message: _rangeMsgCtrl.text.trim(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CmsLevelPillsGridCard(
          category: cat,
          isBusy: _isBusy,
          onCycleLevel: (lv, next) => _applyRangeOverride(
            fromLevel: lv,
            toLevel: lv,
            status: next,
            message: next == 'coming_soon' ? _rangeMsgCtrl.text.trim() : '',
          ),
        ),
      ],
    );
  }
}
