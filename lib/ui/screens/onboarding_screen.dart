import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../core/sound_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 4;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'أهلاً بك في معركة\nأحفاد الصحابة',
      description:
          'انضم إلى التحدي الإسلامي الأكبر، واختبر معرفتك في مجالات متعددة من العلوم الشرعية. نحن هنا لنختبر إيمانك وذكائك!',
      icon: Icons.shield_moon_rounded, // Represents strength/heritage
    ),
    OnboardingItem(
      title: 'المسابقات الإسلامية',
      description:
          'اختبر مهاراتك في المسابقات الدينية المتنوعة، حيث تشمل الأسئلة التحدي في القرآن الكريم، الأحاديث، السيرة النبوية، وأقوال الصحابة.',
      icon: Icons.emoji_events_rounded, // Represents competition
    ),
    OnboardingItem(
      title: 'مكتبة أحفاد الصحابة',
      description:
          'مكتبتنا تضم مجموعة ضخمة من القرآن الكريم، الأحاديث النبوية، سيرة الصحابة، حكمة وأقوال. اكتشف كل ما هو جديد في عالم العلوم الشرعية.',
      icon: Icons.menu_book_rounded, // Represents library
    ),
    OnboardingItem(
      title: 'استعد للتحدي!',
      description:
          'حان وقت بدء معركة معرفتك. استعد لأقوى المسابقات والإجابات المذهلة. هيا بنا!',
      icon: Icons.rocket_launch_rounded, // Represents starting/action
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    SoundService().playClick();
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    await SharedPrefsService.saveOnboardingSeen();
    if (mounted) {
      // After onboarding, always go to profile setup for first-time users
      Navigator.pushReplacementNamed(
        context, 
        AppRoutes.profileSetup,
        arguments: {'isFirstTime': true},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Skip Button
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    onPressed: () {
                      SoundService().playClick();
                      _finishOnboarding();
                    },
                    child: Text(
                      'تخطي',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: _numPages,
                  itemBuilder: (context, index) {
                    return _buildPageContent(_items[index], index);
                  },
                ),
              ),

              // Bottom Area (Indicators & Button)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  children: [
                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_numPages, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppTheme.accentColor
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: AppTheme.primaryDark,
                          elevation: 10,
                          shadowColor: AppTheme.accentColor.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentPage == _numPages - 1 ? 'ابدأ الآن' : 'التالي',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(OnboardingItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic Area
          Expanded(
            flex: 5,
            child: Center(
              child: _buildAnimatedIcon(item.icon, index == _currentPage),
            ),
          ),
          
          const SizedBox(height: 32),

          // Text Area
          Expanded(
            flex: 4,
            child: Column(
              children: [
                ShaderMask(
                   shaderCallback: (bounds) => const LinearGradient(
                     colors: [Color(0xFFFFD700), Colors.white],
                     begin: Alignment.topCenter,
                     end: Alignment.bottomCenter,
                   ).createShader(bounds),
                   child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: Colors.white, // Fallback
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                    fontFamily: 'Cairo', // Clean readable font for body
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon(IconData icon, bool isVisible) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: isVisible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentColor.withOpacity(0.2),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: AppTheme.accentColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withOpacity(0.2 * value),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Icon(
                  icon,
                  size: 80,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}
