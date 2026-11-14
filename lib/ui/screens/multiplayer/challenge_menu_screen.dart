import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/nearby_service.dart';
import 'create_challenge_screen.dart';
import 'join_challenge_screen.dart';
import 'private_room_hub_screen.dart';
import 'lobby_screen.dart';

/// القائمة الرئيسية لوضع التحدي (منظومة الأونلاين والبلوتوث المحلي)
class ChallengeMenuScreen extends StatefulWidget {
  const ChallengeMenuScreen({super.key});

  @override
  State<ChallengeMenuScreen> createState() => _ChallengeMenuScreenState();
}

class _ChallengeMenuScreenState extends State<ChallengeMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// طلب أذونات البلوتوث المحلي حصراً وبشكل ذكي (SDK-Aware)
  Future<bool> _requestPermissions() async {
    final result = await NearbyService.instance.requestPermissionsDetailed();
    
    if (!result.isGranted && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text(
                'أذونات التقارب المحلي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لتشغيل وضع التحدي المحلي بدون إنترنت، يلزم:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '✓ تفعيل البلوتوث للأجهزة القريبة',
                style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12),
              ),
              const Text(
                '✓ السماح بأذونات البحث والمزامنة',
                style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text(
                result.isPermanentlyDenied
                    ? 'تم حظر الأذونات مسبقاً من إعدادات النظام؛ يرجى فتح الإعدادات لتمكينها يدوياً.'
                    : 'يمكنك المحاولة مجدداً أو تمكينها من إعدادات التطبيق.',
                style: const TextStyle(color: Colors.orange, fontSize: 11, fontFamily: 'Cairo'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white60, fontFamily: 'Cairo'),
              ),
            ),
            if (result.isPermanentlyDenied)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                },
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text(
                  'فتح الإعدادات',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'حسناً',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  /// نافذة اختيار دور تحدي البلوتوث المحلي (إنشاء أو انضمام)
  void _showLocalBluetoothOptions() {
    SoundService().playClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 25,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bluetooth_searching_rounded, color: Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحدي البلوتوث المحلي 📡',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      'تنافس بدون إنترنت مع الأجهزة القريبة',
                      style: TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Option 1: Create Challenge (Host)
            _buildLocalOptionCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'إنشاء تحدي جديد (مضيف 👑)',
              subtitle: 'كن القائد وحدد نوع الأسئلة وعددها',
              color: AppTheme.accentColor,
              onTap: () async {
                Navigator.pop(ctx);
                final granted = await _requestPermissions();
                if (granted && mounted) {
                  _navigateTo(const CreateChallengeScreen());
                }
              },
            ),
            const SizedBox(height: 12),

            // Option 2: Join Challenge (Guest)
            _buildLocalOptionCard(
              icon: Icons.search_rounded,
              title: 'البحث عن تحدي والانضمام (ضيف 🔍)',
              subtitle: 'ابحث عن مجالس التحدي المجاورة وشارك فوراً',
              color: const Color(0xFF00E676),
              onTap: () async {
                Navigator.pop(ctx);
                final granted = await _requestPermissions();
                if (granted && mounted) {
                  _navigateTo(const JoinChallengeScreen());
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // VS Icon
                        _buildVsIcon(),
                        
                        const SizedBox(height: 24),
                        
                        // 1. Private Rooms (Code & WhatsApp Invite) - Zero Permission Barrier
                        _buildMenuButton(
                          icon: Icons.castle_rounded,
                          title: 'غرف التحدي الخاصة 🏰',
                          subtitle: 'كود سداسي ودعوة الأصدقاء عبر واتساب',
                          color: AppTheme.accentColor,
                          onTap: () => _navigateTo(const PrivateRoomHubScreen()),
                        ),
                        
                        const SizedBox(height: 16),

                        // 2. Quick Matchmaking (Online Arena) - Zero Permission Barrier
                        _buildMenuButton(
                          icon: Icons.radar_rounded,
                          title: 'الميدان السريع المباشر ⚔️',
                          subtitle: 'مطابقة أونلاين فورية أو ضد البوت',
                          color: AppTheme.accentLight,
                          onTap: () => _navigateTo(const LobbyScreen()),
                        ),
                        
                        const SizedBox(height: 16),

                        // 3. Local Bluetooth Challenge (Offline Nearby with Role Selection)
                        _buildMenuButton(
                          icon: Icons.bluetooth_searching_rounded,
                          title: 'تحدي البلوتوث المحلي 📡',
                          subtitle: 'تنافس بدون إنترنت مع الأجهزة القريبة',
                          color: Colors.blueAccent,
                          onTap: _showLocalBluetoothOptions,
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Instructions
                        _buildInstructions(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title and Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppTheme.accentColor.withValues(alpha: 0.3), blurRadius: 10)],
                ),
                child: const Icon(Icons.sports_kabaddi_rounded, color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.accentLight, AppTheme.accentColor],
                ).createShader(bounds),
                child: const Text(
                  'وضع التحدي',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // Back button
          GestureDetector(
            onTap: () {
              SoundService().playClick();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.accentColor, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVsIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.accentColor.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.accentLight, AppTheme.accentColor],
          ).createShader(bounds),
          child: const Text(
            'VS',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        SoundService().playClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white.withValues(alpha: 0.5), size: 18),
              const SizedBox(width: 8),
              Text(
                'كيفية التحدي',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• غرف التحدي الخاصة والميدان السريع تعمل عبر الإنترنت مباشرة دون أذونات\n'
            '• تحدي البلوتوث مخصص للتنافس المحلي بدون إنترنت في نفس المكان',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.5,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
