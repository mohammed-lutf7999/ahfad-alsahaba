import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leaderboard_model.dart';

/// Service for managing leaderboard data with Supabase.
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch global leaderboard stream (Real-time)
  Stream<List<RankEntry>> getLeaderboardStream({int limit = 50}) {
    return _supabase
        .from('leaderboard')
        .stream(primaryKey: ['id'])
        .order('score', ascending: false)
        .limit(limit)
        .map((data) {
          final List<Map<String, dynamic>> maps = data;
          return maps.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return RankEntry(
              name: item['display_name'] ?? 'مجهول',
              score: item['score'] ?? 0,
              rank: index + 1,
              countryCode: item['country_code'] ?? '',
              isMe: item['user_id'] == _supabase.auth.currentUser?.id,
            );
          }).toList();
        });
  }

  /// Fetch global leaderboard (One-time fetch)
  Future<List<RankEntry>> fetchGlobalLeaderboard({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('leaderboard')
          .select()
          .order('score', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      
      return data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value as Map<String, dynamic>;
        return RankEntry(
          name: item['display_name'] ?? 'مجهول',
          score: item['score'] ?? 0,
          rank: index + 1,
          countryCode: item['country_code'] ?? '',
          isMe: item['user_id'] == _supabase.auth.currentUser?.id,
        );
      }).toList();
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Submit or update user score
  Future<bool> submitScore(int score, {String? displayName, String? countryCode}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Check if user already exists in leaderboard
      final existing = await _supabase
          .from('leaderboard')
          .select('id, score')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) {
        // Update only if new score is higher
        final currentScore = existing['score'] as int? ?? 0;
        if (score > currentScore) {
          await _supabase
              .from('leaderboard')
              .update({
                'score': score,
                'display_name': displayName ?? user.userMetadata?['full_name'] ?? 'لاعب',
                'country_code': countryCode ?? 'XX',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', user.id);
        }
      } else {
        // Insert new record
        await _supabase.from('leaderboard').insert({
          'user_id': user.id,
          'score': score,
          'display_name': displayName ?? user.userMetadata?['full_name'] ?? 'لاعب',
          'country_code': countryCode ?? 'XX',
          'email': user.email,
        });
      }
      return true;
    } catch (e) {
      print('Error submitting score: $e');
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

      final userScore = response['score'] as int;
      
      // Count how many users have higher scores
      final countResponse = await _supabase
          .from('leaderboard')
          .select('id')
          .gt('score', userScore);

      return (countResponse as List).length + 1;
    } catch (e) {
      print('Error getting user rank: $e');
      return null;
    }
  }
}
