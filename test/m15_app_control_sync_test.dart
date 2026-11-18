import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    AppControlService.instance.resetForTesting();
  });

  group('Phase 1: PlayerCode SAH-XXXX, AppControlModels & Ultra-Low-Cost Sync', () {
    test('PlayerProfile validates and generates canonical SAH-XXXX codes', () {
      for (int i = 0; i < 20; i++) {
        final code = PlayerProfile.generatePlayerCode();
        expect(PlayerProfile.isValidPlayerCode(code), isTrue);
        expect(code, matches(RegExp(r'^SAH-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}$')));
      }

      expect(PlayerProfile.isValidPlayerCode('sah-ab23'), isTrue);
      expect(PlayerProfile.isValidPlayerCode('BAD-CODE'), isFalse);
      expect(PlayerProfile.isValidPlayerCode('SAH-12'), isFalse);
      expect(PlayerProfile.isValidPlayerCode('SAH-WAYTOOLONGCODE'), isFalse);
      expect(PlayerProfile.isValidPlayerCode(''), isFalse);
      expect(PlayerProfile.isValidPlayerCode(null), isFalse);
    });

    test('Legacy profile without playerCode receives persistent device SAH-XXXX across restarts', () async {
      final legacyJson = jsonEncode([
        {
          'id': 'legacy_p1',
          'name': 'فارس قديم',
          'totalScore': 500,
        }
      ]);
      SharedPreferences.setMockInitialValues({
        'player_profiles': legacyJson,
        'active_profile_id': 'legacy_p1',
      });
      await SharedPrefsService.init(forceReload: true);
      await ProfileService.instance.init();

      final firstLoaded = ProfileService.instance.activeProfile!;
      final assignedCode = firstLoaded.playerCode;
      expect(PlayerProfile.isValidPlayerCode(assignedCode), isTrue);
      expect(SharedPrefsService.getDevicePlayerCode(), equals(assignedCode));

      // Simulate cold restart reading persisted profiles JSON
      await ProfileService.instance.init();
      expect(ProfileService.instance.activeProfile!.playerCode, equals(assignedCode));
    });

    test('AppReleaseConfig evaluates force and optional update boundaries accurately', () {
      const cfg = AppReleaseConfig(
        minVersionCode: 19,
        latestVersionCode: 21,
      );

      expect(cfg.isForceUpdateRequired(18), isTrue);
      expect(cfg.isForceUpdateRequired(19), isFalse);
      expect(cfg.isOptionalUpdateAvailable(18), isFalse);
      expect(cfg.isOptionalUpdateAvailable(19), isTrue);
      expect(cfg.isOptionalUpdateAvailable(20), isTrue);
      expect(cfg.isOptionalUpdateAvailable(21), isFalse);
    });

    test('AppDynamicEvent honors active state and UTC time bounds', () {
      final now = DateTime.utc(2026, 11, 15, 20, 0);
      final active = AppDynamicEvent(
        id: 'ev1',
        title: 'ليلة القدر',
        isActive: true,
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 1)),
      );
      final expired = AppDynamicEvent(
        id: 'ev2',
        title: 'حدث منتهي',
        isActive: true,
        endsAt: now.subtract(const Duration(minutes: 1)),
      );
      final upcoming = AppDynamicEvent(
        id: 'ev3',
        title: 'حدث قادم',
        isActive: true,
        startsAt: now.add(const Duration(minutes: 10)),
      );

      expect(active.isCurrentlyActiveAt(now), isTrue);
      expect(expired.isCurrentlyActiveAt(now), isFalse);
      expect(upcoming.isCurrentlyActiveAt(now), isFalse);
    });

    test('AppControlService enforces 15m TTL, delta changed=false preservation, and maintenance fast recovery', () async {
      DateTime fakeNow = DateTime.utc(2026, 11, 15, 20, 0);
      int rpcCalls = 0;
      bool serverMaintenance = false;

      final service = AppControlService.instance;
      service.clockOverride = () => fakeNow;
      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        rpcCalls++;
        if (rpcCalls == 1) {
          return {
            'changed': true,
            'config_version': 3,
            'is_admin': false,
            'release_config': {
              'platform': 'android',
              'min_version_code': 1,
              'latest_version_code': 19,
              'latest_version_name': '1.0.18',
              'maintenance_mode': false,
              'feature_flags': {'online_multiplayer': true, 'show_event_banner': true},
              'config_version': 3,
            },
            'active_event': {
              'id': 'ev_ramadan',
              'badge_text': 'موسم خاص',
              'title': 'تحدي الفرسان',
              'action_type': 'open_event_screen',
              'is_active': true,
            },
            'announcements': [
              {
                'id': 'ann_1',
                'title': 'مرحباً بكم',
                'body': 'بداية موسم جديد',
                'message_type': 'normal',
                'target_scope': 'all',
                'is_dismissible': true,
              },
            ],
          };
        }

        if (clientConfigVersion == 3 && !serverMaintenance) {
          return {
            'changed': false,
            'config_version': 3,
            'is_admin': true,
          };
        }

        return {
          'changed': true,
          'config_version': 4,
          'is_admin': true,
          'release_config': {
            'platform': 'android',
            'min_version_code': 1,
            'latest_version_code': 19,
            'maintenance_mode': serverMaintenance,
            'config_version': 4,
          },
          'active_event': null,
          'announcements': const [],
        };
      };

      // 1. Initial cold sync
      await service.syncControlState(currentVersionCode: 18);
      expect(rpcCalls, equals(1));
      expect(service.snapshot.configVersion, equals(3));
      expect(service.activeEventNotifier.value?.title, equals('تحدي الفرسان'));
      expect(service.pendingAnnouncementsNotifier.value.length, equals(1));
      expect(service.isAdminNotifier.value, isFalse);

      // 2. Call again after 2 minutes -> skipped by 3-minute TTL cooldown!
      fakeNow = fakeNow.add(const Duration(minutes: 2));
      await service.syncControlState(currentVersionCode: 18);
      expect(rpcCalls, equals(1));

      // 3. Call again after 4 minutes total -> hits server, gets delta changed=false, preserves activeEvent & updates isAdmin
      fakeNow = fakeNow.add(const Duration(minutes: 2));
      await service.syncControlState(currentVersionCode: 18);
      expect(rpcCalls, equals(2));
      expect(service.activeEventNotifier.value?.title, equals('تحدي الفرسان'));
      expect(service.isAdminNotifier.value, isTrue);

      // 4. Acknowledge announcement -> 0ms removal + persisted seen ID
      String? ackedId;
      service.acknowledgeOverride = ({required String announcementId, String? playerCode}) async {
        ackedId = announcementId;
        return true;
      };
      await service.markAnnouncementSeen(service.pendingAnnouncementsNotifier.value.first);
      await Future<void>.delayed(Duration.zero);
      expect(service.pendingAnnouncementsNotifier.value, isEmpty);
      expect(SharedPrefsService.getSeenAnnouncementIds().contains('ann_1'), isTrue);
      expect(ackedId, equals('ann_1'));

      // 5. Force sync into maintenance mode, then verify 20s later bypasses 15m TTL so locked player can exit maintenance quickly
      serverMaintenance = true;
      await service.syncControlState(force: true, currentVersionCode: 18);
      expect(rpcCalls, equals(3));
      expect(service.releaseConfigNotifier.value.maintenanceMode, isTrue);

      serverMaintenance = false;
      fakeNow = fakeNow.add(const Duration(seconds: 20));
      await service.syncControlState(currentVersionCode: 18);
      expect(rpcCalls, equals(4));
      expect(service.releaseConfigNotifier.value.maintenanceMode, isFalse);

      // 6. Verify 0ms cold hydration from persisted cache
      service.resetForTesting();
      expect(service.snapshot.configVersion, equals(0));
      await service.initFromCache();
      expect(service.snapshot.configVersion, equals(4));
      expect(service.isAdminNotifier.value, isTrue);
    });

    test('AppControlService gracefully preserves cached config on offline exception & AdminService initializes safely without Supabase', () async {
      final service = AppControlService.instance;
      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        return {
          'changed': true,
          'config_version': 9,
          'is_admin': false,
          'release_config': {
            'platform': 'android',
            'min_version_code': 1,
            'latest_version_code': 18,
            'feature_flags': {'ghost_matches': false},
            'config_version': 9,
          },
          'active_event': null,
          'announcements': const [],
        };
      };
      await service.syncControlState(force: true, currentVersionCode: 18);
      expect(service.featureFlagsNotifier.value.ghostMatches, isFalse);

      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        throw const SocketException('No network');
      };
      await service.syncControlState(force: true, currentVersionCode: 18);
      expect(service.featureFlagsNotifier.value.ghostMatches, isFalse);
      expect(service.snapshot.configVersion, equals(9));

      // AdminService must NOT throw even if Supabase wasn't initialized yet
      final admin = AdminService();
      admin.clearCachedAdminStatus();
      expect(() => admin.isAdmin, returnsNormally);
    });

    test('AppControlService deduplicates concurrent calls, throttles player directory (6h), and cools down optional update (24h)', () async {
      DateTime fakeNow = DateTime.utc(2026, 11, 15, 22, 0);
      int inFlightHits = 0;
      int dirHits = 0;

      final service = AppControlService.instance;
      service.clockOverride = () => fakeNow;
      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        inFlightHits++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return {
          'changed': true,
          'config_version': 10,
          'is_admin': false,
          'release_config': {
            'platform': 'android',
            'min_version_code': 1,
            'latest_version_code': 25,
            'config_version': 10,
          },
          'active_event': null,
          'announcements': const [],
        };
      };

      // Concurrent syncs coalesce into a single RPC call
      await Future.wait([
        service.syncControlState(force: true, currentVersionCode: 18),
        service.syncControlState(force: true, currentVersionCode: 18),
        service.syncControlState(force: true, currentVersionCode: 18),
      ]);
      expect(inFlightHits, equals(1));

      // Optional update respects 24h prompt cooldown
      expect(service.shouldPromptOptionalUpdate(currentVersionCode: 18), isTrue);
      await service.markOptionalUpdatePrompted();
      expect(service.shouldPromptOptionalUpdate(currentVersionCode: 18), isFalse);
      fakeNow = fakeNow.add(const Duration(hours: 25));
      expect(service.shouldPromptOptionalUpdate(currentVersionCode: 18), isTrue);

      // Player directory sync throttles 6h cleanly and supports force: true
      service.directorySyncOverride = ({
        required String playerCode,
        required String displayName,
        required int trophies,
        required int playerLevel,
        required int totalScore,
        required String platform,
        required String appVersion,
        required int versionCode,
      }) async {
        dirHits++;
        return PlayerProfile.isValidPlayerCode(playerCode);
      };

      expect(await service.syncPlayerDirectory(), isTrue);
      expect(dirHits, equals(1));
      fakeNow = fakeNow.add(const Duration(hours: 2));
      expect(await service.syncPlayerDirectory(), isFalse);
      expect(dirHits, equals(1));
      expect(await service.syncPlayerDirectory(force: true), isTrue);
      expect(dirHits, equals(2));
    });
  });
}
