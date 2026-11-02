import '../local/shared_prefs_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import 'profile_service.dart';

/// Result of an authentication operation.
class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;
  final bool shouldNavigateToSetup;

  AuthResult._({
    required this.success, 
    this.errorMessage, 
    this.user,
    this.shouldNavigateToSetup = false,
  });

  factory AuthResult.success(User user) => AuthResult._(success: true, user: user);
  factory AuthResult.error(String message) => AuthResult._(success: false, errorMessage: message);
  factory AuthResult.signedOut() => AuthResult._(success: true, shouldNavigateToSetup: true);
}

/// Service for handling authentication with Google and Supabase.
/// Extends ChangeNotifier to notify UI of auth state changes.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  AuthService._internal() {
    // Listen to Supabase auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      debugPrint('Auth state changed: ${data.event}');
      notifyListeners();
    });
  }

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;




  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Initialize Google Sign-In with Web Client ID
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: SupabaseConfig.googleWebClientId,
      );

      // Sign out first to ensure account picker shows
      await googleSignIn.signOut();

      // Trigger the sign-in flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        return AuthResult.error('تم إلغاء تسجيل الدخول');
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult.error('فشل في استرجاع معلومات المصادقة');
      }

      // Sign in to Supabase with the Google ID token (with timeout)
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      ).timeout(const Duration(seconds: 20), onTimeout: () {
        throw AuthException('انتهت مهلة الاتصال بالخادم. تحقق من الإنترنت.');
      });

      if (response.user == null) {
        return AuthResult.error('فشل في تسجيل الدخول');
      }

      // Create or load user-specific profile
      final displayName = response.user!.userMetadata?['full_name'] ?? 
                         response.user!.userMetadata?['name'] ?? 
                         'لاعب';
      
      await ProfileService.instance.createOrLoadProfileForUser(
        userId: response.user!.id,
        displayName: displayName,
      );

      // Notify listeners immediately so UI updates
      notifyListeners();

      // Perform background tasks (Sync & Email) without blocking UI
      // We don't await these for the return, but we catch errors specifically
      Future.wait([
        syncProfileToCloud().catchError((e) => debugPrint('Background sync error: $e')),
        _sendWelcomeEmail(response.user!).catchError((e) => debugPrint('Background email error: $e')),
      ]);

      return AuthResult.success(response.user!);
    } on PlatformException catch (e) {
      debugPrint('PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'channel-error') {
        return AuthResult.error('خطأ في الاتصال. يرجى التأكد من إعدادات Google Services وتشغيل VPN إذا لزم الأمر');
      }
      return AuthResult.error('خطأ في المنصة: ${e.message}');
    } on SocketException {
      return AuthResult.error('لا يوجد اتصال بالإنترنت. تحقق من الشبكة');
    } on AuthException catch (e) {
      return AuthResult.error('خطأ في المصادقة: ${e.message}');
    } on TimeoutException {
      return AuthResult.error('انتهت مهلة الاتصال. الانترنت بطيء');
    } catch (e) {
      debugPrint('Unknown error: $e');
      if (e.toString().contains('SocketException') || e.toString().contains('connection abort')) {
        return AuthResult.error('فشل الاتصال بالخادم. تحقق من الإنترنت');
      }
      return AuthResult.error('حدث خطأ غير متوقع');
    }
  }

  /// Sync local profile to Supabase leaderboard - PUBLIC method
  Future<void> syncProfileToCloud() async {
    final user = currentUser;
    if (user == null) return;
    
    try {
      // Get active local profile
      final activeProfile = ProfileService.instance.activeProfile;
      
      String displayName = activeProfile?.name ?? 
                          user.userMetadata?['full_name'] ?? 
                          user.userMetadata?['name'] ?? 
                          'لاعب';
      
      int score = activeProfile?.totalScore ?? 0;

      // Check if user exists in leaderboard
      final existing = await _supabase
          .from('leaderboard')
          .select('id, score')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        // Update profile data - keep higher score
        final currentScore = existing['score'] as int? ?? 0;
        await _supabase
            .from('leaderboard')
            .update({
              'display_name': displayName,
              'avatar_url': user.userMetadata?['avatar_url'],
              'score': score > currentScore ? score : currentScore,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', user.id);
      } else {
        // Create new leaderboard entry
        await _supabase.from('leaderboard').insert({
          'user_id': user.id,
          'display_name': displayName,
          'email': user.email,
          'avatar_url': user.userMetadata?['avatar_url'],
          'score': score,
          'country_code': 'XX',
        });
      }
      
      debugPrint('Profile synced to cloud: $displayName, score: $score');
    } catch (e) {
      debugPrint('Failed to sync profile: $e');
    }
  }

  /// Update user score in leaderboard - call after game completion
  Future<bool> updateScoreToCloud(int newScore) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final activeProfile = ProfileService.instance.activeProfile;
      
      // Get current score from cloud
      final existing = await _supabase
          .from('leaderboard')
          .select('score')
          .eq('user_id', user.id)
          .maybeSingle();
      
      final cloudScore = existing?['score'] as int? ?? 0;
      final finalScore = newScore > cloudScore ? newScore : cloudScore;
      
      await _supabase
          .from('leaderboard')
          .upsert({
            'user_id': user.id,
            'display_name': activeProfile?.name ?? userDisplayName,
            'email': user.email,
            'avatar_url': user.userMetadata?['avatar_url'],
            'score': finalScore,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');
      
      debugPrint('Score updated to cloud: $finalScore');
      return true;
    } catch (e) {
      debugPrint('Failed to update score: $e');
      return false;
    }
  }

  /// Send welcome email via Edge Function
  Future<void> _sendWelcomeEmail(User user) async {
    try {
      await _supabase.functions.invoke(
        'welcome-email',
        body: {
          'email': user.email,
          'name': user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? 'عزيزي',
        },
      );
    } catch (e) {
      // Silently fail - welcome email is not critical
      debugPrint('Failed to send welcome email: $e');
    }
  }

  /// Sign out and clear local profile data
  /// IMPORTANT: Syncs data to cloud BEFORE clearing local storage
  /// Returns AuthResult with shouldNavigateToSetup = true
  Future<AuthResult> signOut() async {
    try {
      // CRITICAL: Sync and then clear local profile data
      // This ensures data is saved to cloud before sign-out
      await ProfileService.instance.syncAndClearProfile();
      
      // Sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      
      // Sign out from Supabase
      await _supabase.auth.signOut();
      
      // Notify listeners
      notifyListeners();
      
      return AuthResult.signedOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      return AuthResult.error('حدث خطأ أثناء تسجيل الخروج');
    }
  }

  /// Get user display name (prefer local profile, fallback to Google name)
  String get userDisplayName {
    // Prefer local profile name
    final activeProfile = ProfileService.instance.activeProfile;
    if (activeProfile != null && activeProfile.name.isNotEmpty) {
      return activeProfile.name;
    }
    
    // Fallback to Google metadata
    final metadata = currentUser?.userMetadata;
    if (metadata != null) {
      final googleName = metadata['full_name'] ?? metadata['name'];
      if (googleName != null && googleName.toString().isNotEmpty) {
        return googleName.toString();
      }
    }
    
    return 'مستخدم';
  }

  /// Get user email
  String? get userEmail => currentUser?.email;

  /// Get user avatar URL from Google
  String? get userAvatarUrl => currentUser?.userMetadata?['avatar_url'];

  /// Delete user account and associated cloud data (Google Play Policy Compliance)
  Future<bool> deleteAccountAndData() async {
    try {
      final user = currentUser;
      if (user != null) {
        try {
          await _supabase.from('user_progress').delete().eq('user_id', user.id);
        } catch (_) {}
        try {
          await _supabase.from('leaderboard').delete().eq('user_id', user.id);
        } catch (_) {}
        try {
          await _supabase.from('matchmaking_queue').delete().eq('user_id', user.id);
        } catch (_) {}
      }

      await SharedPrefsService.resetAllProgress();
      await ProfileService.instance.clearAllProfiles();

      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      } catch (_) {}
      try {
        await _supabase.auth.signOut();
      } catch (_) {}

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete account error: $e');
      return false;
    }
  }
}
