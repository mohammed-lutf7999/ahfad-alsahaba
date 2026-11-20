import 'package:flutter/material.dart';

import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
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
          _isBanned = detail.permissions.isBanned;
          _banReasonCtrl.text = detail.permissions.banReason;
          _permNotesCtrl.text = detail.permissions.notes;
          _canUseOnline = detail.permissions.canUseOnline;
          _canUseDiwan = detail.permissions.canUseDiwan;
          _canUseGuilds = detail.permissions.canUseGuilds;
          _canHostLiveArenas = detail.permissions.canHostLiveArenas;
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
            _isBanned = updated.permissions.isBanned;
            _banReasonCtrl.text = updated.permissions.banReason;
            _permNotesCtrl.text = updated.permissions.notes;
            _canUseOnline = updated.permissions.canUseOnline;
            _canUseDiwan = updated.permissions.canUseDiwan;
            _canUseGuilds = updated.permissions.canUseGuilds;
            _canHostLiveArenas = updated.permissions.canHostLiveArenas;
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppCustomTheme.of(context).surfaceCard,
          title: const Text(
            'تأكيد منح التعويض',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
          content: Text(
            'اللاعب: ${detail.displayName}\n'
            'دنانير: $coins | ياقوت: $gems | خبرة: $xp\n'
            'السبب: $reason',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'تأكيد ومنح',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

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

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return AdminScaffoldShell(
      title: 'دعم اللاعبين والتعويضات',
      subtitle: 'فحص الحسابات، المقتنيات، والمنح بسقوف رقابية',
      isLoading: _isSearching || _isLoadingDetail,
      onRefresh: _runSearch,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          AdminSectionCard(
            title: 'البحث في الحسابات والضيوف',
            icon: Icons.person_search_rounded,
            child: Column(
              children: [
                AdminTextField(
                  controller: _searchCtrl,
                  label: 'الاسم، البريد، أو كود SAH-XXXX',
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _runSearch(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search_rounded, color: accent),
                    onPressed: _runSearch,
                  ),
                ),
                const SizedBox(height: 10),
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: accent),
                  )
                else if (_players.isEmpty)
                  const Text(
                    'لا توجد نتائج مطابقة.',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                  )
                else
                  for (final p in _players.take(12)) ...[
                    _PlayerRowTile(
                      player: p,
                      isSelected:
                          (_detail?.userId != null && _detail?.userId == p.userId) ||
                          (_detail?.playerCode != null &&
                              _detail?.playerCode == p.playerCode),
                      onTap: () => _openDossier(p),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
          if (_isLoadingDetail) ...[
            const SizedBox(height: 16),
            Center(child: CircularProgressIndicator(color: accent)),
          ] else if (_detail != null) ...[
            const SizedBox(height: 16),
            _buildDossierSection(_detail!),
          ],
        ],
      ),
    );
  }

  Widget _buildDossierSection(AdminPlayerDetail d) {
    final customTheme = AppCustomTheme.of(context);
    final email = (d.directory?['email'] ?? d.leaderboard?['email'])?.toString();
    final appVer = d.directory?['app_version']?.toString();
    final verCode = d.directory?['version_code']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionCard(
          title: 'ملف اللاعب: ${d.displayName}',
          icon: Icons.badge_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((d.playerCode != null && d.playerCode!.isNotEmpty) ||
                  (email != null && email.isNotEmpty) ||
                  appVer != null) ...[
                Text(
                  [
                    if (d.playerCode != null && d.playerCode!.isNotEmpty)
                      'الكود: ${d.playerCode}',
                    if (email != null && email.isNotEmpty) email,
                    if (appVer != null)
                      'النسخة: $appVer${verCode != null ? " (b$verCode)" : ""}',
                  ].join(' • '),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStatChip(label: 'المستوى', value: 'م${d.playerLevel}'),
                  _MiniStatChip(label: 'الكؤوس', value: '🏆 ${d.trophies}'),
                  _MiniStatChip(label: 'النقاط XP', value: '${d.totalScore}'),
                  _MiniStatChip(label: 'الدنانير', value: '🪙 ${d.coins}'),
                  _MiniStatChip(label: 'الياقوت', value: '💎 ${d.gems}'),
                  _MiniStatChip(label: 'السلسلة', value: '🔥 ${d.winStreak}'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'المقتنيات (${d.inventory.length}):',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: customTheme.sovereignAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (d.inventory.isEmpty)
                const Text(
                  'لا توجد عناصر متجر مملوكة.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white60),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in d.inventory)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item.title}${item.isVisible ? "" : " (مخفي)"}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                  ],
                ),
              if (d.recentMatches.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'آخر النزالات (${d.recentMatches.length}):',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: customTheme.sovereignAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                for (final m in d.recentMatches.take(5))
                  Text(
                    '• ${m.isGhostMatch ? "👻" : "⚔️"} ${m.myScore} نقطة (${m.status})',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          title: 'تعويض آمن بسقف رقابي',
          icon: Icons.card_giftcard_rounded,
          accentColor: const Color(0xFF10B981),
          child: d.canReceiveCompensation
              ? Form(
                  key: _compFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'السقف: حتى 10,000 دينار، 100 ياقوتة، و5,000 خبرة لكل معاملة.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: AdminTextField(
                              controller: _coinsCtrl,
                              label: 'دنانير',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim()) ?? -1;
                                return (n < 0 || n > 10000) ? '0..10000' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AdminTextField(
                              controller: _gemsCtrl,
                              label: 'ياقوت',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim()) ?? -1;
                                return (n < 0 || n > 100) ? '0..100' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AdminTextField(
                              controller: _xpCtrl,
                              label: 'خبرة XP',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim()) ?? -1;
                                return (n < 0 || n > 5000) ? '0..5000' : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AdminTextField(
                        controller: _reasonCtrl,
                        label: 'سبب التعويض (إلزامي للتدقيق)',
                        validator: (v) => (v ?? '').trim().length < 3
                            ? 'اكتب سبباً واضحاً (3 أحرف على الأقل)'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      AdminPrimaryButton(
                        key: const Key('btn_grant_player_compensation'),
                        label: 'منح التعويض وتسجيله',
                        icon: Icons.verified_rounded,
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        isLoading: _isCompensating,
                        onPressed: _submitCompensation,
                      ),
                    ],
                  ),
                )
              : const Text(
                  'حساب ضيف محلي غير مربوط بحساب سحابي؛ لا يمكن شحن رصيده سحابياً قبل ربط Google.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.amberAccent),
                ),
        ),
        const SizedBox(height: 16),
        AdminSectionCard(
          key: const Key('player_permissions_card'),
          title: 'الصلاحيات والحظر الفردي 🛡️',
          icon: Icons.security_rounded,
          accentColor: const Color(0xFF38BDF8),
          child: d.canManagePermissions
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile.adaptive(
                      key: const Key('player_ban_switch'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.redAccent,
                      title: const Text(
                        'حظر الحساب بالكامل 🚫',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _isBanned
                            ? 'اللاعب محظور حالياً ويمنع من دخول اللعبة'
                            : 'الحساب نشط وغير محظور',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: _isBanned ? Colors.redAccent : Colors.white60,
                          fontSize: 11.5,
                        ),
                      ),
                      value: _isBanned,
                      onChanged: (v) {
                        setState(() => _isBanned = v);
                      },
                    ),
                    if (_isBanned) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        key: const Key('player_ban_duration_dropdown'),
                        isExpanded: true,
                        value: _banHours,
                        dropdownColor: AppCustomTheme.of(context).surfaceCard,
                        decoration: const InputDecoration(
                          labelText: 'مدة الحظر',
                          labelStyle: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white70,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem<int?>(
                            value: 24,
                            child: Text(
                              '24 ساعة (يوم واحد)',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                              ),
                            ),
                          ),
                          DropdownMenuItem<int?>(
                            value: 168,
                            child: Text(
                              '7 أيام (أسبوع)',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                              ),
                            ),
                          ),
                          DropdownMenuItem<int?>(
                            value: 720,
                            child: Text(
                              '30 يوماً (شهر)',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                              ),
                            ),
                          ),
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'حظر دائم ⛔',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() => _banHours = val),
                      ),
                      const SizedBox(height: 8),
                      AdminTextField(
                        key: const Key('player_ban_reason_input'),
                        controller: _banReasonCtrl,
                        label: 'سبب الحظر (يظهر للاعب)',
                      ),
                    ],
                    const Divider(color: Colors.white24, height: 24),
                    const Text(
                      'التحكم الدقيق في الميزات:',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      key: const Key('perm_switch_online'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF38BDF8),
                      title: const Text(
                        'المعارك الجماعية أونلاين ⚔️',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      value: _canUseOnline,
                      onChanged: (v) => setState(() => _canUseOnline = v),
                    ),
                    SwitchListTile.adaptive(
                      key: const Key('perm_switch_diwan'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF38BDF8),
                      title: const Text(
                        'ديوان الأحفاد والمحادثة 💬',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      value: _canUseDiwan,
                      onChanged: (v) => setState(() => _canUseDiwan = v),
                    ),
                    SwitchListTile.adaptive(
                      key: const Key('perm_switch_guilds'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF38BDF8),
                      title: const Text(
                        'الكتائب والمساهمة 🛡️',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      value: _canUseGuilds,
                      onChanged: (v) => setState(() => _canUseGuilds = v),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'صلاحية استضافة البطولات الحية (Live Arena):',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<bool?>(
                      key: const Key('player_perm_host_arena_dropdown'),
                      isExpanded: true,
                      value: _canHostLiveArenas,
                      dropdownColor: AppCustomTheme.of(context).surfaceCard,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem<bool?>(
                          value: null,
                          child: Text(
                            'حسب السياسة العامة (افتراضي)',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                            ),
                          ),
                        ),
                        DropdownMenuItem<bool?>(
                          value: true,
                          child: Text(
                            'تفويض معلم — مسموح دائماً 🎓',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.greenAccent,
                            ),
                          ),
                        ),
                        DropdownMenuItem<bool?>(
                          value: false,
                          child: Text(
                            'ممنوع فردياً 🚫',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _canHostLiveArenas = val),
                    ),
                    if (d.permissions.isEffectivelyDiwanMutedNow ||
                        d.diwanModeration != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.volume_off_rounded,
                              color: Colors.amberAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'اللاعب مكتوم حالياً في الديوان',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.amberAccent,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              key: const Key('btn_quick_unmute_player'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                              onPressed: _quickUnmutePlayer,
                              child: const Text(
                                'فك الكتم',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    AdminTextField(
                      controller: _permNotesCtrl,
                      label: 'ملاحظات إدارية خاصة (لا تظهر للاعب)',
                    ),
                    const SizedBox(height: 14),
                    AdminPrimaryButton(
                      key: const Key('btn_save_player_permissions'),
                      label: 'حفظ الصلاحيات والحظر',
                      icon: Icons.save_rounded,
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      isLoading: _isSavingPerms,
                      onPressed: _savePlayerPermissions,
                    ),
                  ],
                )
              : const Text(
                  'حساب ضيف محلي غير مربوط بحساب سحابي؛ لا يمكن فرض حظر أو صلاحيات سحابية عليه قبل ربط Google.',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.amberAccent),
                ),
        ),
      ],
    );
  }
}

class _PlayerRowTile extends StatelessWidget {
  final AdminPlayerSearchResult player;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlayerRowTile({
    required this.player,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accent
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    '${player.isGuest ? "ضيف" : (player.email ?? "Google")} • 🏆 ${player.trophies} • م${player.playerLevel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white60,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white60,
              fontSize: 10.5,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
