import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/services/multiplayer_service.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/private_room_hub_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/private_room_lobby_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M9 Private Rooms & Social Invites Tests', () {
    test('PrivateRoomResult initializes with correct properties', () {
      final expiry = DateTime.now().add(const Duration(minutes: 3));
      final result = PrivateRoomResult(
        success: true,
        matchId: 'room_123',
        roomCode: '842190',
        expiresAt: expiry,
        seed: 555,
        questionIds: ['quran:1:0', 'hadith:1:1'],
      );

      expect(result.success, isTrue);
      expect(result.matchId, 'room_123');
      expect(result.roomCode, '842190');
      expect(result.expiresAt, expiry);
      expect(result.seed, 555);
      expect(result.questionIds?.length, 2);
    });

    testWidgets('PrivateRoomHubScreen renders both Create and Join cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [AppCustomTheme.andalusianGold],
          ),
          home: const PrivateRoomHubScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('غرف التحدي الخاصة ⚔️'), findsOneWidget);

      // Verify Card 1: Create Room
      expect(find.text('إنشاء غرفة جديدة'), findsOneWidget);
      expect(find.text('إنشاء غرفة خاصة 🏰'), findsOneWidget);

      // Verify Divider
      expect(find.text('أو'), findsOneWidget);

      // Verify Card 2: Join Room
      expect(find.text('الانضمام إلى غرفة صديق'), findsOneWidget);
      expect(find.text('لصق الكود من الحافظة'), findsOneWidget);
      expect(find.text('دخول المعركة الآن ⚔️'), findsOneWidget);
    });

    testWidgets('PrivateRoomLobbyScreen renders formatted code and share options',
        (WidgetTester tester) async {
      final roomResult = PrivateRoomResult(
        success: true,
        matchId: 'room_test_999',
        roomCode: '842190',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        seed: 12345,
        questionIds: ['quran:1:0', 'hadith:1:0', 'fiqh:1:0'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [AppCustomTheme.andalusianGold],
          ),
          home: PrivateRoomLobbyScreen(
            roomResult: roomResult,
            roomStream: const Stream.empty(),
          ),
        ),
      );

      // Pump 100ms for pulse animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Title
      expect(find.text('غرفة التحدي الخاص ⚔️'), findsOneWidget);

      // Verify Formatted Code (842 - 190)
      expect(find.text('842 - 190'), findsOneWidget);

      // Verify Buttons
      expect(find.text('نسخ الكود'), findsOneWidget);
      expect(find.text('مشاركة واتساب'), findsOneWidget);

      // Verify Matchup Cards
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('بانتظار الصديق..'), findsOneWidget);
      expect(find.text('إلغاء الغرفة والعودة'), findsOneWidget);
    });
  });
}
