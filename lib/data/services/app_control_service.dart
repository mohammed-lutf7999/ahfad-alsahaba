import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_constants.dart';
import '../local/shared_prefs_service.dart';
import '../models/app_control_models.dart';
import '../models/player_profile_model.dart';
import 'profile_service.dart';

enum AppUpdateOutcome {
  updated,
  cancelledByUser,
  storeOpened,
  failed,
}

typedef ControlStateFetcher = Future<Map<String, dynamic>?> Function({
  required String platform,
  required int versionCode,
  required int clientConfigVersion,
  String? playerCode,
});

typedef AnnouncementAckSender = Future<bool> Function({
  required String announcementId,
  String? playerCode,
});

typedef DirectorySyncSender = Future<bool> Function({
  required String playerCode,
  required String displayName,
  required int trophies,
  required int playerLevel,
  required int totalScore,
  required String platform,
  required String appVersion,
  required int versionCode,
});

typedef BuildNumberResolver = Future<int> Function();

typedef AppUpdateExecutor = Future<AppUpdateOutcome> Function({
  required bool isForced,
  String? customStoreUrl,
});

/// Ultra-low-cost, cache-first App Control & Targeted Announcements service.
///
/// Design principles:
/// 1. Boots in 0ms from SharedPreferences JSON cache.
/// 2. Throttles background server polling via [AppConstants.appControlSyncCooldownMinutes]
///    (default 15m), bypassed immediately during maintenance or `force: true`.
/// 3. Uses delta `config_version` checks (<100B response when nothing changed).
/// 4. Deduplicates concurrent in-flight sync calls and timeouts at 5s.
class AppControlService extends ChangeNotifier {
  static final AppControlService instance = AppControlService._internal();
  AppControlService._internal();

  AppControlSnapshot _snapshot = AppControlSnapshot.defaults();
  AppControlSnapshot get snapshot => _snapshot;

  final ValueNotifier<AppReleaseConfig> releaseConfigNotifier =
      ValueNotifier<AppReleaseConfig>(const AppReleaseConfig());
  final ValueNotifier<AppFeatureFlags> featureFlagsNotifier =
      ValueNotifier<AppFeatureFlags>(const AppFeatureFlags());
  final ValueNotifier<AppDynamicEvent?> activeEventNotifier =
      ValueNotifier<AppDynamicEvent?>(null);
  final ValueNotifier<bool> isAdminNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<AppAnnouncement>> pendingAnnouncementsNotifier =
      ValueNotifier<List<AppAnnouncement>>(const []);

  Future<AppControlSnapshot>? _inFlightSync;
  bool _initialized = false;
  int? _resolvedBuildNumber;

  @visibleForTesting
  ControlStateFetcher? rpcStateFetcherOverride;

  @visibleForTesting
  AnnouncementAckSender? acknowledgeOverride;

  @visibleForTesting
  DirectorySyncSender? directorySyncOverride;

  @visibleForTesting
  BuildNumberResolver? buildNumberResolverOverride;

  @visibleForTesting
  AppUpdateExecutor? performUpdateOverride;

  @visibleForTesting
  DateTime Function()? clockOverride;

  DateTime _nowUtc() => (clockOverride?.call() ?? DateTime.now()).toUtc();

  int get effectiveBuildNumber =>
      _resolvedBuildNumber ?? AppConstants.appBuildNumber;

  String _currentPlatform() => kIsWeb ? 'web' : 'android';

  SupabaseClient? _safeSupabase() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Resolves runtime Android/iOS build number cleanly with cached fallback to
  /// [AppConstants.appBuildNumber] if running under unit tests or non-native targets.
  Future<int> resolveCurrentBuildNumber() async {
    if (buildNumberResolverOverride != null) {
      final resolved = await buildNumberResolverOverride!();
      if (resolved > 0) {
        _resolvedBuildNumber = resolved;
        return resolved;
      }
      return AppConstants.appBuildNumber;
    }
    if (_resolvedBuildNumber != null && _resolvedBuildNumber! > 0) {
      return _resolvedBuildNumber!;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final parsed = int.tryParse(info.buildNumber.trim());
      if (parsed != null && parsed > 0) {
        _resolvedBuildNumber = parsed;
        return parsed;
      }
    } catch (_) {
      // Safe fallback in test environment or unsupported platforms.
    }
    _resolvedBuildNumber = AppConstants.appBuildNumber;
    return AppConstants.appBuildNumber;
  }

  /// Resets in-memory state cleanly for deterministic unit tests.
  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _inFlightSync = null;
    _resolvedBuildNumber = null;
    rpcStateFetcherOverride = null;
    acknowledgeOverride = null;
    directorySyncOverride = null;
    buildNumberResolverOverride = null;
    performUpdateOverride = null;
    clockOverride = null;
    _applySnapshot(AppControlSnapshot.defaults());
  }

  /// Hydrates control state at 0ms from local SharedPreferences cache.
  Future<void> initFromCache() async {
    await SharedPrefsService.init();
    final cachedJson = SharedPrefsService.getCachedAppControlJson();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        final loaded = AppControlSnapshot.fromJson(map);
        _applySnapshot(_sanitizeSnapshotForNow(loaded));
      } catch (e) {
        debugPrint('AppControlService cache decode failed, using defaults: $e');
        _applySnapshot(AppControlSnapshot.defaults());
      }
    } else {
      _applySnapshot(AppControlSnapshot.defaults());
    }
    _initialized = true;
  }

  /// Refreshes active scheduled event visibility using local UTC clock (0 DB calls).
  void refreshTimedVisualState() {
    _applySnapshot(_sanitizeSnapshotForNow(_snapshot));
  }

  /// Synchronizes remote config, dynamic event, and pending announcements
  /// using delta `config_version` and strict 15-minute TTL cooldown.
  Future<AppControlSnapshot> syncControlState({
    bool force = false,
    int? currentVersionCode,
    String? playerCode,
    int cooldownMinutes = AppConstants.appControlSyncCooldownMinutes,
  }) async {
    if (!_initialized) {
      await initFromCache();
    }

    if (_inFlightSync != null) {
      return _inFlightSync!;
    }

    final resolvedBuild =
        currentVersionCode ?? await resolveCurrentBuildNumber();
    if (currentVersionCode != null && currentVersionCode > 0) {
      _resolvedBuildNumber = currentVersionCode;
    }

    final future = _performSync(
      force: force,
      currentVersionCode: resolvedBuild,
      playerCode: playerCode,
      cooldownMinutes: cooldownMinutes,
    );
    _inFlightSync = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightSync, future)) {
        _inFlightSync = null;
      }
    }
  }

  Future<AppControlSnapshot> _performSync({
    required bool force,
    required int currentVersionCode,
    String? playerCode,
    required int cooldownMinutes,
  }) async {
    final nowUtc = _nowUtc();
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final lastSyncMs = SharedPrefsService.getLastAppControlSyncMs();
    final inMaintenance = _snapshot.releaseConfig.maintenanceMode;

    // Allow faster recovery checks when locked in maintenance (15s floor),
    // otherwise enforce the 15-minute economy TTL cooldown.
    final effectiveCooldownMs = inMaintenance
        ? const Duration(seconds: 15).inMilliseconds
        : Duration(minutes: cooldownMinutes).inMilliseconds;

    if (!force && lastSyncMs > 0 && (nowMs - lastSyncMs) < effectiveCooldownMs) {
      final sanitized = _sanitizeSnapshotForNow(_snapshot);
      if (!identical(sanitized, _snapshot)) {
        _applySnapshot(sanitized);
      }
      return _snapshot;
    }

    final resolvedPlayerCode = _resolvePlayerCode(playerCode);
    final cachedVersion = SharedPrefsService.getCachedConfigVersion();

    try {
      Map<String, dynamic>? rpcResult;
      if (rpcStateFetcherOverride != null) {
        rpcResult = await rpcStateFetcherOverride!(
          platform: _currentPlatform(),
          versionCode: currentVersionCode,
          clientConfigVersion: cachedVersion,
          playerCode: resolvedPlayerCode,
        ).timeout(const Duration(seconds: 5));
      } else {
        final client = _safeSupabase();
        if (client == null) return _snapshot;
        final raw = await client.rpc(
          'get_app_control_state',
          params: {
            'p_platform': _currentPlatform(),
            'p_version_code': currentVersionCode,
            'p_client_config_version': cachedVersion,
            if (resolvedPlayerCode != null) 'p_player_code': resolvedPlayerCode,
          },
        ).timeout(const Duration(seconds: 5));
        if (raw is Map) {
          rpcResult = Map<String, dynamic>.from(raw);
        }
      }

      if (rpcResult == null) return _snapshot;

      await SharedPrefsService.setLastAppControlSyncMs(nowMs);

      final changed = rpcResult['changed'] as bool? ?? false;
      final serverIsAdmin = rpcResult['is_admin'] as bool?;
      final serverConfigVer =
          (rpcResult['config_version'] as num?)?.toInt() ?? cachedVersion;

      if (!changed) {
        final updated = _sanitizeSnapshotForNow(
          _snapshot.copyWith(
            configVersion: serverConfigVer > 0
                ? serverConfigVer
                : _snapshot.configVersion,
            isAdmin: serverIsAdmin ?? _snapshot.isAdmin,
            syncedAt: nowUtc,
          ),
        );
        _applySnapshot(updated);
        await _persistSnapshot(updated);
        return _snapshot;
      }

      final parsed = AppControlSnapshot.fromJson({
        ...rpcResult,
        'synced_at': nowUtc.toIso8601String(),
      });
      final sanitized = _sanitizeSnapshotForNow(parsed);
      _applySnapshot(sanitized);
      await _persistSnapshot(sanitized);
      return _snapshot;
    } catch (e) {
      debugPrint('AppControlService sync skipped (offline-safe): $e');
      final sanitized = _sanitizeSnapshotForNow(_snapshot);
      _applySnapshot(sanitized);
      return _snapshot;
    }
  }

  /// Marks an announcement read locally (0ms) and sends server receipt in background.
  Future<void> markAnnouncementSeen(
    AppAnnouncement announcement, {
    String? playerCode,
  }) async {
    await SharedPrefsService.markAnnouncementSeen(announcement.id);
    final remaining = _snapshot.announcements
        .where((a) => a.id != announcement.id)
        .toList();
    final updated = _snapshot.copyWith(announcements: remaining);
    _applySnapshot(updated);
    await _persistSnapshot(updated);

    final resolvedCode = _resolvePlayerCode(playerCode);
    unawaited(_sendAnnouncementAck(announcement.id, resolvedCode));
  }

  Future<void> _sendAnnouncementAck(String announcementId, String? playerCode) async {
    try {
      if (acknowledgeOverride != null) {
        await acknowledgeOverride!(
          announcementId: announcementId,
          playerCode: playerCode,
        ).timeout(const Duration(seconds: 5));
        return;
      }
      final client = _safeSupabase();
      if (client == null) return;
      await client.rpc(
        'acknowledge_announcement',
        params: {
          'p_announcement_id': announcementId,
          if (playerCode != null) 'p_player_code': playerCode,
        },
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Announcement receipt sync deferred: $e');
    }
  }

  /// Registers/updates this player's short `SAH-XXXX` directory record once per 6 hours
  /// (or immediately when [force] is true). Zero impact when offline.
  Future<bool> syncPlayerDirectory({
    PlayerProfile? profile,
    bool force = false,
    int? versionCode,
  }) async {
    await SharedPrefsService.init();
    final nowMs = _nowUtc().millisecondsSinceEpoch;
    final lastMs = SharedPrefsService.getLastDirectorySyncMs();
    if (!force &&
        lastMs > 0 &&
        (nowMs - lastMs) < const Duration(hours: 6).inMilliseconds) {
      return false;
    }

    final active = profile ?? ProfileService.instance.activeProfile;
    final code = _resolvePlayerCode(active?.playerCode) ??
        await SharedPrefsService.getOrCreateDevicePlayerCode();
    if (!PlayerProfile.isValidPlayerCode(code)) return false;

    final displayName = active?.name ?? 'لاعب';
    final trophies = active?.trophies ?? 1000;
    final playerLevel = active?.levelInfo.level ?? 1;
    final totalScore = active?.totalScore ?? 0;
    final buildCode = versionCode ?? await resolveCurrentBuildNumber();

    try {
      bool ok = false;
      if (directorySyncOverride != null) {
        ok = await directorySyncOverride!(
          playerCode: code,
          displayName: displayName,
          trophies: trophies,
          playerLevel: playerLevel,
          totalScore: totalScore,
          platform: _currentPlatform(),
          appVersion: AppConstants.appVersion,
          versionCode: buildCode,
        ).timeout(const Duration(seconds: 5));
      } else {
        final client = _safeSupabase();
        if (client == null) return false;
        final res = await client.rpc(
          'sync_player_directory',
          params: {
            'p_player_code': code,
            'p_display_name': displayName,
            'p_trophies': trophies,
            'p_player_level': playerLevel,
            'p_total_score': totalScore,
            'p_platform': _currentPlatform(),
            'p_app_version': AppConstants.appVersion,
            'p_version_code': buildCode,
          },
        ).timeout(const Duration(seconds: 5));
        ok = (res is Map && res['ok'] == true);
      }

      if (ok) {
        await SharedPrefsService.setLastDirectorySyncMs(nowMs);
        await SharedPrefsService.setDevicePlayerCode(code);
      }
      return ok;
    } catch (e) {
      debugPrint('syncPlayerDirectory deferred (offline-safe): $e');
      return false;
    }
  }

  /// Attempts Google Play In-App Update (`immediate` when [isForced], `flexible` otherwise)
  /// with automatic fallback to `market://` or Play Store HTTPS URL via `url_launcher`.
  Future<AppUpdateOutcome> performUpdate({
    required bool isForced,
    String? customStoreUrl,
  }) async {
    if (performUpdateOverride != null) {
      return performUpdateOverride!(
        isForced: isForced,
        customStoreUrl: customStoreUrl,
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final info = await InAppUpdate.checkForUpdate().timeout(
          const Duration(seconds: 6),
        );
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          if (isForced && info.immediateUpdateAllowed) {
            final result = await InAppUpdate.performImmediateUpdate();
            if (result == AppUpdateResult.success) {
              return AppUpdateOutcome.updated;
            }
            if (result == AppUpdateResult.userDeniedUpdate) {
              return AppUpdateOutcome.cancelledByUser;
            }
          } else if (!isForced && info.flexibleUpdateAllowed) {
            final result = await InAppUpdate.startFlexibleUpdate();
            if (result == AppUpdateResult.success) {
              try {
                await InAppUpdate.completeFlexibleUpdate();
              } catch (e) {
                debugPrint('completeFlexibleUpdate notice: $e');
              }
              return AppUpdateOutcome.updated;
            }
            if (result == AppUpdateResult.userDeniedUpdate) {
              return AppUpdateOutcome.cancelledByUser;
            }
          }
        }
      } catch (e) {
        debugPrint('InAppUpdate unavailable, falling back to store URL: $e');
      }
    }

    return _launchStoreFallback(customStoreUrl);
  }

  Future<AppUpdateOutcome> _launchStoreFallback(String? customStoreUrl) async {
    final candidates = <String>[
      AppConstants.playStoreMarketUri,
      if (customStoreUrl != null && customStoreUrl.trim().isNotEmpty)
        customStoreUrl.trim(),
      AppConstants.playStoreWebUrl,
    ];
    for (final raw in candidates) {
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return AppUpdateOutcome.storeOpened;
      } catch (e) {
        debugPrint('Store fallback failed for $raw: $e');
      }
    }
    return AppUpdateOutcome.failed;
  }

  /// Allows optional update prompt at most once every 24 hours.
  bool shouldPromptOptionalUpdate({int? currentVersionCode}) {
    final code = currentVersionCode ?? effectiveBuildNumber;
    if (!_snapshot.releaseConfig.isOptionalUpdateAvailable(code)) {
      return false;
    }
    final lastPromptMs = SharedPrefsService.getOptionalUpdateLastPromptMs();
    if (lastPromptMs <= 0) return true;
    final elapsedMs = _nowUtc().millisecondsSinceEpoch - lastPromptMs;
    return elapsedMs >= const Duration(hours: 24).inMilliseconds;
  }

  Future<void> markOptionalUpdatePrompted() async {
    await SharedPrefsService.setOptionalUpdateLastPromptMs(
      _nowUtc().millisecondsSinceEpoch,
    );
  }

  /// Allows [AdminService] to reflect fresh verified admin privilege cleanly.
  void setAdminStatus(bool isAdmin) {
    if (_snapshot.isAdmin == isAdmin) return;
    _snapshot = _snapshot.copyWith(isAdmin: isAdmin);
    isAdminNotifier.value = isAdmin;
    notifyListeners();
  }

  String? _resolvePlayerCode(String? explicit) {
    if (PlayerProfile.isValidPlayerCode(explicit)) {
      return explicit!.trim().toUpperCase();
    }
    final profileCode = ProfileService.instance.activeProfile?.playerCode;
    if (PlayerProfile.isValidPlayerCode(profileCode)) {
      return profileCode!.trim().toUpperCase();
    }
    return SharedPrefsService.getDevicePlayerCode();
  }

  AppControlSnapshot _sanitizeSnapshotForNow(AppControlSnapshot raw) {
    final nowUtc = _nowUtc();
    final seenIds = SharedPrefsService.getSeenAnnouncementIds();
    final buildCode = effectiveBuildNumber;
    final filteredAnnouncements = raw.announcements
        .where(
          (a) =>
              a.id.isNotEmpty &&
              a.isActive &&
              !a.isExpiredAt(nowUtc) &&
              !seenIds.contains(a.id) &&
              a.matchesVersion(buildCode),
        )
        .toList();

    final event = raw.activeEvent;
    final eventNotExpired = event != null &&
        event.isActive &&
        (event.endsAt == null || nowUtc.isBefore(event.endsAt!.toUtc()));

    return AppControlSnapshot(
      configVersion: raw.configVersion,
      isAdmin: raw.isAdmin,
      releaseConfig: raw.releaseConfig,
      // Keep scheduled upcoming events cached on device so they illuminate on
      // activeEventNotifier at the exact startsAt moment with zero extra DB hits.
      activeEvent: eventNotExpired ? event : null,
      announcements: filteredAnnouncements,
      syncedAt: raw.syncedAt,
    );
  }

  Future<void> _persistSnapshot(AppControlSnapshot snap) async {
    await SharedPrefsService.setCachedConfigVersion(snap.configVersion);
    await SharedPrefsService.setCachedAppControlJson(jsonEncode(snap.toJson()));
  }

  void _applySnapshot(AppControlSnapshot next) {
    final nowUtc = _nowUtc();
    _snapshot = next;

    if (!_sameReleaseConfig(releaseConfigNotifier.value, next.releaseConfig)) {
      releaseConfigNotifier.value = next.releaseConfig;
      featureFlagsNotifier.value = next.releaseConfig.featureFlags;
    }

    final ev = next.activeEvent;
    final resolvedEvent =
        (ev != null && ev.isCurrentlyActiveAt(nowUtc)) ? ev : null;
    if (activeEventNotifier.value?.id != resolvedEvent?.id ||
        activeEventNotifier.value?.updatedAt != resolvedEvent?.updatedAt ||
        activeEventNotifier.value?.title != resolvedEvent?.title) {
      activeEventNotifier.value = resolvedEvent;
    }

    isAdminNotifier.value = next.isAdmin;

    if (!_sameAnnouncements(
      pendingAnnouncementsNotifier.value,
      next.announcements,
    )) {
      pendingAnnouncementsNotifier.value = List<AppAnnouncement>.unmodifiable(
        next.announcements,
      );
    }
    notifyListeners();
  }

  bool _sameReleaseConfig(AppReleaseConfig a, AppReleaseConfig b) {
    return a.platform == b.platform &&
        a.minVersionCode == b.minVersionCode &&
        a.latestVersionCode == b.latestVersionCode &&
        a.latestVersionName == b.latestVersionName &&
        a.updateTitle == b.updateTitle &&
        a.updateMessage == b.updateMessage &&
        a.updateUrl == b.updateUrl &&
        a.maintenanceMode == b.maintenanceMode &&
        a.maintenanceTitle == b.maintenanceTitle &&
        a.maintenanceMessage == b.maintenanceMessage &&
        a.configVersion == b.configVersion &&
        a.updatedAt == b.updatedAt &&
        _sameBoolMaps(a.featureFlags.toJson(), b.featureFlags.toJson());
  }

  bool _sameBoolMaps(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool _sameAnnouncements(List<AppAnnouncement> a, List<AppAnnouncement> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].body != b[i].body ||
          a[i].messageType != b[i].messageType ||
          a[i].isDismissible != b[i].isDismissible) {
        return false;
      }
    }
    return true;
  }
}

