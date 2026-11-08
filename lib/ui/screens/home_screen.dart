import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../core/app_routes.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../core/sound_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/progression_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/quote_service.dart';
import '../widgets/avatar_selector.dart';
import '../widgets/animated_avatar_frame.dart';
import '../widgets/level_badge_widget.dart';
import '../widgets/islamic_quote_card.dart';
import 'library_screen.dart';
import '../../core/size_config.dart';
import '../widgets/coach_mark_overlay.dart';
import 'home/widgets/home_logo_with_effects.dart';
import 'home/widgets/home_start_button.dart';
import 'home/widgets/home_glowing_trophy_button.dart';
import 'home/widgets/home_glory_panel.dart';
import 'home/widgets/home_speed_dial.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _quotesLoaded = false;
  
  // Tutorial Keys
  final GlobalKey _profileKey = GlobalKey(); // New
  final GlobalKey _quoteKey = GlobalKey();   // New
  final GlobalKey _startKey = GlobalKey();
  final GlobalKey _libraryKey = GlobalKey();
  final GlobalKey _challengeKey = GlobalKey(); // Speed Dial or Action
  final GlobalKey _achievementsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    
    // Listen for profile changes to update score display
    ProfileService.instance.addListener(_onProfileChanged);
    ProgressionService.instance.addListener(_onProfileChanged);
    AchievementService.instance.addListener(_onProfileChanged);
    AuthService().addListener(_onProfileChanged);
    
    // Reconcile and check achievements
    AchievementService.instance.reconcileAchievements();

    // Load quotes
    _loadQuotes();

    // Check Tutorial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorial();
    });
  }

  Future<void> _checkTutorial() async {
    final hasSeen = await SharedPrefsService.getHasSeenTutorial(); // Need to implement this getter
    if (!hasSeen) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => CoachMarkOverlay(
        steps: [
          CoachMarkStep(
            key: _profileKey,
            title: 'ملفك الشخصي',
            description: 'اضغط هنا لتعديل اسمك وصورتك الرمزية ومتابعة مستواك.',
            shape: BoxShape.rectangle, // Or Circle if we target avatar only
          ),
          CoachMarkStep(
            key: _startKey,
            title: 'ابدأ المسابقة',
            description: 'ابدأ هنا للإجابة على أسئلة إسلامية ممتعة وتنمية معرفتك.',
            shape: BoxShape.rectangle,
          ),
          CoachMarkStep(
            key: _quoteKey,
            title: 'نور وهداية',
            description: 'تزود يومياً بأقوال مأثورة وحكم من السلف الصالح.',
            shape: BoxShape.rectangle,
          ),
          CoachMarkStep(
             key: _challengeKey,
             title: 'التحدي والإعدادات',
             description: 'تحدَّ أصدقاءك واختبر معلوماتك، أو خصص التطبيق بما يناسبك من هنا.',
             shape: BoxShape.circle,
          ),
          CoachMarkStep(
            key: _libraryKey,
            title: 'المكتبة الإسلامية',
            description: 'تصفح قصص الصحابة والسلف الصالح لإثراء ثقافتك.',
            shape: BoxShape.rectangle,
          ),
          CoachMarkStep(
            key: _achievementsKey,
            title: 'إنجازاتك',
            description: 'تابع تقدمك واحصل على جوائز وأوسمة عند إتمام المستويات.',
            shape: BoxShape.circle,
          ),
        ],
        onFinished: () async {
          await SharedPrefsService.setHasSeenTutorial(true);
          overlayEntry.remove();
        },
        onSkipped: () async {
           await SharedPrefsService.setHasSeenTutorial(true);
           overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
  
  Future<void> _loadQuotes() async {
    await QuoteService.instance.loadQuotes();
    if (mounted) {
      setState(() {
        _quotesLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_onProfileChanged);
    ProgressionService.instance.removeListener(_onProfileChanged);
    AchievementService.instance.removeListener(_onProfileChanged);
    AuthService().removeListener(_onProfileChanged);
    _controller.dispose();
    super.dispose();
  }
  
  // Called when profile data changes (e.g. after game completion)
  void _onProfileChanged() {
    if (mounted) setState(() {});
  }
  
  // Refresh profile data when navigating back
  void _refreshProfile() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final profile = ProfileService.instance.activeProfile;
    final newAchievements = AchievementService.instance.newAchievementsCount;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: profile != null ? GestureDetector(
          onTap: () async {
            SoundService().playClick();
            await Navigator.pushNamed(context, AppRoutes.profileSelector);
            _refreshProfile();
          },
          child: Center(
            child: AnimatedAvatarFrame(
              size: 46,
              frameKey: profile.equippedFrame,
              winStreak: profile.winStreak,
              child: ProfileAvatar(avatarIndex: profile.avatarIndex, size: 38),
            ),
          ),
        ) : null,
        title: profile != null ? GestureDetector(
          key: _profileKey, // Attach Key Here
          onTap: () async {
            SoundService().playClick();
            await Navigator.pushNamed(context, AppRoutes.profileSelector);
            _refreshProfile();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      profile.name,
                      style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  LevelBadgeWidget(
                    levelInfo: profile.levelInfo,
                    customTitle: profile.effectiveTitle,
                    isCompact: true,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, color: AppTheme.accentLight, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    '${profile.totalScore}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '🪙 ${profile.coins}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '💎 ${profile.gems}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ) : null,
        actions: [
          // Achievements button with glow effect
          HomeGlowingTrophyButton(
            key: _achievementsKey,
            hasNotification: newAchievements > 0,
            notificationCount: newAchievements,
            onTap: () async {
              SoundService().playClick();
              await Navigator.pushNamed(context, AppRoutes.achievements);
              _refreshProfile();
            },
          ),
          // Speed Dial
          HomeSpeedDial(
            challengeKey: _challengeKey,
            onRefresh: _refreshProfile,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppCustomTheme.of(context).backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute safely
                      children: [
                        if (profile != null)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: getProportionateScreenWidth(20),
                              vertical: 4,
                            ),
                            child: HomeGloryPanel(
                              profile: profile,
                              onRefresh: _refreshProfile,
                            ),
                          ),
                        SizedBox(height: getProportionateScreenHeight(6)), 
                        
                        // 1. Logo/Title Area
                        // Use Flexible so it can shrink if needed
                        Flexible(
                          flex: 4,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HomeLogoWithEffects(),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 2. Islamic Quote Card Area
                        // Use Expanded/Flexible
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: getProportionateScreenWidth(20),
                                vertical: 10),
                            child: _quotesLoaded && QuoteService.instance.dailyQuotes.isNotEmpty
                                ? Container(
                                    key: _quoteKey, // Attach Key Here (Container wrapper to ensure bounds)
                                    child: IslamicQuoteCard(
                                      quotes: QuoteService.instance.dailyQuotes,
                                    ),
                                  )
                                : const SizedBox.shrink(), // Don't show empty placeholder large
                          ),
                        ),

                        // 3. Buttons Area
                        // Keep fixed height logic but ensure padding
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: getProportionateScreenWidth(40),
                              vertical: getProportionateScreenHeight(20)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              HomeStartButton(
                                key: _startKey,
                                onTap: () => Navigator.pushNamed(
                                    context, AppRoutes.categories),
                              ),

                              SizedBox(height: getProportionateScreenHeight(16)),
                              _buildMenuButton(
                                context,
                                'مكتبة أحفاد الصحابة',
                                Icons.menu_book_rounded,
                                () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const LibraryScreen()));
                                },
                                isPrimary: false,
                                key: _libraryKey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, IconData icon,
      VoidCallback onTap, {bool isPrimary = true, Key? key}) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: getProportionateScreenHeight(60), // Resizable height
      child: ElevatedButton(
        onPressed: () {
          SoundService().playClick();
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppTheme.accentColor : Colors.transparent,
          foregroundColor: isPrimary ? AppTheme.primaryDark : AppTheme.accentColor,
          elevation: isPrimary ? 8 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: AppTheme.accentColor, width: 1.5),
          ),
          shadowColor: AppTheme.accentColor.withValues(alpha: 80),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.rtl, // Ensuring RTL
          children: [
            Icon(icon, size: getProportionateScreenWidth(24)),
            SizedBox(width: getProportionateScreenWidth(12)),
            Text(
              title,
              style: TextStyle(fontSize: getProportionateScreenWidth(18), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

}
