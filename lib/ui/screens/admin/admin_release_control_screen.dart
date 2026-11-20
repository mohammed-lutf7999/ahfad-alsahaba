import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/app_control_service.dart';
import 'widgets/admin_ui_kit.dart';

/// In-App Admin Screen for managing app version gates (`minVersionCode`,
/// `latestVersionCode`), emergency `maintenanceMode`, and live `FeatureFlags`.
class AdminReleaseControlScreen extends StatefulWidget {
  final AppReleaseConfig? initialConfig;

  const AdminReleaseControlScreen({
    super.key,
    this.initialConfig,
  });

  @override
  State<AdminReleaseControlScreen> createState() =>
      _AdminReleaseControlScreenState();
}

class _AdminReleaseControlScreenState extends State<AdminReleaseControlScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _minVersionCtrl;
  late final TextEditingController _latestVersionCtrl;
  late final TextEditingController _latestNameCtrl;
  late final TextEditingController _updateUrlCtrl;
  late final TextEditingController _updateTitleCtrl;
  late final TextEditingController _updateMessageCtrl;
  late final TextEditingController _maintenanceTitleCtrl;
  late final TextEditingController _maintenanceMessageCtrl;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _maintenanceMode = false;
  bool _onlineMultiplayer = true;
  bool _ghostMatches = true;
  bool _privateRooms = true;
  bool _knightsStore = true;
  bool _showEventBanner = true;
  bool _dailyChallenges = true;
  bool _royalInbox = true;
  bool _liveAnnouncementPing = true;
  bool _wiseTeacherMode = true;
  bool _diwanChat = true;
  bool _guildsArenas = true;
  bool _quickPhrases = true;
  bool _liveArenaHostRestricted = true;
  int _configVersion = 1;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialConfig ??
        AppControlService.instance.releaseConfigNotifier.value;
    _minVersionCtrl = TextEditingController();
    _latestVersionCtrl = TextEditingController();
    _latestNameCtrl = TextEditingController();
    _updateUrlCtrl = TextEditingController();
    _updateTitleCtrl = TextEditingController();
    _updateMessageCtrl = TextEditingController();
    _maintenanceTitleCtrl = TextEditingController();
    _maintenanceMessageCtrl = TextEditingController();
    _hydrateFromConfig(seed);
    if (widget.initialConfig == null) {
      _refreshFromServer();
    }
  }

  void _hydrateFromConfig(AppReleaseConfig cfg) {
    _minVersionCtrl.text = cfg.minVersionCode.toString();
    _latestVersionCtrl.text = cfg.latestVersionCode.toString();
    _latestNameCtrl.text = cfg.latestVersionName;
    _updateUrlCtrl.text = cfg.updateUrl;
    _updateTitleCtrl.text = cfg.updateTitle;
    _updateMessageCtrl.text = cfg.updateMessage;
    _maintenanceTitleCtrl.text = cfg.maintenanceTitle;
    _maintenanceMessageCtrl.text = cfg.maintenanceMessage;
    _maintenanceMode = cfg.maintenanceMode;
    _onlineMultiplayer = cfg.featureFlags.onlineMultiplayer;
    _ghostMatches = cfg.featureFlags.ghostMatches;
    _privateRooms = cfg.featureFlags.privateRooms;
    _knightsStore = cfg.featureFlags.knightsStore;
    _showEventBanner = cfg.featureFlags.showEventBanner;
    _dailyChallenges = cfg.featureFlags.dailyChallenges;
    _royalInbox = cfg.featureFlags.royalInbox;
    _liveAnnouncementPing = cfg.featureFlags.liveAnnouncementPing;
    _wiseTeacherMode = cfg.featureFlags.wiseTeacherMode;
    _diwanChat = cfg.featureFlags.diwanChat;
    _guildsArenas = cfg.featureFlags.guildsArenas;
    _quickPhrases = cfg.featureFlags.quickPhrases;
    _liveArenaHostRestricted = cfg.featureFlags.liveArenaHostRestricted;
    _configVersion = cfg.configVersion;
  }

  Future<void> _refreshFromServer() async {
    setState(() => _isLoading = true);
    try {
      final overview = await AdminService().getOverview();
      if (!mounted) return;
      if (overview != null) {
        setState(() => _hydrateFromConfig(overview.releaseConfig));
      }
    } catch (e) {
      if (mounted) {
        showAdminFeedback(
          context,
          'تعذر تحميل أحدث الإعدادات من السحابة؛ يتم عرض آخر نسخة معروفة.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _minVersionCtrl.dispose();
    _latestVersionCtrl.dispose();
    _latestNameCtrl.dispose();
    _updateUrlCtrl.dispose();
    _updateTitleCtrl.dispose();
    _updateMessageCtrl.dispose();
    _maintenanceTitleCtrl.dispose();
    _maintenanceMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _onMaintenanceSwitchChanged(bool nextValue) async {
    SoundService().playClick();
    if (!nextValue) {
      setState(() => _maintenanceMode = false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final customTheme = AppCustomTheme.of(ctx);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: customTheme.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.redAccent.withValues(alpha: 0.65),
              ),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تأكيد تفعيل وضع الصيانة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'سيمنع وضع الصيانة جميع اللاعبين (ما عدا المشرفين) من دخول التطبيق بمجرد مزامنتهم حتى تقوم بإيقافه.',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'تأكيد التفعيل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _maintenanceMode = true);
    }
  }

  Future<void> _saveConfig() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final minVer = int.tryParse(_minVersionCtrl.text.trim()) ?? 0;
    final latestVer = int.tryParse(_latestVersionCtrl.text.trim()) ?? 0;
    if (minVer <= 0 || latestVer < minVer) {
      showAdminFeedback(
        context,
        'يجب أن يكون رقم الإصدار الأحدث أكبر من أو يساوي الحد الأدنى الإلزامي.',
        isError: true,
      );
      return;
    }

    SoundService().playClick();
    setState(() => _isSaving = true);
    try {
      final saved = await AdminService().upsertReleaseConfig(
        minVersionCode: minVer,
        latestVersionCode: latestVer,
        latestVersionName: _latestNameCtrl.text.trim(),
        updateTitle: _updateTitleCtrl.text.trim(),
        updateMessage: _updateMessageCtrl.text.trim(),
        updateUrl: _updateUrlCtrl.text.trim(),
        maintenanceMode: _maintenanceMode,
        maintenanceTitle: _maintenanceTitleCtrl.text.trim(),
        maintenanceMessage: _maintenanceMessageCtrl.text.trim(),
        featureFlags: {
          'online_multiplayer': _onlineMultiplayer,
          'ghost_matches': _ghostMatches,
          'private_rooms': _privateRooms,
          'knights_store': _knightsStore,
          'show_event_banner': _showEventBanner,
          'daily_challenges': _dailyChallenges,
          'royal_inbox': _royalInbox,
          'live_announcement_ping': _liveAnnouncementPing,
          'wise_teacher_mode': _wiseTeacherMode,
          'diwan_chat': _diwanChat,
          'guilds_arenas': _guildsArenas,
          'quick_phrases': _quickPhrases,
          'live_arena_host_restricted': _liveArenaHostRestricted,
        },
      );
      if (!mounted) return;
      if (saved != null) {
        setState(() => _hydrateFromConfig(saved));
        showAdminFeedback(
          context,
          'تم حفظ الإعدادات ونشرها حياً (النسخة #${saved.configVersion}) ✅',
        );
      } else {
        showAdminFeedback(
          context,
          'لم يتم حفظ الإعدادات؛ تحقق من صلاحيات المشرف أو الاتصال بالإنترنت.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdminFeedback(context, 'فشل حفظ الإعدادات: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return AdminScaffoldShell(
      title: 'الإصدارات والصيانة والمزايا',
      subtitle: 'بصمة الإعدادات الحالية: #$_configVersion',
      isLoading: _isLoading,
      onRefresh: _refreshFromServer,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSectionCard(
                title: 'وضع الصيانة الطارئ',
                icon: Icons.engineering_rounded,
                accentColor:
                    _maintenanceMode ? Colors.redAccent : customTheme.sovereignAccent,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      key: const Key('admin_maintenance_switch'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.redAccent,
                      title: const Text(
                        'تفعيل وضع الصيانة الشامل',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _maintenanceMode
                            ? 'التطبيق مغلق حالياً أمام اللاعبين (المشرف يمكنه التجاوز)'
                            : 'التطبيق متاح ويعمل بصورة طبيعية',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11.5,
                        ),
                      ),
                      value: _maintenanceMode,
                      onChanged: _onMaintenanceSwitchChanged,
                    ),
                    const SizedBox(height: 10),
                    AdminTextField(
                      controller: _maintenanceTitleCtrl,
                      label: 'عنوان شاشة الصيانة',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _maintenanceMessageCtrl,
                      label: 'رسالة الصيانة للاعبين',
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdminSectionCard(
                title: 'إصدارات المتجر والتحديث الإلزامي',
                icon: Icons.system_update_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AdminTextField(
                            controller: _minVersionCtrl,
                            label: 'الحد الأدنى (إلزامي)',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final n = int.tryParse(v?.trim() ?? '');
                              if (n == null || n < 1) return 'رقم صحيح >= 1';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AdminTextField(
                            controller: _latestVersionCtrl,
                            label: 'أحدث بناء (اختياري)',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final latest = int.tryParse(v?.trim() ?? '');
                              final minV =
                                  int.tryParse(_minVersionCtrl.text.trim()) ?? 0;
                              if (latest == null || latest < 1) {
                                return 'رقم صحيح >= 1';
                              }
                              if (latest < minV) {
                                return 'يجب >= الحد الأدنى';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _latestNameCtrl,
                      label: 'اسم الإصدار الأحدث (versionName)',
                      hint: 'مثال: 1.0.18',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _updateUrlCtrl,
                      label: 'رابط التحديث في المتجر (اختياري/سقوط)',
                      keyboardType: TextInputType.url,
                      validator: (v) {
                        final raw = v?.trim() ?? '';
                        if (raw.isEmpty) return null;
                        final lower = raw.toLowerCase();
                        if (!lower.startsWith('https://') &&
                            !lower.startsWith('http://')) {
                          return 'يجب أن يبدأ الرابط بـ https:// أو http://';
                        }
                        final uri = Uri.tryParse(raw);
                        if (uri == null || uri.host.trim().isEmpty) {
                          return 'أدخل رابط متجر مكتمل وصحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _updateTitleCtrl,
                      label: 'عنوان نافذة التحديث',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    AdminTextField(
                      controller: _updateMessageCtrl,
                      label: 'وصف التحديث ومميزاته',
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdminSectionCard(
                title: 'أعلام التحكم الفوري بالمزايا (Feature Flags)',
                icon: Icons.tune_rounded,
                child: Column(
                  children: [
                    _buildFlagTile(
                      key: const Key('flag_online_multiplayer'),
                      title: 'المباريات الأونلاين السريعة',
                      subtitle: 'تفعيل أو إيقاف الميدان المباشر',
                      value: _onlineMultiplayer,
                      onChanged: (v) => setState(() => _onlineMultiplayer = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_ghost_matches'),
                      title: 'محرك معارك الأشباح المسجّلة',
                      subtitle: 'السقوط للبوت المحلي فقط عند الإيقاف',
                      value: _ghostMatches,
                      onChanged: (v) => setState(() => _ghostMatches = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_private_rooms'),
                      title: 'غرف التحدي الخاصة',
                      subtitle: 'إتاحة أو قفل غرف الأصدقاء السداسية',
                      value: _privateRooms,
                      onChanged: (v) => setState(() => _privateRooms = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_knights_store'),
                      title: 'سوق الفرسان (المتجر)',
                      subtitle: 'فتح أو إغلاق تبويب وشاشات المتجر',
                      value: _knightsStore,
                      onChanged: (v) => setState(() => _knightsStore = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_show_event_banner'),
                      title: 'بانر الأحداث الديناميكية',
                      subtitle: 'إظهار أو إخفاء شريط الفعاليات في الرئيسية',
                      value: _showEventBanner,
                      onChanged: (v) => setState(() => _showEventBanner = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_daily_challenges'),
                      title: 'التحدي اليومي المتجدد 🌟',
                      subtitle: 'إظهار بطاقة الجولة اليومية في قائمة التحدي',
                      value: _dailyChallenges,
                      onChanged: (v) => setState(() => _dailyChallenges = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_royal_inbox'),
                      title: 'صندوق البريد الملكي 📬',
                      subtitle: 'تفعيل أو إيقاف صندوق الرسائل والهدايا للاعبين',
                      value: _royalInbox,
                      onChanged: (v) => setState(() => _royalInbox = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_live_announcement_ping'),
                      title: 'النبضة اللحظية للرسائل ⚡',
                      subtitle: 'إيقاظ فوري (<1ث) للمتصلين أو إيقافه لتوفير WebSockets',
                      value: _liveAnnouncementPing,
                      onChanged: (v) =>
                          setState(() => _liveAnnouncementPing = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_wise_teacher_mode'),
                      title: 'وضع المعلم الحكيم 🧠',
                      subtitle: 'التحكم المركزي بميزة مراجعة الأخطاء والإضاءة التاريخية',
                      value: _wiseTeacherMode,
                      onChanged: (v) => setState(() => _wiseTeacherMode = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_diwan_chat'),
                      title: 'ديوان الأحفاد (الدردشة الحية) 💬',
                      subtitle: 'فتح أو إيقاف غرفة التواصل الجماعي وتحديات الديوان',
                      value: _diwanChat,
                      onChanged: (v) => setState(() => _diwanChat = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_guilds_arenas'),
                      title: 'الكتائب والبطولات الجماعية 🛡️',
                      subtitle: 'تفعيل أو إيقاف نظام الكتائب وغرف البطولات الحية',
                      value: _guildsArenas,
                      onChanged: (v) => setState(() => _guildsArenas = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_quick_phrases'),
                      title: 'عبارات الفرسان السريعة في النزالات 💬',
                      subtitle: 'إتاحة إرسال واستقبال عبارات الفروسية في المعارك',
                      value: _quickPhrases,
                      onChanged: (v) => setState(() => _quickPhrases = v),
                    ),
                    _buildFlagTile(
                      key: const Key('flag_live_arena_host_restricted'),
                      title: 'حصر إنشاء البطولات الحية بالمعلمين والمشرفين 🎓',
                      subtitle: 'قصر زر إنشاء البطولة على المشرفين أو المعلمين المفوّضين',
                      value: _liveArenaHostRestricted,
                      onChanged: (v) =>
                          setState(() => _liveArenaHostRestricted = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AdminPrimaryButton(
                key: const Key('admin_save_release_config_btn'),
                label: 'حفظ ونشر الإعدادات فوراً',
                icon: Icons.cloud_upload_rounded,
                isLoading: _isSaving,
                onPressed: _saveConfig,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlagTile({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      key: key,
      contentPadding: EdgeInsets.zero,
      activeColor: AppCustomTheme.of(context).sovereignAccent,
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 11.5,
        ),
      ),
      value: value,
      onChanged: (val) {
        SoundService().playClick();
        onChanged(val);
      },
    );
  }
}

