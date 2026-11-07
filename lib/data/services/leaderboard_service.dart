import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/arena_model.dart';
import '../models/leaderboard_model.dart';
import '../models/player_level_model.dart';

/// Service for managing leaderboard data with Supabase.
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch global leaderboard stream (Real-time)
  Stream<List<RankEntry>> getLeaderboardStream({
    int limit = 50,
    bool orderByTrophies = false,
  }) {
    final currentUserId = _supabase.auth.currentUser?.id;
    return _supabase
        .from('leaderboard')
        .stream(primaryKey: ['id'])
        .order(orderByTrophies ? 'trophies' : 'score', ascending: false)
        .limit(limit)
        .map((data) {
          final List<Map<String, dynamic>> maps = data;
          return maps.asMap().entries.map((entry) {
            return RankEntry.fromSupabaseMap(
              entry.value,
              rank: entry.key + 1,
              currentUserId: currentUserId,
            );
          }).toList();
        });
  }

  /// Fetch global leaderboard (One-time fetch)
  Future<List<RankEntry>> fetchGlobalLeaderboard({
    int limit = 50,
    bool orderByTrophies = false,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('leaderboard')
          .select()
          .order(orderByTrophies ? 'trophies' : 'score', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;

      return data.asMap().entries.map((entry) {
        final item = entry.value as Map<String, dynamic>;
        return RankEntry.fromSupabaseMap(
          item,
          rank: entry.key + 1,
          currentUserId: currentUserId,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Submit or update user score with computed level, title, and arena metadata
  Future<bool> submitScore(
    int score, {
    String? displayName,
    String? countryCode,
    int? trophies,
    String? equippedFrame,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final existing = await _supabase
          .from('leaderboard')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final currentScore = (existing?['score'] as num?)?.toInt() ?? 0;
      final currentTrophies = (existing?['trophies'] as num?)?.toInt() ?? 1000;
      final bestScore = score > currentScore ? score : currentScore;
      final resolvedTrophies = ArenaModel.clampTrophies(trophies ?? currentTrophies);

      final levelInfo = PlayerLevelInfo.fromTotalScore(bestScore);
      final arenaInfo = ArenaModel.fromTrophies(resolvedTrophies);

      final fullPayload = <String, dynamic>{
        'score': bestScore,
        'display_name': displayName ?? user.userMetadata?['full_name'] ?? 'لاعب',
        'country_code': countryCode ?? (existing?['country_code'] as String?) ?? 'YE',
        'trophies': resolvedTrophies,
        'player_level': levelInfo.level,
        'player_title': levelInfo.title,
        'arena_id': arenaInfo.id,
        'arena_name': arenaInfo.name,
        'equipped_frame': equippedFrame ??
            (existing?['equipped_frame'] as String?) ??
            levelInfo.frameKey,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        try {
          await _supabase
              .from('leaderboard')
              .update(fullPayload)
              .eq('user_id', user.id);
        } on PostgrestException {
          await _supabase
              .from('leaderboard')
              .update({
                'score': bestScore,
                'display_name': fullPayload['display_name'],
                'country_code': fullPayload['country_code'],
                'updated_at': fullPayload['updated_at'],
              })
              .eq('user_id', user.id);
        }
      } else {
        try {
          await _supabase.from('leaderboard').insert({
            'user_id': user.id,
            'email': user.email,
            'avatar_url': user.userMetadata?['avatar_url'],
            ...fullPayload,
          });
        } on PostgrestException {
          await _supabase.from('leaderboard').insert({
            'user_id': user.id,
            'score': bestScore,
            'display_name': fullPayload['display_name'],
            'country_code': fullPayload['country_code'],
            'email': user.email,
          });
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error submitting score: $e');
      return false;
    }
  }

  /// Get current user's rank
  Future<int?> getUserRank() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('leaderboard')
          .select('score')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;

      final userScore = (response['score'] as num).toInt();

      final countResponse = await _supabase
          .from('leaderboard')
          .select('id')
          .gt('score', userScore);

      return (countResponse as List).length + 1;
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return null;
    }
  }
}
