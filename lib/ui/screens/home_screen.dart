import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../core/app_routes.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../core/sound_service.dart';
import '../../data/services/app_control_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/progression_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/quote_service.dart';
import '../../data/services/royal_inbox_service.dart';
import '../dialogs/app_control_dialogs.dart';
import '../widgets/avatar_selector.dart';
import '../widgets/animated_avatar_frame.dart';
import '../widgets/level_badge_widget.dart';
import '../widgets/islamic_quote_card.dart';
import '../widgets/home_dynamic_event_banner.dart';
import 'library_screen.dart';
import 'glory/glory_road_screen.dart';
import 'store/knights_store_screen.dart';
import '../../core/size_config.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/navigation/royal_bottom_nav_bar.dart';
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
  final int _bottomNavIndex = 0;
  
  // Tutorial Keys
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _quoteKey = GlobalKey();
  final GlobalKey _startKey = GlobalKey();
  final GlobalKey _libraryKey = GlobalKey();
  final GlobalKey _challengeKey = GlobalKey();
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
    AppControlService.instance.featureFlagsNotifier.addListener(
      _onControlStateChanged,
    );
    AppControlService.instance.activeEventNotifier.addListener(
      _onControlStateChanged,
    );
    AppControlService.instance.releaseConfigNotifier.addListener(
      _onControlStateChanged,
    );
    AppControlService.instance.pendingAnnouncementsNotifier.addListener(
      _onControlStateChanged,
    );
    
    // Load quotes asynchronously off the critical startup build path
    _loadQuotes();

    // Defer post-frame tutorial & achievement reconciliation until frame 1 is painted
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      unawaited(RoyalInboxService.instance.initFromCache());
      AchievementService.instance.reconcileAchievements();
      AppControlCoordinator.instance.markAppReadyForGates();
      AppControlService.instance.refreshTimedVisualState();
      unawaited(AppControlService.instance.syncPlayerDirectory());
      final showedGate = await AppControlCoordinator.instance.checkAndPresent(
        context,
      );
      if (!mounted || showedGate) return;
      await _checkTutorial();
    });
  }

  void _onControlStateChanged() {
    if (!mounted) return;
    setState(() {});
    final service = AppControlService.instance;
    final hasPendingGate = service.releaseConfigNotifier.value.maintenanceMode ||
        service.releaseConfigNotifier.value.isForceUpdateRequired(
          service.effectiveBuildNumber,
        ) ||
        service.pendingAnnouncementsNotifier.value.isNotEmpty;
    if (!hasPendingGate) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppControlCoordinator.instance.checkAndPresent(context);
    });
  }

  Future<void> _checkTutorial() async {
    final hasSeen = await SharedPrefsService.getHasSeenTutorial();
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
            shape: BoxShape.rectangle,
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
    AppControlService.instance.featureFlagsNotifier.removeListener(
      _onControlStateChanged,
    );
    AppControlService.instance.activeEventNotifier.removeListener(
      _onControlStateChanged,
    );
    AppControlService.instance.releaseConfigNotifier.removeListener(
      _onControlStateChanged,
    );
    AppControlService.instance.pendingAnnouncementsNotifier.removeListener(
      _onControlStateChanged,
    );
    _controller.dispose();
    super.dispose();
  }
  
  void _onProfileChanged() {
    if (mounted) setState(() {});
  }
  
  void _refreshProfile() {
    if (mounted) setState(() {});
  }

  Future<void> _handleBottomNavTap(int index) async {
    if (index == 0) {
      // Already on Home
      return;
    }

    if (index == 1) {
      // Library
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
      );
      _refreshProfile();
      return;
    }

    if (index == 2) {
      // Center Crest: Challenge / Direct Battles
      await Navigator.pushNamed(context, AppRoutes.challenge);
      _refreshProfile();
      return;
    }

    if (index == 3) {
      // Glory Road
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GloryRoadScreen()),
      );
      _refreshProfile();
      return;
    }

    if (index == 4) {
      if (!AppControlService.instance.featureFlagsNotifier.value.knightsStore) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('سوق الفرسان مغلق مؤقتاً للصيانة والتحديث 🛡️'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // Knights Store
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KnightsStoreScreen()),
      );
      _refreshProfile();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final profile = ProfileService.instance.activeProfile;
    final newAchievements = AchievementService.instance.newAchievementsCount;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: profile != null ? GestureDetector(
          key: const Key('home_player_avatar_btn'),
          onTap: () {
            SoundService().playClick();
            _openPlayerHubMenu(context, profile.playerCode);
          },
          child: Center(
            child: ValueListenableBuilder<int>(
              valueListenable: RoyalInboxService.instance.unreadCountNotifier,
              builder: (context, unreadCount, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedAvatarFrame(
                    size: 46,
                    frameKey: profile.equippedFrame,
                    winStreak: profile.winStreak,
                    child: ProfileAvatar(avatarIndex: profile.avatarIndex, size: 38),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ) : null,
        title: profile != null ? GestureDetector(
          key: _profileKey,
          onTap: () {
            SoundService().playClick();
            _openPlayerHubMenu(context, profile.playerCode);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
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
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: RoyalBottomNavBar(
          currentIndex: _bottomNavIndex,
          onTap: _handleBottomNavTap,
          libraryKey: _libraryKey,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppCustomTheme.of(context).backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final controlFlags =
                  AppControlService.instance.featureFlagsNotifier.value;
              final activeEvent =
                  AppControlService.instance.activeEventNotifier.value;
              final hasActiveBanner = controlFlags.showEventBanner &&
                  activeEvent != null &&
                  activeEvent.isCurrentlyActiveAt(DateTime.now().toUtc());
              final isVerySmall =
                  constraints.maxHeight < (hasActiveBanner ? 610 : 560);

              Widget content = Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Upper Arena & Glory Card
                  if (profile != null)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(20),
                        vertical: 2,
                      ),
                      child: HomeGloryPanel(
                        profile: profile,
                        onRefresh: _refreshProfile,
                      ),
                    ),
                  
                  // 1. Center Hero Visual Emblem (Responsive Size)
                  Flexible(
                    flex: 3,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Center(
                          child: HomeLogoWithEffects(
                            customSize: (constraints.maxHeight *
                                    (hasActiveBanner ? 0.16 : 0.20))
                                .clamp(95.0, 138.0),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 1.5 Dynamic Cloud Event Banner (0px when inactive/disabled)
                  const HomeDynamicEventBanner(),

                  // 2. Compact Islamic Wisdom Capsule (92px)
                  if (_quotesLoaded && QuoteService.instance.dailyQuotes.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: getProportionateScreenWidth(20),
                        vertical: 4,
                      ),
                      child: Container(
                        key: _quoteKey,
                        child: IslamicQuoteCard(
                          quotes: QuoteService.instance.dailyQuotes,
                        ),
                      ),
                    ),

                  // 3. Main Start CTA Button (Opulent Gold)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: getProportionateScreenWidth(32),
                      vertical: 6,
                    ),
                    child: HomeStartButton(
                      key: _startKey,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.categories,
                      ),
                    ),
                  ),

                  // Space for Bottom Floating Dock
                  const SizedBox(height: 70),
                ],
              );

              if (isVerySmall) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(child: content),
                  ),
                );
              }

              return content;
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openPlayerHubMenu(BuildContext context, String playerCode) async {
    final customTheme = AppCustomTheme.of(context);
    final unread = RoyalInboxService.instance.unreadCount;
    final inboxEnabled =
        AppControlService.instance.featureFlagsNotifier.value.royalInbox;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: customTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  key: const Key('player_menu_inbox_tile'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: customTheme.sovereignAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  tileColor: customTheme.deepBackground.withValues(alpha: 0.45),
                  leading: Icon(
                    Icons.mark_email_unread_rounded,
                    color: customTheme.sovereignAccent,
                  ),
                  title: const Text(
                    'صندوق البريد الملكي 📬',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    inboxEnabled
                        ? (unread > 0
                            ? 'لديك $unread رسالة غير مقروءة'
                            : 'رسائل الإدارة والهدايا والتعويضات')
                        : 'متوقف مؤقتاً للصيانة من الإدارة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 15,
                          color: Colors.white54,
                        ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    SoundService().playClick();
                    await Navigator.pushNamed(context, AppRoutes.royalInbox);
                    if (mounted) _refreshProfile();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  key: const Key('player_menu_profile_tile'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  tileColor: customTheme.deepBackground.withValues(alpha: 0.35),
                  leading: const Icon(
                    Icons.person_rounded,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'ملفاتي وهويتي 👤',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'إدارة الحساب وتبديل الملف • الكود: $playerCode',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Colors.white54,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    SoundService().playClick();
                    await Navigator.pushNamed(context, AppRoutes.profileSelector);
                    if (mounted) _refreshProfile();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
