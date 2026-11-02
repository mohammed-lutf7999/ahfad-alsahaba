import '../../data/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../core/sound_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/admin_service.dart'; // Add AdminService import
import '../../data/models/player_profile_model.dart'; // Add PlayerProfile import
import '../widgets/avatar_selector.dart';
import 'admin_dashboard_screen.dart'; // Import AdminDashboardScreen

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _soundEnabled;
  late bool _vibrationEnabled;
  late int _questionTime;
  int _adminAccessCounter = 0; // Counter for hidden admin access

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _soundEnabled = SharedPrefsService.getSoundEnabled();
    _vibrationEnabled = SharedPrefsService.getVibrationEnabled();
    _questionTime = SharedPrefsService.getQuestionTime();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService.instance.activeProfile;
    final isAdmin = AdminService().isAdmin; // Check admin status
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
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
                          border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
                        ),
                        child: const Icon(Icons.arrow_forward_ios, color: AppTheme.accentColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector( // Hidden admin gesture
                        onTap: () {
                           if (isAdmin) {
                             _adminAccessCounter++;
                             if (_adminAccessCounter >= 3) { // Triple tap to access
                               _adminAccessCounter = 0;
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                               );
                             }
                           }
                        },
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppTheme.accentLight, AppTheme.accentColor],
                          ).createShader(bounds),
                          child: const Text(
                            'الإعدادات',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.settings_rounded, color: AppTheme.primaryDark, size: 22),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Settings content
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
                    border: Border.all(color: AppTheme.accentColor.withAlpha(60), width: 1.5),
                    boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(30), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: ListView(
                    children: [
                      Center(
                        child: Container(
                          width: 45, height: 4,
                          decoration: BoxDecoration(color: AppTheme.accentColor.withAlpha(100), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Profile Section
                      if (profile != null) ...[
                        _buildSectionTitle('الملف الشخصي'),
                        const SizedBox(height: 14),
                        _buildProfileCard(profile),
                        const SizedBox(height: 28),
                      ],

                      _buildSectionTitle('إعدادات الصوت'),
                      const SizedBox(height: 14),

                      _buildSwitchTile(Icons.volume_up_rounded, 'الصوت', 'تفعيل المؤثرات الصوتية', _soundEnabled, (value) async {
                        setState(() => _soundEnabled = value);
                        await SharedPrefsService.saveSoundEnabled(value);
                      }),

                      _buildSwitchTile(Icons.vibration_rounded, 'الاهتزاز', 'تفعيل الاهتزاز عند الإجابة', _vibrationEnabled, (value) async {
                        setState(() => _vibrationEnabled = value);
                        await SharedPrefsService.saveVibrationEnabled(value);
                      }),

                      const SizedBox(height: 28),

                      _buildSectionTitle('إعدادات المسابقة'),
                      const SizedBox(height: 14),

                      _buildTimerSetting(),

                      const SizedBox(height: 28),

                      _buildSectionTitle('إعدادات البيانات والحساب'),
                      const SizedBox(height: 14),

                      _buildActionTile(Icons.refresh_rounded, 'إعادة تعيين التقدم', 'حذف بيانات التقدم والنقاط المحلية', AppTheme.errorColor, _showResetDialog),
                      const SizedBox(height: 10),
                      _buildActionTile(Icons.delete_forever_rounded, 'حذف الحساب والبيانات', 'حذف الحساب السحابي وجميع البيانات نهائياً', AppTheme.errorColor, _showDeleteAccountDialog),

                      const SizedBox(height: 28),

                      _buildSectionTitle('حول التطبيق والسياسات'),
                      const SizedBox(height: 14),

                      _buildActionTile(Icons.privacy_tip_rounded, 'سياسة الخصوصية وأمان البيانات', 'بيان الخصوصية المعتمد لمتجر Google Play', AppTheme.accentDark, _showPrivacyPolicyDialog),
                      const SizedBox(height: 10),
                      _buildInfoTile(Icons.info_rounded, 'الإصدار', AppConstants.appVersion),
                      _buildInfoTile(Icons.apps_rounded, 'اسم التطبيق', AppConstants.appName),
                      _buildInfoTile(Icons.person_pin_rounded, 'تطوير وبرمجة', AppConstants.developerName),
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
  
  Widget _buildProfileCard(PlayerProfile profile) { // Added type
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentColor.withOpacity(0.15), AppTheme.accentColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              ProfileAvatar(avatarIndex: profile.avatarIndex, size: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${profile.totalScore}',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.stars_rounded, color: AppTheme.accentColor, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          '${profile.highScore}',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.emoji_events_rounded, color: AppTheme.accentLight, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    SoundService().playClick();
                    await Navigator.pushNamed(context, AppRoutes.profileSelector);
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('تبديل السجل', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    SoundService().playClick();
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.profileSetup,
                      arguments: {'existingProfile': profile},
                    );
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded, color: AppTheme.primaryDark, size: 18),
                        SizedBox(width: 8),
                        Text('تعديل', style: TextStyle(color: AppTheme.primaryDark, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentDark));
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentColor.withAlpha(50)),
        boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(20), blurRadius: 6)],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.accentColor.withAlpha(30), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppTheme.accentDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.accentColor, activeTrackColor: AppTheme.accentColor.withAlpha(80)),
        ],
      ),
    );
  }

  Widget _buildTimerSetting() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentColor.withAlpha(50)),
        boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(20), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.accentColor.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.timer_rounded, color: AppTheme.accentDark, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('وقت السؤال', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryDark)),
                    const SizedBox(height: 2),
                    Text('$_questionTime ثانية لكل سؤال', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Text('${AppConstants.maxQuestionTime}ث', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Expanded(
                child: Slider(
                  value: _questionTime.toDouble(),
                  min: AppConstants.minQuestionTime.toDouble(),
                  max: AppConstants.maxQuestionTime.toDouble(),
                  divisions: (AppConstants.maxQuestionTime - AppConstants.minQuestionTime) ~/ 5,
                  activeColor: AppTheme.accentColor,
                  inactiveColor: AppTheme.accentColor.withAlpha(50),
                  onChanged: (value) async {
                    setState(() => _questionTime = value.toInt());
                    await SharedPrefsService.saveQuestionTime(value.toInt());
                  },
                ),
              ),
              Text('${AppConstants.minQuestionTime}ث', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: color.withAlpha(180))),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentColor.withAlpha(50)),
        boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(20), blurRadius: 6)],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.accentColor.withAlpha(30), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppTheme.accentDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryDark))),
          Text(value, style: TextStyle(fontSize: 14, color: AppTheme.accentDark)),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const Icon(Icons.warning_rounded, color: AppTheme.errorColor), const SizedBox(width: 8), Text('تأكيد إعادة التعيين', style: TextStyle(color: AppTheme.primaryDark))],
        ),
        content: Text('سيتم حذف جميع بيانات التقدم والنقاط. هل أنت متأكد؟', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: TextStyle(color: AppTheme.accentDark))),
          ElevatedButton(
            onPressed: () async {
              await SharedPrefsService.resetAllProgress();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('تم إعادة تعيين جميع البيانات بنجاح', textAlign: TextAlign.center),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
              _loadSettings();
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.privacy_tip_rounded, color: AppTheme.accentColor),
            const SizedBox(width: 8),
            Text('سياسة الخصوصية وأمان البيانات', style: TextStyle(color: AppTheme.primaryDark, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'نحن في تطبيق "معركة أحفاد الصحابة" نلتزم بأعلى معايير حماية خصوصيتك وبياناتك وفق سياسات Google Play:\n\n'
                '1. البيانات المجمعة:\n'
                '• الاسم والبريد الإلكتروني (اختيارياً عند تسجيل الدخول بحساب Google لحفظ تقدمك السحابي فقط).\n'
                '• درجات وإنجازات المسابقة وتصنيفك في لوحة الشرف.\n\n'
                '2. اللعب بدون إنترنت:\n'
                '• التطبيق يعمل بالكامل دون الحاجة لإنترنت في نمط اللعب الفردي والتحدي القريب (Nearby).\n\n'
                '3. مشاركة البيانات:\n'
                '• لا نشارك أي بيانات شخصية مع أطراف ثالثة أو شبكات إعلانية.\n'
                '• جميع الاتصالات السحابية مشفرة ببروتوكول HTTPS/WSS الآمن.\n\n'
                '4. التحكم في بياناتك وحذفها:\n'
                '• يمكنك في أي وقت إعادة تعيين بياناتك محلياً أو حذف حسابك وبياناتك السحابية نهائياً من زر "حذف الحساب والبيانات".',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, height: 1.6, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
            child: const Text('موافق', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            Text('تأكيد حذف الحساب والبيانات', style: TextStyle(color: AppTheme.primaryDark, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'سيتم حذف تقدمك السحابي وتصنيفك في لوحة الشرف وبيانات ملفك الشخصي نهائياً وبلا رجعة. هل أنت متأكد؟',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: AppTheme.accentDark)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('جارٍ حذف الحساب والبيانات...', textAlign: TextAlign.center),
                duration: Duration(seconds: 2),
              ));
              
              await AuthService().deleteAccountAndData();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('تم حذف الحساب وجميع البيانات بنجاح', textAlign: TextAlign.center),
                  backgroundColor: AppTheme.successColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
                _loadSettings();
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
