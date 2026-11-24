import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile_service.dart';
import 'match_realtime_channel.dart';
import 'multiplayer_models.dart';

/// Handles active match lifecycle: readiness, answer submission, opponent progress,
/// instant rematch RPC, opponent profile lookup, and finish/score sync.
class MatchSessionService {
  MatchSessionService({
    required SupabaseClient Function() clientGetter,
    required String? Function() currentUserIdGetter,
    required MatchRealtimeChannel realtimeChannel,
  })  : _clientGetter = clientGetter,
        _currentUserIdGetter = currentUserIdGetter,
        _realtimeChannel = realtimeChannel;

  final SupabaseClient Function() _clientGetter;
  final String? Function() _currentUserIdGetter;
  final MatchRealtimeChannel _realtimeChannel;

  SupabaseClient get _client => _clientGetter();
  String? get _currentUserId => _currentUserIdGetter();

  /// Confirms this player is ready to start.
  Future<bool> confirmReady(String matchId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final response = await _client.rpc('confirm_ready', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
      });

      if (response != null && response is List && response.isNotEmpty) {
        final data = response.first as Map<String, dynamic>;
        return data['both_ready'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error confirming ready: $e');
      return false;
    }
  }

  /// Gets the full match data (including question_ids).
  Future<Map<String, dynamic>?> getMatchData(String matchId) async {
    try {
      return await _client
          .from('matches')
          .select('*')
          .eq('id', matchId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error getting match data: $e');
      return null;
    }
  }

  /// Submits an answer and gets updated scores.
  Future<Map<String, int>> submitAnswer({
    required String matchId,
    required int questionIndex,
    required bool isCorrect,
    required int timeLeft,
    int currentLocalScore = 0,
  }) async {
    final userId = _currentUserId;
    final fallbackPoints = isCorrect ? (10 + timeLeft.clamp(0, 15)) : 0;
    final fallbackScore = currentLocalScore + fallbackPoints;

    if (userId == null) return {'myScore': fallbackScore, 'opponentScore': 0};

    try {
      final response = await _client.rpc('submit_answer', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
        'p_question_index': questionIndex,
        'p_is_correct': isCorrect,
        'p_time_left': timeLeft,
      });

      if (response != null && response is List && response.isNotEmpty) {
        final data = response.first as Map<String, dynamic>;
        return {
          'myScore': (data['new_score'] as num?)?.toInt() ?? fallbackScore,
          'opponentScore': (data['opponent_score'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (e) {
      debugPrint('Error submitting answer via RPC, using fallback update: $e');
      try {
        await updateProgress(
          matchId: matchId,
          score: fallbackScore,
          questionIndex: questionIndex + 1,
        );
      } catch (_) {}
    }
    return {'myScore': fallbackScore, 'opponentScore': 0};
  }

  /// Finishes the match and determines winner.
  Future<Map<String, dynamic>> finishMatch(String matchId) async {
    final userId = _currentUserId;
    if (userId == null) return {};

    try {
      final response = await _client.rpc('finish_match', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
      });

      if (response != null && response is List && response.isNotEmpty) {
        final data = response.first as Map<String, dynamic>;
        return {
          'winnerId': data['winner_user_id'],
          'myScore': (data['my_final_score'] as num?)?.toInt() ?? 0,
          'opponentScore': (data['opponent_final_score'] as num?)?.toInt() ?? 0,
          'trophiesDelta': (data['trophies_delta'] as num?)?.toInt() ?? 0,
          'totalTrophies':
              (data['my_total_trophies'] as num?)?.toInt() ?? 1000,
        };
      }
    } catch (e) {
      debugPrint('Error finishing match: $e');
    }
    return {};
  }

  /// Updates the player's progress in the match (legacy fallback).
  Future<void> updateProgress({
    required String matchId,
    required int score,
    required int questionIndex,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _client.from('match_participants').update({
      'current_score': score,
      'current_question_index': questionIndex,
    }).match({
      'match_id': matchId,
      'user_id': userId,
    });
  }

  /// Listens to opponent's progress.
  Stream<Map<String, dynamic>> listenToOpponentProgress(
    String matchId,
    String opponentId,
  ) {
    return _client
        .from('match_participants')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .map((event) {
          return event.firstWhere(
            (row) => row['user_id'] == opponentId,
            orElse: () => <String, dynamic>{},
          );
        })
        .where((data) => data.isNotEmpty);
  }

  /// Calls the idempotent RPC `create_instant_rematch` to start or join a rematch room.
  Future<MatchmakingResult> createInstantRematch({
    required String parentMatchId,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return MatchmakingResult(error: 'User not logged in');

      final response = await _client.rpc('create_instant_rematch', params: {
        'p_parent_match_id': parentMatchId,
        'p_user_id': userId,
      });

      if (response == null || (response is List && response.isEmpty)) {
        return MatchmakingResult(error: 'Failed to create rematch');
      }

      final data = (response as List).first as Map<String, dynamic>;
      final matchId = data['match_id'] as String;
      final seed = (data['seed'] as num).toInt();
      final questionIds = data['question_ids'] != null
          ? List<String>.from(data['question_ids'])
          : null;
      final isFriendly = data['is_friendly'] as bool? ?? false;

      final p1 = data['player1_id'] as String;
      final p2 = data['player2_id'] as String;
      final opponentId = (p1 == userId) ? p2 : p1;

      await _realtimeChannel.sendRematchAccept(
        parentMatchId,
        senderId: userId,
        newMatchId: matchId,
      );

      return MatchmakingResult(
        success: true,
        matchId: matchId,
        opponentId: opponentId,
        seed: seed,
        questionIds: questionIds,
        isFriendly: isFriendly,
      );
    } catch (e) {
      debugPrint('Error creating instant rematch: $e');
      return MatchmakingResult(
        error: e is PostgrestException ? e.message : e.toString(),
      );
    }
  }

  /// Fetches basic data (name, avatar, score, glory level, frame, win streak) for the opponent.
  Future<Map<String, dynamic>?> fetchOpponentData(String opponentId) async {
    if (opponentId == 'bot_opponent') {
      final rnd = Random();
      final botNames = ['الذكي', 'المتحدي', 'العبقري', 'المثقف', 'المنافس'];
      final myProfile = ProfileService.instance.activeProfile;
      final baseScore = myProfile?.totalScore ?? 600;
      final botScore =
          (baseScore + (rnd.nextInt(400) - 150)).clamp(150, 50000);
      final baseTrophies = myProfile?.trophies ?? 1000;
      final botTrophies =
          (baseTrophies + (rnd.nextInt(120) - 60)).clamp(800, 3000);
      return {
        'display_name': botNames[rnd.nextInt(botNames.length)],
        'avatar_index': rnd.nextInt(10),
        'score': botScore,
        'trophies': botTrophies,
        'win_streak': rnd.nextInt(4),
      };
    }

    const fallback = {
      'display_name': 'لاعب',
      'avatar_index': 0,
      'score': 0,
      'trophies': 1000,
      'win_streak': 0,
    };

    try {
      final data = await _client
          .from('leaderboard')
          .select(
            'display_name, avatar_url, score, trophies, player_level, player_title, equipped_frame, arena_id, arena_name',
          )
          .eq('user_id', opponentId)
          .maybeSingle();

      final progress = await _client
          .from('user_progress')
          .select(
            'display_name, avatar_index, total_score, player_level, player_title, equipped_frame, win_streak',
          )
          .eq('user_id', opponentId)
          .maybeSingle();

      if (data != null || progress != null) {
        final lbScore = (data?['score'] as num?)?.toInt() ?? 0;
        final upScore = (progress?['total_score'] as num?)?.toInt() ?? 0;
        return {
          'display_name':
              data?['display_name'] ?? progress?['display_name'] ?? 'لاعب',
          'avatar_url': data?['avatar_url'],
          'avatar_index': (progress?['avatar_index'] as num?)?.toInt() ?? 0,
          'score': lbScore >= upScore ? lbScore : upScore,
          'trophies': (data?['trophies'] as num?)?.toInt() ?? 1000,
          'player_level':
              (data?['player_level'] as num?)?.toInt() ??
              (progress?['player_level'] as num?)?.toInt(),
          'player_title':
              (data?['player_title'] as String?) ??
              (progress?['player_title'] as String?),
          'equipped_frame':
              (data?['equipped_frame'] as String?) ??
              (progress?['equipped_frame'] as String?),
          'arena_name': data?['arena_name'] as String?,
          'win_streak': (progress?['win_streak'] as num?)?.toInt() ?? 0,
        };
      }
      return Map<String, dynamic>.from(fallback);
    } catch (_) {
      return Map<String, dynamic>.from(fallback);
    }
  }

  /// Updates the user's total score after a bot match.
  Future<void> updateScoreToCloud(int matchScore) async {
    try {
      final profile = ProfileService.instance.activeProfile;
      if (profile != null) {
        final newProfile =
            profile.copyWith(totalScore: profile.totalScore + matchScore);
        await ProfileService.instance.updateProfile(newProfile);
      }
    } catch (e) {
      debugPrint('Error updating score: $e');
    }
  }
}
