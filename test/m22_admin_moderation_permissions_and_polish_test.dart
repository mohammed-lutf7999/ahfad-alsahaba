import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_players_support_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_release_control_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_social_moderation_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin_dashboard_screen.dart';

Widget _wrap360(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(
      size: Size(360, 800),
      padding: EdgeInsets.only(top: 48, bottom: 48),
      viewPadding: EdgeInsets.only(top: 48, bottom: 48),
    ),
    child: MaterialApp(
      locale: const Locale('ar'),
      builder: (context, c) => Directionality(
        textDirection: TextDirection.rtl,
        child: c ?? const SizedBox.shrink(),
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    AdminService().resetForTesting();
    AppControlService.instance.resetForTesting();
  });

  tearDown(() {
    AdminService().resetForTesting();
    AppControlService.instance.resetForTesting();
  });

  group('Milestone 18 & 19: Moderation, Permissions & Release Suite', () {
    test('canHostLiveArena truth-table validates all policy & permission permutations', () {
      final ctrl = AppControlService.instance;

      // 1. When guilds_arenas is OFF, nobody can host (not even admin)
      ctrl.featureFlagsNotifier.value =
          const AppFeatureFlags(guildsArenas: false);
      expect(ctrl.canHostLiveArena(isAdminOverride: true), isFalse);
      expect(ctrl.canHostLiveArena(isAdminOverride: false), isFalse);

      // Turn guilds_arenas ON
      ctrl.featureFlagsNotifier.value = const AppFeatureFlags(
        guildsArenas: true,
        liveArenaHostRestricted: true,
      );

      // 2. Admin can always host when guilds_arenas is ON
      expect(ctrl.canHostLiveArena(isAdminOverride: true), isTrue);

      // 3. Normal user with restricted mode:
      // Default (canHostLiveArenas == null) -> restricted=true -> false
      ctrl.playerPermissionsNotifier.value = const PlayerPermissions(
        canHostLiveArenas: null,
      );
      expect(ctrl.canHostLiveArena(isAdminOverride: false), isFalse);

      // 4. Authorized Teacher Override (canHostLiveArenas == true) -> allowed even when restricted=true
      ctrl.playerPermissionsNotifier.value = const PlayerPermissions(
        canHostLiveArenas: true,
      );
      expect(ctrl.canHostLiveArena(isAdminOverride: false), isTrue);

      // 5. Open policy (restricted=false)
      ctrl.featureFlagsNotifier.value = const AppFeatureFlags(
        guildsArenas: true,
        liveArenaHostRestricted: false,
      );
      // Default user can host in open mode
      ctrl.playerPermissionsNotifier.value = const PlayerPermissions(
        canHostLiveArenas: null,
      );
      expect(ctrl.canHostLiveArena(isAdminOverride: false), isTrue);

      // Explicitly denied individual override (canHostLiveArenas == false) in open mode -> denied
      ctrl.playerPermissionsNotifier.value = const PlayerPermissions(
        canHostLiveArenas: false,
      );
      expect(ctrl.canHostLiveArena(isAdminOverride: false), isFalse);

      // 6. Effectively banned player can never host
      ctrl.playerPermissionsNotifier.value = PlayerPermissions(
        isBanned: true,
        bannedUntil: DateTime.now().toUtc().add(const Duration(hours: 24)),
        canHostLiveArenas: true,
      );
      expect(ctrl.canHostLiveArena(isAdminOverride: false), isFalse);
    });

    test('PlayerPermissions and moderation snapshots serialize & deserialize cleanly', () {
      final perms = PlayerPermissions.fromJson({
        'is_banned': true,
        'banned_until': '2026-12-01T12:00:00.000Z',
        'ban_reason': 'ألفاظ غير لائقة',
        'is_diwan_muted': true,
        'diwan_muted_until': '2026-11-25T12:00:00.000Z',
        'diwan_mute_reason': 'سبام',
        'can_use_online': false,
        'can_use_diwan': false,
        'can_use_guilds': true,
        'can_host_live_arenas': true,
        'effective_can_host_live_arenas': true,
        'notes': 'ملاحظة تدقيق إدارية',
      });

      expect(perms.isBanned, isTrue);
      expect(perms.banReason, equals('ألفاظ غير لائقة'));
      expect(perms.isDiwanMuted, isTrue);
      expect(perms.canUseOnline, isFalse);
      expect(perms.canUseDiwan, isFalse);
      expect(perms.canUseGuilds, isTrue);
      expect(perms.canHostLiveArenas, isTrue);
      expect(perms.notes, equals('ملاحظة تدقيق إدارية'));

      final json = perms.toJson();
      expect(json['is_banned'], isTrue);
      expect(json['can_host_live_arenas'], isTrue);
      expect(json['can_use_guilds'], isTrue);

      final queue = AdminDiwanModerationQueue.fromJson({
        'reports': [
          {
            'message_id': 'msg_1',
            'sender_id': 'u_1',
            'sender_name': 'فارس 1',
            'sender_code': 'SAH-AAAA',
            'content': 'مخالفة',
            'reports_count': 3,
            'latest_reason': 'إساءة',
          }
        ],
        'muted_users': [
          {
            'user_id': 'u_2',
            'display_name': 'فارس 2',
            'muted_until': '2026-12-01T00:00:00Z',
            'reason': 'تكرار',
          }
        ],
      });

      expect(queue.reports.length, equals(1));
      expect(queue.reports.first.reportsCount, equals(3));
      expect(queue.mutedUsers.length, equals(1));
      expect(queue.mutedUsers.first.displayName, equals('فارس 2'));

      final ga = AdminGuildsAndArenasSnapshot.fromJson({
        'guilds': [
          {
            'id': 'g_1',
            'name': 'كتيبة اليرموك',
            'leader_name': 'خالد',
            'members_count': 15,
            'max_members': 30,
            'weekly_score': 500,
            'total_score': 2500,
          }
        ],
        'live_sessions': [
          {
            'id': 's_1',
            'pin_code': '12345',
            'title': 'بطولة الجمعة',
            'host_name': 'المعلم',
            'status': 'active',
            'participants_count': 42,
          }
        ],
      });

      expect(ga.guilds.length, equals(1));
      expect(ga.guilds.first.name, equals('كتيبة اليرموك'));
      expect(ga.liveSessions.length, equals(1));
      expect(ga.liveSessions.first.pinCode, equals('12345'));
      expect(ga.liveSessions.first.isActiveOrWaiting, isTrue);
    });

    testWidgets('AdminDashboardScreen renders 13 flags subtitle and navigates to moderation', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final admin = AdminService();
      admin.overviewFetcherOverride = () async => const AdminOverview(
            totalAccounts: 100,
            directoryPlayers: 80,
            guestPlayers: 20,
            active24h: 15,
            activeEvents: 1,
            activeAnnouncements: 2,
            releaseConfig: AppReleaseConfig(),
          );
      admin.diwanQueueFetcherOverride = ({int limit = 50}) async =>
          const AdminDiwanModerationQueue();
      admin.guildsArenasFetcherOverride = ({int limit = 50}) async =>
          const AdminGuildsAndArenasSnapshot();

      await tester.pumpWidget(_wrap360(const AdminDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('التحديث الإلزامي، وضع الصيانة، و13 علم ميزة وتحكم ديناميكي'), findsOneWidget);

      final modCard = find.byKey(const Key('admin_nav_social_moderation'));
      expect(modCard, findsOneWidget);
      await tester.ensureVisible(modCard);
      await tester.tap(modCard);
      await tester.pumpAndSettle();

      expect(find.byType(AdminSocialModerationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminSocialModerationScreen renders all 3 tabs and executes actions cleanly', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final admin = AdminService();
      String? executedDiwanAction;
      String? executedGuildAction;

      admin.diwanQueueFetcherOverride = ({int limit = 50}) async {
        return const AdminDiwanModerationQueue(
          reports: [
            AdminDiwanReport(
              messageId: 'rep_msg_1',
              senderId: 'user_bad_1',
              senderName: 'مخالف',
              senderCode: 'SAH-9999',
              content: 'نص إعلان غير لائق',
              reportsCount: 4,
              latestReason: 'رابط أو إعلان مخالف',
            ),
          ],
          mutedUsers: [
            AdminMutedUser(
              userId: 'muted_user_1',
              displayName: 'لاعب مكتوم',
              playerCode: 'SAH-8888',
              reason: 'ألفاظ حادة',
            ),
          ],
        );
      };

      admin.guildsArenasFetcherOverride = ({int limit = 50}) async {
        return const AdminGuildsAndArenasSnapshot(
          guilds: [
            AdminGuildSummary(
              id: 'g_test_1',
              name: 'كتيبة الفاتحين',
              leaderName: 'طارق',
              membersCount: 12,
              maxMembers: 30,
              weeklyScore: 120,
              totalScore: 1200,
            ),
          ],
          liveSessions: [
            AdminLiveSessionSummary(
              id: 'arena_test_1',
              pinCode: '54321',
              title: 'بطولة التاريخ',
              hostName: 'المشرف',
              status: 'active',
              participantsCount: 25,
            ),
          ],
        );
      };

      admin.diwanModeratorOverride = ({
        required String action,
        String? messageId,
        String? targetUserId,
        int muteHours = 24,
        String reason = '',
      }) async {
        executedDiwanAction = action;
        return {'ok': true};
      };

      admin.guildArenaModeratorOverride = ({
        required String action,
        required String targetId,
        String reason = '',
      }) async {
        executedGuildAction = action;
        return {
          'ok': true,
          'leaderboard': [
            {'player_id': 'p1', 'score': 100}
          ]
        };
      };

      await tester.pumpWidget(_wrap360(const AdminSocialModerationScreen()));
      await tester.pumpAndSettle();

      // Tab 1: Reports
      expect(find.textContaining('نص إعلان غير لائق'), findsOneWidget);
      expect(find.text('4 بلاغات ⚠️'), findsOneWidget);

      final muteBtn = find.byKey(const Key('btn_mute_report_user_rep_msg_1'));
      expect(muteBtn, findsOneWidget);
      await tester.tap(muteBtn);
      await tester.pumpAndSettle();
      expect(executedDiwanAction, equals('mute_user'));

      // Switch to Tab 2: Muted Users
      final mutedTab = find.byKey(const Key('admin_social_moderation_tab_muted'));
      await tester.tap(mutedTab);
      await tester.pumpAndSettle();

      expect(find.text('لاعب مكتوم'), findsOneWidget);
      final unmuteBtn = find.byKey(const Key('unmute_user_btn_muted_user_1'));
      expect(unmuteBtn, findsOneWidget);
      await tester.tap(unmuteBtn);
      await tester.pumpAndSettle();
      expect(executedDiwanAction, equals('unmute_user'));

      // Switch to Tab 3: Guilds & Live Arenas
      final gaTab = find.byKey(const Key('admin_social_moderation_tab_guilds_arenas'));
      await tester.tap(gaTab);
      await tester.pumpAndSettle();

      expect(find.text('PIN: 54321'), findsOneWidget);
      expect(find.text('كتيبة الفاتحين'), findsOneWidget);

      final forceFinishBtn = find.byKey(const Key('btn_force_finish_session_arena_test_1'));
      expect(forceFinishBtn, findsOneWidget);
      await tester.tap(forceFinishBtn);
      await tester.pumpAndSettle();
      expect(executedGuildAction, equals('force_finish_session'));

      final resetGuildBtn = find.byKey(const Key('btn_reset_guild_score_g_test_1'));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(resetGuildBtn, findsOneWidget);
      await tester.tap(resetGuildBtn);
      await tester.pumpAndSettle();
      expect(executedGuildAction, equals('reset_single_guild_score'));

      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminPlayersSupportScreen renders permissions card and saves tri-state permission', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final admin = AdminService();
      Map<String, dynamic>? savedPerms;

      admin.userSearcherOverride = ({required String query, int limit = 20}) async {
        return const [
          AdminPlayerSearchResult(
            userId: 'usr_support_1',
            playerCode: 'SAH-7777',
            displayName: 'فارس التجربة',
            email: 'tester@gmail.com',
            trophies: 1250,
            playerLevel: 5,
            totalScore: 4000,
            isGuest: false,
          ),
        ];
      };

      admin.playerDetailFetcherOverride = ({String? userId, String? playerCode}) async {
        return const AdminPlayerDetail(
          userId: 'usr_support_1',
          playerCode: 'SAH-7777',
          directory: {'display_name': 'فارس التجربة'},
          progress: {'coins': 500, 'gems': 10, 'total_score': 4000, 'player_level': 5},
          leaderboard: {'score': 4000, 'trophies': 1250},
          permissions: PlayerPermissions(
            canUseOnline: true,
            canUseDiwan: true,
            canUseGuilds: true,
            canHostLiveArenas: null,
          ),
        );
      };

      admin.playerPermissionsUpserterOverride = ({
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
        savedPerms = {
          'user_id': userId,
          'is_banned': isBanned,
          'can_use_online': canUseOnline,
          'can_use_diwan': canUseDiwan,
          'can_use_guilds': canUseGuilds,
          'can_host_live_arenas': canHostLiveArenas,
          'notes': notes,
          'player_code': 'SAH-7777',
        };
        return savedPerms;
      };

      await tester.pumpWidget(_wrap360(const AdminPlayersSupportScreen()));
      await tester.pumpAndSettle();

      // Tap on player row to open dossier
      final row = find.text('فارس التجربة');
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();

      // Permissions card must appear
      final permCard = find.byKey(const Key('player_permissions_card'));
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(permCard, findsOneWidget);

      // Verify granular switches and tri-state dropdown
      expect(find.byKey(const Key('perm_switch_online')), findsOneWidget);
      expect(find.byKey(const Key('perm_switch_diwan')), findsOneWidget);
      expect(find.byKey(const Key('perm_switch_guilds')), findsOneWidget);
      expect(
        find.byKey(const Key('player_perm_host_arena_dropdown')),
        findsOneWidget,
      );

      // Save permissions
      final saveBtn = find.byKey(const Key('btn_save_player_permissions'));
      await tester.drag(find.byType(ListView), const Offset(0, -520));
      await tester.pumpAndSettle();
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedPerms, isNotNull);
      expect(savedPerms!['user_id'], equals('usr_support_1'));
      expect(savedPerms!['is_banned'], isFalse);

      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminReleaseControlScreen toggles quick_phrases and live_arena_host_restricted', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final admin = AdminService();
      Map<String, dynamic>? savedConfig;

      admin.releaseConfigSaverOverride = ({
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
      }) async {
        savedConfig = Map<String, dynamic>.from(featureFlags ?? {});
        return const AppReleaseConfig(configVersion: 2);
      };

      await tester.pumpWidget(_wrap360(const AdminReleaseControlScreen()));
      await tester.pumpAndSettle();

      final quickPhrasesTile = find.byKey(const Key('flag_quick_phrases'));
      expect(quickPhrasesTile, findsOneWidget);
      await tester.ensureVisible(quickPhrasesTile);
      await tester.tap(quickPhrasesTile);
      await tester.pumpAndSettle();

      final arenaRestrictedTile = find.byKey(const Key('flag_live_arena_host_restricted'));
      expect(arenaRestrictedTile, findsOneWidget);
      await tester.ensureVisible(arenaRestrictedTile);
      await tester.tap(arenaRestrictedTile);
      await tester.pumpAndSettle();

      final saveBtn = find.byKey(const Key('admin_save_release_config_btn'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedConfig, isNotNull);
      expect(savedConfig!['quick_phrases'], isFalse); // toggled from true to false
      expect(savedConfig!['live_arena_host_restricted'], isFalse); // toggled from true to false
      expect(savedConfig!['guilds_arenas'], isTrue); // default true

      expect(tester.takeException(), isNull);
    });
  });
}
