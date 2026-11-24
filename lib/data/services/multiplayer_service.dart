import 'package:supabase_flutter/supabase_flutter.dart';

import 'multiplayer/match_realtime_channel.dart';
import 'multiplayer/match_session_service.dart';
import 'multiplayer/matchmaking_service.dart';
import 'multiplayer/multiplayer_models.dart';
import 'multiplayer/private_room_service.dart';

export 'multiplayer/multiplayer_models.dart';

/// Backward-compatible Facade over specialized multiplayer sub-services.
class MultiplayerService {
  static final MultiplayerService _instance = MultiplayerService._internal();
  static MultiplayerService get instance => _instance;

  late final MatchRealtimeChannel _realtime;
  late final MatchmakingService _matchmaking;
  late final PrivateRoomService _privateRooms;
  late final MatchSessionService _sessions;

  MultiplayerService._internal() {
    _realtime = MatchRealtimeChannel(
      clientGetter: () => _client,
      currentUserIdGetter: () => currentUserId,
    );
    _matchmaking = MatchmakingService(
      clientGetter: () => _client,
      currentUserIdGetter: () => currentUserId,
    );
    _privateRooms = PrivateRoomService(
      clientGetter: () => _client,
      currentUserIdGetter: () => currentUserId,
    );
    _sessions = MatchSessionService(
      clientGetter: () => _client,
      currentUserIdGetter: () => currentUserId,
      realtimeChannel: _realtime,
    );
  }

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String? get lastOpponentId => _matchmaking.lastOpponentId;
  set lastOpponentId(String? value) => _matchmaking.lastOpponentId = value;

  Stream<String> get quickPhrasesStream => _realtime.quickPhrasesStream;

  // ==================== MATCHMAKING & GHOSTS ====================

  Future<MatchmakingResult> findMatch({
    required String appVersion,
    int? trophies,
    String? lastOpponentId,
  }) =>
      _matchmaking.findMatch(
        appVersion: appVersion,
        trophies: trophies,
        lastOpponentId: lastOpponentId,
      );

  void stopHeartbeat() => _matchmaking.stopHeartbeat();

  Future<void> cancelMatchmaking() => _matchmaking.cancelMatchmaking();

  Future<void> cancelMatch(String matchId) => _matchmaking.cancelMatch(matchId);

  Stream<Map<String, dynamic>> listenForMatchFound() =>
      _matchmaking.listenForMatchFound();

  Future<GhostMatchResult> findOrCreateGhostMatch({int? trophies}) =>
      _matchmaking.findOrCreateGhostMatch(trophies: trophies);

  Future<bool> saveGhostTimeline({
    required String matchId,
    required List<Map<String, dynamic>> timeline,
  }) =>
      _matchmaking.saveGhostTimeline(matchId: matchId, timeline: timeline);

  Future<MatchmakingResult> createBotMatch() => _matchmaking.createBotMatch();

  // ==================== PRIVATE ROOMS ====================

  Future<PrivateRoomResult> createPrivateRoom() =>
      _privateRooms.createPrivateRoom();

  Future<PrivateRoomResult> joinPrivateRoom(String roomCode) =>
      _privateRooms.joinPrivateRoom(roomCode);

  Future<void> cancelPrivateRoom(String matchId) =>
      _privateRooms.cancelPrivateRoom(matchId);

  Stream<Map<String, dynamic>> listenToPrivateRoom(String matchId) =>
      _privateRooms.listenToPrivateRoom(matchId);

  // ==================== MATCH SESSIONS & SCORING ====================

  Future<bool> confirmReady(String matchId) => _sessions.confirmReady(matchId);

  Future<Map<String, dynamic>?> getMatchData(String matchId) =>
      _sessions.getMatchData(matchId);

  Future<Map<String, int>> submitAnswer({
    required String matchId,
    required int questionIndex,
    required bool isCorrect,
    required int timeLeft,
    int currentLocalScore = 0,
  }) =>
      _sessions.submitAnswer(
        matchId: matchId,
        questionIndex: questionIndex,
        isCorrect: isCorrect,
        timeLeft: timeLeft,
        currentLocalScore: currentLocalScore,
      );

  Future<Map<String, dynamic>> finishMatch(String matchId) =>
      _sessions.finishMatch(matchId);

  Future<void> updateProgress({
    required String matchId,
    required int score,
    required int questionIndex,
  }) =>
      _sessions.updateProgress(
        matchId: matchId,
        score: score,
        questionIndex: questionIndex,
      );

  Stream<Map<String, dynamic>> listenToOpponentProgress(
    String matchId,
    String opponentId,
  ) =>
      _sessions.listenToOpponentProgress(matchId, opponentId);

  Future<MatchmakingResult> createInstantRematch({
    required String parentMatchId,
  }) =>
      _sessions.createInstantRematch(parentMatchId: parentMatchId);

  Future<Map<String, dynamic>?> fetchOpponentData(String opponentId) =>
      _sessions.fetchOpponentData(opponentId);

  Future<void> updateScoreToCloud(int matchScore) =>
      _sessions.updateScoreToCloud(matchScore);

  // ==================== REALTIME CHANNELS ====================

  Stream<MatchState> listenToMatchState(String matchId) =>
      _realtime.listenToMatchState(matchId);

  Future<void> sendReaction(String matchId, String emoji) =>
      _realtime.sendReaction(matchId, emoji);

  Future<void> sendQuickPhrase(String matchId, String phrase) =>
      _realtime.sendQuickPhrase(matchId, phrase);

  Stream<String> listenToReactions(String matchId) =>
      _realtime.listenToReactions(matchId);

  Future<void> sendRematchOffer(String matchId) =>
      _realtime.sendRematchOffer(matchId);

  Future<void> sendRematchLeave(String matchId) =>
      _realtime.sendRematchLeave(matchId);

  Stream<Map<String, dynamic>> listenToRematchEvents(String matchId) =>
      _realtime.listenToRematchEvents(matchId);

  void closeRematchChannel() => _realtime.closeRematchChannel();

  void dispose() {
    _matchmaking.stopHeartbeat();
    _realtime.dispose();
  }
}
