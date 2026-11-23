import 'package:flutter/foundation.dart';

import '../../models/app_control_models.dart';
import 'admin_service_base.dart';

/// Admin domain mixin for ghost telemetry, immutable audit logs, owner admin
/// roster management, and Supabase resource health/cleanup.
mixin AdminResourcesAuditMixin on AdminServiceBase {
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

  @protected
  void resetResourcesAuditForTesting() {
    ghostsFetcherOverride = null;
    ghostTogglerOverride = null;
    auditLogsFetcherOverride = null;
    adminsFetcherOverride = null;
    adminManagerOverride = null;
    resourceHealthFetcherOverride = null;
    resourceCleanupOverride = null;
  }

  Future<List<AdminGhostSummary>> listGhosts({int limit = 30}) async {
    if (ghostsFetcherOverride != null) {
      return ghostsFetcherOverride!(limit: limit);
    }
    final client = supabaseClient;
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
    final client = supabaseClient;
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
    final client = supabaseClient;
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
    final client = supabaseClient;
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
    final client = supabaseClient;
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
    final client = supabaseClient;
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
    final client = supabaseClient;
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

  /// Upserts per-player dynamic permissions & ban state (`admin_upsert_player_permissions`)
}
