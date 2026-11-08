import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../core/app_theme.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../core/app_routes.dart';
import 'dart:math' as math;
import '../../data/local/shared_prefs_service.dart';
import '../../core/sound_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/progression_service.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/quote_service.dart';
import '../../data/services/auth_service.dart';
import '../widgets/avatar_selector.dart';
import '../widgets/animated_avatar_frame.dart';
import '../widgets/level_badge_widget.dart';
import '../widgets/glory_progress_bar.dart';
import '../widgets/islamic_quote_card.dart';
import 'library_screen.dart';
import '../../core/size_config.dart';
import '../widgets/coach_mark_overlay.dart'; // Import custom overlay
import '../widgets/top_notification.dart'; // Import top notification
import 'creative_empire_screen.dart';
import 'global_ranking_screen.dart';
import 'glory/glory_road_screen.dart';
import 'store/knights_store_screen.dart';
import 'multiplayer/lobby_screen.dart';

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
          _GlowingTrophyButton(
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
          _buildSpeedDial(),
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
                            child: _buildGloryAndStorePanel(context),
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const _LogoWithEffects(),
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
                              _StartGameButton(
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

  Widget _buildGloryAndStorePanel(BuildContext context) {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return const SizedBox.shrink();
    final levelInfo = profile.levelInfo;
    final arena = ProgressionService.instance.currentArena;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Arena & Trophies + Progress Bar clickable to Glory Road
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              SoundService().playClick();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GloryRoadScreen()),
              );
              _refreshProfile();
            },
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            arena.icon,
                            color: arena.accentColor,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              arena.name,
                              style: TextStyle(
                                color: arena.accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '🏆 ${profile.trophies} كأس',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GloryProgressBar(
                  levelInfo: levelInfo,
                  height: 8,
                  showLabels: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Bottom Row: Direct Prominent Buttons for Glory Road & Knight's Store
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      SoundService().playClick();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GloryRoadScreen(),
                        ),
                      );
                      _refreshProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.military_tech_rounded, size: 18),
                    label: const Text(
                      'طريق المجد 🏆',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      SoundService().playClick();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KnightsStoreScreen(),
                        ),
                      );
                      _refreshProfile();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD700),
                      backgroundColor: Colors.amber.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      side: const BorderSide(
                        color: Color(0xFFFFD700),
                        width: 1.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: const Text(
                      'سوق الفرسان 🪙',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
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

  Widget _buildSpeedDial() {
    return Padding(
      padding: const EdgeInsets.only(left: 8), // إبعاد عن حافة الشاشة
      child: SizedBox(
        width: 40,
        height: 40,
        child: SpeedDial(
          key: _challengeKey,
          icon: Icons.keyboard_arrow_down_rounded,
          activeIcon: Icons.close_rounded,
          iconTheme: const IconThemeData(color: AppTheme.primaryDark, size: 20),
          buttonSize: const Size(40, 40),
          childrenButtonSize: const Size(44, 44),
          backgroundColor: AppTheme.accentColor,
          activeBackgroundColor: Colors.red.shade400,
          elevation: 4,
          overlayColor: Colors.black,
          overlayOpacity: 0.3,
          spacing: 8,
          spaceBetweenChildren: 8,
          direction: SpeedDialDirection.down,
          animationDuration: const Duration(milliseconds: 150),
          tooltip: '',
          heroTag: 'speed-dial',
          children: [
            // Online Challenge Button (New)
            SpeedDialChild(
               child: const Icon(Icons.language_rounded, color: AppTheme.primaryDark, size: 22),
               backgroundColor: const Color(0xFF00E676), // Bright Green
               onTap: () {
                 SoundService().playClick();
                 Navigator.push(
                   context,
                   MaterialPageRoute(builder: (context) => const LobbyScreen()),
                 );
               },
            ),
            // Challenge Button
            SpeedDialChild(
              child: const Icon(Icons.sports_kabaddi_rounded, color: AppTheme.primaryDark, size: 20),
              backgroundColor: AppTheme.accentColor,
              onTap: () {
                SoundService().playClick();
                Navigator.pushNamed(context, AppRoutes.challenge);
              },
            ),
            // Settings Button
            SpeedDialChild(
              child: const Icon(Icons.settings_rounded, color: AppTheme.primaryDark, size: 20),
              backgroundColor: AppTheme.accentLight,
              onTap: () async {
                SoundService().playClick();
                await Navigator.pushNamed(context, AppRoutes.settings);
                _refreshProfile();
              },
            ),
            // Creative Empire Button (Imperial)
            SpeedDialChild(
              child: const Icon(Icons.diamond_rounded, color: AppTheme.primaryDark, size: 22),
              backgroundColor: const Color(0xFFFFD700), // Gold
              onTap: () {
                SoundService().playClick();
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreativeEmpireScreen()),
                );
              },
            ),
            
            // Global Ranking Button
            SpeedDialChild(
              child: const Icon(Icons.public_rounded, color: AppTheme.primaryDark, size: 22),
              backgroundColor: Colors.cyanAccent,
              onTap: () {
                SoundService().playClick();
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GlobalRankingScreen()),
                );
              },
            ),
            
            // Google Sign-In Button (Icon only - like other buttons)
            SpeedDialChild(
              child: AuthService().isLoggedIn 
                  ? const Icon(Icons.logout_rounded, color: Colors.white, size: 22)
                  : Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                    ),
              backgroundColor: AuthService().isLoggedIn ? Colors.red.shade400 : Colors.white,
              onTap: () async {
                SoundService().playClick();
                if (AuthService().isLoggedIn) {
                  // Sign Out - clear data and navigate to profile setup
                  final result = await AuthService().signOut();
                  if (mounted) {
                    TopNotification.showWarning(
                      context, 
                      'تم تسجيل الخروج بنجاح',
                    );
                    // Navigate to profile setup screen
                    if (result.shouldNavigateToSetup) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.profileSetup,
                        (route) => false,
                        arguments: {'isFirstTime': true},
                      );
                    }
                  }
                } else {
                  // Sign In with Google
                  final result = await AuthService().signInWithGoogle();
                  if (mounted) {
                    if (result.success) {
                      TopNotification.showSuccess(
                        context, 
                        'مرحباً ${AuthService().userDisplayName}! 🎉',
                      );
                      // Refresh to show new profile data
                      setState(() {});
                    } else {
                      TopNotification.showError(
                        context, 
                        result.errorMessage ?? 'حدث خطأ',
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoWithEffects extends StatefulWidget {
  const _LogoWithEffects();

  @override
  State<_LogoWithEffects> createState() => _LogoWithEffectsState();
}

class _LogoWithEffectsState extends State<_LogoWithEffects> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  
  // Interaction state
  double _scale = 1.0;
  double _intensity = 1.0;

  @override
  void initState() {
    super.initState();
    // Breathing/Pulse Animation
    _pulseController = AnimationController(
        duration: const Duration(seconds: 3), vsync: this)..repeat(reverse: true);
    
    // Solar Rays Rotation
    _rotationController = AnimationController(
        duration: const Duration(seconds: 10), vsync: this)..repeat();

    // Particles Animation
    _particleController = AnimationController(
        duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.95;
      _intensity = 2.0;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
      _intensity = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
      _intensity = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    double size = getProportionateScreenWidth(160); // Base size scaled
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Solar Rays (Background)
              RotationTransition(
                turns: _rotationController,
                child: _SolarRays(size: size),
              ),

              // 2. Gold Particles (Falling/Floating)
              Positioned.fill(
                child: _ParticleSystem(controller: _particleController),
              ),

              // 3. Main Logo with Breathing Glow
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glowValue = _pulseController.value;
                  double innerSize = size * 0.66; // approx 120/180
                  return Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.goldGradient,
                      boxShadow: [
                        // Bloom/Glow Effect
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.4 * _intensity),
                          blurRadius: (30 + (20 * glowValue * _intensity)) * (size/180),
                          spreadRadius: 5 + (10 * glowValue),
                        ),
                        // Inner "Hot" Glow
                        BoxShadow(
                          color: Colors.orangeAccent.withValues(alpha: 0.3 * _intensity),
                          blurRadius: 15,
                          spreadRadius: -2,
                        ),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Center(
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: innerSize,
                          width: innerSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )); // Fixed closing parenthesis
                },
              ),
              
              // 4. Interaction Flash (Overlay)
              AnimatedOpacity(
                 opacity: _intensity > 1.0 ? 0.3 : 0.0,
                 duration: const Duration(milliseconds: 200),
                 child: Container(
                   width: size * 0.66, height: size * 0.66,
                   decoration: const BoxDecoration(
                     shape: BoxShape.circle,
                     color: Colors.white,
                     boxShadow: [BoxShadow(color: Colors.white, blurRadius: 20, spreadRadius: 5)]
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

class _SolarRays extends StatelessWidget {
  final double size;
  const _SolarRays({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SolarRaysPainter(),
    );
  }
}

class _SolarRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
         const Color(0xFFFFD700).withValues(alpha: 0.3), // Gold
         Colors.transparent
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));
    
    // Draw background glow
    canvas.drawCircle(center, size.width / 2, paint);
      
    // Draw Rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    for (int i = 0; i < 12; i++) {
       final angle = (i * 30) * (math.pi / 180);
       final start = center;
       final end = Offset(
         center.dx + (size.width / 2) * math.cos(angle),
         center.dy + (size.height / 2) * math.sin(angle),
       );
       canvas.drawLine(start, end, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParticleSystem extends StatelessWidget {
  final AnimationController controller;
  const _ParticleSystem({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(progress: controller.value),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter({required this.progress});

  // Static random seeds for 20 particles (x, y, speed, size)
  static final List<List<double>> _particles = List.generate(20, (index) {
     final r = math.Random(index);
     return [r.nextDouble(), r.nextDouble(), r.nextDouble() * 0.5 + 0.5, r.nextDouble() * 3 + 1];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFD700);
    
    for (var p in _particles) {
      final x = p[0] * size.width;
      // y moves down with progress
      double y = (p[1] + progress) % 1.0 * size.height;
      
      final opacity = 1.0 - ((y - size.height/2).abs() / (size.height/2)); // Fade edges
      
      paint.color = const Color(0xFFFFD700).withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), p[3], paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}

class _StartGameButton extends StatefulWidget {
  final VoidCallback onTap;

  const _StartGameButton({super.key, required this.onTap});

  @override
  State<_StartGameButton> createState() => _StartGameButtonState();
}

class _StartGameButtonState extends State<_StartGameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: false);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: getProportionateScreenHeight(64), // Scale
      child: GestureDetector(
        onTap: () {
          SoundService().playClick();
          widget.onTap();
        },
        child: Stack(
          children: [
            // Base Layer with Gold Gradient & Shadow
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3), // Inner glow
                    blurRadius: 10,
                    spreadRadius: -2,
                  )
                ],
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.white24, shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow_rounded,
                          color: AppTheme.primaryDark, size: getProportionateScreenWidth(28)),
                    ),
                     SizedBox(width: getProportionateScreenWidth(14)),
                     Text(
                      'ابدأ التحدي',
                      style: TextStyle(
                          fontSize: getProportionateScreenWidth(22),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                          fontFamily: 'Cairo'), // Matches logo font
                    ),
                  ],
                ),
              ),
            ),
//...

            // Shimmer Effect
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      widthFactor: 0.6,
                      heightFactor: 1.0,
                      alignment: AlignmentTween(
                        begin: const Alignment(
                            -3.5, 0.0), // Start from far left
                        end: const Alignment(
                            3.5, 0.0), // End at far right
                      ).evaluate(_shimmerController),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            begin: const Alignment(-0.5, -0.5),
                            end: const Alignment(1.5, 1.5), // Diagonal shine
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Glass/Gloss Highlight (Top edge)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 25,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر الكؤوس المتوهج مع تأثيرات الشمس والاهتزاز
class _GlowingTrophyButton extends StatefulWidget {
  final bool hasNotification;
  final int notificationCount;
  final VoidCallback onTap;

  const _GlowingTrophyButton({
    required this.hasNotification,
    required this.notificationCount,
    required this.onTap,
    super.key,
  });

  @override
  State<_GlowingTrophyButton> createState() => _GlowingTrophyButtonState();
}

class _GlowingTrophyButtonState extends State<_GlowingTrophyButton>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _wobbleController;
  late AnimationController _raysController;
  
  late Animation<double> _glowAnimation;
  late Animation<double> _wobbleAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Glow pulse animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    // Wobble animation
    _wobbleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _wobbleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.05), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.03), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0), weight: 25),
    ]).animate(CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut));
    
    // Rays rotation
    _raysController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    // Start periodic wobble
    _startPeriodicWobble();
  }

  void _startPeriodicWobble() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _wobbleController.forward(from: 0).then((_) {
          _startPeriodicWobble();
        });
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _wobbleController.dispose();
    _raysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _wobbleAnimation, _raysController]),
      builder: (context, child) {
        return Transform.rotate(
          angle: _wobbleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating rays behind
                  Transform.rotate(
                    angle: _raysController.value * math.pi * 2,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.accentColor.withValues(alpha: 0.3 * _glowAnimation.value),
                            AppTheme.accentColor.withValues(alpha: 0.1 * _glowAnimation.value),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      child: CustomPaint(
                        painter: _TrophyRaysPainter(
                          color: AppTheme.accentColor.withValues(alpha: 0.5 * _glowAnimation.value),
                        ),
                      ),
                    ),
                  ),
                  
                  // Glowing background
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentColor.withValues(alpha: 0.2),
                          AppTheme.accentColor.withValues(alpha: 0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.4 * _glowAnimation.value),
                          blurRadius: 12 * _glowAnimation.value,
                          spreadRadius: 2 * _glowAnimation.value,
                        ),
                      ],
                    ),
                  ),
                  
                  // Trophy icon with scale
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: AppTheme.accentColor,
                      size: 26,
                      shadows: [
                        Shadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  
                  // Notification badge
                  if (widget.hasNotification)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          '${widget.notificationCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// رسام الأشعة للكأس
class _TrophyRaysPainter extends CustomPainter {
  final Color color;

  _TrophyRaysPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw 8 rays
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180;
      final innerRadius = size.width * 0.3;
      final outerRadius = size.width * 0.5;
      
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * innerRadius,
          center.dy + math.sin(angle) * innerRadius,
        ),
        Offset(
          center.dx + math.cos(angle) * outerRadius,
          center.dy + math.sin(angle) * outerRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrophyRaysPainter oldDelegate) => oldDelegate.color != color;
}
