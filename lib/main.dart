import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/app_routes.dart';
import 'core/supabase_config.dart';
import 'data/local/shared_prefs_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/profile_service.dart';
import 'data/services/progression_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences with error handling
  try {
    await SharedPrefsService.init();
  } catch (e) {
    debugPrint('SharedPrefsService init error: $e');
  }
  
  // Initialize ProfileService
  try {
    await ProfileService.instance.init();
  } catch (e) {
    debugPrint('ProfileService init error: $e');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  // Initialize Notification Service with error handling
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  // Set preferred orientations
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('setPreferredOrientations error: $e');
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const IslamicQuizApp());
}

class IslamicQuizApp extends StatelessWidget {
  const IslamicQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ProgressionService.instance,
        ProfileService.instance,
      ]),
      builder: (context, _) {
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
      },
    );
  }
}
