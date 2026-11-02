import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/nearby_service.dart';
import 'create_challenge_screen.dart';
import 'join_challenge_screen.dart';

/// القائمة الرئيسية لوضع التحدي
class ChallengeMenuScreen extends StatefulWidget {
  const ChallengeMenuScreen({super.key});

  @override
  State<ChallengeMenuScreen> createState() => _ChallengeMenuScreenState();
}

class _ChallengeMenuScreenState extends State<ChallengeMenuScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
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

  Future<bool> _requestPermissions() async {
    setState(() => _isLoading = true);
    
    // التحقق من الأذونات أولاً
    final granted = await NearbyService.instance.requestPermissions();
    
    setState(() => _isLoading = false);
    
    if (!granted && mounted) {
      // عرض dialog واضح للمستخدم
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.orange, size: 30),
              SizedBox(width: 12),
              Text('الأذونات مطلوبة', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لتشغيل وضع التحدي، يجب:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('✓ تفعيل البلوتوث', style: TextStyle(color: Colors.white70)),
              Text('✓ تفعيل الموقع (GPS)', style: TextStyle(color: Colors.white70)),
              Text('✓ السماح بالأذونات للتطبيق', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 12),
              Text(
                'فعّلها من إعدادات الجهاز ثم حاول مرة أخرى.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً', style: TextStyle(color: AppTheme.accentColor)),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // VS Icon
                        _buildVsIcon(),
                        
                        const SizedBox(height: 40),
                        
                        // Create Challenge Button
                        _buildMenuButton(
                          icon: Icons.add_circle_outline_rounded,
                          title: 'إنشاء تحدي',
                          subtitle: 'كن المضيف وادعُ أصدقاءك',
                          color: AppTheme.accentColor,
                          onTap: () => _navigateTo(const CreateChallengeScreen()),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Join Challenge Button
                        _buildMenuButton(
                          icon: Icons.search_rounded,
                          title: 'انضم لتحدي',
                          subtitle: 'ابحث عن تحدي قريب',
                          color: AppTheme.accentLight,
                          onTap: () => _navigateTo(const JoinChallengeScreen()),
                        ),
                        
                        const SizedBox(height: 40),
                        
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
                  boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 10)],
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
                color: AppTheme.accentColor.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
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
            AppTheme.accentColor.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentColor.withOpacity(0.3),
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
      onTap: () async {
        SoundService().playClick();
        final granted = await _requestPermissions();
        if (granted) {
          onTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
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
                color: color.withOpacity(0.2),
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
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 18),
              const SizedBox(width: 8),
              Text(
                'كيفية التحدي',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• تأكد من تفعيل البلوتوث والموقع\n'
            '• المضيف ينشئ الغرفة ويختار التحدي\n'
            '• اللاعبون الآخرون يبحثون وينضمون',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
              height: 1.5,
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
