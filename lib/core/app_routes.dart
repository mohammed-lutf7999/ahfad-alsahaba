import 'package:flutter/material.dart';
import '../ui/screens/splash_screen.dart';
import '../ui/screens/onboarding_screen.dart'; 
import '../ui/screens/home_screen.dart';
import '../ui/screens/categories_screen.dart';
import '../ui/screens/levels_screen.dart';
import '../ui/screens/quiz_screen.dart';
import '../ui/screens/result_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/profile_setup_screen.dart';
import '../ui/screens/profile_selector_screen.dart';
import '../ui/screens/achievements_screen.dart';
import '../ui/screens/multiplayer/challenge_menu_screen.dart';
import '../ui/screens/multiplayer/private_room_hub_screen.dart';
import '../ui/screens/glory/glory_road_screen.dart';
import '../ui/screens/store/knights_store_screen.dart';
import '../data/models/player_profile_model.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String categories = '/categories';
  static const String levels = '/levels';
  static const String quiz = '/quiz';
  static const String result = '/result';
  static const String settings = '/settings';
  static const String profileSetup = '/profile-setup';
  static const String profileSelector = '/profile-selector';
  static const String achievements = '/achievements';
  static const String challenge = '/challenge';
  static const String privateRoomHub = '/private-room-hub';
  static const String gloryRoad = '/glory-road';
  static const String knightsStore = '/knights-store';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fadeRoute(const SplashScreen(), settings);
      case onboarding:
        return _fadeRoute(const OnboardingScreen(), settings);
      case home:
        return _fadeRoute(const HomeScreen(), settings);
      case categories:
        return _slideRoute(const CategoriesScreen(), settings);
      case levels:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(
          LevelsScreen(
            categoryId: args['categoryId'],

          ),
          settings,
        );
      case quiz:
        final args = settings.arguments as Map<String, dynamic>;
        return _slideRoute(
          QuizScreen(
            categoryId: args['categoryId'],
            levelId: args['levelId'],
            levelNumber: args['levelNumber'],
          ),
          settings,
        );
      case result:
        final args = settings.arguments as Map<String, dynamic>;
        return _fadeRoute(
          ResultScreen(
            correctAnswers: args['correctAnswers'],
            totalQuestions: args['totalQuestions'],
            totalScore: args['totalScore'],
            categoryId: args['categoryId'],
            levelId: args['levelId'],
            userAnswers: args['userAnswers'],
          ),
          settings,
        );
      case AppRoutes.settings:
        return _slideRoute(const SettingsScreen(), settings);
      case profileSetup:
        final args = settings.arguments as Map<String, dynamic>?;
        PlayerProfile? existingProfile;
        bool isFirstTime = false;
        if (args != null) {
          existingProfile = args['existingProfile'] as PlayerProfile?;
          isFirstTime = args['isFirstTime'] as bool? ?? false;
        }
        return _fadeRoute(
          ProfileSetupScreen(
            existingProfile: existingProfile,
            isFirstTime: isFirstTime,
          ),
          settings,
        );
      case profileSelector:
        return _slideRoute(const ProfileSelectorScreen(), settings);
      case achievements:
        return _slideRoute(const AchievementsScreen(), settings);
      case challenge:
        return _slideRoute(const ChallengeMenuScreen(), settings);
      case privateRoomHub:
        return _slideRoute(const PrivateRoomHubScreen(), settings);
      case gloryRoad:
        return _slideRoute(const GloryRoadScreen(), settings);
      case knightsStore:
        return _slideRoute(const KnightsStoreScreen(), settings);
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('صفحة غير موجودة'))),
        );
    }
  }

  static PageRouteBuilder _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static PageRouteBuilder _slideRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
