import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/data/services/nearby_service.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/challenge_menu_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M12 Nearby Connections & SDK-Aware Permissions Tests', () {
    test('NearbyPermissionResult holds granted and permanently denied states correctly', () {
      const success = NearbyPermissionResult(isGranted: true);
      expect(success.isGranted, isTrue);
      expect(success.isPermanentlyDenied, isFalse);
      expect(success.failureReason, isNull);

      const denied = NearbyPermissionResult(
        isGranted: false,
        isPermanentlyDenied: true,
        failureReason: 'Location denied',
      );
      expect(denied.isGranted, isFalse);
      expect(denied.isPermanentlyDenied, isTrue);
      expect(denied.failureReason, equals('Location denied'));
    });

    test('NearbyService starts with clean disconnected state and empty players', () {
      final service = NearbyService.instance;
      expect(service.connectionState, equals(ConnectionState.disconnected));
      expect(service.connectedPlayers, isEmpty);
      expect(service.discoveredChallenges, isEmpty);
      expect(service.localId, isEmpty);
      expect(service.currentConfig, isNull);
    });

    testWidgets('ChallengeMenuScreen renders all three chivalric mode buttons cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChallengeMenuScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('وضع التحدي'), findsOneWidget);
      expect(find.text('غرف التحدي الخاصة 🏰'), findsOneWidget);
      expect(find.text('الميدان السريع المباشر ⚔️'), findsOneWidget);
      expect(find.text('تحدي البلوتوث المحلي 📡'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
    });

    testWidgets('Tapping Local Bluetooth button opens Chivalric Role Selection bottom sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChallengeMenuScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Local Bluetooth Challenge
      final bluetoothButton = find.text('تحدي البلوتوث المحلي 📡');
      expect(bluetoothButton, findsOneWidget);
      await tester.tap(bluetoothButton);
      await tester.pumpAndSettle();

      // Check bottom sheet options appear
      expect(find.text('إنشاء تحدي جديد (مضيف 👑)'), findsOneWidget);
      expect(find.text('البحث عن تحدي والانضمام (ضيف 🔍)'), findsOneWidget);
      expect(find.text('كن القائد وحدد نوع الأسئلة وعددها'), findsOneWidget);
    });
  });
}
