import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/achievement_model.dart';
import '../models/player_profile_model.dart';

/// Service for syncing user progress to/from Supabase cloud storage.
/// This ensures user data persists across sign-in/sign-out cycles.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if user is authenticated
  bool get _isAuthenticated => _supabase.auth.currentUser != null;
  
  /// Get current user ID
  String? get _userId => _supabase.auth.currentUser?.id;

  /// Sync complete profile data to cloud
  /// Call this after every game completion or significant change
  Future<bool> syncProfileToCloud(PlayerProfile profile) async {
    if (!_isAuthenticated || _userId == null) {
      debugPrint('CloudSync: Not authenticated, skipping sync');
      return false;
    }

    try {
      debugPrint('CloudSync: Syncing profile to cloud...');
      
      // Prepare data for cloud storage
      final data = {
        'user_id': _userId,
        'display_name': profile.name,
        'avatar_index': profile.avatarIndex,
        'total_score': profile.totalScore,
        'high_score': profile.highScore,
        'category_progress': jsonEncode(profile.categoryProgress),
        'level_stars': jsonEncode(profile.levelStars),
        'level_scores': jsonEncode(profile.levelScores),
        'achievement_progress': jsonEncode(
          profile.achievementProgress.map((k, v) => MapEntry(k, v.toJson()))
        ),
        'current_streak': profile.currentStreak,
        'total_days_played': profile.totalDaysPlayed,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if record exists
      final existing = await _supabase
          .from('user_progress')
          .select('id, total_score')
          .eq('user_id', _userId!)
          .maybeSingle();

      if (existing != null) {
        // Update existing record - keep higher score
        final cloudScore = (existing['total_score'] as num?)?.toInt() ?? 0;
        if (profile.totalScore >= cloudScore) {
          // Local has higher or equal score, update cloud
          await _supabase
              .from('user_progress')
              .update(data)
              .eq('user_id', _userId!);
          debugPrint('CloudSync: Updated cloud progress with score ${profile.totalScore}');
        } else {
          // Cloud has higher score - keep higher cloud score and also update local profile!
          profile.totalScore = cloudScore;
          if (cloudScore > profile.highScore) {
            profile.highScore = cloudScore;
          }
          data['total_score'] = cloudScore;
          data['high_score'] = profile.highScore;
          await _supabase
              .from('user_progress')
              .update(data)
              .eq('user_id', _userId!);
          debugPrint('CloudSync: Updated cloud and kept higher cloud score $cloudScore');
        }
      } else {
        // Insert new record
        await _supabase.from('user_progress').insert(data);
        debugPrint('CloudSync: Created new cloud progress record');
      }

      // Also update leaderboard for ranking
      await _updateLeaderboard(profile);

      return true;
    } catch (e) {
      debugPrint('CloudSync Error: $e');
      return false;
    }
  }

  /// Update leaderboard table (for global ranking)
  Future<void> _updateLeaderboard(PlayerProfile profile) async {
    if (!_isAuthenticated || _userId == null) return;

    try {
      final user = _supabase.auth.currentUser!;
      
      // Check if user exists in leaderboard (same pattern as AuthService)
      final existing = await _supabase
          .from('leaderboard')
          .select('id, score')
          .eq('user_id', _userId!)
          .maybeSingle();

      if (existing != null) {
        // Update existing record - keep higher score
        final currentScore = (existing['score'] as num?)?.toInt() ?? 0;
        final newScore = profile.totalScore > currentScore ? profile.totalScore : currentScore;
        if (newScore > profile.totalScore) {
          profile.totalScore = newScore;
        }
        
        await _supabase
            .from('leaderboard')
            .update({
              'display_name': profile.name,
              'avatar_url': user.userMetadata?['avatar_url'],
              'score': newScore,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', _userId!);
        
        debugPrint('CloudSync: Leaderboard updated - score: $newScore');
      } else {
        // Insert new record
        await _supabase.from('leaderboard').insert({
          'user_id': _userId,
          'display_name': profile.name,
          'email': user.email,
          'avatar_url': user.userMetadata?['avatar_url'],
          'score': profile.totalScore,
          'country_code': 'XX',
        });
        
        debugPrint('CloudSync: Leaderboard entry created - score: ${profile.totalScore}');
      }
    } catch (e) {
      debugPrint('CloudSync: Leaderboard update failed: $e');
    }
  }

  /// Fetch complete profile data from cloud
  /// Reconciles both `user_progress` and `leaderboard` so no points are ever lost.
  Future<PlayerProfile?> fetchProfileFromCloud() async {
    if (!_isAuthenticated || _userId == null) {
      debugPrint('CloudSync: Not authenticated, cannot fetch');
      return null;
    }

    try {
      debugPrint('CloudSync: Fetching profile from cloud...');
      
      final data = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', _userId!)
          .maybeSingle();

      Map<String, dynamic>? lbData;
      try {
        lbData = await _supabase
            .from('leaderboard')
            .select('display_name, score')
            .eq('user_id', _userId!)
            .maybeSingle();
      } catch (e) {
        debugPrint('CloudSync: Leaderboard fetch warning: $e');
      }

      if (data == null && lbData == null) {
        debugPrint('CloudSync: No cloud data found for user');
        return null;
      }

      final lbScore = (lbData?['score'] as num?)?.toInt() ?? 0;
      final lbName = lbData?['display_name']?.toString();

      if (data == null && lbData != null) {
        return PlayerProfile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: (lbName != null && lbName.isNotEmpty) ? lbName : 'لاعب',
          avatarIndex: 0,
          linkedUserId: _userId,
          totalScore: lbScore,
          highScore: lbScore,
        );
      }

      // Parse JSON fields from user_progress
      Map<String, int> categoryProgress = {};
      Map<String, int> levelStars = {};
      Map<String, int> levelScores = {};
      Map<String, AchievementProgress> achievementProgress = {};
      
      try {
        if (data!['category_progress'] != null) {
          final decoded = data['category_progress'] is String 
              ? jsonDecode(data['category_progress']) 
              : data['category_progress'];
          if (decoded is Map) {
            categoryProgress = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
          }
        }
        
        if (data['level_stars'] != null) {
          final decoded = data['level_stars'] is String 
              ? jsonDecode(data['level_stars']) 
              : data['level_stars'];
          if (decoded is Map) {
            levelStars = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
          }
        }
        
        if (data['level_scores'] != null) {
          final decoded = data['level_scores'] is String 
              ? jsonDecode(data['level_scores']) 
              : data['level_scores'];
          if (decoded is Map) {
            levelScores = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
          }
        }

        if (data['achievement_progress'] != null) {
          final decoded = data['achievement_progress'] is String
              ? jsonDecode(data['achievement_progress'])
              : data['achievement_progress'];
          if (decoded is Map) {
            achievementProgress = decoded.map(
              (k, v) => MapEntry(
                k.toString(),
                AchievementProgress.fromJson(Map<String, dynamic>.from(v as Map)),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('CloudSync: Error parsing JSON data: $e');
      }

      final upScore = (data!['total_score'] as num?)?.toInt() ?? 0;
      final upHighScore = (data['high_score'] as num?)?.toInt() ?? 0;
      final bestTotalScore = upScore >= lbScore ? upScore : lbScore;
      final bestHighScore = upHighScore >= bestTotalScore ? upHighScore : bestTotalScore;

      // Create profile from cloud data
      final profile = PlayerProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: data['display_name'] ?? lbName ?? 'لاعب',
        avatarIndex: (data['avatar_index'] as num?)?.toInt() ?? 0,
        linkedUserId: _userId,
        totalScore: bestTotalScore,
        highScore: bestHighScore,
        categoryProgress: categoryProgress,
        levelStars: levelStars,
        levelScores: levelScores,
        achievementProgress: achievementProgress,
        currentStreak: (data['current_streak'] as num?)?.toInt() ?? 0,
        totalDaysPlayed: (data['total_days_played'] as num?)?.toInt() ?? 0,
      );

      debugPrint('CloudSync: Fetched profile - score: ${profile.totalScore}, levels: ${levelStars.length}');
      return profile;
    } catch (e) {
      debugPrint('CloudSync: Fetch error: $e');
      return null;
    }
  }

  /// Check if user has cloud data
  Future<bool> hasCloudData() async {
    if (!_isAuthenticated || _userId == null) return false;

    try {
      final data = await _supabase
          .from('user_progress')
          .select('id')
          .eq('user_id', _userId!)
          .maybeSingle();
      return data != null;
    } catch (e) {
      return false;
    }
  }

  /// Delete user's cloud data (for account cleanup)
  Future<bool> deleteCloudData() async {
    if (!_isAuthenticated || _userId == null) return false;

    try {
      await _supabase
          .from('user_progress')
          .delete()
          .eq('user_id', _userId!);
      
      await _supabase
          .from('leaderboard')
          .delete()
          .eq('user_id', _userId!);
      
      debugPrint('CloudSync: Cloud data deleted');
      return true;
    } catch (e) {
      debugPrint('CloudSync: Delete error: $e');
      return false;
    }
  }
}
