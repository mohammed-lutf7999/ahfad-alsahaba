import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/data/services/multiplayer_service.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/widgets/game_match_result_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M8 Instant Rematch System Tests', () {
    test('MatchmakingResult holds isFriendly flag correctly', () {
      final normalResult = MatchmakingResult(
        success: true,
        matchId: 'match_123',
        opponentId: 'opp_456',
        seed: 777,
        isFriendly: false,
      );
      expect(normalResult.isFriendly, isFalse);

      final friendlyResult = MatchmakingResult(
        success: true,
        matchId: 'match_789',
        opponentId: 'opp_456',
        seed: 888,
        isFriendly: true,
      );
      expect(friendlyResult.isFriendly, isTrue);
    });

    testWidgets('GameMatchResultDialog renders rematch button and score comparison',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  GameMatchResultDialog.show(
                    context,
                    isWinner: true,
                    isDraw: false,
                    effectiveDelta: 25,
                    totalTrophies: 1250,
                    coinsEarned: 50,
                    myScore: 40,
                    opponentScore: 20,
                    opponentName: 'المنافس الأندلسي',
                    isBot: true,
                    onDismiss: () {},
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify Winner Title and Badges
      expect(find.text('انتهت المباراة!'), findsOneWidget);
      expect(find.text('🎉 أنت الفائز!'), findsOneWidget);
      expect(find.text('+25 كأساً 🏆 (1250)'), findsOneWidget);
      expect(find.text('+50 🪙 دنانير الفتح'), findsOneWidget);

      // Verify Score cards
      expect(find.text('أنت'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('المنافس الأندلسي'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);

      // Verify Buttons: Rematch and Return
      expect(find.text('طلب إعادة النزال ⚔️'), findsOneWidget);
      expect(find.text('العودة للرئيسية'), findsOneWidget);
    });

    testWidgets('GameMatchResultDialog calls onDismiss when clicking Return to Home',
        (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  GameMatchResultDialog.show(
                    context,
                    isWinner: false,
                    isDraw: false,
                    effectiveDelta: -12,
                    totalTrophies: 988,
                    coinsEarned: 0,
                    myScore: 10,
                    opponentScore: 30,
                    opponentName: 'فارس المجد',
                    isBot: true,
                    onDismiss: () {
                      dismissed = true;
                    },
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('حظاً أوفر..'), findsOneWidget);

      // Tap Return to Home
      await tester.tap(find.text('العودة للرئيسية'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(find.text('انتهت المباراة!'), findsNothing);
    });
  });
}

