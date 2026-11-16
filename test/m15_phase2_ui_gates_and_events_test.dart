import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/core/app_theme.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/ui/dialogs/app_control_dialogs.dart';
import 'package:ahfad_alsahaba/ui/screens/dynamic_event_detail_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/home_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/challenge_menu_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/private_room_hub_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/settings_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/store/knights_store_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/home_dynamic_event_banner.dart';
import 'package:ahfad_alsahaba/ui/widgets/navigation/royal_bottom_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ThemeData buildTestTheme() {
    return AppTheme.lightTheme.copyWith(
      extensions: const <ThemeExtension<dynamic>>[
        AppCustomTheme.andalusianGold,
      ],
    );
  }

  Widget wrapEdgeToEdgeApp({
    required Widget home,
    Map<String, WidgetBuilder>? routes,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return MaterialApp(
      key: UniqueKey(),
      navigatorKey: navigatorKey,
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
      routes: routes ??
          {
            AppRoutes.knightsStore: (_) => const Scaffold(
                  body: Center(child: Text('MOCK_KNIGHTS_STORE_ROUTE')),
                ),
            AppRoutes.challenge: (_) => const Scaffold(
                  body: Center(child: Text('MOCK_CHALLENGE_ROUTE')),
                ),
            AppRoutes.quiz: (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments;
              return Scaffold(
                body: Center(
                  child: Text('MOCK_QUIZ_ROUTE:${args is Map ? args['categoryId'] : ''}'),
                ),
              );
            },
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
    final seedProfile = jsonEncode([
      {
        'id': 'p_test_1',
        'name': 'فارس الاختبار',
        'playerCode': 'SAH-7K9M',
        'totalScore': 2500,
        'highScore': 500,
        'trophies': 1250,
        'coins': 400,
        'gems': 20,
      }
    ]);
    SharedPreferences.setMockInitialValues({
      'player_profiles': seedProfile,
      'active_profile_id': 'p_test_1',
      'device_player_code': 'SAH-7K9M',
      'has_seen_tutorial': true,
    });
    await SharedPrefsService.init(forceReload: true);
    await ProfileService.instance.init();
    AppControlService.instance.resetForTesting();
    AppControlService.instance.buildNumberResolverOverride = () async => 18;
    AppControlCoordinator.instance.resetForTesting();
  });

  group('Pre-Phase 2 Verification Fixes', () {
    test('AppAnnouncement.matchesVersion accurately gates minVersionCode and maxVersionCode', () {
      const ranged = AppAnnouncement(
        id: 'ann_ver',
        messageType: AnnouncementType.normal,
        title: 'نسخة محددة',
        body: 'رسالة لإصدارات معينة',
        minVersionCode: 18,
        maxVersionCode: 20,
      );
      expect(ranged.matchesVersion(17), isFalse);
      expect(ranged.matchesVersion(18), isTrue);
      expect(ranged.matchesVersion(19), isTrue);
      expect(ranged.matchesVersion(20), isTrue);
      expect(ranged.matchesVersion(21), isFalse);

      const unbounded = AppAnnouncement(
        id: 'ann_all',
        messageType: AnnouncementType.normal,
        title: 'عام',
        body: 'للجميع',
      );
      expect(unbounded.matchesVersion(1), isTrue);
      expect(unbounded.matchesVersion(999), isTrue);
    });

    test('Scheduled upcoming event activates automatically via refreshTimedVisualState without extra RPC', () async {
      DateTime fakeNow = DateTime.utc(2026, 11, 16, 10, 0);
      int rpcCalls = 0;

      final service = AppControlService.instance;
      service.clockOverride = () => fakeNow;
      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        rpcCalls++;
        return {
          'changed': true,
          'config_version': 5,
          'is_admin': false,
          'release_config': {'config_version': 5},
          'active_event': {
            'id': 'ev_sched',
            'title': 'حدث مجدول قريباً',
            'is_active': true,
            'starts_at': '2026-11-16T12:00:00Z',
            'ends_at': '2026-11-16T18:00:00Z',
          },
          'announcements': const [],
        };
      };

      await service.syncControlState(force: true, currentVersionCode: 18);
      expect(rpcCalls, equals(1));
      // Future event is preserved in snapshot but NOT visible yet in notifier
      expect(service.snapshot.activeEvent, isNotNull);
      expect(service.activeEventNotifier.value, isNull);

      // Clock crosses startsAt -> refreshTimedVisualState activates without extra DB read
      fakeNow = DateTime.utc(2026, 11, 16, 12, 1);
      service.refreshTimedVisualState();
      expect(service.activeEventNotifier.value?.id, equals('ev_sched'));
      expect(rpcCalls, equals(1));

      // Clock passes endsAt -> automatically clears event without extra DB read
      fakeNow = DateTime.utc(2026, 11, 16, 18, 5);
      service.refreshTimedVisualState();
      expect(service.activeEventNotifier.value, isNull);
      expect(rpcCalls, equals(1));
    });
  });

  group('Phase 2: Protected Gates, Dynamic Events & Feature Flags (360x800dp)', () {
    testWidgets('Maintenance gate blocks back-pop, supports live retry recovery, and honors admin bypass', (tester) async {
      await setPhoneViewport(tester);
      final service = AppControlService.instance;
      bool serverInMaintenance = true;
      bool adminUser = false;

      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        return {
          'changed': true,
          'config_version': serverInMaintenance ? 11 : 12,
          'is_admin': adminUser,
          'release_config': {
            'min_version_code': 1,
            'latest_version_code': 18,
            'maintenance_mode': serverInMaintenance,
            'maintenance_title': 'صيانة مجدولة',
            'maintenance_message': 'جاري ترقية الخوادم؛ نعود خلال دقائق.',
            'config_version': serverInMaintenance ? 11 : 12,
          },
          'active_event': null,
          'announcements': const [],
        };
      };

      late BuildContext hostContext;
      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          home: Builder(
            builder: (ctx) {
              hostContext = ctx;
              return const Scaffold(body: Center(child: Text('HOME_HOST')));
            },
          ),
        ),
      );

      // Non-admin sees maintenance dialog without admin bypass button
      final gateFuture = AppControlCoordinator.instance.checkAndPresent(
        hostContext,
        force: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('صيانة مجدولة'), findsOneWidget);
      expect(find.text('تجاوز الصيانة (دخول المشرف)'), findsNothing);
      expect(tester.takeException(), isNull);

      // PopScope(canPop: false) blocks Navigator.maybePop
      await Navigator.of(hostContext).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('صيانة مجدولة'), findsOneWidget);

      // Server exits maintenance -> tapping 'إعادة المحاولة الآن' closes gate cleanly
      serverInMaintenance = false;
      await tester.tap(find.text('إعادة المحاولة الآن'));
      await tester.pumpAndSettle();
      expect(await gateFuture, isTrue);
      expect(find.text('صيانة مجدولة'), findsNothing);

      // Admin sees bypass button and enters without re-opening until maintenance ends
      serverInMaintenance = true;
      adminUser = true;
      final adminGateFuture = AppControlCoordinator.instance.checkAndPresent(
        hostContext,
        force: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('تجاوز الصيانة (دخول المشرف)'), findsOneWidget);
      await tester.tap(find.text('تجاوز الصيانة (دخول المشرف)'));
      await tester.pumpAndSettle();
      expect(await adminGateFuture, isTrue);
      expect(AppControlCoordinator.instance.isAdminMaintenanceBypassed, isTrue);

      // Subsequent check does not re-block bypassed admin
      final secondAttempt = await AppControlCoordinator.instance.checkAndPresent(
        hostContext,
        force: true,
      );
      expect(secondAttempt, isFalse);
      expect(find.text('صيانة مجدولة'), findsNothing);
    });

    testWidgets('Force update dialog stays unclosable even on userDeniedUpdate fallback', (tester) async {
      await setPhoneViewport(tester);
      final service = AppControlService.instance;
      int performCalls = 0;

      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        return {
          'changed': true,
          'config_version': 20,
          'is_admin': false,
          'release_config': {
            'min_version_code': 25,
            'latest_version_code': 25,
            'latest_version_name': '2.0.0',
            'update_title': 'تحديث حرج متاح',
            'update_message': 'يرجى تحديث التطبيق لمواصلة المنافسة.',
            'config_version': 20,
          },
          'active_event': null,
          'announcements': const [],
        };
      };
      service.performUpdateOverride = ({
        required bool isForced,
        String? customStoreUrl,
      }) async {
        performCalls++;
        expect(isForced, isTrue);
        return AppUpdateOutcome.cancelledByUser;
      };

      late BuildContext hostContext;
      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          home: Builder(
            builder: (ctx) {
              hostContext = ctx;
              return const Scaffold(body: Center(child: Text('HOME_HOST')));
            },
          ),
        ),
      );

      // Intentionally do not await because ForceUpdateDialog never self-dismisses
      AppControlCoordinator.instance.checkAndPresent(hostContext, force: true);
      await tester.pumpAndSettle();

      expect(find.text('تحديث حرج متاح'), findsOneWidget);
      expect(find.text('تحديث الآن'), findsOneWidget);

      await tester.tap(find.text('تحديث الآن'));
      await tester.pumpAndSettle();

      expect(performCalls, equals(1));
      // Still locked open with clear user explanation
      expect(find.text('تحديث حرج متاح'), findsOneWidget);
      expect(
        find.text('هذا التحديث إلزامي للمتابعة؛ يرجى إتمام التحديث من المتجر.'),
        findsOneWidget,
      );

      // Back button / maybePop still blocked
      await Navigator.of(hostContext).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('تحديث حرج متاح'), findsOneWidget);
    });

    testWidgets('Announcements render sequentially for all 4 types, support mandatory lock, ack receipts, and CTA route', (tester) async {
      await setPhoneViewport(tester);
      final service = AppControlService.instance;
      final ackedIds = <String>[];

      service.acknowledgeOverride = ({
        required String announcementId,
        String? playerCode,
      }) async {
        ackedIds.add(announcementId);
        return true;
      };

      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        return {
          'changed': true,
          'config_version': 30,
          'is_admin': false,
          'release_config': {
            'min_version_code': 1,
            'latest_version_code': 18,
            'config_version': 30,
          },
          'active_event': null,
          'announcements': [
            {
              'id': 'ann_mandatory',
              'message_type': 'mandatory',
              'target_scope': 'single_user',
              'title': 'تنبيه إلزامي هام',
              'body': 'يرجى مراجعة قواعد اللعب النظيف.',
            },
            {
              'id': 'ann_admin',
              'message_type': 'admin',
              'title': 'رسالة الإدارة',
              'body': 'تم اعتماد بطولة الفرسان.',
            },
            {
              'id': 'ann_motiv',
              'message_type': 'motivational',
              'title': 'تحدٍ تحفيزي',
              'body': 'أنت على بعد فوز واحد من الوسام الذهبي!',
              'cta_label': 'اذهب للمتجر',
              'cta_route': AppRoutes.knightsStore,
            },
            {
              'id': 'ann_normal',
              'message_type': 'normal',
              'title': 'إشعار عام',
              'body': 'نتمنى لكم تجربة ممتعة.',
            },
          ],
        };
      };

      late BuildContext hostContext;
      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          home: Builder(
            builder: (ctx) {
              hostContext = ctx;
              return const Scaffold(body: Center(child: Text('HOME_HOST')));
            },
          ),
        ),
      );

      final future = AppControlCoordinator.instance.checkAndPresent(
        hostContext,
        force: true,
        allowOptionalUpdate: false,
      );
      await tester.pumpAndSettle();

      // 1. Mandatory announcement cannot be popped via back navigation
      expect(find.text('تنبيه إلزامي هام'), findsOneWidget);
      await Navigator.of(hostContext).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('تنبيه إلزامي هام'), findsOneWidget);

      await tester.tap(find.text('فهمت وأوافق'));
      await tester.pumpAndSettle();

      // 2. Admin message
      expect(find.text('رسالة الإدارة'), findsOneWidget);
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();

      // 3. Motivational with internal CTA
      expect(find.text('تحدٍ تحفيزي'), findsOneWidget);
      expect(find.text('اذهب للمتجر'), findsOneWidget);
      await tester.tap(find.text('اذهب للمتجر'));
      await tester.pumpAndSettle();
      expect(find.text('MOCK_KNIGHTS_STORE_ROUTE'), findsOneWidget);

      // Navigate back -> 4th announcement shows cleanly
      Navigator.of(hostContext).pop();
      await tester.pumpAndSettle();

      expect(find.text('إشعار عام'), findsOneWidget);
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();

      expect(await future, isTrue);
      expect(
        ackedIds,
        equals(['ann_mandatory', 'ann_admin', 'ann_motiv', 'ann_normal']),
      );
      expect(service.pendingAnnouncementsNotifier.value, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Optional update dialog respects 24h cooldown when postponed with لاحقاً', (tester) async {
      await setPhoneViewport(tester);
      DateTime fakeNow = DateTime.utc(2026, 11, 16, 10, 0);
      final service = AppControlService.instance;
      service.clockOverride = () => fakeNow;
      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        return {
          'changed': true,
          'config_version': 31,
          'is_admin': false,
          'release_config': {
            'min_version_code': 1,
            'latest_version_code': 22,
            'latest_version_name': '1.0.22',
            'update_title': 'تحديث اختياري جديد',
            'update_message': 'إصدار محسن متاح على المتجر.',
            'config_version': 31,
          },
          'active_event': null,
          'announcements': const [],
        };
      };

      late BuildContext hostContext;
      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          home: Builder(
            builder: (ctx) {
              hostContext = ctx;
              return const Scaffold(body: Center(child: Text('HOME_HOST')));
            },
          ),
        ),
      );

      final firstFuture = AppControlCoordinator.instance.checkAndPresent(
        hostContext,
        force: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('تحديث اختياري جديد'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);

      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      expect(await firstFuture, isTrue);
      expect(find.text('تحديث اختياري جديد'), findsNothing);

      // Within 24h cooldown -> does not re-open
      fakeNow = fakeNow.add(const Duration(hours: 10));
      final blocked = await AppControlCoordinator.instance.checkAndPresent(
        hostContext,
        force: true,
      );
      expect(blocked, isFalse);
      expect(find.text('تحديث اختياري جديد'), findsNothing);

      // After 24h cooldown -> prompts cleanly again
      fakeNow = fakeNow.add(const Duration(hours: 15));
      final secondFuture = AppControlCoordinator.instance.checkAndPresent(
        hostContext,
        force: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('تحديث اختياري جديد'), findsOneWidget);
      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      expect(await secondFuture, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeDynamicEventBanner collapses to 0px when hidden and opens DynamicEventDetailScreen cleanly at 360x800dp', (tester) async {
      await setPhoneViewport(tester);
      final service = AppControlService.instance;
      final nowUtc = DateTime.now().toUtc();

      // Case 1: Inactive -> SizedBox.shrink (0x0)
      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          home: const Scaffold(
            body: Center(child: HomeDynamicEventBanner()),
          ),
        ),
      );
      await tester.pump();
      final emptyBox = tester.getSize(find.byType(HomeDynamicEventBanner));
      expect(emptyBox.height, equals(0));

      // Case 2: Live event + showEventBanner = true -> renders cleanly & opens detail screen
      final event = AppDynamicEvent(
        id: 'ev_live_1',
        title: 'موسم الخلفاء الراشدين',
        subtitle: 'أسئلة حصرية وأوسمة ذهبية لمدة 48 ساعة',
        body: 'انطلق في مسابقة خاصة تغطي سيرة الخلفاء الراشدين ومواقفهم المشرقة.',
        badgeText: 'موسم نشط الآن',
        iconName: 'mosque',
        themeColorHex: '#D4AF37',
        actionType: DynamicEventActionType.openEventScreen,
        ctaLabel: 'التفاصيل',
        isActive: true,
        startsAt: nowUtc.subtract(const Duration(hours: 1)),
        endsAt: nowUtc.add(const Duration(hours: 24)),
      );

      service.featureFlagsNotifier.value = const AppFeatureFlags(showEventBanner: true);
      service.activeEventNotifier.value = event;

      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          home: const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HomeDynamicEventBanner(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('موسم الخلفاء الراشدين'), findsOneWidget);
      expect(find.text('موسم نشط الآن'), findsOneWidget);
      expect(tester.getSize(find.byType(HomeDynamicEventBanner)).height, greaterThan(48));
      expect(tester.takeException(), isNull);

      // Tapping opens DynamicEventDetailScreen
      await tester.tap(find.text('موسم الخلفاء الراشدين'));
      await tester.pumpAndSettle();
      expect(find.byType(DynamicEventDetailScreen), findsOneWidget);
      expect(find.textContaining('الخلفاء الراشدين'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Case 3: showEventBanner = false collapses live banner to 0px
      service.featureFlagsNotifier.value = const AppFeatureFlags(showEventBanner: false);
      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          home: const Scaffold(
            body: Center(child: HomeDynamicEventBanner()),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(HomeDynamicEventBanner)).height, equals(0));
    });

    testWidgets('FeatureFlags toggle ChallengeMenuScreen, RoyalBottomNavBar, and KnightsStoreScreen gates', (tester) async {
      await setPhoneViewport(tester);
      final service = AppControlService.instance;

      // Enable all flags first
      service.featureFlagsNotifier.value = const AppFeatureFlags(
        privateRooms: true,
        onlineMultiplayer: true,
        dailyChallenges: true,
        knightsStore: true,
      );

      await tester.pumpWidget(
        wrapEdgeToEdgeApp(home: const ChallengeMenuScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('غرف التحدي الخاصة 🏰'), findsOneWidget);
      expect(find.text('الميدان السريع المباشر ⚔️'), findsOneWidget);
      expect(find.text('تحدي البلوتوث المحلي 📡'), findsOneWidget);
      expect(find.text('التحدي اليومي المتجدد 🌟'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Disable privateRooms, onlineMultiplayer, and dailyChallenges dynamically
      service.featureFlagsNotifier.value = const AppFeatureFlags(
        privateRooms: false,
        onlineMultiplayer: false,
        dailyChallenges: false,
        knightsStore: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('التحدي اليومي المتجدد 🌟'), findsNothing);
      expect(find.text('تحدي البلوتوث المحلي 📡'), findsOneWidget);
      expect(find.text('متوفرة قريباً — متوقفة مؤقتاً للصيانة 🔒'), findsOneWidget);
      expect(find.text('المباريات الأونلاين متوقفة مؤقتاً للصيانة 🔒'), findsOneWidget);

      // Tapping locked online mode shows SnackBar instead of navigating
      await tester.tap(find.text('الميدان السريع المباشر ⚔️'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('متوقف مؤقتاً للصيانة والتحديث'), findsOneWidget);

      // RoyalBottomNavBar reflects locked Knights Store
      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          home: Scaffold(
            bottomNavigationBar: RoyalBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('مغلق'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // KnightsStoreScreen directly blocks catalog & offers back button when knightsStore = false
      await tester.pumpWidget(
        wrapEdgeToEdgeApp(home: const KnightsStoreScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('سوق الفرسان مغلق مؤقتاً'), findsOneWidget);
      expect(find.text('العودة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsScreen displays player code SAH-7K9M and copies it to clipboard cleanly', (tester) async {
      await setPhoneViewport(tester);
      String? copiedText;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          copiedText = args?['text']?.toString();
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        wrapEdgeToEdgeApp(home: const SettingsScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('settings_player_code_text')), findsOneWidget);
      expect(find.text('SAH-7K9M'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('settings_copy_player_code_btn')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(copiedText, equals('SAH-7K9M'));
      expect(find.text('تم نسخ كود اللاعب: SAH-7K9M ✅'), findsOneWidget);
    });

    testWidgets('HomeScreen renders active HomeDynamicEventBanner with zero overflow at 360x800dp and defers CoachMark when gate opens', (tester) async {
      await setPhoneViewport(tester);
      final service = AppControlService.instance;
      final nowUtc = DateTime.now().toUtc();

      service.directorySyncOverride = ({
        required String playerCode,
        required String displayName,
        required int trophies,
        required int playerLevel,
        required int totalScore,
        required String platform,
        required String appVersion,
        required int versionCode,
      }) async =>
          true;

      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async =>
          {
            'changed': true,
            'config_version': 40,
            'is_admin': false,
            'release_config': {
              'min_version_code': 1,
              'latest_version_code': 18,
              'config_version': 40,
              'feature_flags': {'show_event_banner': true},
            },
            'active_event': {
              'id': 'ev_home_1',
              'title': 'موسم غزوات بدر والفتح',
              'subtitle': 'نافس في التحدي الموسمي الآن',
              'badge_text': 'موسم نشط',
              'is_active': true,
              'starts_at': nowUtc.subtract(const Duration(hours: 1)).toIso8601String(),
              'ends_at': nowUtc.add(const Duration(hours: 12)).toIso8601String(),
            },
            'announcements': const [],
          };

      await tester.pumpWidget(
        wrapEdgeToEdgeApp(home: const HomeScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeDynamicEventBanner), findsOneWidget);
      expect(find.text('موسم غزوات بدر والفتح'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Now verify CoachMark tutorial is deferred if a blocking gate appears on Home mount
      await SharedPrefsService.setHasSeenTutorial(false);
      await SharedPrefsService.setLastAppControlSyncMs(0);
      AppControlCoordinator.instance.resetForTesting();
      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async =>
          {
            'changed': true,
            'config_version': 41,
            'is_admin': false,
            'release_config': {
              'min_version_code': 1,
              'latest_version_code': 18,
              'maintenance_mode': true,
              'maintenance_title': 'صيانة تمنع التداخل',
              'maintenance_message': 'نعتذر عن التوقف المؤقت.',
              'config_version': 41,
            },
            'active_event': null,
            'announcements': const [],
          };

      await tester.pumpWidget(
        wrapEdgeToEdgeApp(home: const HomeScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('صيانة تمنع التداخل'), findsOneWidget);
      expect(find.text('ملفك الشخصي'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PrivateRoomHubScreen locks directly when privateRooms feature flag is false', (tester) async {
      await setPhoneViewport(tester);
      AppControlService.instance.featureFlagsNotifier.value =
          const AppFeatureFlags(privateRooms: false);

      await tester.pumpWidget(
        wrapEdgeToEdgeApp(home: const PrivateRoomHubScreen()),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('غرف التحدي الخاصة مغلقة مؤقتاً'), findsOneWidget);
      expect(find.text('إنشاء غرفة وتحدي صديق'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('AppControlService.performUpdate falls back cleanly to store launcher and handles failure without throwing', () async {
      const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
      bool allowLaunch = true;
      final launchedUrls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(urlChannel, (call) async {
        if (call.method == 'launch' || call.method == 'launchUrl') {
          final url = (call.arguments as Map?)?['url']?.toString() ?? '';
          launchedUrls.add(url);
          return allowLaunch;
        }
        return false;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(urlChannel, null);
      });

      final outcomeOpened = await AppControlService.instance.performUpdate(
        isForced: true,
        customStoreUrl: 'https://example.com/custom-update',
      );
      expect(outcomeOpened, equals(AppUpdateOutcome.storeOpened));
      expect(launchedUrls, isNotEmpty);

      allowLaunch = false;
      final outcomeFailed = await AppControlService.instance.performUpdate(
        isForced: false,
      );
      expect(outcomeFailed, equals(AppUpdateOutcome.failed));
    });

    testWidgets('Lifecycle resume check via navigatorKey overlay context opens gate without Navigator context error', (tester) async {
      await setPhoneViewport(tester);
      final service = AppControlService.instance;
      service.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async =>
          {
            'changed': true,
            'config_version': 99,
            'is_admin': false,
            'release_config': {
              'min_version_code': 1,
              'latest_version_code': 18,
              'maintenance_mode': true,
              'maintenance_title': 'صيانة عند استئناف التطبيق',
              'maintenance_message': 'اختبار الاستئناف من الخلفية.',
              'config_version': 99,
            },
            'active_event': null,
            'announcements': const [],
          };

      final navKey = GlobalKey<NavigatorState>();
      AppControlCoordinator.instance.markAppReadyForGates();

      await tester.pumpWidget(
        wrapEdgeToEdgeApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Center(child: Text('RESUME_HOST'))),
        ),
      );
      await tester.pump();

      final overlayCtx = navKey.currentState?.overlay?.context;
      expect(overlayCtx, isNotNull);

      AppControlCoordinator.instance.checkAndPresent(
        overlayCtx!,
        force: true,
        allowOptionalUpdate: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('صيانة عند استئناف التطبيق'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
