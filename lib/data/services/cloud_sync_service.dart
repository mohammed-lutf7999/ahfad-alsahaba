import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/achievement_model.dart';
import '../models/arena_model.dart';
import '../models/player_level_model.dart';
import '../models/player_profile_model.dart';

/// Service for syncing user progress, levels, arenas, and store inventory to/from Supabase.
/// Guarantees zero data loss across local & cloud sessions.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Check if user is authenticated (safe even if Supabase is not initialized in offline/test environments)
  bool get _isAuthenticated {
    try {
      return _supabase.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Get current user ID
  String? get _userId {
    try {
      return _supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Sync complete profile data (including 100-Level Mastery, Economy & Inventory) to cloud.
  Future<bool> syncProfileToCloud(PlayerProfile profile) async {
    if (!_isAuthenticated || _userId == null) {
      debugPrint('CloudSync: Not authenticated, skipping sync');
      return false;
    }

    try {
      debugPrint('CloudSync: Syncing profile to cloud...');

      // Check if record exists in `user_progress`
      final existing = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', _userId!)
          .maybeSingle();

      if (existing != null) {
        final cloudScore = (existing['total_score'] as num?)?.toInt() ?? 0;
        final cloudHighScore = (existing['high_score'] as num?)?.toInt() ?? 0;

        // Reconcile strictly monotonic fields (`total_score` & `high_score`) with GREATEST
        // so server-awarded points are never overwritten, while allowing non-monotonic fields
        // (`coins`, `gems`, `win_streak`) to reflect legitimate deductions/resets.
        if (cloudScore > profile.totalScore) {
          profile.totalScore = cloudScore;
        }
        if (cloudHighScore > profile.highScore) {
          profile.highScore = cloudHighScore;
        }
      }

      final levelInfo = profile.levelInfo;

      final baseData = <String, dynamic>{
        'user_id': _userId,
        'display_name': profile.name,
        'avatar_index': profile.avatarIndex,
        'total_score': profile.totalScore,
        'high_score': profile.highScore,
        'category_progress': jsonEncode(profile.categoryProgress),
        'level_stars': jsonEncode(profile.levelStars),
        'level_scores': jsonEncode(profile.levelScores),
        'achievement_progress': jsonEncode(
          profile.achievementProgress.map((k, v) => MapEntry(k, v.toJson())),
        ),
        'current_streak': profile.currentStreak,
        'total_days_played': profile.totalDaysPlayed,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final fullData = <String, dynamic>{
        ...baseData,
        'player_level': levelInfo.level,
        'player_title': profile.effectiveTitle,
        'current_level_xp': levelInfo.currentLevelXp,
        'next_level_xp': levelInfo.nextLevelXp,
        'coins': profile.coins,
        'gems': profile.gems,
        'win_streak': profile.winStreak,
        'equipped_theme': profile.equippedTheme,
        'equipped_frame': profile.equippedFrame,
      };

      if (existing != null) {
        try {
          await _supabase
              .from('user_progress')
              .update(fullData)
              .eq('user_id', _userId!);
        } on PostgrestException {
          await _supabase
              .from('user_progress')
              .update(baseData)
              .eq('user_id', _userId!);
        }
        debugPrint(
          'CloudSync: Updated cloud progress (score: ${profile.totalScore}, level: ${levelInfo.level}, coins: ${profile.coins})',
        );
      } else {
        try {
          await _supabase.from('user_progress').insert(fullData);
        } on PostgrestException {
          await _supabase.from('user_progress').insert(baseData);
        }
        debugPrint('CloudSync: Created new cloud progress record');
      }

      // Sync unlocked store items to `user_inventory`
      await _syncInventoryToCloud(profile.unlockedItemIds);

      // Also update leaderboard for global ranking & arena sync
      await _updateLeaderboard(profile);

      return true;
    } catch (e) {
      debugPrint('CloudSync Error: $e');
      return false;
    }
  }

  /// Syncs locally unlocked store items to `public.user_inventory`,
  /// and removes consumed tactical power-ups so they never resurrect or block re-purchase.
  Future<void> _syncInventoryToCloud(List<String> unlockedItemIds) async {
    if (!_isAuthenticated || _userId == null) return;

    try {
      for (final itemId in unlockedItemIds) {
        await _supabase.from('user_inventory').upsert(
          {
            'user_id': _userId,
            'item_id': itemId,
          },
          onConflict: 'user_id,item_id',
        );
      }

      const consumablePowerups = [
        'powerup_shield',
        'powerup_insight',
        'powerup_xp_banner',
      ];
      for (final powerupId in consumablePowerups) {
        if (!unlockedItemIds.contains(powerupId)) {
          await _supabase
              .from('user_inventory')
              .delete()
              .eq('user_id', _userId!)
              .eq('item_id', powerupId);
        }
      }
    } catch (e) {
      // Non-fatal if migration 009 is not yet applied or item_id not in store_items
      debugPrint('CloudSync: Inventory sync notice: $e');
    }
  }

  /// Update leaderboard table (for global ranking, level badge, and competitive arena)
  Future<void> _updateLeaderboard(PlayerProfile profile) async {
    if (!_isAuthenticated || _userId == null) return;

    try {
      final user = _supabase.auth.currentUser!;

      final existing = await _supabase
          .from('leaderboard')
          .select()
          .eq('user_id', _userId!)
          .maybeSingle();

      final currentScore = (existing?['score'] as num?)?.toInt() ?? 0;
      final newScore = math.max(profile.totalScore, currentScore);
      if (newScore > profile.totalScore) {
        profile.totalScore = newScore;
      }

      // Enforce 800-trophy protection floor while honoring active profile's updated trophies
      final effectiveTrophies = ArenaModel.clampTrophies(profile.trophies);
      profile.trophies = effectiveTrophies;

      final levelInfo = PlayerLevelInfo.fromTotalScore(newScore);
      final arenaInfo = ArenaModel.fromTrophies(effectiveTrophies);

      final baseLeaderboardData = <String, dynamic>{
        'display_name': profile.name,
        'avatar_url': user.userMetadata?['avatar_url'],
        'score': newScore,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final fullLeaderboardData = <String, dynamic>{
        ...baseLeaderboardData,
        'trophies': effectiveTrophies,
        'player_level': levelInfo.level,
        'player_title': profile.effectiveTitle,
        'arena_id': arenaInfo.id,
        'arena_name': arenaInfo.name,
        'equipped_frame': profile.equippedFrame,
      };

      if (existing != null) {
        try {
          await _supabase
              .from('leaderboard')
              .update(fullLeaderboardData)
              .eq('user_id', _userId!);
        } on PostgrestException {
          await _supabase
              .from('leaderboard')
              .update(baseLeaderboardData)
              .eq('user_id', _userId!);
        }
        debugPrint(
          'CloudSync: Leaderboard updated - score: $newScore, level: ${levelInfo.level}, arena: ${arenaInfo.name}',
        );
      } else {
        try {
          await _supabase.from('leaderboard').insert({
            'user_id': _userId,
            'email': user.email,
            'country_code': 'YE',
            ...fullLeaderboardData,
          });
        } on PostgrestException {
          await _supabase.from('leaderboard').insert({
            'user_id': _userId,
            'email': user.email,
            'country_code': 'YE',
            ...baseLeaderboardData,
          });
        }
        debugPrint('CloudSync: Leaderboard entry created - score: $newScore');
      }
    } catch (e) {
      debugPrint('CloudSync: Leaderboard update failed: $e');
    }
  }

  /// Fetch complete profile data from cloud.
  /// Reconciles `user_progress`, `leaderboard`, and `user_inventory` so no points or items are ever lost.
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
            .select()
            .eq('user_id', _userId!)
            .maybeSingle();
      } catch (e) {
        debugPrint('CloudSync: Leaderboard fetch warning: $e');
      }

      if (data == null && lbData == null) {
        debugPrint('CloudSync: No cloud data found for user');
        return null;
      }

      // Fetch unlocked store inventory items if available
      final List<String> unlockedItemIds = [
        'theme_andalusian_gold',
        'item_frame_wood',
      ];
      try {
        final invRows = await _supabase
            .from('user_inventory')
            .select('item_id')
            .eq('user_id', _userId!);
        for (final row in (invRows as List<dynamic>)) {
          final itemId = (row as Map<String, dynamic>)['item_id']?.toString();
          if (itemId != null && !unlockedItemIds.contains(itemId)) {
            unlockedItemIds.add(itemId);
          }
        }
      } catch (e) {
        debugPrint('CloudSync: Inventory fetch notice: $e');
      }

      final lbScore = (lbData?['score'] as num?)?.toInt() ?? 0;
      final lbTrophies = ArenaModel.clampTrophies(
        (lbData?['trophies'] as num?)?.toInt() ?? 1000,
      );
      final lbName = lbData?['display_name']?.toString();
      final lbFrame = lbData?['equipped_frame']?.toString();

      if (data == null && lbData != null) {
        final computedLevel = PlayerLevelInfo.fromTotalScore(lbScore);
        return PlayerProfile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: (lbName != null && lbName.isNotEmpty) ? lbName : 'لاعب',
          avatarIndex: 0,
          linkedUserId: _userId,
          totalScore: lbScore,
          highScore: lbScore,
          trophies: lbTrophies,
          coins: 100 +
              PlayerLevelInfo.totalCoinsGrantedBetweenLevels(
                1,
                computedLevel.level,
              ),
          equippedFrame: lbFrame ?? computedLevel.frameKey,
          unlockedItemIds: unlockedItemIds,
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
            categoryProgress = decoded.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            );
          }
        }

        if (data['level_stars'] != null) {
          final decoded = data['level_stars'] is String
              ? jsonDecode(data['level_stars'])
              : data['level_stars'];
          if (decoded is Map) {
            levelStars = decoded.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            );
          }
        }

        if (data['level_scores'] != null) {
          final decoded = data['level_scores'] is String
              ? jsonDecode(data['level_scores'])
              : data['level_scores'];
          if (decoded is Map) {
            levelScores = decoded.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            );
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
                AchievementProgress.fromJson(
                  Map<String, dynamic>.from(v as Map),
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('CloudSync: Error parsing JSON data: $e');
      }

      final upScore = (data!['total_score'] as num?)?.toInt() ?? 0;
      final upHighScore = (data['high_score'] as num?)?.toInt() ?? 0;
      final bestTotalScore = math.max(upScore, lbScore);
      final bestHighScore = math.max(upHighScore, bestTotalScore);
      final computedLevel = PlayerLevelInfo.fromTotalScore(bestTotalScore);

      final cloudCoins = (data['coins'] as num?)?.toInt() ?? 100;
      final cloudGems = (data['gems'] as num?)?.toInt() ?? 10;
      final cloudWinStreak = (data['win_streak'] as num?)?.toInt() ?? 0;
      final equippedTheme =
          data['equipped_theme']?.toString() ?? 'andalusian_gold';
      final equippedFrame = data['equipped_frame']?.toString() ??
          lbFrame ??
          computedLevel.frameKey;
      final rawTitle = data['player_title']?.toString() ??
          lbData?['player_title']?.toString();
      const honorTitles = ['صقر الأندلس', 'درع القادسية', 'علامة الزمان'];
      final equippedTitle =
          (rawTitle != null && honorTitles.contains(rawTitle)) ? rawTitle : null;

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
        coins: cloudCoins,
        gems: cloudGems,
        trophies: lbTrophies,
        winStreak: cloudWinStreak,
        equippedTheme: equippedTheme,
        equippedFrame: equippedFrame,
        equippedTitle: equippedTitle,
        unlockedItemIds: unlockedItemIds,
      );

      debugPrint(
        'CloudSync: Fetched profile - score: ${profile.totalScore}, level: ${profile.levelInfo.level}, arena: ${profile.arenaInfo.name}, coins: ${profile.coins}',
      );
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
