import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/core/app_theme.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_announcements_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_events_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_release_control_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin_dashboard_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/home_dynamic_event_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ThemeData buildTestTheme() {
    return AppTheme.getThemeFor(AppCustomTheme.andalusianGold);
  }

  Widget wrapEdgeToEdge(Widget home) {
    return MaterialApp(
      key: UniqueKey(),
      theme: buildTestTheme(),
      locale: const Locale('ar'),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: mq.copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: home,
    );
  }

  Future<void> setPhoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    AppControlService.instance.resetForTesting();
    AdminService().resetForTesting();
  });

  group('Phase 3A: In-App Admin Command Center (360x800dp)', () {
    test('AppAnnouncement round-trips expiresAt, copyWith, and expiration check cleanly', () async {
      final parsed = AppAnnouncement.fromJson({
        'id': 'ann_exp_1',
        'title': 'عرض موقت',
        'body': 'ينتهي قريباً',
        'message_type': 'admin',
        'target_scope': 'all',
        'is_active': true,
        'expires_at': '2026-12-01T18:30:00.000Z',
      });
      expect(parsed.expiresAt?.toUtc(), equals(DateTime.utc(2026, 12, 1, 18, 30)));
      expect(parsed.isExpiredAt(DateTime.utc(2026, 12, 1, 18, 29)), isFalse);
      expect(parsed.isExpiredAt(DateTime.utc(2026, 12, 1, 18, 30)), isTrue);

      final copied = parsed.copyWith(isActive: false);
      expect(copied.isActive, isFalse);
      expect(copied.expiresAt, equals(parsed.expiresAt));
      expect(copied.toJson()['expires_at'], equals('2026-12-01T18:30:00.000Z'));
    });

    testWidgets('AdminDashboardScreen renders 6 overview stats, email card, and navigates to all 3 new screens with 0 overflow', (tester) async {
      await setPhoneViewport(tester);
      int overviewHits = 0;

      final admin = AdminService();
      admin.overviewFetcherOverride = () async {
        overviewHits++;
        return const AdminOverview(
          totalAccounts: 412,
          directoryPlayers: 309,
          guestPlayers: 103,
          active24h: 47,
          activeEvents: 2,
          activeAnnouncements: 3,
          releaseConfig: AppReleaseConfig(
            minVersionCode: 16,
            latestVersionCode: 18,
            latestVersionName: '1.0.17',
            maintenanceMode: false,
          ),
        );
      };
      admin.announcementsFetcherOverride = ({int limit = 50}) async => [];
      admin.eventsFetcherOverride = () async => [];

      await tester.pumpWidget(wrapEdgeToEdge(const AdminDashboardScreen()));
      await tester.pumpAndSettle();

      expect(overviewHits, equals(1));
      expect(find.text('412'), findsOneWidget);
      expect(find.text('47'), findsOneWidget);
      expect(find.text('309'), findsOneWidget);
      expect(find.text('103'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('إرسال بريد إلكتروني'), findsOneWidget);
      expect(find.text('الإصدارات والصيانة والمزايا'), findsOneWidget);
      expect(find.text('الرسائل الموجّهة والبحث'), findsOneWidget);
      expect(find.text('الأحداث والمواسم الديناميكية'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Navigate to Release Control Screen & back (refreshes overview)
      final releaseCard = find.byKey(const Key('admin_nav_release_control'));
      await tester.ensureVisible(releaseCard);
      await tester.tap(releaseCard);
      await tester.pumpAndSettle();
      expect(find.byType(AdminReleaseControlScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(overviewHits, equals(2));

      // Navigate to Announcements Screen & back
      final annCard = find.byKey(const Key('admin_nav_announcements'));
      await tester.ensureVisible(annCard);
      await tester.tap(annCard);
      await tester.pumpAndSettle();
      expect(find.byType(AdminAnnouncementsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
      await tester.pumpAndSettle();

      // Navigate to Events Screen & back
      final eventsCard = find.byKey(const Key('admin_nav_events'));
      await tester.ensureVisible(eventsCard);
      await tester.tap(eventsCard);
      await tester.pumpAndSettle();
      expect(find.byType(AdminEventsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminReleaseControlScreen validates versions, requires maintenance confirmation, and saves all 6 feature flags', (tester) async {
      await setPhoneViewport(tester);
      int saveCalls = 0;
      Map<String, dynamic>? savedPayload;

      AdminService().releaseConfigSaverOverride = ({
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
        saveCalls++;
        savedPayload = {
          'minVersionCode': minVersionCode,
          'latestVersionCode': latestVersionCode,
          'latestVersionName': latestVersionName,
          'maintenanceMode': maintenanceMode,
          'featureFlags': featureFlags,
        };
        return AppReleaseConfig(
          minVersionCode: minVersionCode,
          latestVersionCode: latestVersionCode,
          latestVersionName: latestVersionName,
          updateTitle: updateTitle,
          updateMessage: updateMessage,
          maintenanceMode: maintenanceMode,
          maintenanceTitle: maintenanceTitle,
          maintenanceMessage: maintenanceMessage,
          featureFlags: AppFeatureFlags.fromJson(featureFlags),
          configVersion: 15,
        );
      };

      await tester.pumpWidget(
        wrapEdgeToEdge(
          const AdminReleaseControlScreen(
            initialConfig: AppReleaseConfig(
              minVersionCode: 16,
              latestVersionCode: 18,
              latestVersionName: '1.0.17',
              configVersion: 14,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 1. Validate minVersionCode > latestVersionCode blocks save cleanly
      final minField = find.widgetWithText(TextFormField, 'الحد الأدنى (إلزامي)');
      final latestField = find.widgetWithText(TextFormField, 'أحدث بناء (اختياري)');
      await tester.enterText(minField, '25');
      await tester.enterText(latestField, '20');

      final saveBtn = find.byKey(const Key('admin_save_release_config_btn'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(saveCalls, equals(0));
      expect(find.text('يجب >= الحد الأدنى'), findsOneWidget);

      // Fix latestVersionCode -> 26, test invalid updateUrl rejected cleanly
      await tester.enterText(latestField, '26');
      final urlField = find.widgetWithText(
        TextFormField,
        'رابط التحديث في المتجر (اختياري/سقوط)',
      );
      await tester.enterText(urlField, 'play.google.com/invalid');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(saveCalls, equals(0));
      expect(find.text('يجب أن يبدأ الرابط بـ https:// أو http://'), findsOneWidget);

      await tester.enterText(
        urlField,
        'https://play.google.com/store/apps/details?id=com.ahfad.alsahaba.battle',
      );
      await tester.pump();

      // 2. Maintenance switch requires confirmation dialog
      final maintSwitch = find.byKey(const Key('admin_maintenance_switch'));
      await tester.ensureVisible(maintSwitch);
      await tester.tap(maintSwitch);
      await tester.pumpAndSettle();
      expect(find.text('تأكيد تفعيل وضع الصيانة'), findsOneWidget);

      await tester.tap(find.text('تأكيد التفعيل'));
      await tester.pumpAndSettle();

      // 3. Toggle knightsStore & ghostMatches feature flags OFF
      final storeFlag = find.byKey(const Key('flag_knights_store'));
      await tester.ensureVisible(storeFlag);
      await tester.tap(storeFlag);
      final ghostFlag = find.byKey(const Key('flag_ghost_matches'));
      await tester.ensureVisible(ghostFlag);
      await tester.tap(ghostFlag);
      await tester.pump();

      // 4. Save succeeds and updates config version
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(saveCalls, equals(1));
      expect(savedPayload?['minVersionCode'], equals(25));
      expect(savedPayload?['latestVersionCode'], equals(26));
      expect(savedPayload?['maintenanceMode'], isTrue);
      expect(savedPayload?['featureFlags']['knights_store'], isFalse);
      expect(savedPayload?['featureFlags']['ghost_matches'], isFalse);
      expect(find.text('بصمة الإعدادات الحالية: #15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminAnnouncementsScreen searches Google & SAH-XXXX guests, sends mandatory targeted message, and toggles list state', (tester) async {
      await setPhoneViewport(tester);
      final admin = AdminService();
      final createdPayloads = <Map<String, dynamic>>[];
      bool? lastToggledState;

      admin.announcementsFetcherOverride = ({int limit = 50}) async => [
            AppAnnouncement(
              id: 'ann_existing_1',
              title: 'تنبيه سابق',
              body: 'محتوى تجريبي',
              messageType: AnnouncementType.admin,
              targetScope: 'all',
              isActive: true,
              receiptCount: 42,
              expiresAt: DateTime(2026, 12, 1, 18, 30),
            ),
          ];

      admin.userSearcherOverride = ({required String query, int limit = 20}) async {
        expect(limit, lessThanOrEqualTo(20));
        return [
          const AdminPlayerSearchResult(
            userId: null,
            playerCode: 'SAH-9X4B',
            displayName: 'فارس الضيوف',
            trophies: 1320,
            isGuest: true,
          ),
          const AdminPlayerSearchResult(
            userId: 'u-google-1',
            playerCode: 'SAH-2M8P',
            displayName: 'بطل جوجل',
            email: 'hero@gmail.com',
            trophies: 1550,
            isGuest: false,
          ),
        ];
      };

      admin.announcementCreatorOverride = ({
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
      }) async {
        createdPayloads.add({
          'title': title,
          'body': body,
          'messageType': messageType,
          'targetScope': targetScope,
          'targetUserId': targetUserId,
          'targetPlayerCode': targetPlayerCode,
          'ctaRoute': ctaRoute,
          'isDismissible': isDismissible,
          'minVersionCode': minVersionCode,
          'maxVersionCode': maxVersionCode,
        });
        return AppAnnouncement(
          id: 'ann_new_1',
          title: title,
          body: body,
          messageType: messageType,
          targetScope: targetScope,
          targetPlayerCode: targetPlayerCode,
          ctaLabel: ctaLabel,
          ctaRoute: ctaRoute,
          isDismissible: isDismissible,
          minVersionCode: minVersionCode,
          maxVersionCode: maxVersionCode,
          isActive: true,
          receiptCount: 0,
        );
      };

      admin.announcementStatusSetterOverride = (id, active) async {
        lastToggledState = active;
        return true;
      };

      await tester.pumpWidget(wrapEdgeToEdge(const AdminAnnouncementsScreen()));
      await tester.pumpAndSettle();

      // Verify existing receipt count & expiresAt display cleanly
      expect(find.text('👁️ 42'), findsOneWidget);
      expect(find.textContaining('ينتهي: 2026-12-01'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Select Mandatory + Single User scope
      await tester.tap(find.byKey(const Key('ann_type_mandatory')));
      await tester.tap(find.byKey(const Key('scope_single_user_chip')));
      await tester.pumpAndSettle();

      // Search & wait debounce (350ms)
      final searchField = find.byKey(const Key('admin_user_search_field'));
      await tester.ensureVisible(searchField);
      await tester.enterText(searchField, 'SAH-9X4B');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('فارس الضيوف'), findsOneWidget);
      expect(find.text('بطل جوجل'), findsOneWidget);

      // Select guest player
      await tester.ensureVisible(find.text('فارس الضيوف'));
      await tester.tap(find.text('فارس الضيوف'));
      await tester.pumpAndSettle();
      expect(find.text('المستهدف: فارس الضيوف (SAH-9X4B)'), findsOneWidget);

      // Fill title, body, route, version bounds
      await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان الرسالة'),
        'هدية مستحقة',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'نص الرسالة'),
        'مبارك حصولك على الوسام الذهبي',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'المسار أو الرابط (اختياري)'),
        AppRoutes.knightsStore,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'من رقم بناء (اختياري)'),
        '18',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'إلى رقم بناء (اختياري)'),
        '20',
      );

      final sendBtn = find.byKey(const Key('admin_send_announcement_btn'));
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(createdPayloads.length, equals(1));
      final sent = createdPayloads.first;
      expect(sent['messageType'], equals(AnnouncementType.mandatory));
      expect(sent['isDismissible'], isFalse);
      expect(sent['targetScope'], equals('single_user'));
      expect(sent['targetPlayerCode'], equals('SAH-9X4B'));
      expect(sent['ctaRoute'], equals(AppRoutes.knightsStore));
      expect(sent['minVersionCode'], equals(18));
      expect(sent['maxVersionCode'], equals(20));
      expect(find.text('هدية مستحقة'), findsOneWidget);
      expect(find.text('البناء: 18..20'), findsOneWidget);
      expect(find.text('المسار: /knights-store'), findsOneWidget);

      // Toggle an existing announcement switch in list
      final listSwitch =
          find.byKey(const Key('toggle_announcement_ann_existing_1'));
      await tester.ensureVisible(listSwitch);
      await tester.tap(listSwitch);
      await tester.pumpAndSettle();
      expect(lastToggledState, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminEventsScreen live-previews banner, saves new event, toggles state, edits, and confirms deletion', (tester) async {
      await setPhoneViewport(tester);
      final admin = AdminService();
      final savedEvents = <Map<String, dynamic>>[];
      final eventsStore = <AppDynamicEvent>[
        const AppDynamicEvent(
          id: 'ev_1',
          badgeText: 'قديم',
          title: 'فعالية سابقة',
          subtitle: 'وصف قديم',
          priority: 50,
          isActive: true,
        ),
      ];

      admin.eventsFetcherOverride = () async => List<AppDynamicEvent>.from(eventsStore);
      admin.eventUpserterOverride = ({
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
      }) async {
        savedEvents.add({
          'id': id,
          'title': title,
          'actionType': actionType,
          'actionTarget': actionTarget,
          'priority': priority,
        });
        final created = AppDynamicEvent(
          id: id ?? 'ev_new_2',
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
        );
        if (id == null) {
          eventsStore.insert(0, created);
        } else {
          final idx = eventsStore.indexWhere((e) => e.id == id);
          if (idx >= 0) eventsStore[idx] = created;
        }
        return created;
      };
      admin.eventTogglerOverride = (id, active) async {
        final idx = eventsStore.indexWhere((e) => e.id == id);
        final old = eventsStore[idx];
        final updated = AppDynamicEvent(
          id: old.id,
          badgeText: old.badgeText,
          title: old.title,
          subtitle: old.subtitle,
          priority: old.priority,
          isActive: active,
        );
        eventsStore[idx] = updated;
        return updated;
      };
      admin.eventDeleterOverride = (id) async {
        eventsStore.removeWhere((e) => e.id == id);
        return true;
      };

      await tester.pumpWidget(wrapEdgeToEdge(const AdminEventsScreen()));
      await tester.pumpAndSettle();

      // Verify live HomeDynamicEventBanner preview updates cleanly
      expect(find.byType(HomeDynamicEventBanner), findsOneWidget);
      // Choose open_url with non-http text -> validation rejects cleanly
      await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان الحدث'),
        'مسابقة ليلة القدر',
      );
      final openUrlChip = find.byKey(const Key('event_action_open_url'));
      await tester.ensureVisible(openUrlChip);
      await tester.tap(openUrlChip);
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'الهدف (مسار أو URL)'),
        'invalid-link',
      );
      final saveBtn = find.byKey(const Key('admin_save_event_btn'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
      expect(find.text('يجب أن يبدأ بـ https://'), findsOneWidget);
      expect(savedEvents, isEmpty);

      // Switch to navigate_route with valid target -> saves cleanly
      final routeChip = find.byKey(const Key('event_action_navigate_route'));
      await tester.ensureVisible(routeChip);
      await tester.tap(routeChip);
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'الهدف (مسار أو URL)'),
        AppRoutes.challenge,
      );

      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedEvents.length, equals(1));
      expect(savedEvents.first['title'], equals('مسابقة ليلة القدر'));
      expect(savedEvents.first['actionType'], equals(DynamicEventActionType.navigateRoute));
      expect(savedEvents.first['actionTarget'], equals(AppRoutes.challenge));

      // Edit existing event ev_1
      final editBtn = find.byKey(const Key('edit_event_ev_1'));
      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();
      expect(find.text('تعديل الحدث المحدد'), findsOneWidget);

      // Toggle existing event switch
      final toggleSwitch = find.byKey(const Key('toggle_event_ev_1'));
      await tester.ensureVisible(toggleSwitch);
      await tester.tap(toggleSwitch);
      await tester.pumpAndSettle();

      // Delete existing event with confirmation dialog
      final deleteBtn = find.byKey(const Key('delete_event_ev_1'));
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();
      expect(find.text('حذف الحدث نهائياً؟'), findsOneWidget);

      await tester.tap(find.text('حذف').last);
      await tester.pumpAndSettle();
      expect(find.text('فعالية سابقة'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
