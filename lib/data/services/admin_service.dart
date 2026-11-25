import 'package:flutter/foundation.dart';

import 'admin/admin_cms_level_mgmt_mixin.dart';
import 'admin/admin_cms_quiz_mixin.dart';
import 'admin/admin_cms_store_library_mixin.dart';
import 'admin/admin_events_announcements_mixin.dart';
import 'admin/admin_moderation_mixin.dart';
import 'admin/admin_players_mixin.dart';
import 'admin/admin_release_config_mixin.dart';
import 'admin/admin_resources_audit_mixin.dart';
import 'admin/admin_service_base.dart';

/// Unified Admin Service Facade decomposed in Plan 21 (Wave 1) from a single
/// 1,547-line God File into focused domain modules under `lib/data/services/admin/`
/// with 100% backward compatibility for UI screens and test overrides.
class AdminService extends AdminServiceBase
    with
        AdminReleaseConfigMixin,
        AdminEventsAnnouncementsMixin,
        AdminCmsStoreLibraryMixin,
        AdminCmsQuizMixin,
        AdminCmsLevelMgmtMixin,
        AdminPlayersMixin,
        AdminModerationMixin,
        AdminResourcesAuditMixin {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  @visibleForTesting
  void resetForTesting() {
    resetBaseForTesting();
    resetReleaseConfigForTesting();
    resetEventsAnnouncementsForTesting();
    resetCmsStoreLibraryForTesting();
    resetCmsQuizForTesting();
    resetCmsLevelMgmtForTesting();
    resetPlayersForTesting();
    resetModerationForTesting();
    resetResourcesAuditForTesting();
  }
}
