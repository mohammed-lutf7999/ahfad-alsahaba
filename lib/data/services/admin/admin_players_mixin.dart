import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_control_models.dart';
import 'admin_service_base.dart';

/// Admin domain mixin for player directory search, dossier inspection,
/// capped compensations, bans, and individual player permissions.
mixin AdminPlayersMixin on AdminServiceBase {
  @visibleForTesting
  Future<List<AdminPlayerSearchResult>> Function({
    required String query,
    int limit,
  })? userSearcherOverride;

  @visibleForTesting
  Future<AdminPlayerDetail?> Function({String? userId, String? playerCode})?
      playerDetailFetcherOverride;

  @visibleForTesting
  Future<Map<String, dynamic>?> Function({
    required String userId,
    required int coinsDelta,
    required int gemsDelta,
    required int xpDelta,
    required String reason,
  })? playerCompensationOverride;

  @visibleForTesting
  Future<Map<String, dynamic>?> Function({
    required String userId,
    required bool isBanned,
    int? banHours,
    required String banReason,
    required bool canUseOnline,
    required bool canUseDiwan,
    required bool canUseGuilds,
    bool? canHostLiveArenas,
    required String notes,
  })? playerPermissionsUpserterOverride;

  @protected
  void resetPlayersForTesting() {
    userSearcherOverride = null;
    playerDetailFetcherOverride = null;
    playerCompensationOverride = null;
    playerPermissionsUpserterOverride = null;
  }

  Future<List<AdminPlayerSearchResult>> searchUsers({
    String query = '',
    int limit = 20,
  }) async {
    if (userSearcherOverride != null) {
      return userSearcherOverride!(query: query, limit: limit);
    }
    final client = supabaseClient;
    if (client == null) return [];
    final res = await client.rpc(
      'admin_search_users',
      params: {
        'p_query': query.trim(),
        'p_limit': limit.clamp(1, 20),
      },
    ).timeout(const Duration(seconds: 5));
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) =>
              AdminPlayerSearchResult.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<AdminPlayerDetail?> getPlayerDetail({
    String? userId,
    String? playerCode,
  }) async {
    if (playerDetailFetcherOverride != null) {
      return playerDetailFetcherOverride!(
        userId: userId,
        playerCode: playerCode,
      );
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client.rpc(
      'admin_get_player_detail',
      params: {
        'p_user_id': userId,
        'p_player_code': playerCode?.trim().toUpperCase(),
      },
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      return AdminPlayerDetail.fromJson(Map<String, dynamic>.from(res));
    }
    return null;
  }

  Future<Map<String, dynamic>?> grantPlayerCompensation({
    required String userId,
    int coinsDelta = 0,
    int gemsDelta = 0,
    int xpDelta = 0,
    required String reason,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('معرّف اللاعب مطلوب لمنح التعويض');
    }
    if (coinsDelta < 0 ||
        coinsDelta > 10000 ||
        gemsDelta < 0 ||
        gemsDelta > 100 ||
        xpDelta < 0 ||
        xpDelta > 5000) {
      throw RangeError('تجاوزت الحدود القصوى المسموحة للتعويض');
    }
    if (coinsDelta == 0 && gemsDelta == 0 && xpDelta == 0) {
      throw ArgumentError('يجب إدخال قيمة واحدة على الأقل للتعويض');
    }
    final cleanedReason = reason.trim();
    if (cleanedReason.length < 3) {
      throw ArgumentError('سبب التعويض مطلوب (3 أحرف على الأقل)');
    }
    if (playerCompensationOverride != null) {
      return playerCompensationOverride!(
        userId: userId.trim(),
        coinsDelta: coinsDelta,
        gemsDelta: gemsDelta,
        xpDelta: xpDelta,
        reason: cleanedReason,
      );
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client.rpc(
      'admin_grant_player_compensation',
      params: {
        'p_user_id': userId.trim(),
        'p_coins_delta': coinsDelta,
        'p_gems_delta': gemsDelta,
        'p_xp_delta': xpDelta,
        'p_reason': cleanedReason,
      },
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      final result = Map<String, dynamic>.from(res);
      final targetCode = (result['player_code'] ?? '').toString().trim();
      unawaited(
        broadcastControlPing(
          targetCode: targetCode.isNotEmpty ? targetCode : 'SINGLE',
          targetUserId: userId.trim(),
        ),
      );
      return result;
    }
    return null;
  }

  Future<Map<String, dynamic>?> upsertPlayerPermissions({
    required String userId,
    required bool isBanned,
    int? banHours,
    String banReason = '',
    bool canUseOnline = true,
    bool canUseDiwan = true,
    bool canUseGuilds = true,
    bool? canHostLiveArenas,
    String notes = '',
  }) async {
    Map<String, dynamic>? result;
    if (playerPermissionsUpserterOverride != null) {
      result = await playerPermissionsUpserterOverride!(
        userId: userId,
        isBanned: isBanned,
        banHours: banHours,
        banReason: banReason,
        canUseOnline: canUseOnline,
        canUseDiwan: canUseDiwan,
        canUseGuilds: canUseGuilds,
        canHostLiveArenas: canHostLiveArenas,
        notes: notes,
      );
    } else {
      final client = supabaseClient;
      if (client == null) return null;
      final res = await client.rpc(
        'admin_upsert_player_permissions',
        params: {
          'p_user_id': userId.trim(),
          'p_is_banned': isBanned,
          'p_ban_hours': banHours,
          'p_ban_reason': banReason.trim(),
          'p_can_use_online': canUseOnline,
          'p_can_use_diwan': canUseDiwan,
          'p_can_use_guilds': canUseGuilds,
          'p_can_host_live_arenas': canHostLiveArenas,
          'p_notes': notes.trim(),
        },
      ).timeout(const Duration(seconds: 6));
      if (res is Map) {
        result = Map<String, dynamic>.from(res);
      }
    }
    if (result != null) {
      final playerCode = result['player_code']?.toString();
      unawaited(
        broadcastControlPing(
          targetCode:
              (playerCode != null && playerCode.trim().isNotEmpty)
                  ? playerCode.trim()
                  : 'SINGLE',
          targetUserId: userId.trim(),
        ),
      );
    }
    return result;
  }
}
