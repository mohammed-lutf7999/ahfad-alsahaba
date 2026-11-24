import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'multiplayer_models.dart';

/// Handles creating, joining, cancelling, and listening to 6-digit PIN private rooms.
class PrivateRoomService {
  PrivateRoomService({
    required SupabaseClient Function() clientGetter,
    required String? Function() currentUserIdGetter,
  })  : _clientGetter = clientGetter,
        _currentUserIdGetter = currentUserIdGetter;

  final SupabaseClient Function() _clientGetter;
  final String? Function() _currentUserIdGetter;

  SupabaseClient get _client => _clientGetter();
  String? get _currentUserId => _currentUserIdGetter();

  /// Creates a private room with a 6-digit PIN code and 3-minute validity.
  Future<PrivateRoomResult> createPrivateRoom() async {
    try {
      final userId = _currentUserId;
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
        expiresAt:
            expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null,
        seed: seed,
        questionIds: questionIds,
      );
    } catch (e) {
      debugPrint('Error creating private room: $e');
      return PrivateRoomResult(
        error: e is PostgrestException ? e.message : e.toString(),
      );
    }
  }

  /// Joins an active private room using its 6-digit PIN code.
  Future<PrivateRoomResult> joinPrivateRoom(String roomCode) async {
    try {
      final userId = _currentUserId;
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
      return PrivateRoomResult(
        error: e is PostgrestException ? e.message : e.toString(),
      );
    }
  }

  /// Cancels an active private room safely.
  Future<void> cancelPrivateRoom(String matchId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;
      await _client.rpc('cancel_private_room', params: {
        'p_match_id': matchId,
        'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('Error cancelling private room: $e');
    }
  }

  /// Listens to a private room for guest joining (when status becomes 'matched').
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
}
