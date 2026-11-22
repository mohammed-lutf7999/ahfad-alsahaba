import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_control_service.dart';

/// Shared base class for [AdminService] domain mixins providing safe Supabase
/// access, cloud admin status caching, and REST live broadcast helpers.
abstract class AdminServiceBase {
  static const String _primaryAdminEmail = 'dia666111@gmail.com';
  bool? _cloudVerifiedAdmin;

  @visibleForTesting
  Future<void> Function(
    String sessionId,
    List<Map<String, dynamic>> leaderboard,
  )? liveArenaFinishBroadcasterOverride;

  @protected
  void resetBaseForTesting() {
    _cloudVerifiedAdmin = null;
    liveArenaFinishBroadcasterOverride = null;
  }

  @protected
  SupabaseClient? get supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Synchronous best-known admin flag combining cloud verification & signed-in email.
  bool get isAdmin {
    if (_cloudVerifiedAdmin != null) return _cloudVerifiedAdmin!;
    final user = supabaseClient?.auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    return user != null && email == _primaryAdminEmail;
  }

  /// Verifies admin authorization live against `public.check_is_admin()` RPC.
  Future<bool> refreshAdminStatus() async {
    final client = supabaseClient;
    if (client == null || client.auth.currentUser == null) {
      _cloudVerifiedAdmin = false;
      AppControlService.instance.setAdminStatus(false);
      return false;
    }
    try {
      final res = await client
          .rpc('check_is_admin')
          .timeout(const Duration(seconds: 5));
      final verified = res == true;
      _cloudVerifiedAdmin = verified;
      AppControlService.instance.setAdminStatus(verified);
      return verified;
    } catch (e) {
      debugPrint('Error refreshing admin status: $e');
      return isAdmin;
    }
  }

  /// Clears cached cloud verification cleanly (e.g. on sign-out).
  void clearCachedAdminStatus() {
    _cloudVerifiedAdmin = null;
    AppControlService.instance.setAdminStatus(false);
  }

  /// Broadcasts an immediate `finish` event over REST `httpSend` on `live_arena_<sessionId>`
  /// (never gated by `liveAnnouncementPing` because participants are already on the arena channel).
  Future<void> broadcastLiveArenaFinish({
    required String sessionId,
    List<Map<String, dynamic>> leaderboard = const [],
  }) async {
    final cleanId = sessionId.trim();
    if (cleanId.isEmpty) return;
    if (liveArenaFinishBroadcasterOverride != null) {
      await liveArenaFinishBroadcasterOverride!(cleanId, leaderboard);
      return;
    }
    final client = supabaseClient;
    if (client == null) return;
    try {
      final ch = client.channel('live_arena_$cleanId');
      await ch.httpSend(
        event: 'arena_event',
        payload: {
          'type': 'finish',
          'question_index': 999,
          'leaderboard': leaderboard,
        },
        timeout: const Duration(seconds: 4),
      );
    } catch (e) {
      debugPrint('AdminService broadcastLiveArenaFinish notice: $e');
    }
  }

  void syncAndBroadcastAll() {
    unawaited(AppControlService.instance.syncControlState(force: true));
    unawaited(broadcastControlPing(targetCode: 'ALL'));
  }

  /// Emits a non-blocking silent sync ping on `app_control_live` over REST (`httpSend`)
  /// so active foreground clients pull fresh state in `<1s` with zero socket churn.
  Future<void> broadcastControlPing({
    String targetCode = 'ALL',
    String? targetUserId,
  }) async {
    if (!AppControlService
        .instance.featureFlagsNotifier.value.liveAnnouncementPing) {
      return;
    }
    final client = supabaseClient;
    if (client == null) return;
    try {
      final ch = client.channel('app_control_live');
      await ch.httpSend(
        event: 'control_ping',
        payload: {
          'target_code': targetCode.trim().toUpperCase(),
          if (targetUserId != null && targetUserId.trim().isNotEmpty)
            'target_user_id': targetUserId.trim(),
          'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        timeout: const Duration(seconds: 4),
      );
    } catch (e) {
      debugPrint('AdminService broadcastControlPing notice: $e');
    }
  }

  /// Get all users from leaderboard (for email list)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final client = supabaseClient;
    if (client == null) return [];
    try {
      final response = await client
          .from('leaderboard')
          .select('display_name, email, score, created_at')
          .order('created_at', ascending: false)
          .limit(500);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  /// Send broadcast email via Edge Function
  Future<bool> sendBroadcast({
    required List<String> emails,
    required String subject,
    required String message,
  }) async {
    final client = supabaseClient;
    if (client == null) return false;
    try {
      await client.functions.invoke(
        'admin-broadcast',
        body: {
          'recipients': emails,
          'subject': subject,
          'message': message,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
      return false;
    }
  }
}
