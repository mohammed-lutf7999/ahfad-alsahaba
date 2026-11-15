import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'core/app_routes.dart';
import 'core/startup_bootstrap.dart';
import 'data/local/shared_prefs_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/profile_service.dart';
import 'data/services/progression_service.dart';

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

class _IslamicQuizAppState extends State<IslamicQuizApp> {
  late String _activeThemeId;

  @override
  void initState() {
    super.initState();
    _activeThemeId = ProgressionService.instance.activeTheme.themeId;
    ProgressionService.instance.addListener(_onThemeCheck);
    ProfileService.instance.addListener(_onThemeCheck);
  }

  void _onThemeCheck() {
    final nextThemeId = ProgressionService.instance.activeTheme.themeId;
    if (nextThemeId != _activeThemeId && mounted) {
      setState(() {
        _activeThemeId = nextThemeId;
      });
    }
  }

  @override
  void dispose() {
    ProgressionService.instance.removeListener(_onThemeCheck);
    ProfileService.instance.removeListener(_onThemeCheck);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCustomTheme = ProgressionService.instance.activeTheme;
    return MaterialApp(
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
