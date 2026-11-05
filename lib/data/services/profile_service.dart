import 'package:flutter/material.dart';

import '../models/player_profile_model.dart';
import '../local/shared_prefs_service.dart';
import 'cloud_sync_service.dart';

/// Service for managing player profiles with cloud sync support.
/// Ensures data persists across sign-in/sign-out cycles and app updates.
class ProfileService extends ChangeNotifier {
  static ProfileService? _instance;
  static ProfileService get instance {
    _instance ??= ProfileService._();
    return _instance!;
  }
  ProfileService._();

  final CloudSyncService _cloudSync = CloudSyncService();
  
  List<PlayerProfile> _profiles = [];
  String? _activeProfileId;
  bool _isSyncing = false;
  
  /// Get all profiles
  List<PlayerProfile> get profiles => _profiles;
  
  /// Get active profile
  PlayerProfile? get activeProfile {
    if (_activeProfileId == null) {
      return _profiles.isNotEmpty ? _profiles.first : null;
    }
    try {
      return _profiles.firstWhere((p) => p.id == _activeProfileId);
    } catch (e) {
      return _profiles.isNotEmpty ? _profiles.first : null;
    }
  }
  
  /// Check if any profiles exist
  bool get hasProfiles => _profiles.isNotEmpty;
  
  /// Check if currently syncing
  bool get isSyncing => _isSyncing;
  
  /// Initialize the service - load profiles from storage
  Future<void> init() async {
    // 🛡️ Guard: Ensure SharedPrefs is ready even if main.dart failed specific init
    await SharedPrefsService.init();
    
    await _loadProfiles();
    _activeProfileId = SharedPrefsService.getActiveProfileId();
    
    // If no active profile set but profiles exist, use first one
    if ((_activeProfileId == null || _activeProfileId!.isEmpty) && _profiles.isNotEmpty) {
      _activeProfileId = _profiles.first.id;
      await SharedPrefsService.setActiveProfileId(_activeProfileId!);
    }

    // Rescue any legacy SharedPreferences progress into activeProfile if higher
    final current = activeProfile;
    if (current != null) {
      final didRescue = _mergeLegacySharedPrefsInto(current);
      if (didRescue) {
        await _saveProfiles();
      }
    }
    
    debugPrint('ProfileService initialized: ${_profiles.length} profiles, active: $_activeProfileId');
  }
  
  /// Load profiles from SharedPreferences
  Future<void> _loadProfiles() async {
    final jsonString = SharedPrefsService.getProfilesJson();
    if (jsonString != null && jsonString.isNotEmpty && jsonString != '[]') {
      try {
        _profiles = PlayerProfile.profilesFromJson(jsonString);
      } catch (e) {
        debugPrint('Error loading profiles: $e');
        _profiles = [];
      }
    }
    if (_profiles.isEmpty) {
      // Check if we need to migrate existing progress to a new profile
      await _migrateExistingProgress();
    }
  }

  /// Merge any legacy SharedPreferences keys into [profile] if legacy values are higher.
  /// Returns true if any field was upgraded.
  bool _mergeLegacySharedPrefsInto(PlayerProfile profile) {
    bool changed = false;
    final existingScore = SharedPrefsService.getTotalScore();
    final existingHighScore = SharedPrefsService.getHighScore();

    if (existingScore > profile.totalScore) {
      profile.totalScore = existingScore;
      changed = true;
    }
    if (existingHighScore > profile.highScore) {
      profile.highScore = existingHighScore;
      changed = true;
    }

    const categories = ['quran', 'hadith', 'fiqh', 'seerah', 'history', 'aqeedah'];
    for (final cat in categories) {
      final unlocked = SharedPrefsService.getCategoryProgress(cat);
      final currentUnlocked = profile.categoryProgress[cat] ?? 1;
      if (unlocked > currentUnlocked) {
        profile.categoryProgress[cat] = unlocked;
        changed = true;
      }

      for (int level = 1; level <= 10; level++) {
        final stars = SharedPrefsService.getLevelStars(cat, level);
        final score = SharedPrefsService.getLevelScore(cat, level);
        final key = '${cat}_$level';
        if (stars > (profile.levelStars[key] ?? 0)) {
          profile.levelStars[key] = stars;
          changed = true;
        }
        if (score > (profile.levelScores[key] ?? 0)) {
          profile.levelScores[key] = score;
          changed = true;
        }
      }
    }
    return changed;
  }
  
  /// Migrate existing game progress to first profile (for app update)
  Future<void> _migrateExistingProgress() async {
    final existingScore = SharedPrefsService.getTotalScore();
    final existingHighScore = SharedPrefsService.getHighScore();
    
    if (existingScore > 0 || existingHighScore > 0) {
      debugPrint('Migrating existing progress to new profile...');
      
      final profile = PlayerProfile.create(
        name: 'لاعب 1',
        avatarIndex: 0,
      );
      _mergeLegacySharedPrefsInto(profile);
      
      _profiles = [profile];
      _activeProfileId = profile.id;
      await _saveProfiles();
      await SharedPrefsService.setActiveProfileId(profile.id);
      
      debugPrint('Migration complete. Profile created: ${profile.name}');
    }
  }
  
  /// Save all profiles to local storage
  Future<void> _saveProfiles() async {
    final jsonString = PlayerProfile.profilesToJson(_profiles);
    await SharedPrefsService.saveProfilesJson(jsonString);
  }
  
  /// Create a new profile
  Future<PlayerProfile> createProfile({
    required String name,
    int avatarIndex = 0,
    String? linkedUserId,
  }) async {
    final profile = PlayerProfile.create(
      name: name,
      avatarIndex: avatarIndex,
      linkedUserId: linkedUserId,
    );
    _mergeLegacySharedPrefsInto(profile);
    _profiles.add(profile);
    await _saveProfiles();
    notifyListeners();
    return profile;
  }
  
  /// Create or load profile for authenticated user.
  /// Preserves and merges any existing local profile (even if previously unlinked)
  /// with cloud progress so players NEVER lose their points or unlocked levels.
  Future<PlayerProfile> createOrLoadProfileForUser({
    required String userId,
    required String displayName,
    int avatarIndex = 0,
  }) async {
    _isSyncing = true;
    notifyListeners();
    
    try {
      // Find local candidate profile: either already linked to this userId,
      // or an unlinked local profile the player was playing on before signing in.
      int localIndex = _profiles.indexWhere((p) => p.linkedUserId == userId);
      if (localIndex < 0) {
        // Check activeProfile if unlinked
        final currentActive = activeProfile;
        if (currentActive != null && (currentActive.linkedUserId == null || currentActive.linkedUserId!.isEmpty)) {
          localIndex = _profiles.indexWhere((p) => p.id == currentActive.id);
        }
      }
      if (localIndex < 0) {
        // Check any unlinked profile
        localIndex = _profiles.indexWhere((p) => p.linkedUserId == null || p.linkedUserId!.isEmpty);
      }

      // First, try to fetch profile from cloud
      final cloudProfile = await _cloudSync.fetchProfileFromCloud();
      
      if (cloudProfile != null) {
        cloudProfile.linkedUserId = userId;
        if (cloudProfile.name.isEmpty || cloudProfile.name == 'لاعب') {
          cloudProfile.name = displayName;
        }
        
        // Merge legacy SharedPrefs if any
        _mergeLegacySharedPrefsInto(cloudProfile);

        if (localIndex >= 0) {
          final localProfile = _profiles[localIndex];
          // Preserve local ID and custom name if user customized it
          final scoreBeforeMerge = cloudProfile.totalScore;
          final starsBeforeMerge = cloudProfile.levelStars.length;
          _mergeProfiles(localProfile, cloudProfile);
          _profiles[localIndex] = cloudProfile;

          // If local profile had higher score or more progress than cloud, sync back to cloud!
          if (cloudProfile.totalScore > scoreBeforeMerge || cloudProfile.levelStars.length > starsBeforeMerge) {
            await _cloudSync.syncProfileToCloud(cloudProfile);
          }
        } else {
          _profiles.add(cloudProfile);
        }
        
        _activeProfileId = cloudProfile.id;
        await _saveProfiles();
        await SharedPrefsService.setActiveProfileId(cloudProfile.id);
        
        debugPrint('Loaded & merged profile from cloud: ${cloudProfile.name}, score: ${cloudProfile.totalScore}');
        
        _isSyncing = false;
        notifyListeners();
        return cloudProfile;
      }
      
      // No cloud data - check if we have a local profile (linked or unlinked)
      if (localIndex >= 0) {
        final existingLocal = _profiles[localIndex];
        existingLocal.linkedUserId = userId;
        if (existingLocal.name.isEmpty || existingLocal.name == 'لاعب' || existingLocal.name == 'لاعب 1') {
          existingLocal.name = displayName;
        }
        _mergeLegacySharedPrefsInto(existingLocal);

        _activeProfileId = existingLocal.id;
        await _saveProfiles();
        await SharedPrefsService.setActiveProfileId(existingLocal.id);
        
        // Sync local progress to cloud
        await _cloudSync.syncProfileToCloud(existingLocal);
        
        _isSyncing = false;
        notifyListeners();
        return existingLocal;
      }
      
      // No cloud or local data - create new profile
      final newProfile = PlayerProfile.create(
        name: displayName,
        avatarIndex: avatarIndex,
        linkedUserId: userId,
      );
      _mergeLegacySharedPrefsInto(newProfile);
      
      _profiles.add(newProfile);
      _activeProfileId = newProfile.id;
      await _saveProfiles();
      await SharedPrefsService.setActiveProfileId(newProfile.id);
      
      // Sync new profile to cloud
      await _cloudSync.syncProfileToCloud(newProfile);
      
      debugPrint('Created new profile for user: $userId, name: $displayName');
      
      _isSyncing = false;
      notifyListeners();
      return newProfile;
    } catch (e) {
      debugPrint('Error in createOrLoadProfileForUser: $e');
      _isSyncing = false;
      notifyListeners();
      
      // Fallback: if a local profile already exists, keep using it instead of overwriting with 0!
      if (activeProfile != null) {
        activeProfile!.linkedUserId = userId;
        await _saveProfiles();
        return activeProfile!;
      }

      final fallbackProfile = PlayerProfile.create(
        name: displayName,
        avatarIndex: avatarIndex,
        linkedUserId: userId,
      );
      _mergeLegacySharedPrefsInto(fallbackProfile);
      _profiles.add(fallbackProfile);
      _activeProfileId = fallbackProfile.id;
      await _saveProfiles();
      await SharedPrefsService.setActiveProfileId(fallbackProfile.id);
      return fallbackProfile;
    }
  }
  
  /// Merge two profiles, taking the best values from each
  void _mergeProfiles(PlayerProfile local, PlayerProfile cloud) {
    // Take higher scores
    if (local.totalScore > cloud.totalScore) {
      cloud.totalScore = local.totalScore;
    }
    if (local.highScore > cloud.highScore) {
      cloud.highScore = local.highScore;
    }
    if (local.currentStreak > cloud.currentStreak) {
      cloud.currentStreak = local.currentStreak;
    }
    if (local.totalDaysPlayed > cloud.totalDaysPlayed) {
      cloud.totalDaysPlayed = local.totalDaysPlayed;
    }

    // Preserve user-chosen local name if cloud has a generic fallback name
    if (local.name.isNotEmpty &&
        local.name != 'لاعب' &&
        local.name != 'لاعب 1' &&
        (cloud.name.isEmpty || cloud.name == 'لاعب' || cloud.name == 'لاعب 1')) {
      cloud.name = local.name;
    }
    
    // Merge category progress (take higher values)
    for (final entry in local.categoryProgress.entries) {
      final cloudValue = cloud.categoryProgress[entry.key] ?? 0;
      if (entry.value > cloudValue) {
        cloud.categoryProgress[entry.key] = entry.value;
      }
    }
    
    // Merge level stars (take higher values)
    for (final entry in local.levelStars.entries) {
      final cloudValue = cloud.levelStars[entry.key] ?? 0;
      if (entry.value > cloudValue) {
        cloud.levelStars[entry.key] = entry.value;
      }
    }
    
    // Merge level scores (take higher values)
    for (final entry in local.levelScores.entries) {
      final cloudValue = cloud.levelScores[entry.key] ?? 0;
      if (entry.value > cloudValue) {
        cloud.levelScores[entry.key] = entry.value;
      }
    }

    // Merge achievement progress
    for (final entry in local.achievementProgress.entries) {
      final cloudAch = cloud.achievementProgress[entry.key];
      if (cloudAch == null ||
          entry.value.currentValue > cloudAch.currentValue ||
          (entry.value.isUnlocked && !cloudAch.isUnlocked)) {
        cloud.achievementProgress[entry.key] = entry.value;
      }
    }
  }
  
  /// Sync current profile to cloud - call after game completion
  Future<bool> syncToCloud() async {
    final profile = activeProfile;
    if (profile == null) return false;
    
    final result = await _cloudSync.syncProfileToCloud(profile);
    await _saveProfiles();
    notifyListeners();
    return result;
  }
  
  /// Sync and clear local profile data (called on sign out)
  /// IMPORTANT: Syncs to cloud BEFORE clearing local data
  Future<void> syncAndClearProfile() async {
    _isSyncing = true;
    notifyListeners();
    
    try {
      // CRITICAL: Sync current profile to cloud BEFORE clearing
      final profile = activeProfile;
      if (profile != null) {
        debugPrint('Syncing profile to cloud before sign-out...');
        await _cloudSync.syncProfileToCloud(profile);
        debugPrint('Profile synced successfully before sign-out');
      }
    } catch (e) {
      debugPrint('Error syncing before sign-out: $e');
    }
    
    // Now clear local data
    _profiles.clear();
    _activeProfileId = null;
    await SharedPrefsService.saveProfilesJson('');
    await SharedPrefsService.setProfileSetupComplete(false);
    
    _isSyncing = false;
    notifyListeners();
    debugPrint('Local profile data cleared after sync');
  }
  
  /// Update a profile and sync to cloud
  Future<void> updateProfile(PlayerProfile profile) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
      await _saveProfiles();
      notifyListeners();
      
      // Sync to cloud in background
      _cloudSync.syncProfileToCloud(profile);
    }
  }
  
  /// Save and sync active profile - call after game completion
  Future<void> saveActiveProfileAndSync() async {
    await _saveProfiles();
    notifyListeners();
    
    // Sync to cloud
    final profile = activeProfile;
    if (profile != null) {
      await _cloudSync.syncProfileToCloud(profile);
      await _saveProfiles();
      notifyListeners();
    }
  }
  
  /// Delete a profile
  Future<bool> deleteProfile(String profileId) async {
    if (_profiles.length <= 1) {
      return false;
    }
    
    _profiles.removeWhere((p) => p.id == profileId);
    
    if (_activeProfileId == profileId) {
      _activeProfileId = _profiles.first.id;
      await SharedPrefsService.setActiveProfileId(_activeProfileId!);
    }
    
    await _saveProfiles();
    notifyListeners();
    return true;
  }
  
  /// Set active profile
  Future<void> setActiveProfile(String profileId) async {
    if (_profiles.any((p) => p.id == profileId)) {
      _activeProfileId = profileId;
      await SharedPrefsService.setActiveProfileId(profileId);
      notifyListeners();
    }
  }
  
  /// Save current profile's progress (local only)
  Future<void> saveActiveProfile() async {
    await _saveProfiles();
    notifyListeners();
  }
  
  /// Get profile by ID
  PlayerProfile? getProfileById(String id) {
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get profile linked to a specific user ID
  PlayerProfile? getProfileByUserId(String userId) {
    try {
      return _profiles.firstWhere((p) => p.linkedUserId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Clear all profiles locally (e.g. on account deletion or full reset)
  Future<void> clearAllProfiles() async {
    _profiles.clear();
    _activeProfileId = null;
    await SharedPrefsService.saveProfilesJson('[]');
    await SharedPrefsService.setActiveProfileId('');
    await SharedPrefsService.setProfileSetupComplete(false);
    notifyListeners();
  }
}
