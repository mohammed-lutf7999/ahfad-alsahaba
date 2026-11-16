import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/services/achievement_service.dart';
import '../data/services/admin_service.dart';
import '../data/services/app_control_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/profile_service.dart';
import 'supabase_config.dart';

/// Coordinates non-blocking Local-First / Stale-While-Revalidate (SWR) startup
/// initialization so the first frame paints immediately without network waits.
class StartupBootstrap {
  StartupBootstrap._();

  static Future<bool>? _supabaseInitFuture;
  static Future<void>? _backgroundSyncFuture;
  static bool _supabaseReady = false;

  /// Returns `true` when Supabase is already initialized and safe to query.
  static bool get isSupabaseReady {
    if (_supabaseReady) return true;
    try {
      Supabase.instance.client;
      _supabaseReady = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Initializes Supabase once, coalescing concurrent callers without throwing.
  static Future<bool> initSupabase() {
    if (isSupabaseReady) {
      AuthService().bindAuthStateListenerIfReady();
      return Future<bool>.value(true);
    }

    _supabaseInitFuture ??= _runSupabaseInit();
    return _supabaseInitFuture!;
  }

  static Future<bool> _runSupabaseInit() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _supabaseReady = true;
      AuthService().bindAuthStateListenerIfReady();
      return true;
    } catch (e) {
      debugPrint('StartupBootstrap Supabase init error: $e');
      _supabaseInitFuture = null;
      return false;
    }
  }

  /// Ensures Supabase is ready before executing cloud/auth operations.
  static Future<bool> ensureSupabaseReady() {
    if (isSupabaseReady) return Future<bool>.value(true);
    return initSupabase();
  }

  /// Background SWR cloud reconciliation (AGENTS.md Rule 3):
  /// Merges logged-in cloud progress with local profile without blocking UI.
  static Future<void> runBackgroundStartupSync() {
    _backgroundSyncFuture ??= _performBackgroundStartupSync().whenComplete(() {
      _backgroundSyncFuture = null;
    });
    return _backgroundSyncFuture!;
  }

  static Future<void> _performBackgroundStartupSync() async {
    final ready = await ensureSupabaseReady();
    if (!ready) return;

    try {
      final user = AuthService().currentUser;
      if (user != null) {
        final displayName = user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            'لاعب';
        await ProfileService.instance
            .createOrLoadProfileForUser(
              userId: user.id,
              displayName: displayName.toString(),
            )
            .timeout(const Duration(seconds: 6));
        unawaited(AdminService().refreshAdminStatus());
      }
      await AchievementService.instance.reconcileAchievements();
      unawaited(AppControlService.instance.syncPlayerDirectory());
      unawaited(AppControlService.instance.syncControlState());
    } catch (e) {
      debugPrint('StartupBootstrap background sync notice: $e');
    }
  }
}

