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
  final bool isFriendly;

  MatchmakingResult({
    this.success = false,
    this.matchId,
    this.opponentId,
    this.seed,
    this.questionIds,
    this.isWaiting = false,
    this.error,
    this.isFriendly = false,
  });
}

class PrivateRoomResult {
  final bool success;
  final String? matchId;
  final String? roomCode;
  final DateTime? expiresAt;
  final String? opponentId;
  final int? seed;
  final List<String>? questionIds;
  final String? error;

  PrivateRoomResult({
    this.success = false,
    this.matchId,
    this.roomCode,
    this.expiresAt,
    this.opponentId,
    this.seed,
    this.questionIds,
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

class GhostMatchResult {
  final bool success;
  final String? matchId;
  final String? ghostUserId;
  final String? ghostName;
  final int? ghostAvatarIndex;
  final String? ghostFrame;
  final int? ghostLevel;
  final int? ghostTrophies;
  final int? seed;
  final List<String>? questionIds;
  final List<Map<String, dynamic>>? timeline;
  final bool isFriendly;
  final int dailyGhostCount;
  final String? error;

  GhostMatchResult({
    this.success = false,
    this.matchId,
    this.ghostUserId,
    this.ghostName,
    this.ghostAvatarIndex,
    this.ghostFrame,
    this.ghostLevel,
    this.ghostTrophies,
    this.seed,
    this.questionIds,
    this.timeline,
    this.isFriendly = false,
    this.dailyGhostCount = 0,
    this.error,
  });
}

class MultiplayerService {
  static final MultiplayerService _instance = MultiplayerService._internal();
  static MultiplayerService get instance => _instance;

  SupabaseClient get _client => Supabase.instance.client;
  
  // Subscriptions management
  RealtimeChannel? _matchChannel;
  RealtimeChannel? _reactionChannel;
  RealtimeChannel? _rematchChannel;
  StreamController<MatchState>? _matchStateController;

  MultiplayerService._internal();

  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String? lastOpponentId;

  /// Finds a match using the server-side RPC function with dynamic trophy matchmaking & anti-farming.
  Future<MatchmakingResult> findMatch({
    required String appVersion,
    int? trophies,
    String? lastOpponentId,
  }) async {
    try {
      final userId = currentUserId;
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
        // User added to queue - waiting
        _startHeartbeat(); // Keep alive
        return MatchmakingResult(success: true, isWaiting: true);
      } else {
        // Match found immediately! Stop any heartbeat
        stopHeartbeat();
        final data = (response as List).first as Map<String, dynamic>;
        final matchId = data['match_id'] as String;
        final seed = (data['seed'] as num).toInt();
        final questionIds = data['question_ids'] != null
            ? List<String>.from(data['question_ids'])
            : null;
        
        // Determine opponent ID
        final p1 = data['player1_id'] as String;
        final p2 = data['player2_id'] as String;
        final opponentId = (p1 == userId) ? p2 : p1;

        // Remember as last opponent for diversity/anti-farming
        lastOpponentId = opponentId;

        return MatchmakingResult(
          success: true,
          isWaiting: false,
          matchId: matchId,
          opponentId: opponentId,
          seed: seed,
          questionIds: questionIds,
        );
      }
    } catch (e) {
      return MatchmakingResult(error: e.toString());
    }
  }

  Timer? _heartbeatTimer;

  /// Stops the queue heartbeat timer immediately
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Cancels matchmaking by removing the user from the queue.
  Future<void> cancelMatchmaking() async {
    stopHeartbeat();
    
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await _client
          .from('matchmaking_queue')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting from matchmaking_queue: $e');
    }
  }

  /// Cancels/closes a specific match if opponent disconnected or user left VS screen
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
  
  /// Start sending heartbeats to keep the user "active" in the queue
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
       final userId = currentUserId;
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
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    // Only accept matches created around or after this search session started
    final searchStartCutoff = DateTime.now().toUtc().subtract(const Duration(seconds: 15));

    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .map((event) {
          final myMatch = event.firstWhere(
            (row) {
              final isMe = (row['player1_id'] == userId || row['player2_id'] == userId);
              final status = row['status'] as String? ?? '';
              final isFreshMatch = status == 'matched' || status == 'ready';
              
              final createdAtStr = row['created_at'] as String?;
              bool isFromCurrentSearch = true;
              if (createdAtStr != null) {
                final createdAt = DateTime.tryParse(createdAtStr)?.toUtc();
                if (createdAt != null) {
                  isFromCurrentSearch = createdAt.isAfter(searchStartCutoff);
                }
              }
              return isMe && isFreshMatch && isFromCurrentSearch;
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
    int currentLocalScore = 0,
  }) async {
    final userId = currentUserId;
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

        // Local profile score addition and sync is handled centrally in OnlineGameScreen._finishGame
        // to ensure zero duplicate scoring.

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
      final channel = _reactionChannel ?? _client.channel('reactions_$matchId');
      await channel.sendBroadcastMessage(
        event: 'reaction',
        payload: {'emoji': emoji, 'senderId': currentUserId},
      );
    } catch (e) {
      debugPrint('Error sending reaction: $e');
    }
  }

  /// Listens to reactions from the opponent
  Stream<String> listenToReactions(String matchId) {
    _reactionChannel?.unsubscribe();
    final controller = StreamController<String>.broadcast();
    
    _reactionChannel = _client.channel('reactions_$matchId');
    _reactionChannel!.onBroadcast(
      event: 'reaction',
      callback: (payload) {
        final senderId = payload['senderId'] as String?;
        if (senderId != null && senderId == currentUserId) return;
        final emoji = payload['emoji'] as String? ?? '';
        if (emoji.isNotEmpty) {
          controller.add(emoji);
        }
      },
    ).subscribe();
    
    return controller.stream;
  }

  /// Sends a rematch offer to the opponent via Broadcast
  Future<void> sendRematchOffer(String matchId) async {
    try {
      final channel = _rematchChannel ?? _client.channel('rematch_$matchId');
      _rematchChannel = channel;
      await channel.sendBroadcastMessage(
        event: 'rematch_offer',
        payload: {'senderId': currentUserId},
      );
    } catch (e) {
      debugPrint('Error sending rematch offer: $e');
    }
  }

  /// Sends a rematch leave/exit signal to notify opponent immediately
  Future<void> sendRematchLeave(String matchId) async {
    try {
      final channel = _rematchChannel ?? _client.channel('rematch_$matchId');
      await channel.sendBroadcastMessage(
        event: 'rematch_leave',
        payload: {'senderId': currentUserId},
      );
    } catch (e) {
      debugPrint('Error sending rematch leave: $e');
    }
  }

  /// Listens to rematch events (offer, accept, leave)
  Stream<Map<String, dynamic>> listenToRematchEvents(String matchId) {
    _rematchChannel?.unsubscribe();
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    _rematchChannel = _client.channel('rematch_$matchId');
    _rematchChannel!.onBroadcast(
      event: 'rematch_offer',
      callback: (payload) {
        final senderId = payload['senderId'] as String?;
        if (senderId != null && senderId != currentUserId) {
          controller.add({'event': 'offer', 'senderId': senderId});
        }
      },
    );
    _rematchChannel!.onBroadcast(
      event: 'rematch_accept',
      callback: (payload) {
        final senderId = payload['senderId'] as String?;
        final newMatchId = payload['matchId'] as String?;
        if (senderId != null && senderId != currentUserId) {
          controller.add({
            'event': 'accept',
            'senderId': senderId,
            'matchId': newMatchId,
          });
        }
      },
    );
    _rematchChannel!.onBroadcast(
      event: 'rematch_leave',
      callback: (payload) {
        final senderId = payload['senderId'] as String?;
        if (senderId != null && senderId != currentUserId) {
          controller.add({'event': 'leave', 'senderId': senderId});
        }
      },
    );

    _rematchChannel!.subscribe();

    return controller.stream;
  }

  /// Calls the idempotent RPC `create_instant_rematch` to start or join a rematch room
  Future<MatchmakingResult> createInstantRematch({
    required String parentMatchId,
  }) async {
    try {
      final userId = currentUserId;
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

      // Broadcast acceptance with the new match ID
      try {
        final channel = _rematchChannel ?? _client.channel('rematch_$parentMatchId');
        await channel.sendBroadcastMessage(
          event: 'rematch_accept',
          payload: {
            'senderId': userId,
            'matchId': matchId,
          },
        );
      } catch (e) {
        debugPrint('Error broadcasting rematch accept: $e');
      }

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
      return MatchmakingResult(error: e.toString());
    }
  }

  /// Closes the rematch channel
  void closeRematchChannel() {
    _rematchChannel?.unsubscribe();
    _rematchChannel = null;
  }

  /// Creates a private room with a 6-digit PIN code and 3-minute validity
  Future<PrivateRoomResult> createPrivateRoom() async {
    try {
      final userId = currentUserId;
      if (userId == null) return PrivateRoomResult(error: 'User not logged in');

      final response = await _client.rpc('create_private_room', params: {
        'p_host_id': userId,
      });

      if (response == null || (response is List && response.isEmpty)) {
        return PrivateRoomResult(error: 'Failed to create room');
      }

      final data = (response as List).first as Map<String, dynamic>;
      final matchId = data['match_id'] as String;
      final roomCode = data['room_code'] as String;
      final expiresAtStr = data['expires_at'] as String?;
      final seed = (data['seed'] as num).toInt();
      final questionIds = data['question_ids'] != null
          ? List<String>.from(data['question_ids'])
          : null;

      return PrivateRoomResult(
        success: true,
        matchId: matchId,
        roomCode: roomCode,
        expiresAt: expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null,
        seed: seed,
        questionIds: questionIds,
      );
    } catch (e) {
      debugPrint('Error creating private room: $e');
      return PrivateRoomResult(error: e.toString());
    }
  }

  /// Joins an active private room using its 6-digit PIN code
  Future<PrivateRoomResult> joinPrivateRoom(String roomCode) async {
    try {
      final userId = currentUserId;
      if (userId == null) return PrivateRoomResult(error: 'User not logged in');

      final response = await _client.rpc('join_private_room', params: {
        'p_room_code': roomCode.trim(),
        'p_guest_id': userId,
      });

      if (response == null || (response is List && response.isEmpty)) {
        return PrivateRoomResult(error: 'Failed to join room');
      }

      final data = (response as List).first as Map<String, dynamic>;
      final matchId = data['match_id'] as String;
      final hostId = data['host_id'] as String;
      final seed = (data['seed'] as num).toInt();
      final questionIds = data['question_ids'] != null
          ? List<String>.from(data['question_ids'])
          : null;

      return PrivateRoomResult(
        success: true,
        matchId: matchId,
        opponentId: hostId,
        seed: seed,
        questionIds: questionIds,
      );
    } catch (e) {
      debugPrint('Error joining private room: $e');
      return PrivateRoomResult(error: e.toString());
    }
  }

  /// Cancels an active private room safely
  Future<void> cancelPrivateRoom(String matchId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;
      await _client.rpc('cancel_private_room', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('Error cancelling private room: $e');
    }
  }

  /// Listens to a private room for guest joining (when status becomes 'matched')
  Stream<Map<String, dynamic>> listenToPrivateRoom(String matchId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((event) {
          if (event.isEmpty) return <String, dynamic>{};
          return event.first;
        });
  }

  /// Matches or creates a realistic Ghost match with Strict Question Binding & Daily Cap
  Future<GhostMatchResult> findOrCreateGhostMatch({int? trophies}) async {
    try {
      final userId = currentUserId;
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
      final ghostUserId = data['ghost_user_id'] as String?;
      final ghostName = data['ghost_name'] as String? ?? 'فارس الأندلس';
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
      );
    } catch (e) {
      debugPrint('Error finding ghost match: $e');
      return GhostMatchResult(error: e.toString());
    }
  }

  /// Saves a human match timeline to ghost_recordings after applying Hygiene Filter
  Future<bool> saveGhostTimeline({
    required String matchId,
    required List<Map<String, dynamic>> timeline,
  }) async {
    try {
      final userId = currentUserId;
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

  /// Fetches basic data (name, avatar, score, glory level, frame, win streak) for the opponent
  Future<Map<String, dynamic>?> fetchOpponentData(String opponentId) async {
    // Check for bot
    if (opponentId == 'bot_opponent') {
      final rnd = Random();
      final botNames = ['الذكي', 'المتحدي', 'العبقري', 'المثقف', 'المنافس'];
      final myProfile = ProfileService.instance.activeProfile;
      final baseScore = myProfile?.totalScore ?? 600;
      final botScore = (baseScore + (rnd.nextInt(400) - 150)).clamp(150, 50000);
      final baseTrophies = myProfile?.trophies ?? 1000;
      final botTrophies = (baseTrophies + (rnd.nextInt(120) - 60)).clamp(800, 3000);
      return {
        'display_name': botNames[rnd.nextInt(botNames.length)],
        'avatar_index': rnd.nextInt(10),
        'score': botScore,
        'trophies': botTrophies,
        'win_streak': rnd.nextInt(4),
      };
    }

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

      return {
        'display_name': 'لاعب',
        'avatar_index': 0,
        'score': 0,
        'trophies': 1000,
        'win_streak': 0,
      };
    } catch (e) {
      return {
        'display_name': 'لاعب',
        'avatar_index': 0,
        'score': 0,
        'trophies': 1000,
        'win_streak': 0,
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
    stopHeartbeat();
    _matchChannel?.unsubscribe();
    _matchChannel = null;
    _reactionChannel?.unsubscribe();
    _reactionChannel = null;
    _rematchChannel?.unsubscribe();
    _rematchChannel = null;
    _matchStateController?.close();
    _matchStateController = null;
  }
}