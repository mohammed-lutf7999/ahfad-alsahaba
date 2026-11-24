import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/app_control_service.dart';
import 'release/release_feature_flags_card.dart';
import 'release/release_versions_card.dart';
import 'widgets/admin_ui_kit.dart';

/// In-App Admin Screen for managing app version gates (`minVersionCode`,
/// `latestVersionCode`), emergency `maintenanceMode`, and live `FeatureFlags`.
class AdminReleaseControlScreen extends StatefulWidget {
  final AppReleaseConfig? initialConfig;

  const AdminReleaseControlScreen({super.key, this.initialConfig});

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
  int _configVersion = 1;
  final Map<String, bool> _flags = {};

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
    _configVersion = cfg.configVersion;
    final ff = cfg.featureFlags;
    _flags
      ..['online_multiplayer'] = ff.onlineMultiplayer
      ..['ghost_matches'] = ff.ghostMatches
      ..['private_rooms'] = ff.privateRooms
      ..['knights_store'] = ff.knightsStore
      ..['show_event_banner'] = ff.showEventBanner
      ..['daily_challenges'] = ff.dailyChallenges
      ..['royal_inbox'] = ff.royalInbox
      ..['live_announcement_ping'] = ff.liveAnnouncementPing
      ..['wise_teacher_mode'] = ff.wiseTeacherMode
      ..['diwan_chat'] = ff.diwanChat
      ..['guilds_arenas'] = ff.guildsArenas
      ..['quick_phrases'] = ff.quickPhrases
      ..['live_arena_host_restricted'] = ff.liveArenaHostRestricted;
  }

  Future<void> _refreshFromServer() async {
    setState(() => _isLoading = true);
    try {
      final overview = await AdminService().getOverview();
      if (!mounted) return;
      if (overview != null) {
        setState(() => _hydrateFromConfig(overview.releaseConfig));
      }
    } catch (_) {
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
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppCustomTheme.of(ctx).surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.65)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
      ),
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
        featureFlags: Map<String, bool>.from(_flags),
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
              ReleaseMaintenanceCard(
                maintenanceMode: _maintenanceMode,
                titleController: _maintenanceTitleCtrl,
                messageController: _maintenanceMessageCtrl,
                onMaintenanceChanged: _onMaintenanceSwitchChanged,
              ),
              const SizedBox(height: 16),
              ReleaseVersionsCard(
                minVersionCtrl: _minVersionCtrl,
                latestVersionCtrl: _latestVersionCtrl,
                latestNameCtrl: _latestNameCtrl,
                updateUrlCtrl: _updateUrlCtrl,
                updateTitleCtrl: _updateTitleCtrl,
                updateMessageCtrl: _updateMessageCtrl,
              ),
              const SizedBox(height: 16),
              ReleaseFeatureFlagsCard(
                flags: _flags,
                onFlagChanged: (key, val) => setState(() => _flags[key] = val),
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
}
