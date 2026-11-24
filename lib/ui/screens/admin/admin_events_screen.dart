import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import '../../widgets/home_dynamic_event_banner.dart';
import 'events/admin_event_form_card.dart';
import 'events/admin_event_list_item.dart';
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
    final confirmed = await showConfirmDeleteEventDialog(context, ev);
    if (!confirmed || !mounted) return;
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
              AdminEventFormCard(
                isEditing: _editingEventId != null,
                isSaving: _isSaving,
                badgeCtrl: _badgeCtrl,
                titleCtrl: _titleCtrl,
                subtitleCtrl: _subtitleCtrl,
                bodyCtrl: _bodyCtrl,
                ctaLabelCtrl: _ctaLabelCtrl,
                actionTargetCtrl: _actionTargetCtrl,
                colorHexCtrl: _colorHexCtrl,
                priorityCtrl: _priorityCtrl,
                actionType: _actionType,
                iconName: _iconName,
                isActive: _isActive,
                startsAt: _startsAt,
                endsAt: _endsAt,
                onResetForm: _resetForm,
                onPreviewFieldChanged: () => setState(() {}),
                onActionTypeChanged: (t) => setState(() => _actionType = t),
                onColorPresetSelected: (hex) =>
                    setState(() => _colorHexCtrl.text = hex),
                onIconSelected: (k) => setState(() => _iconName = k),
                onPickStart: () async {
                  final dt = await pickAdminDateTime(
                    context,
                    initial: _startsAt,
                  );
                  if (dt != null && mounted) setState(() => _startsAt = dt);
                },
                onClearStart: () => setState(() => _startsAt = null),
                onPickEnd: () async {
                  final dt = await pickAdminDateTime(context, initial: _endsAt);
                  if (dt != null && mounted) setState(() => _endsAt = dt);
                },
                onClearEnd: () => setState(() => _endsAt = null),
                onActiveChanged: (v) => setState(() => _isActive = v),
                onSave: _saveEvent,
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
                            children: _events
                                .map(
                                  (ev) => AdminEventListItem(
                                    event: ev,
                                    onToggleActive: (v) => _toggleEvent(ev, v),
                                    onEdit: () => _populateForEdit(ev),
                                    onDelete: () => _confirmAndDeleteEvent(ev),
                                  ),
                                )
                                .toList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
