import 'package:flutter/material.dart';

import '../models/player_profile_model.dart';
import '../local/shared_prefs_service.dart';
import 'cloud_sync_service.dart';

/// Service for managing player profiles with cloud sync support.
/// Ensures data persists across sign-in/sign-out cycles.
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
    if (_activeProfileId == null) return null;
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
    if (_activeProfileId == null && _profiles.isNotEmpty) {
      _activeProfileId = _profiles.first.id;
      await SharedPrefsService.setActiveProfileId(_activeProfileId!);
    }
    
    debugPrint('ProfileService initialized: ${_profiles.length} profiles, active: $_activeProfileId');
  }
  
  /// Load profiles from SharedPreferences
  Future<void> _loadProfiles() async {
    final jsonString = SharedPrefsService.getProfilesJson();
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        _profiles = PlayerProfile.profilesFromJson(jsonString);
      } catch (e) {
        debugPrint('Error loading profiles: $e');
        _profiles = [];
      }
    } else {
      // Check if we need to migrate existing progress to a new profile
      await _migrateExistingProgress();
    }
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
      profile.totalScore = existingScore;
      profile.highScore = existingHighScore;
      
      // Migrate category progress
      final categories = ['quran', 'hadith', 'fiqh', 'seerah', 'history', 'aqeedah'];
      for (final cat in categories) {
        final unlocked = SharedPrefsService.getCategoryProgress(cat);
        if (unlocked > 1) {
          profile.categoryProgress[cat] = unlocked;
        }
        
        for (int level = 1; level <= 10; level++) {
          final stars = SharedPrefsService.getLevelStars(cat, level);
          final score = SharedPrefsService.getLevelScore(cat, level);
          if (stars > 0) {
            profile.levelStars['${cat}_$level'] = stars;
          }
          if (score > 0) {
            profile.levelScores['${cat}_$level'] = score;
          }
        }
      }
      
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
    _profiles.add(profile);
    await _saveProfiles();
    notifyListeners();
    return profile;
  }
  
  /// Create or load profile for authenticated user
  /// This fetches full progress from cloud if available
  Future<PlayerProfile> createOrLoadProfileForUser({
    required String userId,
    required String displayName,
    int avatarIndex = 0,
  }) async {
    _isSyncing = true;
    notifyListeners();
    
    try {
      // First, try to fetch profile from cloud
      final cloudProfile = await _cloudSync.fetchProfileFromCloud();
      
      if (cloudProfile != null) {
        // Cloud data exists - use it
        cloudProfile.linkedUserId = userId;
        
        // Check if we have a local profile for this user
        final localIndex = _profiles.indexWhere((p) => p.linkedUserId == userId);
        if (localIndex >= 0) {
          // Merge: take higher scores and more progress
          _mergeProfiles(_profiles[localIndex], cloudProfile);
          _profiles[localIndex] = cloudProfile;
        } else {
          _profiles.add(cloudProfile);
        }
        
        _activeProfileId = cloudProfile.id;
        await _saveProfiles();
        await SharedPrefsService.setActiveProfileId(cloudProfile.id);
        
        debugPrint('Loaded profile from cloud: ${cloudProfile.name}, score: ${cloudProfile.totalScore}');
        
        _isSyncing = false;
        notifyListeners();
        return cloudProfile;
      }
      
      // No cloud data - check for existing local profile
      final existingLocal = _profiles.firstWhere(
        (p) => p.linkedUserId == userId,
        orElse: () => PlayerProfile(id: '', name: ''),
      );
      
      if (existingLocal.id.isNotEmpty) {
        _activeProfileId = existingLocal.id;
        await SharedPrefsService.setActiveProfileId(existingLocal.id);
        
        // Sync local to cloud
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
      
      // Fallback: create local profile
      final fallbackProfile = PlayerProfile.create(
        name: displayName,
        avatarIndex: avatarIndex,
        linkedUserId: userId,
      );
      _profiles.add(fallbackProfile);
      _activeProfileId = fallbackProfile.id;
      await _saveProfiles();
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
  }
  
  /// Sync current profile to cloud - call after game completion
  Future<bool> syncToCloud() async {
    final profile = activeProfile;
    if (profile == null) return false;
    
    return await _cloudSync.syncProfileToCloud(profile);
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

