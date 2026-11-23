import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_control_models.dart';
import 'admin_service_base.dart';

/// Admin domain mixin for Diwan reports/mutes moderation and Guild/Live Arena
/// administrative controls.
mixin AdminModerationMixin on AdminServiceBase {
  @visibleForTesting
  Future<AdminDiwanModerationQueue?> Function({int limit})?
      diwanQueueFetcherOverride;

  @visibleForTesting
  Future<Map<String, dynamic>?> Function({
    required String action,
    String? messageId,
    String? targetUserId,
    int muteHours,
    required String reason,
  })? diwanModeratorOverride;

  @visibleForTesting
  Future<AdminGuildsAndArenasSnapshot?> Function({int limit})?
      guildsArenasFetcherOverride;

  @visibleForTesting
  Future<Map<String, dynamic>?> Function({
    required String action,
    required String targetId,
    required String reason,
  })? guildArenaModeratorOverride;

  @protected
  void resetModerationForTesting() {
    diwanQueueFetcherOverride = null;
    diwanModeratorOverride = null;
    guildsArenasFetcherOverride = null;
    guildArenaModeratorOverride = null;
  }

  Future<AdminDiwanModerationQueue> getDiwanModerationQueue({
    int limit = 50,
  }) async {
    if (diwanQueueFetcherOverride != null) {
      return (await diwanQueueFetcherOverride!(limit: limit)) ??
          const AdminDiwanModerationQueue();
    }
    final client = supabaseClient;
    if (client == null) return const AdminDiwanModerationQueue();
    final res = await client.rpc(
      'admin_list_diwan_moderation_queue',
      params: {'p_limit': limit.clamp(1, 100)},
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      return AdminDiwanModerationQueue.fromJson(Map<String, dynamic>.from(res));
    }
    return const AdminDiwanModerationQueue();
  }

  /// Executes Diwan moderation (`delete_message`, `dismiss_reports`, `mute_user`, `unmute_user`, `cleanup_24h`).
  Future<Map<String, dynamic>?> moderateDiwan({
    required String action,
    String? messageId,
    String? targetUserId,
    int muteHours = 24,
    String reason = '',
  }) async {
    final cleanAction = action.trim().toLowerCase();
    Map<String, dynamic>? result;
    if (diwanModeratorOverride != null) {
      result = await diwanModeratorOverride!(
        action: cleanAction,
        messageId: messageId,
        targetUserId: targetUserId,
        muteHours: muteHours,
        reason: reason,
      );
    } else {
      final client = supabaseClient;
      if (client == null) return null;
      final res = await client.rpc(
        'admin_moderate_diwan',
        params: {
          'p_action': cleanAction,
          if (messageId != null && messageId.trim().isNotEmpty)
            'p_message_id': messageId.trim(),
          if (targetUserId != null && targetUserId.trim().isNotEmpty)
            'p_target_user_id': targetUserId.trim(),
          'p_mute_hours': muteHours.clamp(1, 720),
          'p_reason': reason.trim(),
        },
      ).timeout(const Duration(seconds: 6));
      if (res is Map) {
        result = Map<String, dynamic>.from(res);
      }
    }
    if (result != null &&
        (cleanAction == 'mute_user' || cleanAction == 'unmute_user') &&
        targetUserId != null &&
        targetUserId.trim().isNotEmpty) {
      final playerCode = result['player_code']?.toString();
      unawaited(
        broadcastControlPing(
          targetCode:
              (playerCode != null && playerCode.trim().isNotEmpty)
                  ? playerCode.trim()
                  : 'SINGLE',
          targetUserId: targetUserId.trim(),
        ),
      );
    }
    return result;
  }

  /// Lists active Guilds & Live Quiz Arena sessions (`admin_list_guilds_and_arenas`).
  Future<AdminGuildsAndArenasSnapshot> listGuildsAndArenas({
    int limit = 50,
  }) async {
    if (guildsArenasFetcherOverride != null) {
      return (await guildsArenasFetcherOverride!(limit: limit)) ??
          const AdminGuildsAndArenasSnapshot();
    }
    final client = supabaseClient;
    if (client == null) return const AdminGuildsAndArenasSnapshot();
    final res = await client.rpc(
      'admin_list_guilds_and_arenas',
      params: {'p_limit': limit.clamp(1, 100)},
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      return AdminGuildsAndArenasSnapshot.fromJson(
        Map<String, dynamic>.from(res),
      );
    }
    return const AdminGuildsAndArenasSnapshot();
  }

  /// Moderates a Guild or Live Arena (`delete_guild`, `reset_single_guild_score`,
  /// `force_finish_session`, `delete_session`). On `force_finish_session`, immediately
  /// broadcasts a `finish` event over REST `httpSend` on `live_arena_<targetId>`
  /// so connected Host and Students exit the active round immediately.
  Future<Map<String, dynamic>?> moderateGuildOrArena({
    required String action,
    required String targetId,
    String reason = '',
  }) async {
    final cleanAction = action.trim().toLowerCase();
    final cleanTarget = targetId.trim();
    Map<String, dynamic>? result;
    if (guildArenaModeratorOverride != null) {
      result = await guildArenaModeratorOverride!(
        action: cleanAction,
        targetId: cleanTarget,
        reason: reason,
      );
    } else {
      final client = supabaseClient;
      if (client == null) return null;
      final res = await client.rpc(
        'admin_moderate_guild_or_arena',
        params: {
          'p_action': cleanAction,
          'p_target_id': cleanTarget,
          'p_reason': reason.trim(),
        },
      ).timeout(const Duration(seconds: 6));
      if (res is Map) {
        result = Map<String, dynamic>.from(res);
      }
    }

    if (result != null && cleanAction == 'force_finish_session') {
      final lbRaw = result['leaderboard'];
      final leaderboard = lbRaw is List
          ? lbRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const <Map<String, dynamic>>[];
      await broadcastLiveArenaFinish(
        sessionId: cleanTarget,
        leaderboard: leaderboard,
      );
    }
    return result;
  }
}
