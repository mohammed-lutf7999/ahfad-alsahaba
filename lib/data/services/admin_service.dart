import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_control_models.dart';
import 'app_control_service.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  static const String _primaryAdminEmail = 'dia666111@gmail.com';
  bool? _cloudVerifiedAdmin;

  @visibleForTesting
  Future<AdminOverview?> Function()? overviewFetcherOverride;

  @visibleForTesting
  Future<AppReleaseConfig?> Function({
    required String platform,
    required int minVersionCode,
    required int latestVersionCode,
    required String latestVersionName,
    required String updateTitle,
    required String updateMessage,
    String? updateUrl,
    required bool maintenanceMode,
    required String maintenanceTitle,
    required String maintenanceMessage,
    Map<String, dynamic>? featureFlags,
  })? releaseConfigSaverOverride;

  @visibleForTesting
  Future<List<AppDynamicEvent>> Function()? eventsFetcherOverride;

  @visibleForTesting
  Future<AppDynamicEvent?> Function({
    String? id,
    required String badgeText,
    required String title,
    required String subtitle,
    required String body,
    required String ctaLabel,
    required DynamicEventActionType actionType,
    required String actionTarget,
    required String themeColorHex,
    required String iconName,
    required int priority,
    required bool isActive,
    DateTime? startsAt,
    DateTime? endsAt,
  })? eventUpserterOverride;

  @visibleForTesting
  Future<AppDynamicEvent?> Function(String eventId, bool isActive)?
      eventTogglerOverride;

  @visibleForTesting
  Future<bool> Function(String eventId)? eventDeleterOverride;

  @visibleForTesting
  Future<List<AppAnnouncement>> Function({int limit})?
      announcementsFetcherOverride;

  @visibleForTesting
  Future<AppAnnouncement?> Function({
    required String title,
    required String body,
    required AnnouncementType messageType,
    required String targetScope,
    String? targetUserId,
    String? targetPlayerCode,
    String? ctaLabel,
    String? ctaRoute,
    required bool isDismissible,
    DateTime? expiresAt,
    int? minVersionCode,
    int? maxVersionCode,
  })? announcementCreatorOverride;

  @visibleForTesting
  Future<bool> Function(String announcementId, bool isActive)?
      announcementStatusSetterOverride;

  @visibleForTesting
  Future<List<AdminPlayerSearchResult>> Function({
    required String query,
    int limit,
  })? userSearcherOverride;

  @visibleForTesting
  void resetForTesting() {
    _cloudVerifiedAdmin = null;
    overviewFetcherOverride = null;
    releaseConfigSaverOverride = null;
    eventsFetcherOverride = null;
    eventUpserterOverride = null;
    eventTogglerOverride = null;
    eventDeleterOverride = null;
    announcementsFetcherOverride = null;
    announcementCreatorOverride = null;
    announcementStatusSetterOverride = null;
    userSearcherOverride = null;
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Synchronous best-known admin flag combining cloud verification & signed-in email.
  bool get isAdmin {
    if (_cloudVerifiedAdmin != null) return _cloudVerifiedAdmin!;
    final user = _supabase?.auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    return user != null && email == _primaryAdminEmail;
  }

  /// Verifies admin authorization live against `public.check_is_admin()` RPC.
  Future<bool> refreshAdminStatus() async {
    final client = _supabase;
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

  // ==================== APP CONTROL RPCS (MIGRATION 015) ====================

  Future<AdminOverview?> getOverview() async {
    if (overviewFetcherOverride != null) {
      return overviewFetcherOverride!();
    }
    final client = _supabase;
    if (client == null) return null;
    try {
      final res = await client
          .rpc('admin_get_overview')
          .timeout(const Duration(seconds: 5));
      if (res is Map) {
        return AdminOverview.fromJson(Map<String, dynamic>.from(res));
      }
      return null;
    } catch (e) {
      debugPrint('Error loading admin overview: $e');
      rethrow;
    }
  }

  Future<AppReleaseConfig?> upsertReleaseConfig({
    String platform = 'android',
    required int minVersionCode,
    required int latestVersionCode,
    required String latestVersionName,
    required String updateTitle,
    required String updateMessage,
    String? updateUrl,
    required bool maintenanceMode,
    required String maintenanceTitle,
    required String maintenanceMessage,
    Map<String, dynamic>? featureFlags,
  }) async {
    if (releaseConfigSaverOverride != null) {
      return releaseConfigSaverOverride!(
        platform: platform,
        minVersionCode: minVersionCode,
        latestVersionCode: latestVersionCode,
        latestVersionName: latestVersionName,
        updateTitle: updateTitle,
        updateMessage: updateMessage,
        updateUrl: updateUrl,
        maintenanceMode: maintenanceMode,
        maintenanceTitle: maintenanceTitle,
        maintenanceMessage: maintenanceMessage,
        featureFlags: featureFlags,
      );
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client.rpc(
      'admin_upsert_release_config',
      params: {
        'p_platform': platform,
        'p_min_version_code': minVersionCode,
        'p_latest_version_code': latestVersionCode,
        'p_latest_version_name': latestVersionName,
        'p_update_title': updateTitle,
        'p_update_message': updateMessage,
        if (updateUrl != null) 'p_update_url': updateUrl,
        'p_maintenance_mode': maintenanceMode,
        'p_maintenance_title': maintenanceTitle,
        'p_maintenance_message': maintenanceMessage,
        if (featureFlags != null) 'p_feature_flags': featureFlags,
      },
    ).timeout(const Duration(seconds: 5));

    if (res is Map) {
      final config = AppReleaseConfig.fromJson(Map<String, dynamic>.from(res));
      unawaited(AppControlService.instance.syncControlState(force: true));
      return config;
    }
    return null;
  }

  Future<List<AppDynamicEvent>> listDynamicEvents() async {
    if (eventsFetcherOverride != null) {
      return eventsFetcherOverride!();
    }
    final client = _supabase;
    if (client == null) return [];
    final res = await client
        .rpc('admin_list_dynamic_events')
        .timeout(const Duration(seconds: 5));
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => AppDynamicEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<AppDynamicEvent?> upsertDynamicEvent({
    String? id,
    required String badgeText,
    required String title,
    String subtitle = '',
    String body = '',
    String ctaLabel = 'اكتشف الآن',
    DynamicEventActionType actionType = DynamicEventActionType.openEventScreen,
    String actionTarget = '',
    String themeColorHex = '#D4AF37',
    String iconName = 'auto_awesome',
    int priority = 100,
    bool isActive = true,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    if (eventUpserterOverride != null) {
      return eventUpserterOverride!(
        id: id,
        badgeText: badgeText,
        title: title,
        subtitle: subtitle,
        body: body,
        ctaLabel: ctaLabel,
        actionType: actionType,
        actionTarget: actionTarget,
        themeColorHex: themeColorHex,
        iconName: iconName,
        priority: priority,
        isActive: isActive,
        startsAt: startsAt,
        endsAt: endsAt,
      );
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client.rpc(
      'admin_upsert_dynamic_event',
      params: {
        'p_id': id,
        'p_badge_text': badgeText,
        'p_title': title,
        'p_subtitle': subtitle,
        'p_body': body,
        'p_cta_label': ctaLabel,
        'p_action_type': actionType.wireName,
        'p_action_target': actionTarget,
        'p_theme_color_hex': themeColorHex,
        'p_icon_name': iconName,
        'p_priority': priority,
        'p_is_active': isActive,
        'p_starts_at': startsAt?.toUtc().toIso8601String(),
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
      },
    ).timeout(const Duration(seconds: 5));

    if (res is Map) {
      final event = AppDynamicEvent.fromJson(Map<String, dynamic>.from(res));
      unawaited(AppControlService.instance.syncControlState(force: true));
      return event;
    }
    return null;
  }

  Future<AppDynamicEvent?> toggleDynamicEvent(
    String eventId,
    bool isActive,
  ) async {
    if (eventTogglerOverride != null) {
      return eventTogglerOverride!(eventId, isActive);
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client.rpc(
      'admin_toggle_dynamic_event',
      params: {
        'p_event_id': eventId,
        'p_is_active': isActive,
      },
    ).timeout(const Duration(seconds: 5));

    if (res is Map) {
      final event = AppDynamicEvent.fromJson(Map<String, dynamic>.from(res));
      unawaited(AppControlService.instance.syncControlState(force: true));
      return event;
    }
    return null;
  }

  Future<bool> deleteDynamicEvent(String eventId) async {
    if (eventDeleterOverride != null) {
      return eventDeleterOverride!(eventId);
    }
    final client = _supabase;
    if (client == null) return false;
    final res = await client.rpc(
      'admin_delete_dynamic_event',
      params: {'p_event_id': eventId},
    ).timeout(const Duration(seconds: 5));
    final deleted = res == true;
    if (deleted) {
      unawaited(AppControlService.instance.syncControlState(force: true));
    }
    return deleted;
  }

  Future<List<AppAnnouncement>> listAnnouncements({int limit = 50}) async {
    if (announcementsFetcherOverride != null) {
      return announcementsFetcherOverride!(limit: limit);
    }
    final client = _supabase;
    if (client == null) return [];
    final res = await client.rpc(
      'admin_list_announcements',
      params: {'p_limit': limit.clamp(1, 100)},
    ).timeout(const Duration(seconds: 5));
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => AppAnnouncement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<AppAnnouncement?> createAnnouncement({
    required String title,
    required String body,
    AnnouncementType messageType = AnnouncementType.normal,
    String targetScope = 'all',
    String? targetUserId,
    String? targetPlayerCode,
    String? ctaLabel,
    String? ctaRoute,
    bool isDismissible = true,
    DateTime? expiresAt,
    int? minVersionCode,
    int? maxVersionCode,
  }) async {
    if (announcementCreatorOverride != null) {
      return announcementCreatorOverride!(
        title: title,
        body: body,
        messageType: messageType,
        targetScope: targetScope,
        targetUserId: targetUserId,
        targetPlayerCode: targetPlayerCode,
        ctaLabel: ctaLabel,
        ctaRoute: ctaRoute,
        isDismissible: isDismissible,
        expiresAt: expiresAt,
        minVersionCode: minVersionCode,
        maxVersionCode: maxVersionCode,
      );
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client.rpc(
      'admin_create_announcement',
      params: {
        'p_title': title,
        'p_body': body,
        'p_message_type': messageType.wireName,
        'p_target_scope': targetScope,
        'p_target_user_id': targetUserId,
        'p_target_player_code': targetPlayerCode,
        'p_cta_label': ctaLabel,
        'p_cta_route': ctaRoute,
        'p_is_dismissible': isDismissible,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        'p_min_version_code': minVersionCode,
        'p_max_version_code': maxVersionCode,
      },
    ).timeout(const Duration(seconds: 5));

    if (res is Map) {
      final ann = AppAnnouncement.fromJson(Map<String, dynamic>.from(res));
      unawaited(AppControlService.instance.syncControlState(force: true));
      return ann;
    }
    return null;
  }

  Future<bool> setAnnouncementActive(
    String announcementId,
    bool isActive,
  ) async {
    if (announcementStatusSetterOverride != null) {
      return announcementStatusSetterOverride!(announcementId, isActive);
    }
    final client = _supabase;
    if (client == null) return false;
    final res = await client.rpc(
      'admin_set_announcement_active',
      params: {
        'p_announcement_id': announcementId,
        'p_is_active': isActive,
      },
    ).timeout(const Duration(seconds: 5));
    final ok = res == true;
    if (ok) {
      unawaited(AppControlService.instance.syncControlState(force: true));
    }
    return ok;
  }

  Future<List<AdminPlayerSearchResult>> searchUsers({
    String query = '',
    int limit = 20,
  }) async {
    if (userSearcherOverride != null) {
      return userSearcherOverride!(query: query, limit: limit);
    }
    final client = _supabase;
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

  // ==================== LEGACY BROADCAST & EMAIL HELPERS ====================

  /// Fetch dashboard statistics via Edge Function
  Future<Map<String, dynamic>> getStats() async {
    final client = _supabase;
    if (client == null) {
      return {'totalUsers': 0, 'onlineUsers': 0, 'error': 'Supabase not ready'};
    }
    try {
      final response = await client.functions.invoke('admin-stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching admin stats via Edge Function: $e');

      // Fallback: Try client-side count or RPC overview
      try {
        final overview = await getOverview();
        if (overview != null) {
          return {
            'totalUsers': overview.totalAccounts,
            'onlineUsers': overview.active24h,
            'directoryPlayers': overview.directoryPlayers,
            'guestPlayers': overview.guestPlayers,
          };
        }
      } catch (_) {}

      try {
        final countResponse =
            await client.from('leaderboard').count(CountOption.exact);

        return {
          'totalUsers': countResponse,
          'onlineUsers': 0,
          'isFallback': true,
        };
      } catch (fallbackError) {
        debugPrint('Fallback stats failed: $fallbackError');
        return {'totalUsers': 0, 'onlineUsers': 0, 'error': e.toString()};
      }
    }
  }

  /// Get all users from leaderboard (for email list)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final client = _supabase;
    if (client == null) return [];
    try {
      final response = await client
          .from('leaderboard')
          .select('display_name, email, score, created_at')
          .order('created_at', ascending: false);

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
    final client = _supabase;
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
