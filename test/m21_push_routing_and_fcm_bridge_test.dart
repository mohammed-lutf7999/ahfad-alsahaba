import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/data/services/notification_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/push_notification_service.dart';
import 'package:ahfad_alsahaba/data/services/royal_inbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    await ProfileService.instance.init();
    await ProfileService.instance.createProfile(name: 'فارس الإشعارات', avatarIndex: 0);
    AppControlService.instance.resetForTesting();
    RoyalInboxService.instance.resetForTesting();
    PushNotificationService.instance.resetForTesting();
    NotificationService.resetNavigationForTesting();
  });

  group('M14: Push Token Registration & /inbox Deep-Link Routing', () {
    test('parseRouteFromPayload resolves /inbox payloads and rejects unsafe targets', () {
      expect(NotificationService.parseRouteFromPayload(null), equals(AppRoutes.royalInbox));
      expect(NotificationService.parseRouteFromPayload('/inbox'), equals(AppRoutes.royalInbox));
      expect(NotificationService.parseRouteFromPayload('route:/inbox'), equals(AppRoutes.royalInbox));
      expect(
        NotificationService.parseRouteFromPayload('{"route":"/inbox","id":"ann_1"}'),
        equals(AppRoutes.royalInbox),
      );
      expect(
        NotificationService.parseRouteFromPayload('{"route":"/guilds"}'),
        equals(AppRoutes.guilds),
      );
      expect(NotificationService.parseRouteFromPayload('https://evil.example.com'), isNull);
      expect(NotificationService.parseRouteFromPayload('/unknown-secret'), isNull);
    });

    test('PushNotificationService validates token length and forwards playerCode', () async {
      String? savedToken;
      String? savedCode;
      PushNotificationService.instance.tokenRegistrarOverride = ({
        required String token,
        String? playerCode,
        String provider = 'fcm',
        String platform = 'android',
      }) async {
        savedToken = token;
        savedCode = playerCode;
      };

      expect(await PushNotificationService.instance.registerToken('short'), isFalse);
      final ok = await PushNotificationService.instance.registerToken(
        'fcm_live_device_token_9876543210abcdef',
      );
      expect(ok, isTrue);
      expect(savedToken, equals('fcm_live_device_token_9876543210abcdef'));
      expect(savedCode, equals(ProfileService.instance.activeProfile?.playerCode));
    });

    testWidgets('Tapping notification payload navigates directly to RoyalInboxScreen at 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navKey = GlobalKey<NavigatorState>();
      NotificationService.configureNavigation(navKey);
      RoyalInboxService.instance.inboxFetcherOverride = ({String? playerCode, int limit = 25}) async => [];

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          onGenerateRoute: AppRoutes.generateRoute,
          home: const Scaffold(body: Center(child: Text('Home Placeholder'))),
        ),
      );
      await tester.pumpAndSettle();

      PushNotificationService.instance.handleExternalTapPayload('{"route":"/inbox"}');
      await tester.pumpAndSettle();

      expect(find.textContaining('صندوق البريد الملكي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
