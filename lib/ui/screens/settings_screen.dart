import 'package:flutter/material.dart';
import '../../core/app_constants.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../data/models/app_control_models.dart';
import '../../data/services/admin_service.dart';
import '../../data/services/app_control_service.dart';
import '../../data/services/profile_service.dart';
import 'admin_dashboard_screen.dart';
import 'settings/settings_dialogs.dart';
import 'settings/settings_profile_card.dart';
import 'settings/settings_tiles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _soundEnabled;
  late bool _vibrationEnabled;
  late bool _wiseTeacherEnabled;
  late int _questionTime;
  int _adminAccessCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    AdminService().refreshAdminStatus().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _loadSettings() {
    _soundEnabled = SharedPrefsService.getSoundEnabled();
    _vibrationEnabled = SharedPrefsService.getVibrationEnabled();
    _wiseTeacherEnabled = SharedPrefsService.getWiseTeacherEnabled();
    _questionTime = SharedPrefsService.getQuestionTime();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService.instance.activeProfile;
    final isAdmin = AdminService().isAdmin;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    GestureDetector(
                      onTap: () {
                        SoundService().playClick();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.accentColor.withAlpha(80),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (isAdmin) {
                            _adminAccessCounter++;
                            if (_adminAccessCounter >= 3) {
                              _adminAccessCounter = 0;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AdminDashboardScreen(),
                                ),
                              );
                            }
                          }
                        },
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppTheme.accentLight,
                              AppTheme.accentColor,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'الإعدادات',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor.withAlpha(80),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: AppTheme.primaryDark,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                    border: Border.all(
                      color: AppTheme.accentColor.withAlpha(60),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withAlpha(30),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ListView(
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withAlpha(100),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (profile != null) ...[
                        const SettingsSectionTitle('الملف الشخصي'),
                        const SizedBox(height: 14),
                        SettingsProfileCard(
                          profile: profile,
                          onProfileUpdated: () {
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(height: 28),
                      ],
                      const SettingsSectionTitle('إعدادات الصوت'),
                      const SizedBox(height: 14),
                      SettingsSwitchTile(
                        icon: Icons.volume_up_rounded,
                        title: 'الصوت',
                        subtitle: 'تفعيل المؤثرات الصوتية',
                        value: _soundEnabled,
                        onChanged: (value) async {
                          setState(() => _soundEnabled = value);
                          await SharedPrefsService.saveSoundEnabled(value);
                        },
                      ),
                      SettingsSwitchTile(
                        icon: Icons.vibration_rounded,
                        title: 'الاهتزاز',
                        subtitle: 'تفعيل الاهتزاز عند الإجابة',
                        value: _vibrationEnabled,
                        onChanged: (value) async {
                          setState(() => _vibrationEnabled = value);
                          await SharedPrefsService.saveVibrationEnabled(value);
                        },
                      ),
                      const SizedBox(height: 28),
                      const SettingsSectionTitle('إعدادات المسابقة'),
                      const SizedBox(height: 14),
                      SettingsTimerTile(
                        questionTime: _questionTime,
                        onChanged: (value) async {
                          setState(() => _questionTime = value.toInt());
                          await SharedPrefsService.saveQuestionTime(
                            value.toInt(),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<AppFeatureFlags>(
                        valueListenable:
                            AppControlService.instance.featureFlagsNotifier,
                        builder: (context, flags, _) {
                          final adminEnabled = flags.wiseTeacherMode;
                          return SettingsSwitchTile(
                            icon: Icons.psychology_rounded,
                            title: 'وضع المعلم الحكيم 🧠',
                            subtitle: adminEnabled
                                ? 'مراجعة الأخطاء والإضاءة التاريخية في اللعب الفردي'
                                : 'متوقف مؤقتاً من لوحة الإدارة',
                            value: adminEnabled && _wiseTeacherEnabled,
                            onChanged: (value) async {
                              if (!adminEnabled) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'وضع المعلم الحكيم متوقف مؤقتاً من الإدارة',
                                        style: TextStyle(fontFamily: 'Cairo'),
                                      ),
                                    ),
                                  );
                                return;
                              }
                              setState(() => _wiseTeacherEnabled = value);
                              await SharedPrefsService.setWiseTeacherEnabled(
                                value,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      const SettingsSectionTitle('إعدادات البيانات والحساب'),
                      const SizedBox(height: 14),
                      SettingsActionTile(
                        icon: Icons.refresh_rounded,
                        title: 'إعادة تعيين التقدم',
                        subtitle: 'حذف بيانات التقدم والنقاط المحلية',
                        color: AppTheme.errorColor,
                        onTap: () => showSettingsResetDialog(
                          context,
                          onResetComplete: () {
                            _loadSettings();
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SettingsActionTile(
                        icon: Icons.delete_forever_rounded,
                        title: 'حذف الحساب والبيانات',
                        subtitle: 'حذف الحساب السحابي وجميع البيانات نهائياً',
                        color: AppTheme.errorColor,
                        onTap: () => showSettingsDeleteAccountDialog(
                          context,
                          onDeleteComplete: () {
                            _loadSettings();
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SettingsSectionTitle('حول التطبيق والسياسات'),
                      const SizedBox(height: 14),
                      SettingsActionTile(
                        icon: Icons.privacy_tip_rounded,
                        title: 'سياسة الخصوصية وأمان البيانات',
                        subtitle: 'بيان الخصوصية المعتمد لمتجر Google Play',
                        color: AppTheme.accentDark,
                        onTap: () => showSettingsPrivacyPolicyDialog(context),
                      ),
                      const SizedBox(height: 10),
                      const SettingsInfoTile(
                        icon: Icons.info_rounded,
                        title: 'الإصدار',
                        value: AppConstants.appVersion,
                      ),
                      const SettingsInfoTile(
                        icon: Icons.apps_rounded,
                        title: 'اسم التطبيق',
                        value: AppConstants.appName,
                      ),
                      const SettingsInfoTile(
                        icon: Icons.person_pin_rounded,
                        title: 'تطوير وبرمجة',
                        value: AppConstants.developerName,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
