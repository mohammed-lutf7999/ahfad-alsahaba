import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'multiplayer_models.dart';

/// Manages Realtime channels for match status updates, reactions/quick phrases, and rematch signals.
class MatchRealtimeChannel {
  MatchRealtimeChannel({
    required SupabaseClient Function() clientGetter,
    required String? Function() currentUserIdGetter,
  })  : _clientGetter = clientGetter,
        _currentUserIdGetter = currentUserIdGetter;

  final SupabaseClient Function() _clientGetter;
  final String? Function() _currentUserIdGetter;

  SupabaseClient get _client => _clientGetter();
  String? get _currentUserId => _currentUserIdGetter();

  RealtimeChannel? _matchChannel;
  RealtimeChannel? _reactionChannel;
  RealtimeChannel? _rematchChannel;
  StreamController<MatchState>? _matchStateController;
  StreamController<String>? _reactionController;
  StreamController<Map<String, dynamic>>? _rematchController;
  StreamController<String>? _phraseController;
  DateTime? _lastQuickPhraseAt;

  Stream<String> get quickPhrasesStream {
    if (_phraseController == null || _phraseController!.isClosed) {
      _phraseController = StreamController<String>.broadcast();
    }
    return _phraseController!.stream;
  }

  /// Listens to the match state (status, current question, etc.).
  Stream<MatchState> listenToMatchState(String matchId) {
    _matchStateController?.close();
    _matchChannel?.unsubscribe();

    final controller = StreamController<MatchState>.broadcast();
    _matchStateController = controller;

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
            if (controller.isClosed) return;
            final state = MatchState.fromJson(payload.newRecord);
            controller.add(state);
          },
        )
        .subscribe();

    _fetchMatchState(matchId, controller);
    return controller.stream;
  }

  Future<void> _fetchMatchState(
    String matchId,
    StreamController<MatchState> controller,
  ) async {
    try {
      final data = await _client
          .from('matches')
          .select('status, current_question, question_ids, started_at')
          .eq('id', matchId)
          .maybeSingle();

      if (data != null && !controller.isClosed) {
        controller.add(MatchState.fromJson(data));
      }
    } catch (e) {
      debugPrint('Error fetching match state: $e');
    }
  }

  /// Sends a reaction (emoji) to the opponent via Broadcast.
  Future<void> sendReaction(String matchId, String emoji) async {
    try {
      final channel = _reactionChannel ?? _client.channel('reactions_$matchId');
      await channel.sendBroadcastMessage(
        event: 'reaction',
        payload: {'emoji': emoji, 'senderId': _currentUserId},
      );
    } catch (e) {
      debugPrint('Error sending reaction: $e');
    }
  }

  /// Sends a polite chivalric quick phrase over the existing match channel (0 extra sockets).
  Future<void> sendQuickPhrase(String matchId, String phrase) async {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    if (_lastQuickPhraseAt != null &&
        now.difference(_lastQuickPhraseAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastQuickPhraseAt = now;
    try {
      final channel = _reactionChannel ?? _client.channel('reactions_$matchId');
      await channel.sendBroadcastMessage(
        event: 'quick_phrase',
        payload: {'phrase': trimmed, 'senderId': _currentUserId},
      );
    } catch (e) {
      debugPrint('Error sending quick phrase: $e');
    }
  }

  /// Listens to reactions & chivalric quick phrases from the opponent on one channel.
  Stream<String> listenToReactions(String matchId) {
    _reactionChannel?.unsubscribe();
    _reactionController?.close();
    final controller = StreamController<String>.broadcast();
    _reactionController = controller;

    _reactionChannel = _client.channel('reactions_$matchId');
    _reactionChannel!
        .onBroadcast(
          event: 'reaction',
          callback: (payload) {
            if (controller.isClosed) return;
            final senderId = payload['senderId'] as String?;
            if (senderId != null && senderId == _currentUserId) return;
            final emoji = payload['emoji'] as String? ?? '';
            if (emoji.isNotEmpty) controller.add(emoji);
          },
        )
        .onBroadcast(
          event: 'quick_phrase',
          callback: (payload) {
            final senderId = payload['senderId'] as String?;
            if (senderId != null && senderId == _currentUserId) return;
            final phrase = payload['phrase']?.toString().trim() ?? '';
            final pc = _phraseController;
            if (phrase.isNotEmpty && pc != null && !pc.isClosed) {
              pc.add(phrase);
            }
          },
        )
        .subscribe();

    return controller.stream;
  }

  /// Sends a rematch offer to the opponent via Broadcast.
  Future<void> sendRematchOffer(String matchId) async {
    try {
      final channel = _rematchChannel ?? _client.channel('rematch_$matchId');
      _rematchChannel = channel;
      await channel.sendBroadcastMessage(
        event: 'rematch_offer',
        payload: {'senderId': _currentUserId},
      );
    } catch (e) {
      debugPrint('Error sending rematch offer: $e');
    }
  }

  /// Broadcasts rematch acceptance with the newly created match ID.
  Future<void> sendRematchAccept(
    String parentMatchId, {
    required String senderId,
    required String newMatchId,
  }) async {
    try {
      final channel =
          _rematchChannel ?? _client.channel('rematch_$parentMatchId');
      await channel.sendBroadcastMessage(
        event: 'rematch_accept',
        payload: {'senderId': senderId, 'matchId': newMatchId},
      );
    } catch (e) {
      debugPrint('Error broadcasting rematch accept: $e');
    }
  }

  /// Sends a rematch leave/exit signal to notify opponent immediately.
  Future<void> sendRematchLeave(String matchId) async {
    try {
      final channel = _rematchChannel ?? _client.channel('rematch_$matchId');
      await channel.sendBroadcastMessage(
        event: 'rematch_leave',
        payload: {'senderId': _currentUserId},
      );
    } catch (e) {
      debugPrint('Error sending rematch leave: $e');
    }
  }

  /// Listens to rematch events (offer, accept, leave).
  Stream<Map<String, dynamic>> listenToRematchEvents(String matchId) {
    _rematchChannel?.unsubscribe();
    _rematchController?.close();
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _rematchController = controller;

    _rematchChannel = _client.channel('rematch_$matchId');
    _rematchChannel!.onBroadcast(
      event: 'rematch_offer',
      callback: (payload) {
        if (controller.isClosed) return;
        final senderId = payload['senderId'] as String?;
        if (senderId != null && senderId != _currentUserId) {
          controller.add({'event': 'offer', 'senderId': senderId});
        }
      },
    );
    _rematchChannel!.onBroadcast(
      event: 'rematch_accept',
      callback: (payload) {
        if (controller.isClosed) return;
        final senderId = payload['senderId'] as String?;
        final newMatchId = payload['matchId'] as String?;
        if (senderId != null && senderId != _currentUserId) {
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
        if (controller.isClosed) return;
        final senderId = payload['senderId'] as String?;
        if (senderId != null && senderId != _currentUserId) {
          controller.add({'event': 'leave', 'senderId': senderId});
        }
      },
    );

    _rematchChannel!.subscribe();
    return controller.stream;
  }

  void closeRematchChannel() {
    _rematchChannel?.unsubscribe();
    _rematchChannel = null;
    _rematchController?.close();
    _rematchController = null;
  }

  void dispose() {
    _matchChannel?.unsubscribe();
    _matchChannel = null;
    _reactionChannel?.unsubscribe();
    _reactionChannel = null;
    _rematchChannel?.unsubscribe();
    _rematchChannel = null;
    _matchStateController?.close();
    _matchStateController = null;
    _reactionController?.close();
    _reactionController = null;
    _rematchController?.close();
    _rematchController = null;
    _phraseController?.close();
    _phraseController = null;
  }
}
