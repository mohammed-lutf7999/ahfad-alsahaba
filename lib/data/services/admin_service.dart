import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_control_models.dart';
import '../models/cms_models.dart';
import '../models/store_item_model.dart';
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
  Future<List<StoreItemModel>> Function()? storeItemsFetcherOverride;

  @visibleForTesting
  Future<StoreItemModel?> Function(Map<String, dynamic> params)?
      storeItemUpserterOverride;

  @visibleForTesting
  Future<bool> Function({
    required String entityType,
    required String id,
    required bool isVisible,
  })? visibilitySetterOverride;

  @visibleForTesting
  Future<({List<DynamicLibrarySectionData> sections, List<DynamicLibraryItemData> items})>
      Function({String? sectionId})? libraryContentFetcherOverride;

  @visibleForTesting
  Future<DynamicLibrarySectionData?> Function(Map<String, dynamic> params)?
      librarySectionUpserterOverride;

  @visibleForTesting
  Future<DynamicLibraryItemData?> Function(Map<String, dynamic> params)?
      libraryItemUpserterOverride;

  @visibleForTesting
  Future<({List<DynamicQuizCategoryData> categories, List<DynamicQuizQuestionData> questions})>
      Function({String? categoryId, int? levelNumber, int limit})?
      quizContentFetcherOverride;

  @visibleForTesting
  Future<DynamicQuizCategoryData?> Function(Map<String, dynamic> params)?
      quizCategoryUpserterOverride;

  @visibleForTesting
  Future<DynamicQuizQuestionData?> Function(Map<String, dynamic> params)?
      quizQuestionUpserterOverride;

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
  Future<List<AdminGhostSummary>> Function({int limit})? ghostsFetcherOverride;

  @visibleForTesting
  Future<bool> Function(String ghostId, bool isActive)? ghostTogglerOverride;

  @visibleForTesting
  Future<List<AdminAuditLogEntry>> Function({int limit})?
      auditLogsFetcherOverride;

  @visibleForTesting
  Future<AdminRosterSnapshot?> Function()? adminsFetcherOverride;

  @visibleForTesting
  Future<AdminRosterSnapshot?> Function({
    required String action,
    required String email,
    String role,
  })? adminManagerOverride;

  @visibleForTesting
  Future<AdminResourceHealth?> Function()? resourceHealthFetcherOverride;

  @visibleForTesting
  Future<Map<String, dynamic>?> Function({
    required String action,
    int olderThanDays,
  })? resourceCleanupOverride;

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
    storeItemsFetcherOverride = null;
    storeItemUpserterOverride = null;
    visibilitySetterOverride = null;
    libraryContentFetcherOverride = null;
    librarySectionUpserterOverride = null;
    libraryItemUpserterOverride = null;
    quizContentFetcherOverride = null;
    quizCategoryUpserterOverride = null;
    quizQuestionUpserterOverride = null;
    playerDetailFetcherOverride = null;
    playerCompensationOverride = null;
    ghostsFetcherOverride = null;
    ghostTogglerOverride = null;
    auditLogsFetcherOverride = null;
    adminsFetcherOverride = null;
    adminManagerOverride = null;
    resourceHealthFetcherOverride = null;
    resourceCleanupOverride = null;
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
      _syncAndBroadcastAll();
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
      _syncAndBroadcastAll();
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
      _syncAndBroadcastAll();
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
      _syncAndBroadcastAll();
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

  // ==================== DYNAMIC CMS & SUPPORT RPCS (MIGRATION 016) ====================

  Future<List<StoreItemModel>> listStoreItems() async {
    if (storeItemsFetcherOverride != null) {
      return storeItemsFetcherOverride!();
    }
    final client = _supabase;
    if (client == null) return [];
    final res = await client
        .rpc('admin_list_store_items')
        .timeout(const Duration(seconds: 6));
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) =>
              StoreItemModel.fromCloudJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<StoreItemModel?> upsertStoreItem({
    required String id,
    required String title,
    String description = '',
    required StoreItemCategory category,
    int priceCoins = 0,
    int priceGems = 0,
    int minLevel = 1,
    String assetKey = '',
    bool isVisible = true,
    int sortOrder = 100,
    Map<String, dynamic> metadata = const {},
  }) async {
    final params = <String, dynamic>{
      'p_id': id.trim().toLowerCase(),
      'p_title': title.trim(),
      'p_description': description.trim(),
      'p_category': category.name,
      'p_price_coins': priceCoins.clamp(0, 1000000),
      'p_price_gems': priceGems.clamp(0, 100000),
      'p_min_level': minLevel.clamp(1, 100),
      'p_asset_key': assetKey.trim(),
      'p_is_visible': isVisible,
      'p_sort_order': sortOrder,
      'p_metadata': metadata,
    };
    if (storeItemUpserterOverride != null) {
      return storeItemUpserterOverride!(params);
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_store_item', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final parsed =
          StoreItemModel.fromCloudJson(Map<String, dynamic>.from(res));
      _syncAndBroadcastAll();
      return parsed;
    }
    return null;
  }

  Future<bool> setContentVisibility({
    required String entityType,
    required String id,
    required bool isVisible,
  }) async {
    if (visibilitySetterOverride != null) {
      return visibilitySetterOverride!(
        entityType: entityType,
        id: id,
        isVisible: isVisible,
      );
    }
    final client = _supabase;
    if (client == null) return false;
    final res = await client.rpc(
      'admin_set_content_visibility',
      params: {
        'p_entity_type': entityType,
        'p_id': id,
        'p_is_visible': isVisible,
      },
    ).timeout(const Duration(seconds: 6));
    final ok = res is Map && res['ok'] == true;
    if (ok) {
      _syncAndBroadcastAll();
    }
    return ok;
  }

  Future<
      ({
        List<DynamicLibrarySectionData> sections,
        List<DynamicLibraryItemData> items,
      })> listLibraryContent({String? sectionId}) async {
    if (libraryContentFetcherOverride != null) {
      return libraryContentFetcherOverride!(sectionId: sectionId);
    }
    final client = _supabase;
    if (client == null) return (sections: <DynamicLibrarySectionData>[], items: <DynamicLibraryItemData>[]);
    final res = await client.rpc(
      'admin_list_library_content',
      params: {'p_section_id': sectionId},
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      final secRaw = res['sections'] as List? ?? const [];
      final itemRaw = res['items'] as List? ?? const [];
      return (
        sections: secRaw
            .whereType<Map>()
            .map((e) => DynamicLibrarySectionData.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(),
        items: itemRaw
            .whereType<Map>()
            .map((e) =>
                DynamicLibraryItemData.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    return (sections: <DynamicLibrarySectionData>[], items: <DynamicLibraryItemData>[]);
  }

  Future<DynamicLibrarySectionData?> upsertLibrarySection({
    required String id,
    required String title,
    String iconName = 'auto_stories_rounded',
    String colorHex = '#D4AF37',
    int sortOrder = 100,
    bool isVisible = true,
  }) async {
    final params = <String, dynamic>{
      'p_id': id.trim().toLowerCase(),
      'p_title': title.trim(),
      'p_icon_name': iconName,
      'p_color_hex': colorHex.trim(),
      'p_sort_order': sortOrder,
      'p_is_visible': isVisible,
    };
    if (librarySectionUpserterOverride != null) {
      return librarySectionUpserterOverride!(params);
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_library_section', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final sec = DynamicLibrarySectionData.fromJson(
          Map<String, dynamic>.from(res));
      _syncAndBroadcastAll();
      return sec;
    }
    return null;
  }

  Future<DynamicLibraryItemData?> upsertLibraryItem({
    String? id,
    required String sectionId,
    required String title,
    String subtitle = '',
    required String content,
    String sourceRef = '',
    int sortOrder = 100,
    bool isVisible = true,
  }) async {
    final params = <String, dynamic>{
      'p_id': (id == null || id.trim().isEmpty) ? null : id.trim(),
      'p_section_id': sectionId.trim().toLowerCase(),
      'p_title': title.trim(),
      'p_subtitle': subtitle.trim(),
      'p_content': content.trim(),
      'p_source_ref': sourceRef.trim(),
      'p_sort_order': sortOrder,
      'p_is_visible': isVisible,
    };
    if (libraryItemUpserterOverride != null) {
      return libraryItemUpserterOverride!(params);
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_library_item', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final item =
          DynamicLibraryItemData.fromJson(Map<String, dynamic>.from(res));
      _syncAndBroadcastAll();
      return item;
    }
    return null;
  }

  Future<
      ({
        List<DynamicQuizCategoryData> categories,
        List<DynamicQuizQuestionData> questions,
      })> listQuizContent({
    String? categoryId,
    int? levelNumber,
    int limit = 100,
  }) async {
    if (quizContentFetcherOverride != null) {
      return quizContentFetcherOverride!(
        categoryId: categoryId,
        levelNumber: levelNumber,
        limit: limit,
      );
    }
    final client = _supabase;
    if (client == null) {
      return (
        categories: <DynamicQuizCategoryData>[],
        questions: <DynamicQuizQuestionData>[],
      );
    }
    final res = await client.rpc(
      'admin_list_quiz_content',
      params: {
        'p_category_id': categoryId,
        'p_level_number': levelNumber,
        'p_limit': limit.clamp(1, 250),
      },
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      final catRaw = res['categories'] as List? ?? const [];
      final qRaw = res['questions'] as List? ?? const [];
      return (
        categories: catRaw
            .whereType<Map>()
            .map((e) => DynamicQuizCategoryData.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(),
        questions: qRaw
            .whereType<Map>()
            .map((e) => DynamicQuizQuestionData.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    return (
      categories: <DynamicQuizCategoryData>[],
      questions: <DynamicQuizQuestionData>[],
    );
  }

  Future<DynamicQuizCategoryData?> upsertQuizCategory({
    required String id,
    required String name,
    String description = '',
    String iconName = 'quiz_rounded',
    String colorHex = '#1B5E20',
    int totalLevels = 10,
    int sortOrder = 100,
    bool isVisible = true,
    bool isLocked = false,
  }) async {
    final params = <String, dynamic>{
      'p_id': id.trim().toLowerCase(),
      'p_name': name.trim(),
      'p_description': description.trim(),
      'p_icon_name': iconName,
      'p_color_hex': colorHex.trim(),
      'p_total_levels': totalLevels.clamp(1, 100),
      'p_sort_order': sortOrder,
      'p_is_visible': isVisible,
      'p_is_locked': isLocked,
    };
    if (quizCategoryUpserterOverride != null) {
      return quizCategoryUpserterOverride!(params);
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_quiz_category', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final cat =
          DynamicQuizCategoryData.fromJson(Map<String, dynamic>.from(res));
      _syncAndBroadcastAll();
      return cat;
    }
    return null;
  }

  Future<DynamicQuizQuestionData?> upsertQuizQuestion({
    String? id,
    required String categoryId,
    required int levelNumber,
    required String questionText,
    required List<String> options,
    required int correctIndex,
    String explanation = '',
    String syncScope = 'solo_only',
    int sortOrder = 100,
    bool isVisible = true,
  }) async {
    if (options.length != 4 || options.any((o) => o.trim().isEmpty)) {
      throw ArgumentError('يجب توفير 4 خيارات غير فارغة للسؤال');
    }
    if (correctIndex < 0 || correctIndex > 3) {
      throw ArgumentError('رقم الإجابة الصحيحة يجب أن يكون بين 0 و 3');
    }
    final params = <String, dynamic>{
      'p_id': (id == null || id.trim().isEmpty) ? null : id.trim(),
      'p_category_id': categoryId.trim().toLowerCase(),
      'p_level_number': levelNumber.clamp(1, 100),
      'p_question_text': questionText.trim(),
      'p_options': options.map((e) => e.trim()).toList(),
      'p_correct_index': correctIndex,
      'p_explanation': explanation.trim(),
      'p_sync_scope': syncScope,
      'p_sort_order': sortOrder,
      'p_is_visible': isVisible,
    };
    if (quizQuestionUpserterOverride != null) {
      return quizQuestionUpserterOverride!(params);
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_quiz_question', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final q =
          DynamicQuizQuestionData.fromJson(Map<String, dynamic>.from(res));
      _syncAndBroadcastAll();
      return q;
    }
    return null;
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
    final client = _supabase;
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
    final client = _supabase;
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

  Future<List<AdminGhostSummary>> listGhosts({int limit = 30}) async {
    if (ghostsFetcherOverride != null) {
      return ghostsFetcherOverride!(limit: limit);
    }
    final client = _supabase;
    if (client == null) return [];
    final res = await client.rpc(
      'admin_list_ghosts',
      params: {'p_limit': limit.clamp(1, 100)},
    ).timeout(const Duration(seconds: 6));
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => AdminGhostSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<bool> toggleGhost(String ghostId, bool isActive) async {
    if (ghostTogglerOverride != null) {
      return ghostTogglerOverride!(ghostId, isActive);
    }
    final client = _supabase;
    if (client == null) return false;
    final res = await client.rpc(
      'admin_toggle_ghost',
      params: {
        'p_ghost_id': ghostId,
        'p_is_active': isActive,
      },
    ).timeout(const Duration(seconds: 6));
    return res == true;
  }

  Future<List<AdminAuditLogEntry>> listAuditLogs({int limit = 50}) async {
    if (auditLogsFetcherOverride != null) {
      return auditLogsFetcherOverride!(limit: limit);
    }
    final client = _supabase;
    if (client == null) return [];
    final res = await client.rpc(
      'admin_list_audit_logs',
      params: {'p_limit': limit.clamp(1, 200)},
    ).timeout(const Duration(seconds: 6));
    if (res is List) {
      return res
          .whereType<Map>()
          .map(
              (e) => AdminAuditLogEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<AdminRosterSnapshot?> listAdmins() async {
    if (adminsFetcherOverride != null) {
      return adminsFetcherOverride!();
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client
        .rpc('admin_list_admins')
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      return AdminRosterSnapshot.fromJson(Map<String, dynamic>.from(res));
    }
    return null;
  }

  Future<AdminRosterSnapshot?> manageAdmin({
    required String action,
    required String email,
    String role = 'admin',
  }) async {
    if (adminManagerOverride != null) {
      return adminManagerOverride!(action: action, email: email, role: role);
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client.rpc(
      'admin_manage_admin',
      params: {
        'p_action': action.trim().toLowerCase(),
        'p_email': email.trim().toLowerCase(),
        'p_role': role.trim().toLowerCase(),
      },
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      return AdminRosterSnapshot.fromJson(Map<String, dynamic>.from(res));
    }
    return null;
  }

  /// Fetches live PostgreSQL storage & activity telemetry (`admin_get_resource_health`).
  Future<AdminResourceHealth?> getResourceHealth() async {
    if (resourceHealthFetcherOverride != null) {
      return resourceHealthFetcherOverride!();
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client
        .rpc('admin_get_resource_health')
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      return AdminResourceHealth.fromJson(Map<String, dynamic>.from(res));
    }
    return null;
  }

  /// Executes safe admin cleanup (`finished_matches`, `expired_receipts`, `old_audit_logs`).
  Future<Map<String, dynamic>?> cleanupStaleResources({
    required String action,
    int olderThanDays = 30,
  }) async {
    if (resourceCleanupOverride != null) {
      return resourceCleanupOverride!(
        action: action,
        olderThanDays: olderThanDays,
      );
    }
    final client = _supabase;
    if (client == null) return null;
    final res = await client.rpc(
      'admin_cleanup_stale_resources',
      params: {
        'p_action': action.trim().toLowerCase(),
        'p_older_than_days': olderThanDays.clamp(7, 365),
      },
    ).timeout(const Duration(seconds: 8));
    return res is Map ? Map<String, dynamic>.from(res) : null;
  }

  void _syncAndBroadcastAll() {
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
    final client = _supabase;
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
