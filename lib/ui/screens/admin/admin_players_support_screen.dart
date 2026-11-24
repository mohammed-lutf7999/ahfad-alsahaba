import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin/bulk_question_json_validator.dart';
import '../../../data/services/admin_service.dart';
import 'players/player_compensation_card.dart';
import 'players/player_dossier_card.dart';
import 'players/player_permissions_card.dart';
import 'players/player_search_panel.dart';
import 'widgets/admin_ui_kit.dart';

/// In-app Player Inspector & Capped Compensation Suite.
class AdminPlayersSupportScreen extends StatefulWidget {
  const AdminPlayersSupportScreen({super.key});

  @override
  State<AdminPlayersSupportScreen> createState() =>
      _AdminPlayersSupportScreenState();
}

class _AdminPlayersSupportScreenState extends State<AdminPlayersSupportScreen> {
  final _searchCtrl = TextEditingController();
  final _coinsCtrl = TextEditingController(text: '0');
  final _gemsCtrl = TextEditingController(text: '0');
  final _xpCtrl = TextEditingController(text: '0');
  final _reasonCtrl = TextEditingController();
  final _banReasonCtrl = TextEditingController();
  final _permNotesCtrl = TextEditingController();
  final _compFormKey = GlobalKey<FormState>();

  bool _isSearching = true;
  bool _isLoadingDetail = false;
  bool _isCompensating = false;
  bool _isSavingPerms = false;
  bool _isBanned = false;
  int? _banHours = 24;
  bool _canUseOnline = true;
  bool _canUseDiwan = true;
  bool _canUseGuilds = true;
  bool? _canHostLiveArenas;
  List<AdminPlayerSearchResult> _players = const [];
  AdminPlayerDetail? _detail;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _coinsCtrl.dispose();
    _gemsCtrl.dispose();
    _xpCtrl.dispose();
    _reasonCtrl.dispose();
    _banReasonCtrl.dispose();
    _permNotesCtrl.dispose();
    super.dispose();
  }

  void _hydratePermissionFields(AdminPlayerDetail detail, {bool resetBanHours = false}) {
    _isBanned = detail.permissions.isBanned;
    _banReasonCtrl.text = detail.permissions.banReason;
    _permNotesCtrl.text = detail.permissions.notes;
    _canUseOnline = detail.permissions.canUseOnline;
    _canUseDiwan = detail.permissions.canUseDiwan;
    _canUseGuilds = detail.permissions.canUseGuilds;
    _canHostLiveArenas = detail.permissions.canHostLiveArenas;
    if (!resetBanHours) return;
    if (detail.permissions.bannedUntil != null) {
      final diff = detail.permissions.bannedUntil!
          .difference(DateTime.now().toUtc())
          .inHours;
      if (diff <= 24) {
        _banHours = 24;
      } else if (diff <= 168) {
        _banHours = 168;
      } else if (diff <= 720) {
        _banHours = 720;
      } else {
        _banHours = null;
      }
    } else {
      _banHours = _isBanned ? null : 24;
    }
  }

  Future<void> _runSearch() async {
    if (mounted) setState(() => _isSearching = true);
    try {
      final rows = await AdminService().searchUsers(
        query: _searchCtrl.text.trim(),
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _players = rows;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      showAdminFeedback(context, 'فشل البحث عن اللاعبين: $e', isError: true);
    }
  }

  Future<void> _openDossier(AdminPlayerSearchResult player) async {
    if (!player.isTargetable) {
      showAdminFeedback(
        context,
        'هذا السجل لا يملك معرّف حساب أو كود ضيف صالحاً للفحص.',
        isError: true,
      );
      return;
    }
    if (mounted) setState(() => _isLoadingDetail = true);
    try {
      final detail = await AdminService().getPlayerDetail(
        userId: player.userId,
        playerCode: player.playerCode,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoadingDetail = false;
        if (detail != null) {
          _hydratePermissionFields(detail, resetBanHours: true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDetail = false);
      showAdminFeedback(context, 'تعذر تحميل ملف اللاعب: $e', isError: true);
    }
  }

  Future<void> _savePlayerPermissions() async {
    final detail = _detail;
    if (detail == null || !detail.canManagePermissions) {
      showAdminFeedback(
        context,
        'لا يمكن تعديل صلاحيات حساب غير مسجل سحابياً.',
        isError: true,
      );
      return;
    }
    setState(() => _isSavingPerms = true);
    try {
      final res = await AdminService().upsertPlayerPermissions(
        userId: detail.userId!,
        isBanned: _isBanned,
        banHours: _isBanned ? _banHours : null,
        banReason: _banReasonCtrl.text.trim(),
        canUseOnline: _canUseOnline,
        canUseDiwan: _canUseDiwan,
        canUseGuilds: _canUseGuilds,
        canHostLiveArenas: _canHostLiveArenas,
        notes: _permNotesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res != null) {
        showAdminFeedback(context, 'تم حفظ صلاحيات اللاعب بنجاح ✅');
        final updated = await AdminService().getPlayerDetail(
          userId: detail.userId,
          playerCode: detail.playerCode,
        );
        if (mounted && updated != null) {
          setState(() {
            _detail = updated;
            _hydratePermissionFields(updated);
          });
        }
      } else {
        showAdminFeedback(context, 'تعذر حفظ الصلاحيات', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'فشل حفظ الصلاحيات: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSavingPerms = false);
    }
  }

  Future<void> _quickUnmutePlayer() async {
    final detail = _detail;
    if (detail == null || detail.userId == null) return;
    try {
      final res = await AdminService().moderateDiwan(
        action: 'unmute_user',
        targetUserId: detail.userId,
        reason: 'فك كتم فوري من ملف الدعم',
      );
      if (!mounted) return;
      if (res != null) {
        showAdminFeedback(context, 'تم فك كتم اللاعب بنجاح 🕊️');
        final updated = await AdminService().getPlayerDetail(
          userId: detail.userId,
          playerCode: detail.playerCode,
        );
        if (mounted && updated != null) {
          setState(() => _detail = updated);
        }
      }
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'فشل فك الكتم: $e', isError: true);
      }
    }
  }

  Future<void> _submitCompensation() async {
    final detail = _detail;
    if (detail == null || !detail.canReceiveCompensation) {
      showAdminFeedback(
        context,
        'يتطلب التعويض لاعباً مسجّلاً بحساب سحابي (user_progress).',
        isError: true,
      );
      return;
    }
    if (!(_compFormKey.currentState?.validate() ?? false)) return;

    final coins = int.tryParse(_coinsCtrl.text.trim()) ?? 0;
    final gems = int.tryParse(_gemsCtrl.text.trim()) ?? 0;
    final xp = int.tryParse(_xpCtrl.text.trim()) ?? 0;
    final reason = _reasonCtrl.text.trim();

    if (coins == 0 && gems == 0 && xp == 0) {
      showAdminFeedback(
        context,
        'أدخل قيمة موجبة واحدة على الأقل للتعويض.',
        isError: true,
      );
      return;
    }

    final confirmed = await showConfirmCompensationDialog(
      context,
      playerName: detail.displayName,
      coins: coins,
      gems: gems,
      xp: xp,
      reason: reason,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isCompensating = true);
    try {
      await AdminService().grantPlayerCompensation(
        userId: detail.userId!,
        coinsDelta: coins,
        gemsDelta: gems,
        xpDelta: xp,
        reason: reason,
      );
      if (!mounted) return;
      _coinsCtrl.text = '0';
      _gemsCtrl.text = '0';
      _xpCtrl.text = '0';
      _reasonCtrl.clear();
      showAdminFeedback(context, 'تم منح التعويض وتوثيقه في سجل التدقيق ✅');
      final refreshed = await AdminService().getPlayerDetail(
        userId: detail.userId,
        playerCode: detail.playerCode,
      );
      if (!mounted) return;
      setState(() {
        _detail = refreshed ?? _detail;
        _isCompensating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCompensating = false);
      showAdminFeedback(context, 'تعذر منح التعويض: $e', isError: true);
    }
  }

  Future<void> _exportPlayersCsv() async {
    if (_players.isEmpty) {
      showAdminFeedback(context, 'لا يوجد لاعبون لتصديرهم حالياً.', isError: true);
      return;
    }
    try {
      final csv = BulkQuestionJsonValidator.buildPlayersCsv(_players);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}ahfad_players_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          text: 'تصدير بيانات اللاعبين — معركة أحفاد الصحابة (${_players.length} سجل)',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر تصدير ملف CSV: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    final detail = _detail;
    return AdminScaffoldShell(
      title: 'دعم اللاعبين والتعويضات',
      subtitle: 'فحص الحسابات، المقتنيات، والمنح بسقوف رقابية',
      isLoading: _isSearching || _isLoadingDetail,
      onRefresh: _runSearch,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          PlayerSearchPanel(
            searchController: _searchCtrl,
            isSearching: _isSearching,
            players: _players,
            selectedDetail: detail,
            onSearch: _runSearch,
            onExportCsv: _exportPlayersCsv,
            onSelectPlayer: _openDossier,
          ),
          if (_isLoadingDetail) ...[
            const SizedBox(height: 16),
            Center(child: CircularProgressIndicator(color: accent)),
          ] else if (detail != null) ...[
            const SizedBox(height: 16),
            PlayerDossierCard(detail: detail),
            const SizedBox(height: 16),
            PlayerCompensationCard(
              detail: detail,
              formKey: _compFormKey,
              coinsController: _coinsCtrl,
              gemsController: _gemsCtrl,
              xpController: _xpCtrl,
              reasonController: _reasonCtrl,
              isCompensating: _isCompensating,
              onSubmit: _submitCompensation,
            ),
            const SizedBox(height: 16),
            PlayerPermissionsCard(
              detail: detail,
              isBanned: _isBanned,
              banHours: _banHours,
              banReasonController: _banReasonCtrl,
              permNotesController: _permNotesCtrl,
              canUseOnline: _canUseOnline,
              canUseDiwan: _canUseDiwan,
              canUseGuilds: _canUseGuilds,
              canHostLiveArenas: _canHostLiveArenas,
              isSaving: _isSavingPerms,
              onBanChanged: (v) => setState(() => _isBanned = v),
              onBanHoursChanged: (val) => setState(() => _banHours = val),
              onOnlineChanged: (v) => setState(() => _canUseOnline = v),
              onDiwanChanged: (v) => setState(() => _canUseDiwan = v),
              onGuildsChanged: (v) => setState(() => _canUseGuilds = v),
              onHostLiveArenasChanged: (val) =>
                  setState(() => _canHostLiveArenas = val),
              onQuickUnmute: _quickUnmutePlayer,
              onSave: _savePlayerPermissions,
            ),
          ],
        ],
      ),
    );
  }
}
