import 'package:flutter/material.dart';

import '../../../core/app_routes.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import '../../widgets/home_dynamic_event_banner.dart';
import '../dynamic_event_detail_screen.dart';
import 'widgets/admin_ui_kit.dart';

/// In-App Admin Screen for creating, editing, scheduling, toggling, and deleting
/// cloud dynamic events displayed live in `HomeDynamicEventBanner`.
class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _badgeCtrl = TextEditingController(text: 'موسم نشط الآن');
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _ctaLabelCtrl = TextEditingController(text: 'اكتشف الآن');
  final _actionTargetCtrl = TextEditingController();
  final _colorHexCtrl = TextEditingController(text: '#D4AF37');
  final _priorityCtrl = TextEditingController(text: '100');

  String? _editingEventId;
  DynamicEventActionType _actionType = DynamicEventActionType.openEventScreen;
  String _iconName = 'auto_awesome';
  bool _isActive = true;
  DateTime? _startsAt;
  DateTime? _endsAt;

  bool _isLoadingList = true;
  bool _isSaving = false;
  List<AppDynamicEvent> _events = [];

  static const List<String> _colorPresets = [
    '#D4AF37',
    '#10B981',
    '#E11D48',
    '#3B82F6',
    '#8B5CF6',
  ];

  static const List<String> _iconPresets = [
    'auto_awesome',
    'mosque',
    'stars',
    'celebration',
    'military_tech',
    'emoji_events',
    'campaign',
    'bolt',
    'castle',
    'menu_book',
    'shield',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _badgeCtrl.dispose();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _bodyCtrl.dispose();
    _ctaLabelCtrl.dispose();
    _actionTargetCtrl.dispose();
    _colorHexCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await AdminService().listDynamicEvents();
      if (mounted) setState(() => _events = list);
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'تعذر تحميل قائمة الأحداث: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  void _populateForEdit(AppDynamicEvent ev) {
    SoundService().playClick();
    setState(() {
      _editingEventId = ev.id;
      _badgeCtrl.text = ev.badgeText;
      _titleCtrl.text = ev.title;
      _subtitleCtrl.text = ev.subtitle;
      _bodyCtrl.text = ev.body;
      _ctaLabelCtrl.text = ev.ctaLabel;
      _actionTargetCtrl.text = ev.actionTarget;
      _colorHexCtrl.text = ev.themeColorHex;
      _priorityCtrl.text = ev.priority.toString();
      _actionType = ev.actionType;
      _iconName = ev.iconName;
      _isActive = ev.isActive;
      _startsAt = ev.startsAt;
      _endsAt = ev.endsAt;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _resetForm() {
    setState(() {
      _editingEventId = null;
      _badgeCtrl.text = 'موسم نشط الآن';
      _titleCtrl.clear();
      _subtitleCtrl.clear();
      _bodyCtrl.clear();
      _ctaLabelCtrl.text = 'اكتشف الآن';
      _actionTargetCtrl.clear();
      _colorHexCtrl.text = '#D4AF37';
      _priorityCtrl.text = '100';
      _actionType = DynamicEventActionType.openEventScreen;
      _iconName = 'auto_awesome';
      _isActive = true;
      _startsAt = null;
      _endsAt = null;
    });
  }

  AppDynamicEvent _buildPreviewEvent() {
    return AppDynamicEvent(
      id: _editingEventId ?? 'preview',
      badgeText: _badgeCtrl.text.trim().isEmpty
          ? 'حدث نشط'
          : _badgeCtrl.text.trim(),
      title: _titleCtrl.text.trim().isEmpty
          ? 'معاينة عنوان الحدث الديناميكي'
          : _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim().isEmpty
          ? 'سيظهر هذا الشريط للمستخدمين على الشاشة الرئيسية'
          : _subtitleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      ctaLabel: _ctaLabelCtrl.text.trim().isEmpty
          ? 'اكتشف الآن'
          : _ctaLabelCtrl.text.trim(),
      actionType: _actionType,
      actionTarget: _actionTargetCtrl.text.trim(),
      themeColorHex: _colorHexCtrl.text.trim(),
      iconName: _iconName,
      priority: int.tryParse(_priorityCtrl.text.trim()) ?? 100,
      isActive: true,
    );
  }

  Future<void> _saveEvent() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      showAdminFeedback(
        context,
        'يجب أن يكون وقت نهاية الحدث بعد وقت بدايته.',
        isError: true,
      );
      return;
    }

    SoundService().playClick();
    setState(() => _isSaving = true);
    try {
      final saved = await AdminService().upsertDynamicEvent(
        id: _editingEventId,
        badgeText: _badgeCtrl.text.trim().isEmpty
            ? 'حدث نشط'
            : _badgeCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        ctaLabel: _ctaLabelCtrl.text.trim().isEmpty
            ? 'اكتشف الآن'
            : _ctaLabelCtrl.text.trim(),
        actionType: _actionType,
        actionTarget: _actionTargetCtrl.text.trim(),
        themeColorHex: _colorHexCtrl.text.trim().isEmpty
            ? '#D4AF37'
            : _colorHexCtrl.text.trim(),
        iconName: _iconName,
        priority: int.tryParse(_priorityCtrl.text.trim()) ?? 100,
        isActive: _isActive,
        startsAt: _startsAt,
        endsAt: _endsAt,
      );

      if (!mounted) return;
      if (saved != null) {
        final wasEditing = _editingEventId != null;
        _resetForm();
        await _loadEvents();
        if (!mounted) return;
        showAdminFeedback(
          context,
          wasEditing ? 'تم تحديث الحدث بنجاح ✅' : 'تم نشر الحدث الجديد 🎉',
        );
      } else {
        showAdminFeedback(
          context,
          'تعذر حفظ الحدث؛ تحقق من صلاحيات المشرف.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'فشل حفظ الحدث: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleEvent(AppDynamicEvent ev, bool nextActive) async {
    SoundService().playClick();
    final updated = await AdminService().toggleDynamicEvent(ev.id, nextActive);
    if (!mounted) return;
    if (updated != null) {
      setState(() {
        _events = _events
            .map((item) => item.id == ev.id ? updated : item)
            .toList();
      });
      showAdminFeedback(
        context,
        nextActive ? 'تم تفعيل الحدث' : 'تم إيقاف الحدث مؤقتاً',
      );
    } else {
      showAdminFeedback(context, 'تعذر تحديث حالة الحدث', isError: true);
    }
  }

  Future<void> _confirmAndDeleteEvent(AppDynamicEvent ev) async {
    SoundService().playClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppCustomTheme.of(ctx).surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'حذف الحدث نهائياً؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'سيتم حذف «${ev.title}» من قاعدة البيانات.',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'حذف',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final deleted = await AdminService().deleteDynamicEvent(ev.id);
    if (!mounted) return;
    if (deleted) {
      setState(() {
        _events.removeWhere((item) => item.id == ev.id);
        if (_editingEventId == ev.id) _resetForm();
      });
      showAdminFeedback(context, 'تم حذف الحدث بنجاح');
    } else {
      showAdminFeedback(context, 'تعذر حذف الحدث', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return AdminScaffoldShell(
      title: 'إدارة الأحداث والمواسم',
      subtitle: 'معاينة حيّة وجدولة زمنية عبر السحابة',
      isLoading: _isLoadingList,
      onRefresh: _loadEvents,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSectionCard(
                title: 'معاينة فورية لشريط الشاشة الرئيسية',
                icon: Icons.visibility_rounded,
                child: HomeDynamicEventBanner(
                  eventOverride: _buildPreviewEvent(),
                  flagsOverride: const AppFeatureFlags(showEventBanner: true),
                ),
              ),
              const SizedBox(height: 16),
              AdminSectionCard(
                title: _editingEventId == null
                    ? 'إنشاء حدث ديناميكي جديد'
                    : 'تعديل الحدث المحدد',
                icon: Icons.auto_awesome_rounded,
                trailing: _editingEventId == null
                    ? null
                    : TextButton(
                        onPressed: _resetForm,
                        child: const Text(
                          'إلغاء التعديل',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AdminTextField(
                            controller: _badgeCtrl,
                            label: 'نص الشارة',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AdminTextField(
                            controller: _priorityCtrl,
                            label: 'الأولوية',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _titleCtrl,
                      label: 'عنوان الحدث',
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _subtitleCtrl,
                      label: 'العنوان الفرعي (اختياري)',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _bodyCtrl,
                      label: 'النص التفصيلي في صفحة الحدث',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'نوع الإجراء عند الضغط',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildActionTypeChip(
                          DynamicEventActionType.openEventScreen,
                          'فتح صفحة الحدث',
                        ),
                        _buildActionTypeChip(
                          DynamicEventActionType.navigateRoute,
                          'مسار داخلي',
                        ),
                        _buildActionTypeChip(
                          DynamicEventActionType.openUrl,
                          'رابط خارجي',
                        ),
                        _buildActionTypeChip(
                          DynamicEventActionType.none,
                          'عرض فقط',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AdminTextField(
                            controller: _ctaLabelCtrl,
                            label: 'نص الزر',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_actionType != DynamicEventActionType.none) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: AdminTextField(
                              controller: _actionTargetCtrl,
                              label: 'الهدف (مسار أو URL)',
                              hint: _actionType == DynamicEventActionType.openUrl
                                  ? 'https://example.com'
                                  : AppRoutes.challenge,
                              validator: (v) {
                                final raw = v?.trim() ?? '';
                                if ((_actionType ==
                                            DynamicEventActionType
                                                .navigateRoute ||
                                        _actionType ==
                                            DynamicEventActionType.openUrl) &&
                                    raw.isEmpty) {
                                  return 'أدخل المسار أو الرابط';
                                }
                                if (_actionType ==
                                        DynamicEventActionType.openUrl &&
                                    raw.isNotEmpty &&
                                    !raw.toLowerCase().startsWith('http://') &&
                                    !raw.toLowerCase().startsWith('https://')) {
                                  return 'يجب أن يبدأ بـ https://';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _colorHexCtrl,
                      label: 'اللون السداسي (Hex)',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _colorPresets.map((hex) {
                        final c = AppControlVisuals.parseHexColor(
                          hex,
                          customTheme.sovereignAccent,
                        );
                        final selected =
                            _colorHexCtrl.text.trim().toUpperCase() == hex;
                        return GestureDetector(
                          onTap: () => setState(() => _colorHexCtrl.text = hex),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? Colors.white : Colors.white24,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'أيقونة الحدث',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconPresets.map((iconKey) {
                        final selected = _iconName == iconKey;
                        return ChoiceChip(
                          label: Icon(
                            AppControlVisuals.iconForName(iconKey),
                            size: 18,
                            color: selected
                                ? customTheme.sovereignAccent
                                : Colors.white70,
                          ),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _iconName = iconKey),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    _buildSchedulePickerRow(
                      label: 'يبدأ في:',
                      value: _startsAt,
                      onPick: () async {
                        final dt = await pickAdminDateTime(
                          context,
                          initial: _startsAt,
                        );
                        if (dt != null && mounted) {
                          setState(() => _startsAt = dt);
                        }
                      },
                      onClear: () => setState(() => _startsAt = null),
                    ),
                    const SizedBox(height: 8),
                    _buildSchedulePickerRow(
                      label: 'ينتهي في:',
                      value: _endsAt,
                      onPick: () async {
                        final dt = await pickAdminDateTime(
                          context,
                          initial: _endsAt,
                        );
                        if (dt != null && mounted) {
                          setState(() => _endsAt = dt);
                        }
                      },
                      onClear: () => setState(() => _endsAt = null),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeColor: customTheme.sovereignAccent,
                      title: const Text(
                        'تفعيل الحدث (Active)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 10),
                    AdminPrimaryButton(
                      key: const Key('admin_save_event_btn'),
                      label: _editingEventId == null
                          ? 'نشر الحدث الآن 🎉'
                          : 'حفظ تعديلات الحدث ✅',
                      icon: Icons.event_available_rounded,
                      isLoading: _isSaving,
                      onPressed: _saveEvent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdminSectionCard(
                title: 'الأحداث المسجّلة (${_events.length})',
                icon: Icons.celebration_rounded,
                child: _isLoadingList
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _events.isEmpty
                        ? Text(
                            'لا توجد أحداث ديناميكية حالياً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          )
                        : Column(
                            children: _events.map(_buildEventRow).toList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTypeChip(DynamicEventActionType type, String label) {
    final selected = _actionType == type;
    return ChoiceChip(
      key: Key('event_action_${type.wireName}'),
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
      ),
      selected: selected,
      onSelected: (_) => setState(() => _actionType = type),
    );
  }

  Widget _buildSchedulePickerRow({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: onPick,
            icon: const Icon(Icons.schedule_rounded, size: 17),
            label: Text(
              '$label ${formatAdminDateTime(value)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
      ],
    );
  }

  Widget _buildEventRow(AppDynamicEvent ev) {
    final accent = AppControlVisuals.parseHexColor(
      ev.themeColorHex,
      AppCustomTheme.of(context).sovereignAccent,
    );
    final isLive = ev.isCurrentlyActiveAt(DateTime.now().toUtc());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: ev.isActive ? 0.52 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppControlVisuals.iconForName(ev.iconName), color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${isLive ? 'مباشر الآن 🟢' : (ev.isActive ? 'مجدول ⏳' : 'متوقف ⏸️')} • أولوية ${ev.priority}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: Key('toggle_event_${ev.id}'),
                value: ev.isActive,
                activeColor: accent,
                onChanged: (v) => _toggleEvent(ev, v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: Key('edit_event_${ev.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: () => _populateForEdit(ev),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text(
                  'تعديل',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                key: Key('delete_event_${ev.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: () => _confirmAndDeleteEvent(ev),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text(
                  'حذف',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
