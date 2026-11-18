import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'core/app_routes.dart';
import 'core/startup_bootstrap.dart';
import 'data/local/shared_prefs_service.dart';
import 'data/services/app_control_service.dart';
import 'data/services/cms_cache_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/profile_service.dart';
import 'data/services/progression_service.dart';
import 'ui/dialogs/app_control_dialogs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable edge-to-edge globally and apply icon/contrast styling without deprecated
  // statusBarColor / systemNavigationBarColor setters (Android 15+ SDK 35 compliant).
  unawaited(
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).catchError((Object e) {
      debugPrint('setEnabledSystemUIMode error: $e');
    }),
  );
  SystemChrome.setSystemUIOverlayStyle(AppTheme.royalOverlayStyle);
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]).catchError((Object e) {
      debugPrint('setPreferredOrientations error: $e');
    }),
  );

  // Initialize ONLY essential local state required to paint frame 1 (Local-First)
  try {
    await SharedPrefsService.init();
  } catch (e) {
    debugPrint('SharedPrefsService init error: $e');
  }

  try {
    await ProfileService.instance.init();
  } catch (e) {
    debugPrint('ProfileService init error: $e');
  }

  // Hydrate App Control and CMS cache at 0ms from SharedPreferences (never blocks on network)
  try {
    await AppControlService.instance.initFromCache();
    await CmsCacheService.instance.initFromCache();
  } catch (e) {
    debugPrint('AppControlService/CmsCacheService initFromCache error: $e');
  }

  // Start Supabase local session bootstrap concurrently (never blocks runApp / first frame)
  unawaited(StartupBootstrap.initSupabase());

  // Defer notifications/timezone setup until AFTER first UI frame is painted
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(NotificationService.init());
  });

  runApp(const IslamicQuizApp());
}

class IslamicQuizApp extends StatefulWidget {
  const IslamicQuizApp({super.key});

  @override
  State<IslamicQuizApp> createState() => _IslamicQuizAppState();
}

class _IslamicQuizAppState extends State<IslamicQuizApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late String _activeThemeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeThemeId = _themeSignature();
    ProgressionService.instance.addListener(_onThemeCheck);
    ProfileService.instance.addListener(_onThemeCheck);
    CmsCacheService.instance.addListener(_onCmsUpdated);
  }

  String _themeSignature() {
    final t = ProgressionService.instance.activeTheme;
    return '${t.themeId}|${t.deepBackground.toARGB32()}|${t.surfaceCard.toARGB32()}|${t.sovereignAccent.toARGB32()}';
  }

  void _onThemeCheck() {
    final nextSig = _themeSignature();
    if (nextSig != _activeThemeId && mounted) {
      setState(() {
        _activeThemeId = nextSig;
      });
    }
  }

  void _onCmsUpdated() {
    if (mounted) {
      setState(() {
        _activeThemeId = _themeSignature();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppControlService.instance.refreshTimedVisualState();
      AppControlService.instance.startLivePingIfEnabled();
      unawaited(AppControlService.instance.syncControlState());
      if (!AppControlCoordinator.instance.isAppReadyForGates) return;
      final navContext = _navigatorKey.currentState?.overlay?.context;
      if (navContext != null && navContext.mounted) {
        unawaited(
          AppControlCoordinator.instance.checkAndPresent(
            navContext,
            allowOptionalUpdate: false,
          ),
        );
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(AppControlService.instance.stopLivePing());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(AppControlService.instance.stopLivePing());
    ProgressionService.instance.removeListener(_onThemeCheck);
    ProfileService.instance.removeListener(_onThemeCheck);
    CmsCacheService.instance.removeListener(_onCmsUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCustomTheme = ProgressionService.instance.activeTheme;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'معركة أحفاد الصحابة',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getThemeFor(activeCustomTheme),
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOutCubic,
      locale: const Locale('ar', 'SA'),
      onGenerateRoute: AppRoutes.generateRoute,
      initialRoute: AppRoutes.splash,
      builder: (context, child) {
        // تثبيت حجم الخط لمنع تشوه التصميم عند تغيير إعدادات النظام
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );
  }
}
