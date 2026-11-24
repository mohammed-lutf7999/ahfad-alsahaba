import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/models/player_profile_model.dart';
import '../../../data/services/admin_service.dart';
import 'announcements/announcement_composer_card.dart';
import 'announcements/announcement_list_item.dart';
import 'widgets/admin_ui_kit.dart';

/// In-App Admin Screen for publishing global or targeted (`Google` & `SAH-XXXX` guests)
/// announcements across 4 semantic tiers (`normal`, `mandatory`, `admin`, `motivational`).
class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _ctaLabelCtrl = TextEditingController();
  final _ctaRouteCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();
  final _maxVersionCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _manualPlayerCodeCtrl = TextEditingController();

  AnnouncementType _messageType = AnnouncementType.normal;
  String _targetScope = 'all';
  bool _isDismissible = true;
  DateTime? _expiresAt;

  Timer? _searchDebounce;
  bool _isSearching = false;
  List<AdminPlayerSearchResult> _searchResults = [];
  AdminPlayerSearchResult? _selectedPlayer;

  bool _isPublishing = false;
  bool _isLoadingList = true;
  List<AppAnnouncement> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _ctaLabelCtrl.dispose();
    _ctaRouteCtrl.dispose();
    _minVersionCtrl.dispose();
    _maxVersionCtrl.dispose();
    _searchCtrl.dispose();
    _manualPlayerCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await AdminService().listAnnouncements(limit: 50);
      if (mounted) setState(() => _announcements = list);
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'تعذر تحميل سجل الرسائل: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  void _onSearchQueryChanged(String raw) {
    _searchDebounce?.cancel();
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _executePlayerSearch(trimmed);
    });
  }

  Future<void> _executePlayerSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final results =
          await AdminService().searchUsers(query: query, limit: 20);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        showAdminFeedback(context, 'فشل البحث عن اللاعبين: $e', isError: true);
      }
    }
  }

  Future<void> _submitAnnouncement() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    int? minVer;
    int? maxVer;
    if (_minVersionCtrl.text.trim().isNotEmpty) {
      minVer = int.tryParse(_minVersionCtrl.text.trim());
      if (minVer == null || minVer < 1) {
        showAdminFeedback(context, 'حد الإصدار الأدنى غير صالح', isError: true);
        return;
      }
    }
    if (_maxVersionCtrl.text.trim().isNotEmpty) {
      maxVer = int.tryParse(_maxVersionCtrl.text.trim());
      if (maxVer == null || maxVer < 1) {
        showAdminFeedback(context, 'حد الإصدار الأقصى غير صالح', isError: true);
        return;
      }
    }
    if (minVer != null && maxVer != null && maxVer < minVer) {
      showAdminFeedback(
        context,
        'يجب أن يكون الحد الأقصى للإصدار >= الحد الأدنى.',
        isError: true,
      );
      return;
    }

    String? targetUserId;
    String? targetPlayerCode;
    if (_targetScope == 'single_user') {
      final manualCode = _manualPlayerCodeCtrl.text.trim().toUpperCase();
      if (_selectedPlayer != null) {
        targetUserId = _selectedPlayer!.userId;
        targetPlayerCode = PlayerProfile.isValidPlayerCode(
          _selectedPlayer!.playerCode,
        )
            ? _selectedPlayer!.playerCode!.trim().toUpperCase()
            : null;
      } else if (PlayerProfile.isValidPlayerCode(manualCode)) {
        targetPlayerCode = manualCode;
      }

      if ((targetUserId == null || targetUserId.isEmpty) &&
          targetPlayerCode == null) {
        showAdminFeedback(
          context,
          'اختر لاعباً من نتائج البحث أو أدخل كود لاعب صحيح (SAH-XXXX).',
          isError: true,
        );
        return;
      }
    }

    final effectiveDismissible =
        _messageType == AnnouncementType.mandatory ? false : _isDismissible;

    SoundService().playClick();
    setState(() => _isPublishing = true);
    try {
      final created = await AdminService().createAnnouncement(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        messageType: _messageType,
        targetScope: _targetScope,
        targetUserId: targetUserId,
        targetPlayerCode: targetPlayerCode,
        ctaLabel: _ctaLabelCtrl.text.trim().isEmpty
            ? null
            : _ctaLabelCtrl.text.trim(),
        ctaRoute: _ctaRouteCtrl.text.trim().isEmpty
            ? null
            : _ctaRouteCtrl.text.trim(),
        isDismissible: effectiveDismissible,
        expiresAt: _expiresAt,
        minVersionCode: minVer,
        maxVersionCode: maxVer,
      );

      if (!mounted) return;
      if (created != null) {
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _ctaLabelCtrl.clear();
        _ctaRouteCtrl.clear();
        _minVersionCtrl.clear();
        _maxVersionCtrl.clear();
        _searchCtrl.clear();
        _manualPlayerCodeCtrl.clear();
        setState(() {
          _selectedPlayer = null;
          _searchResults = [];
          _expiresAt = null;
          _announcements = [created, ..._announcements];
        });
        showAdminFeedback(context, 'تم إرسال الرسالة بنجاح 🚀');
      } else {
        showAdminFeedback(
          context,
          'تعذر إنشاء الرسالة؛ تحقق من صلاحيات المشرف.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'فشل إرسال الرسالة: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _toggleAnnouncement(AppAnnouncement ann, bool nextActive) async {
    SoundService().playClick();
    final ok = await AdminService().setAnnouncementActive(ann.id, nextActive);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _announcements = _announcements
            .map(
              (item) => item.id == ann.id
                  ? item.copyWith(isActive: nextActive)
                  : item,
            )
            .toList();
      });
      showAdminFeedback(
        context,
        nextActive ? 'تم تفعيل الرسالة' : 'تم إيقاف الرسالة',
      );
    } else {
      showAdminFeedback(context, 'تعذر تحديث حالة الرسالة', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffoldShell(
      title: 'الرسائل الموجّهة والبحث',
      subtitle: 'بث جماعي أو استهداف مباشر (Google & SAH-XXXX)',
      isLoading: _isLoadingList,
      onRefresh: _loadAnnouncements,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnnouncementComposerCard(
                titleCtrl: _titleCtrl,
                bodyCtrl: _bodyCtrl,
                ctaLabelCtrl: _ctaLabelCtrl,
                ctaRouteCtrl: _ctaRouteCtrl,
                minVersionCtrl: _minVersionCtrl,
                maxVersionCtrl: _maxVersionCtrl,
                searchCtrl: _searchCtrl,
                manualPlayerCodeCtrl: _manualPlayerCodeCtrl,
                messageType: _messageType,
                targetScope: _targetScope,
                isDismissible: _isDismissible,
                expiresAt: _expiresAt,
                isSearching: _isSearching,
                isPublishing: _isPublishing,
                searchResults: _searchResults,
                selectedPlayer: _selectedPlayer,
                onMessageTypeChanged: (type) {
                  setState(() {
                    _messageType = type;
                    if (type == AnnouncementType.mandatory) {
                      _isDismissible = false;
                    }
                  });
                },
                onTargetScopeChanged: (s) => setState(() => _targetScope = s),
                onDismissibleChanged: (d) => setState(() => _isDismissible = d),
                onPickExpiry: () async {
                  final picked = await pickAdminDateTime(
                    context,
                    initial: _expiresAt,
                  );
                  if (picked != null && mounted) {
                    setState(() => _expiresAt = picked);
                  }
                },
                onClearExpiry: () => setState(() => _expiresAt = null),
                onSearchChanged: _onSearchQueryChanged,
                onSearchSubmitted: () {
                  final q = _searchCtrl.text.trim();
                  if (q.isNotEmpty) _executePlayerSearch(q);
                },
                onManualCodeChanged: (val) {
                  if (_selectedPlayer != null && val.trim().isNotEmpty) {
                    setState(() => _selectedPlayer = null);
                  }
                },
                onSelectPlayer: (player) {
                  _manualPlayerCodeCtrl.clear();
                  setState(() => _selectedPlayer = player);
                },
                onClearSelectedPlayer: () =>
                    setState(() => _selectedPlayer = null),
                onSubmit: _submitAnnouncement,
              ),
              const SizedBox(height: 16),
              AdminSectionCard(
                title: 'سجل الرسائل المنشورة (${_announcements.length})',
                icon: Icons.mark_chat_read_rounded,
                child: _isLoadingList
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _announcements.isEmpty
                        ? Text(
                            'لا توجد رسائل منشورة حالياً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          )
                        : Column(
                            children: _announcements
                                .map(
                                  (ann) => AnnouncementListItem(
                                    announcement: ann,
                                    onToggleActive: (v) =>
                                        _toggleAnnouncement(ann, v),
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
