import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../services/profile_service.dart';

class MatchmakingResult {
  final bool success;
  final String? matchId;
  final String? opponentId;
  final int? seed;
  final List<String>? questionIds;
  final bool isWaiting;
  final String? error;

  MatchmakingResult({
    this.success = false,
    this.matchId,
    this.opponentId,
    this.seed,
    this.questionIds,
    this.isWaiting = false,
    this.error,
  });
}

class MatchState {
  final String status;
  final int currentQuestion;
  final List<String> questionIds;
  final DateTime? startedAt;
  final bool bothReady;

  MatchState({
    required this.status,
    this.currentQuestion = 0,
    this.questionIds = const [],
    this.startedAt,
    this.bothReady = false,
  });

  factory MatchState.fromJson(Map<String, dynamic> json) {
    return MatchState(
      status: json['status'] ?? 'unknown',
      currentQuestion: json['current_question'] ?? 0,
      questionIds: json['question_ids'] != null 
          ? List<String>.from(json['question_ids']) 
          : [],
      startedAt: json['started_at'] != null 
          ? DateTime.parse(json['started_at']) 
          : null,
    );
  }
}

class MultiplayerService {
  static final MultiplayerService _instance = MultiplayerService._internal();
  static MultiplayerService get instance => _instance;

  final SupabaseClient _client = Supabase.instance.client;
  
  // Subscriptions management
  RealtimeChannel? _matchChannel;
  StreamController<MatchState>? _matchStateController;

  MultiplayerService._internal();

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Finds a match using the server-side RPC function.
  Future<MatchmakingResult> findMatch({required String appVersion}) async {
    try {
      final userId = currentUserId;
      if (userId == null) return MatchmakingResult(error: 'User not logged in');

      final response = await _client.rpc('find_or_create_match', params: {
        'p_user_id': userId,
        'p_app_version': appVersion,
      });
      
      if (response == null || (response is List && response.isEmpty)) {
        // User added to queue - waiting
        _startHeartbeat(); // Keep alive
        return MatchmakingResult(success: true, isWaiting: true);
      } else {
        // Match found immediately!
        final data = (response as List).first as Map<String, dynamic>;
        final matchId = data['match_id'] as String;
        final seed = (data['seed'] as num).toInt();
        
        // Determine opponent ID
        final p1 = data['player1_id'] as String;
        final p2 = data['player2_id'] as String;
        final opponentId = (p1 == userId) ? p2 : p1;

        return MatchmakingResult(
          success: true,
          isWaiting: false,
          matchId: matchId,
          opponentId: opponentId,
          seed: seed,
        );
      }
    } catch (e) {
      return MatchmakingResult(error: e.toString());
    }
  }

  Timer? _heartbeatTimer;

  /// Cancels matchmaking by removing the user from the queue.
  Future<void> cancelMatchmaking() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    final userId = currentUserId;
    if (userId == null) return;

    await _client
        .from('matchmaking_queue')
        .delete()
        .eq('user_id', userId);
  }
  
  /// Start sending heartbeats to keep the user "active" in the queue
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
       final userId = currentUserId;
       if (userId == null) {
         timer.cancel();
         return;
       }
       
       try {
         await _client
          .from('matchmaking_queue')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId);
       } catch (e) {
         debugPrint('Heartbeat error: $e');
       }
    });
  }

  /// Listens for a match to be created for this user (when waiting in queue).
  Stream<Map<String, dynamic>> listenForMatchFound() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    final now = DateTime.now();

    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .map((event) {
          // Find the match that involves me (strictly within last 2 minutes, not stale)
          final myMatch = event.firstWhere(
            (row) {
              final isMe = (row['player1_id'] == userId || row['player2_id'] == userId);
              final status = row['status'] as String? ?? '';
              final isNotDone = status != 'finished' && status != 'expired' && status != 'cancelled';
              
              // Filter out stale zombie matches (> 2 minutes old)
              final createdAtStr = row['created_at'] as String?;
              bool isRecent = true;
              if (createdAtStr != null) {
                final createdAt = DateTime.tryParse(createdAtStr);
                if (createdAt != null) {
                  isRecent = now.difference(createdAt).inMinutes < 2;
                }
              }
              return isMe && isNotDone && isRecent;
            },
            orElse: () => <String, dynamic>{},
          );
          return myMatch;
        })
        .where((match) => 
            match.isNotEmpty && 
            match['seed'] != null && 
            match['id'] != null
        );
  }

  /// Confirms this player is ready to start
  Future<bool> confirmReady(String matchId) async {
    final userId = currentUserId;
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
      print('Error confirming ready: $e');
      return false;
    }
  }

  /// Listens to the match state (status, current question, etc.)
  Stream<MatchState> listenToMatchState(String matchId) {
    // Clean up previous subscription
    _matchStateController?.close();
    _matchChannel?.unsubscribe();

    _matchStateController = StreamController<MatchState>.broadcast();

    _matchChannel = _client
        .channel('match_$matchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: matchId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            final state = MatchState.fromJson(newData);
            _matchStateController?.add(state);
          },
        )
        .subscribe();

    // Also fetch initial state
    _fetchMatchState(matchId);

    return _matchStateController!.stream;
  }

  Future<void> _fetchMatchState(String matchId) async {
    try {
      final data = await _client
          .from('matches')
          .select('status, current_question, question_ids, started_at')
          .eq('id', matchId)
          .maybeSingle();
      
      if (data != null) {
        _matchStateController?.add(MatchState.fromJson(data));
      }
    } catch (e) {
      print('Error fetching match state: $e');
    }
  }

  /// Gets the full match data (including question_ids)
  Future<Map<String, dynamic>?> getMatchData(String matchId) async {
    try {
      final data = await _client
          .from('matches')
          .select('*')
          .eq('id', matchId)
          .maybeSingle();
      return data;
    } catch (e) {
      print('Error getting match data: $e');
      return null;
    }
  }

  /// Submits an answer and gets updated scores
  Future<Map<String, int>> submitAnswer({
    required String matchId,
    required int questionIndex,
    required bool isCorrect,
    required int timeLeft,
  }) async {
    final userId = currentUserId;
    if (userId == null) return {'myScore': 0, 'opponentScore': 0};

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
          'myScore': (data['new_score'] as num?)?.toInt() ?? 0,
          'opponentScore': (data['opponent_score'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (e) {
      print('Error submitting answer: $e');
    }
    return {'myScore': 0, 'opponentScore': 0};
  }

  /// Finishes the match and determines winner
  Future<Map<String, dynamic>> finishMatch(String matchId) async {
    final userId = currentUserId;
    if (userId == null) return {};

    try {
      final response = await _client.rpc('finish_match', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
      });

      if (response != null && response is List && response.isNotEmpty) {
        final data = response.first as Map<String, dynamic>;
        final winnerId = data['winner_user_id'];
        final myScore = (data['my_final_score'] as num?)?.toInt() ?? 0;
        final opponentScore = (data['opponent_final_score'] as num?)?.toInt() ?? 0;
        final trophiesDelta = (data['trophies_delta'] as num?)?.toInt() ?? 0;
        final totalTrophies = (data['my_total_trophies'] as num?)?.toInt() ?? 1000;

        // Immediately update local profile score and sync
        final profile = ProfileService.instance.activeProfile;
        if (profile != null && myScore > 0) {
          final newProfile = profile.copyWith(
            totalScore: profile.totalScore + myScore,
          );
          await ProfileService.instance.updateProfile(newProfile);
        }

        return {
          'winnerId': winnerId,
          'myScore': myScore,
          'opponentScore': opponentScore,
          'trophiesDelta': trophiesDelta,
          'totalTrophies': totalTrophies,
        };
      }
    } catch (e) {
      print('Error finishing match: $e');
    }
    return {};
  }

  /// Updates the player's progress in the match (legacy - now prefer submitAnswer)
  Future<void> updateProgress({
    required String matchId,
    required int score,
    required int questionIndex,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _client.from('match_participants').update({
      'current_score': score,
      'current_question_index': questionIndex,
    }).match({
      'match_id': matchId,
      'user_id': userId,
    });
  }

  /// Listens to opponent's progress
  Stream<Map<String, dynamic>> listenToOpponentProgress(String matchId, String opponentId) {
    return _client
        .from('match_participants')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .map((event) {
          return event.firstWhere(
            (row) => row['user_id'] == opponentId,
            orElse: () => <String, dynamic>{}, // Return empty Map
          );
        })
        .where((data) => data.isNotEmpty);
  }

  /// Sends a reaction (emoji) to the opponent via Broadcast
  Future<void> sendReaction(String matchId, String emoji) async {
    try {
      await _client.channel('match_$matchId').sendBroadcastMessage(
        event: 'reaction',
        payload: {'emoji': emoji, 'senderId': currentUserId},
      );
    } catch (e) {
      print('Error sending reaction: $e');
    }
  }

  /// Listens to reactions from the opponent
  Stream<String> listenToReactions(String matchId) {
    final controller = StreamController<String>.broadcast();
    
    _client.channel('match_$matchId').onBroadcast(
      event: 'reaction',
      callback: (payload) {
        final emoji = payload['emoji'] as String? ?? '';
        if (emoji.isNotEmpty) {
          controller.add(emoji);
        }
      },
    ).subscribe();
    
    return controller.stream;
  }

  /// Creates a local bot match
  Future<MatchmakingResult> createBotMatch() async {
    final rnd = Random();
    final seed = rnd.nextInt(100000);
    final matchId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
    
    // Generate random question IDs similar to server
    // categories: quran, hadith, fiqh, seerah, aqeedah
    final categories = ['quran', 'hadith', 'fiqh', 'seerah', 'aqeedah'];
    final questionIds = categories.map((cat) => '$cat:1:${rnd.nextInt(10)}').toList();

    return MatchmakingResult(
      success: true,
      matchId: matchId,
      opponentId: 'bot_opponent',
      seed: seed,
      questionIds: questionIds,
      isWaiting: false,
    );
  }

  /// Fetches basic data (name, avatar) for the opponent from the leaderboard
  Future<Map<String, dynamic>?> fetchOpponentData(String opponentId) async {
    // Check for bot
    if (opponentId == 'bot_opponent') {
       final rnd = Random();
       final botNames = ['الذكي', 'المتحدي', 'العبقري', 'المثقف', 'المنافس'];
       return {
         'display_name': botNames[rnd.nextInt(botNames.length)],
         'avatar_index': rnd.nextInt(10), // Assuming 10 avatars
         'score': 0, // Starts at 0
       };
    }

    try {
      final data = await _client
          .from('leaderboard')
          .select('display_name, avatar_url, score')
          .eq('user_id', opponentId)
          .maybeSingle();
      
      // If not found in leaderboard, try user_progress
      if (data == null) {
         final progress = await _client
          .from('user_progress')
          .select('display_name, avatar_index, total_score')
          .eq('user_id', opponentId)
          .maybeSingle();
         
         if (progress != null) {
           return {
             'display_name': progress['display_name'] ?? 'لاعب',
             'avatar_index': (progress['avatar_index'] as num?)?.toInt() ?? 0,
             'score': (progress['total_score'] as num?)?.toInt() ?? 0,
           };
         }
      }
      
      if (data != null) {
        return {
          'display_name': data['display_name'] ?? 'لاعب',
          'avatar_url': data['avatar_url'],
          'score': (data['score'] as num?)?.toInt() ?? 0,
        };
      }
      
      // Return default if nothing found
      return {
        'display_name': 'لاعب',
        'avatar_index': 0,
        'score': 0,
      };
    } catch (e) {
      return {
        'display_name': 'لاعب',
        'avatar_index': 0,
        'score': 0,
      };
    }
  }

  /// Updates the user's total score after a bot match
  Future<void> updateScoreToCloud(int matchScore) async {
    try {
      final profile = ProfileService.instance.activeProfile;
      if (profile != null) {
        // Update local profile immediately
        final newProfile = profile.copyWith(totalScore: profile.totalScore + matchScore);
        await ProfileService.instance.updateProfile(newProfile);
        
        // Ensure leaderboard is updated (handled by syncProfileToCloud inside updateProfile, 
        // but we can force a check if needed). 
        // ProfileService.updateProfile calls _saveProfiles and usually triggers sync.
      }
    } catch (e) {
      print('Error updating score: $e');
    }
  }

  /// Clean up subscriptions
  void dispose() {
    _matchChannel?.unsubscribe();
    _matchStateController?.close();
  }
}