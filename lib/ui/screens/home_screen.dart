import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/size_config.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/app_control_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/progression_service.dart';
import '../../data/services/quote_service.dart';
import '../../data/services/royal_inbox_service.dart';
import '../dialogs/app_control_dialogs.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/home_dynamic_event_banner.dart';
import '../widgets/islamic_quote_card.dart';
import '../widgets/navigation/royal_bottom_nav_bar.dart';
import 'glory/glory_road_screen.dart';
import 'home/widgets/home_app_bar.dart';
import 'home/widgets/home_glory_panel.dart';
import 'home/widgets/home_logo_with_effects.dart';
import 'home/widgets/home_player_hub_sheet.dart';
import 'home/widgets/home_start_button.dart';
import 'library_screen.dart';
import 'store/knights_store_screen.dart';

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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

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
    AppControlService.instance.playerPermissionsNotifier.addListener(
      _onControlStateChanged,
    );

    _loadQuotes();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      unawaited(RoyalInboxService.instance.initFromCache());
      AchievementService.instance.reconcileAchievements();
      AppControlCoordinator.instance.markAppReadyForGates();
      NotificationService.flushPendingNavigation();
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
        (!service.isAdminNotifier.value &&
            service.playerPermissionsNotifier.value.isEffectivelyBannedNow) ||
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
    if (!hasSeen) _showTutorial();
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
            description:
                'تحدَّ أصدقاءك واختبر معلوماتك، أو خصص التطبيق بما يناسبك من هنا.',
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
    if (mounted) setState(() => _quotesLoaded = true);
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
    AppControlService.instance.playerPermissionsNotifier.removeListener(
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
    if (index == 0) return;

    if (index == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
      );
      _refreshProfile();
      return;
    }

    if (index == 2) {
      await Navigator.pushNamed(context, AppRoutes.challenge);
      _refreshProfile();
      return;
    }

    if (index == 3) {
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
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KnightsStoreScreen()),
      );
      _refreshProfile();
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
      appBar: HomeAppBar(
        profile: profile,
        newAchievements: newAchievements,
        profileKey: _profileKey,
        achievementsKey: _achievementsKey,
        challengeKey: _challengeKey,
        onOpenPlayerHub: () {
          if (profile == null) return;
          showHomePlayerHubSheet(
            context,
            playerCode: profile.playerCode,
            onRefresh: _refreshProfile,
          );
        },
        onRefresh: _refreshProfile,
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

              final content = Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  const HomeDynamicEventBanner(),
                  if (_quotesLoaded &&
                      QuoteService.instance.dailyQuotes.isNotEmpty)
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
                  const SizedBox(height: 70),
                ],
              );

              if (isVerySmall) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
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
}
