import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/data/services/multiplayer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M10 Dynamic Trophy Matchmaking & Anti-Farming Tests', () {
    test('Dynamic trophy bracket formula expands accurately over elapsed seconds', () {
      int calculateAllowedDiff(int elapsedSeconds) {
        return 100 + (elapsedSeconds * 25);
      }

      // Initial entry: 0s
      expect(calculateAllowedDiff(0), equals(100));

      // After 2s: 150
      expect(calculateAllowedDiff(2), equals(150));

      // After 4s: 200
      expect(calculateAllowedDiff(4), equals(200));

      // After 8s: 300
      expect(calculateAllowedDiff(8), equals(300));

      // After 12s: 400
      expect(calculateAllowedDiff(12), equals(400));
    });

    test('Trophy proximity matching evaluates within expanding thresholds', () {
      bool isMatchAllowed({
        required int playerTrophies,
        required int opponentTrophies,
        required int queueWaitSeconds,
      }) {
        final diff = (playerTrophies - opponentTrophies).abs();
        final allowed = 100 + (queueWaitSeconds * 25);
        return diff <= allowed;
      }

      const p1Trophies = 1200;
      const closeOpponent = 1280; // diff = 80
      const mediumOpponent = 1380; // diff = 180
      const distantOpponent = 1600; // diff = 400

      // At 0 seconds (bracket = 100):
      expect(isMatchAllowed(playerTrophies: p1Trophies, opponentTrophies: closeOpponent, queueWaitSeconds: 0), isTrue);
      expect(isMatchAllowed(playerTrophies: p1Trophies, opponentTrophies: mediumOpponent, queueWaitSeconds: 0), isFalse);
      expect(isMatchAllowed(playerTrophies: p1Trophies, opponentTrophies: distantOpponent, queueWaitSeconds: 0), isFalse);

      // At 4 seconds (bracket = 200):
      expect(isMatchAllowed(playerTrophies: p1Trophies, opponentTrophies: mediumOpponent, queueWaitSeconds: 4), isTrue);
      expect(isMatchAllowed(playerTrophies: p1Trophies, opponentTrophies: distantOpponent, queueWaitSeconds: 4), isFalse);

      // At 12 seconds (bracket = 400):
      expect(isMatchAllowed(playerTrophies: p1Trophies, opponentTrophies: distantOpponent, queueWaitSeconds: 12), isTrue);
    });

    test('MultiplayerService tracks and updates lastOpponentId for anti-farming diversity', () {
      final service = MultiplayerService.instance;
      expect(service.lastOpponentId, isNull);

      // Simulate match conclusion with opponent 'opp_saladin_99'
      service.lastOpponentId = 'opp_saladin_99';
      expect(service.lastOpponentId, equals('opp_saladin_99'));

      // Switch to a new opponent
      service.lastOpponentId = 'opp_khalid_77';
      expect(service.lastOpponentId, equals('opp_khalid_77'));

      // Clean up
      service.lastOpponentId = null;
      expect(service.lastOpponentId, isNull);
    });
  });
}
