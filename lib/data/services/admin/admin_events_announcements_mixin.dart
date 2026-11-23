import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/app_control_models.dart';
import '../app_control_service.dart';
import 'admin_service_base.dart';

/// Admin domain mixin handling dynamic home events and targeted announcements.
mixin AdminEventsAnnouncementsMixin on AdminServiceBase {
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

  @protected
  void resetEventsAnnouncementsForTesting() {
    eventsFetcherOverride = null;
    eventUpserterOverride = null;
    eventTogglerOverride = null;
    eventDeleterOverride = null;
    announcementsFetcherOverride = null;
    announcementCreatorOverride = null;
    announcementStatusSetterOverride = null;
  }

  Future<List<AppDynamicEvent>> listDynamicEvents() async {
    if (eventsFetcherOverride != null) {
      return eventsFetcherOverride!();
    }
    final client = supabaseClient;
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
    final client = supabaseClient;
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
      syncAndBroadcastAll();
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
    final client = supabaseClient;
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
      syncAndBroadcastAll();
      return event;
    }
    return null;
  }

  Future<bool> deleteDynamicEvent(String eventId) async {
    if (eventDeleterOverride != null) {
      return eventDeleterOverride!(eventId);
    }
    final client = supabaseClient;
    if (client == null) return false;
    final res = await client.rpc(
      'admin_delete_dynamic_event',
      params: {'p_event_id': eventId},
    ).timeout(const Duration(seconds: 5));
    final deleted = res == true;
    if (deleted) {
      syncAndBroadcastAll();
    }
    return deleted;
  }

  Future<List<AppAnnouncement>> listAnnouncements({int limit = 50}) async {
    if (announcementsFetcherOverride != null) {
      return announcementsFetcherOverride!(limit: limit);
    }
    final client = supabaseClient;
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
    final client = supabaseClient;
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
      unawaited(
        broadcastControlPing(
          targetCode: targetScope == 'single_user'
              ? (targetPlayerCode ?? 'SINGLE')
              : 'ALL',
          targetUserId: targetUserId,
        ),
      );
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
    final client = supabaseClient;
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
}
