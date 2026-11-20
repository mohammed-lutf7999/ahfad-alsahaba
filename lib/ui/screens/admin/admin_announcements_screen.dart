import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_routes.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/models/player_profile_model.dart';
import '../../../data/services/admin_service.dart';
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
      if (mounted) {
        setState(() => _announcements = list);
      }
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
    final customTheme = AppCustomTheme.of(context);
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
              AdminSectionCard(
                title: 'إنشاء وإرسال رسالة جديدة',
                icon: Icons.campaign_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'نوع الرسالة',
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
                        _buildTypeChip(
                          AnnouncementType.normal,
                          'عادية',
                          customTheme.sovereignAccent,
                        ),
                        _buildTypeChip(
                          AnnouncementType.mandatory,
                          'إجبارية مقفلة',
                          Colors.redAccent,
                        ),
                        _buildTypeChip(
                          AnnouncementType.admin,
                          'إدارية',
                          const Color(0xFF38BDF8),
                        ),
                        _buildTypeChip(
                          AnnouncementType.motivational,
                          'تحفيزية',
                          const Color(0xFF10B981),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'نطاق الاستهداف',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('scope_all_chip'),
                            label: const Center(
                              child: Text(
                                'جميع اللاعبين',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                              ),
                            ),
                            selected: _targetScope == 'all',
                            selectedColor:
                                customTheme.sovereignAccent.withValues(alpha: 0.25),
                            onSelected: (_) => setState(() => _targetScope = 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            key: const Key('scope_single_user_chip'),
                            label: const Center(
                              child: Text(
                                'لاعب محدد 🎯',
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                              ),
                            ),
                            selected: _targetScope == 'single_user',
                            selectedColor:
                                customTheme.sovereignAccent.withValues(alpha: 0.25),
                            onSelected: (_) =>
                                setState(() => _targetScope = 'single_user'),
                          ),
                        ),
                      ],
                    ),
                    if (_targetScope == 'single_user') ...[
                      const SizedBox(height: 12),
                      _buildSingleUserTargetingBox(customTheme),
                    ],
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _titleCtrl,
                      label: 'عنوان الرسالة',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _bodyCtrl,
                      label: 'نص الرسالة',
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AdminTextField(
                            controller: _ctaLabelCtrl,
                            label: 'نص زر الإجراء (اختياري)',
                            hint: 'مثال: افتح المتجر',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AdminTextField(
                            controller: _ctaRouteCtrl,
                            label: 'المسار أو الرابط (اختياري)',
                            hint: AppRoutes.knightsStore,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickRouteChip('المتجر', AppRoutes.knightsStore),
                        _buildQuickRouteChip('التحدي', AppRoutes.challenge),
                        _buildQuickRouteChip('المجد', AppRoutes.gloryRoad),
                        _buildQuickRouteChip('المكتبة', AppRoutes.library),
                        _buildQuickRouteChip('البريد', AppRoutes.royalInbox),
                        _buildQuickRouteChip('الديوان', '/diwan'),
                        _buildQuickRouteChip('الكتائب', AppRoutes.guilds),
                        _buildQuickRouteChip('البطولة الحية', AppRoutes.liveArena),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AdminTextField(
                            controller: _minVersionCtrl,
                            label: 'من رقم بناء (اختياري)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AdminTextField(
                            controller: _maxVersionCtrl,
                            label: 'إلى رقم بناء (اختياري)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: customTheme.sovereignAccent,
                              side: BorderSide(
                                color: customTheme.sovereignAccent
                                    .withValues(alpha: 0.45),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () async {
                              final picked = await pickAdminDateTime(
                                context,
                                initial: _expiresAt,
                              );
                              if (picked != null && mounted) {
                                setState(() => _expiresAt = picked);
                              }
                            },
                            icon: const Icon(Icons.event_rounded, size: 18),
                            label: Text(
                              _expiresAt == null
                                  ? 'انتهاء الصلاحية: مفتوحة'
                                  : 'تنتهي: ${formatAdminDateTime(_expiresAt)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        if (_expiresAt != null) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => setState(() => _expiresAt = null),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                            tooltip: 'مسح التاريخ',
                          ),
                        ],
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.redAccent,
                      title: const Text(
                        'منع الإغلاق العادي (قفل التخطي)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _messageType == AnnouncementType.mandatory
                            ? 'مفعّل تلقائياً لأن النوع إجباري'
                            : 'يطلب من اللاعب ضغط زر الموافقة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                        ),
                      ),
                      value: _messageType == AnnouncementType.mandatory
                          ? true
                          : !_isDismissible,
                      onChanged: _messageType == AnnouncementType.mandatory
                          ? null
                          : (locked) => setState(() => _isDismissible = !locked),
                    ),
                    const SizedBox(height: 12),
                    AdminPrimaryButton(
                      key: const Key('admin_send_announcement_btn'),
                      label: 'إرسال ونشر الرسالة 🚀',
                      icon: Icons.send_rounded,
                      isLoading: _isPublishing,
                      onPressed: _submitAnnouncement,
                    ),
                  ],
                ),
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
                                .map(_buildAnnouncementItem)
                                .toList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(AnnouncementType type, String label, Color color) {
    final selected = _messageType == type;
    return ChoiceChip(
      key: Key('ann_type_${type.wireName}'),
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          color: selected ? Colors.white : Colors.white70,
        ),
      ),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.35),
      side: BorderSide(
        color: selected ? color : Colors.white.withValues(alpha: 0.2),
      ),
      onSelected: (_) {
        SoundService().playClick();
        setState(() {
          _messageType = type;
          if (type == AnnouncementType.mandatory) {
            _isDismissible = false;
          }
        });
      },
    );
  }

  Widget _buildQuickRouteChip(String label, String route) {
    return ActionChip(
      label: Text(
        '$label ($route)',
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
      ),
      onPressed: () {
        _ctaRouteCtrl.text = route;
        if (_ctaLabelCtrl.text.trim().isEmpty) {
          _ctaLabelCtrl.text = 'انتقل إلى $label';
        }
      },
    );
  }

  Widget _buildSingleUserTargetingBox(AppCustomTheme customTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: customTheme.sovereignAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminTextField(
            key: const Key('admin_user_search_field'),
            controller: _searchCtrl,
            label: 'ابحث بالاسم أو البريد أو كود الضيف (SAH-XXXX)',
            onChanged: _onSearchQueryChanged,
            suffixIcon: IconButton(
              icon: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              onPressed: () {
                final q = _searchCtrl.text.trim();
                if (q.isNotEmpty) _executePlayerSearch(q);
              },
            ),
          ),
          const SizedBox(height: 8),
          AdminTextField(
            controller: _manualPlayerCodeCtrl,
            label: 'أو أدخل كود اللاعب يدوياً (اختياري)',
            hint: 'SAH-XXXX',
            onChanged: (val) {
              if (_selectedPlayer != null && val.trim().isNotEmpty) {
                setState(() => _selectedPlayer = null);
              }
            },
          ),
          if (_selectedPlayer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'المستهدف: ${_selectedPlayer!.displayName}'
                      '${_selectedPlayer!.playerCode != null ? ' (${_selectedPlayer!.playerCode})' : ''}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                    onPressed: () => setState(() => _selectedPlayer = null),
                  ),
                ],
              ),
            ),
          ],
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._searchResults.map((player) {
              final isSelected = _selectedPlayer?.userId == player.userId &&
                  _selectedPlayer?.playerCode == player.playerCode;
              return ListTile(
                dense: true,
                enabled: player.isTargetable,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: isSelected
                    ? customTheme.sovereignAccent.withValues(alpha: 0.16)
                    : null,
                leading: Icon(
                  player.isGuest
                      ? Icons.person_outline_rounded
                      : Icons.verified_user_rounded,
                  color: player.isGuest
                      ? Colors.amberAccent
                      : const Color(0xFF38BDF8),
                ),
                title: Text(
                  player.displayName,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${player.isGuest ? 'ضيف 🎭' : (player.email ?? 'حساب Google')}'
                  '${player.playerCode != null ? ' • ${player.playerCode}' : ''}'
                  ' • 🏆 ${player.trophies}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
                trailing: player.isTargetable
                    ? Text(
                        isSelected ? 'مختار' : 'اختيار',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: customTheme.sovereignAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : const Text(
                        'بلا معرّف',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                onTap: player.isTargetable
                    ? () {
                        SoundService().playClick();
                        _manualPlayerCodeCtrl.clear();
                        setState(() => _selectedPlayer = player);
                      }
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildAnnouncementItem(AppAnnouncement ann) {
    final badgeColor = switch (ann.messageType) {
      AnnouncementType.mandatory => Colors.redAccent,
      AnnouncementType.admin => const Color(0xFF38BDF8),
      AnnouncementType.motivational => const Color(0xFF10B981),
      AnnouncementType.normal => AppCustomTheme.of(context).sovereignAccent,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeColor.withValues(alpha: ann.isActive ? 0.5 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ann.messageType.wireName,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ann.targetScope == 'single_user'
                      ? 'موجهة: ${ann.targetPlayerCode ?? ann.targetUserId ?? 'مستخدم'}'
                      : 'للجميع',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '👁️ ${ann.receiptCount}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 11.5,
                ),
              ),
              Switch.adaptive(
                key: Key('toggle_announcement_${ann.id}'),
                value: ann.isActive,
                activeColor: badgeColor,
                onChanged: (v) => _toggleAnnouncement(ann, v),
              ),
            ],
          ),
          Text(
            ann.title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ann.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          if (ann.minVersionCode != null ||
              ann.maxVersionCode != null ||
              ann.expiresAt != null ||
              (ann.ctaRoute != null && ann.ctaRoute!.isNotEmpty)) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (ann.minVersionCode != null || ann.maxVersionCode != null)
                  Text(
                    'البناء: ${ann.minVersionCode ?? 1}..${ann.maxVersionCode ?? '∞'}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 10.5,
                    ),
                  ),
                if (ann.expiresAt != null)
                  Text(
                    'ينتهي: ${formatAdminDateTime(ann.expiresAt)}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.amberAccent.withValues(alpha: 0.85),
                      fontSize: 10.5,
                    ),
                  ),
                if (ann.ctaRoute != null && ann.ctaRoute!.isNotEmpty)
                  Text(
                    'المسار: ${ann.ctaRoute}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: badgeColor.withValues(alpha: 0.9),
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
