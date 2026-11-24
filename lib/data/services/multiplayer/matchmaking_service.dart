import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'multiplayer_models.dart';

/// Manages matchmaking queue, heartbeat, ghost matches, and local bot match creation.
class MatchmakingService {
  MatchmakingService({
    required SupabaseClient Function() clientGetter,
    required String? Function() currentUserIdGetter,
  })  : _clientGetter = clientGetter,
        _currentUserIdGetter = currentUserIdGetter;

  final SupabaseClient Function() _clientGetter;
  final String? Function() _currentUserIdGetter;

  SupabaseClient get _client => _clientGetter();
  String? get _currentUserId => _currentUserIdGetter();

  String? lastOpponentId;
  Timer? _heartbeatTimer;

  /// Finds a match using the server-side RPC function with dynamic trophy matchmaking & anti-farming.
  Future<MatchmakingResult> findMatch({
    required String appVersion,
    int? trophies,
    String? lastOpponentId,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return MatchmakingResult(error: 'User not logged in');

      final effectiveOpponentId = lastOpponentId ?? this.lastOpponentId;

      final params = <String, dynamic>{
        'p_user_id': userId,
        'p_app_version': appVersion,
        'p_trophies': trophies ?? 1000,
      };
      if (effectiveOpponentId != null && effectiveOpponentId.isNotEmpty) {
        params['p_last_opponent_id'] = effectiveOpponentId;
      }

      final response = await _client.rpc('find_or_create_match', params: params);

      if (response == null || (response is List && response.isEmpty)) {
        _startHeartbeat();
        return MatchmakingResult(success: true, isWaiting: true);
      }

      stopHeartbeat();
      final data = (response as List).first as Map<String, dynamic>;
      final matchId = data['match_id'] as String;
      final seed = (data['seed'] as num).toInt();
      final questionIds = data['question_ids'] != null
          ? List<String>.from(data['question_ids'])
          : null;

      final p1 = data['player1_id'] as String;
      final p2 = data['player2_id'] as String;
      final opponentId = (p1 == userId) ? p2 : p1;

      this.lastOpponentId = opponentId;

      return MatchmakingResult(
        success: true,
        isWaiting: false,
        matchId: matchId,
        opponentId: opponentId,
        seed: seed,
        questionIds: questionIds,
      );
    } catch (e) {
      return MatchmakingResult(
        error: e is PostgrestException ? e.message : e.toString(),
      );
    }
  }

  /// Stops the queue heartbeat timer immediately.
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Cancels matchmaking by removing the user from the queue.
  Future<void> cancelMatchmaking() async {
    stopHeartbeat();
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _client.from('matchmaking_queue').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting from matchmaking_queue: $e');
    }
  }

  /// Cancels/closes a specific match if opponent disconnected or user left VS screen.
  Future<void> cancelMatch(String matchId) async {
    stopHeartbeat();
    try {
      await _client
          .from('matches')
          .update({'status': 'finished'})
          .eq('id', matchId);
    } catch (e) {
      debugPrint('Error cancelling match: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      final userId = _currentUserId;
      if (userId == null) {
        timer.cancel();
        return;
      }

      try {
        await _client
            .from('matchmaking_queue')
            .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('Heartbeat error: $e');
      }
    });
  }

  /// Listens for a match to be created for this user (when waiting in queue).
  Stream<Map<String, dynamic>> listenForMatchFound() {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();

    final searchStartCutoff =
        DateTime.now().toUtc().subtract(const Duration(seconds: 15));

    return _client.from('matches').stream(primaryKey: ['id']).map((event) {
      final myMatch = event.firstWhere(
        (row) {
          final isMe =
              (row['player1_id'] == userId || row['player2_id'] == userId);
          final status = row['status'] as String? ?? '';
          final isFreshMatch = status == 'matched' || status == 'ready';
          final isNotGhost = row['is_ghost_match'] != true;

          final createdAtStr = row['created_at'] as String?;
          bool isFromCurrentSearch = true;
          if (createdAtStr != null) {
            final createdAt = DateTime.tryParse(createdAtStr)?.toUtc();
            if (createdAt != null) {
              isFromCurrentSearch = createdAt.isAfter(searchStartCutoff);
            }
          }
          return isMe && isFreshMatch && isNotGhost && isFromCurrentSearch;
        },
        orElse: () => <String, dynamic>{},
      );
      if (myMatch.isNotEmpty) {
        stopHeartbeat();
        final p1 = myMatch['player1_id'] as String?;
        final p2 = myMatch['player2_id'] as String?;
        final oppId = (p1 == userId) ? p2 : p1;
        if (oppId != null) {
          lastOpponentId = oppId;
        }
      }
      return myMatch;
    }).where(
      (match) =>
          match.isNotEmpty && match['seed'] != null && match['id'] != null,
    );
  }

  /// Matches or creates a realistic Ghost match with Strict Question Binding & Daily Cap.
  Future<GhostMatchResult> findOrCreateGhostMatch({int? trophies}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return GhostMatchResult(error: 'User not logged in');

      final response = await _client.rpc('find_or_create_ghost_match', params: {
        'p_user_id': userId,
        'p_trophies': trophies ?? 1000,
      });

      if (response == null || (response is List && response.isEmpty)) {
        return GhostMatchResult(error: 'No ghost available');
      }

      final data = (response as List).first as Map<String, dynamic>;
      final matchId = data['match_id'] as String;
      final isHumanMatch = data['is_human_match'] as bool? ?? false;
      final ghostUserId = data['ghost_user_id'] as String?;
      final ghostName = isHumanMatch
          ? (data['ghost_name'] as String?)
          : (data['ghost_name'] as String? ?? 'فارس الأندلس');
      final ghostAvatarIndex =
          (data['ghost_avatar_index'] as num?)?.toInt() ?? 0;
      final ghostFrame = data['ghost_frame'] as String? ?? 'frame_wood';
      final ghostLevel = (data['ghost_level'] as num?)?.toInt() ?? 5;
      final ghostTrophies = (data['ghost_trophies'] as num?)?.toInt() ?? 1000;
      final seed = (data['seed'] as num).toInt();
      final questionIds = data['question_ids'] != null
          ? List<String>.from(data['question_ids'])
          : null;
      final timelineRaw = data['timeline'];
      final List<Map<String, dynamic>> timeline = (timelineRaw is List)
          ? timelineRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      final isFriendly = data['is_friendly'] as bool? ?? false;
      final dailyCount = (data['daily_ghost_count'] as num?)?.toInt() ?? 0;

      return GhostMatchResult(
        success: true,
        matchId: matchId,
        ghostUserId: ghostUserId,
        ghostName: ghostName,
        ghostAvatarIndex: ghostAvatarIndex,
        ghostFrame: ghostFrame,
        ghostLevel: ghostLevel,
        ghostTrophies: ghostTrophies,
        seed: seed,
        questionIds: questionIds,
        timeline: timeline,
        isFriendly: isFriendly,
        dailyGhostCount: dailyCount,
        isHumanMatch: isHumanMatch,
      );
    } catch (e) {
      debugPrint('Error finding ghost match: $e');
      return GhostMatchResult(
        error: e is PostgrestException ? e.message : e.toString(),
      );
    }
  }

  /// Saves a human match timeline to ghost_recordings after applying Hygiene Filter.
  Future<bool> saveGhostTimeline({
    required String matchId,
    required List<Map<String, dynamic>> timeline,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final res = await _client.rpc('save_ghost_timeline', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
        'p_timeline': timeline,
      });
      return res as bool? ?? false;
    } catch (e) {
      debugPrint('Error saving ghost timeline: $e');
      return false;
    }
  }

  /// Creates a local bot match.
  Future<MatchmakingResult> createBotMatch() async {
    final rnd = Random();
    final seed = rnd.nextInt(100000);
    final matchId = 'bot_${DateTime.now().millisecondsSinceEpoch}';

    final allCategories = ['quran', 'hadith', 'fiqh', 'seerah', 'history', 'aqeedah']
      ..shuffle(rnd);
    final questionIds = allCategories
        .take(5)
        .map((cat) => '$cat:${rnd.nextInt(10) + 1}:${rnd.nextInt(10)}')
        .toList();

    return MatchmakingResult(
      success: true,
      matchId: matchId,
      opponentId: 'bot_opponent',
      seed: seed,
      questionIds: questionIds,
      isWaiting: false,
    );
  }
}
