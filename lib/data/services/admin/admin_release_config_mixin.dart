import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_control_models.dart';
import 'admin_service_base.dart';

/// Admin domain mixin handling overview KPIs, release configuration,
/// and legacy dashboard stats fallback.
mixin AdminReleaseConfigMixin on AdminServiceBase {
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

  @protected
  void resetReleaseConfigForTesting() {
    overviewFetcherOverride = null;
    releaseConfigSaverOverride = null;
  }

  Future<AdminOverview?> getOverview() async {
    if (overviewFetcherOverride != null) {
      return overviewFetcherOverride!();
    }
    final client = supabaseClient;
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
    final client = supabaseClient;
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
      syncAndBroadcastAll();
      return config;
    }
    return null;
  }

  /// Fetch dashboard statistics via Edge Function
  Future<Map<String, dynamic>> getStats() async {
    final client = supabaseClient;
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
      } catch (overviewErr) {
        debugPrint('Admin stats overview fallback failed: $overviewErr');
      }

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
}
