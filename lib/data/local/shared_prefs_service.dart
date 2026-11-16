import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_profile_model.dart';
import '../models/question_model.dart';

class SharedPrefsService {
  static SharedPreferences? _prefs;

  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyHasSeenTutorial = 'has_seen_tutorial';

  static Future<void> init({bool forceReload = false}) async {
    if (_prefs != null && !forceReload) return;
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<SharedPreferences> get _instance async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // Settings
  static bool getSoundEnabled() => _prefs?.getBool(_keySoundEnabled) ?? true;
  static Future<void> setSoundEnabled(bool value) async => await _prefs?.setBool(_keySoundEnabled, value);
  // Alias for legacy support
  static Future<void> saveSoundEnabled(bool value) => setSoundEnabled(value);

  static bool getVibrationEnabled() => _prefs?.getBool(_keyVibrationEnabled) ?? true;
  static Future<void> setVibrationEnabled(bool value) async => await _prefs?.setBool(_keyVibrationEnabled, value);
  // Alias for legacy support
  static Future<void> saveVibrationEnabled(bool value) => setVibrationEnabled(value);

  static Future<bool> getHasSeenTutorial() async {
     return _prefs?.getBool(_keyHasSeenTutorial) ?? false;
  }
  
  static Future<void> setHasSeenTutorial(bool value) async => await _prefs?.setBool(_keyHasSeenTutorial, value);

  static Future<void> saveQuestionTime(int seconds) async {
    await _prefs?.setInt('question_time', seconds);
  }

  static int getQuestionTime() {
    return _prefs?.getInt('question_time') ?? 20;
  }

  // Progress
  static Future<void> saveTotalScore(int score) async {
    await _prefs?.setInt('total_score', score);
  }

  static int getTotalScore() {
    return _prefs?.getInt('total_score') ?? 0;
  }

  static Future<void> saveHighScore(int score) async {
    final currentHigh = getHighScore();
    if (score > currentHigh) {
      await _prefs?.setInt('high_score', score);
    }
  }

  static int getHighScore() {
    return _prefs?.getInt('high_score') ?? 0;
  }

  // Category Progress
  static Future<void> saveCategoryProgress(
    String categoryId,
    int unlockedLevels,
  ) async {
    await _prefs?.setInt('category_${categoryId}_unlocked', unlockedLevels);
  }

  static int getCategoryProgress(String categoryId) {
    return _prefs?.getInt('category_${categoryId}_unlocked') ?? 1;
  }

  // Level Progress
  static Future<void> saveLevelProgress(
    String categoryId,
    int levelNumber,
    int stars,
    int score,
  ) async {
    // Only update stars if new value is higher
    final currentStars = getLevelStars(categoryId, levelNumber);
    if (stars > currentStars) {
      await _prefs?.setInt('level_${categoryId}_${levelNumber}_stars', stars);
    }
    
    // Always save latest score (or high score? usually high score implies best)
    // The GameController handles high_score (global). This is level score.
    // Let's save max level score too.
    final currentLevelScore = getLevelScore(categoryId, levelNumber);
    if (score > currentLevelScore) {
      await _prefs?.setInt('level_${categoryId}_${levelNumber}_score', score);
    }

    if (stars > 0) {
      await _prefs?.setBool('level_${categoryId}_${levelNumber}_completed', true);
    }
  }

  static int getLevelStars(String categoryId, int levelNumber) {
    return _prefs?.getInt('level_${categoryId}_${levelNumber}_stars') ?? 0;
  }

  static int getLevelScore(String categoryId, int levelNumber) {
    return _prefs?.getInt('level_${categoryId}_${levelNumber}_score') ?? 0;
  }

  static bool isLevelCompleted(String categoryId, int levelNumber) {
    return _prefs?.getBool('level_${categoryId}_${levelNumber}_completed') ??
        false;
  }

  static bool isLevelUnlocked(String categoryId, int levelNumber) {
    if (levelNumber == 1) return true;
    return isLevelCompleted(categoryId, levelNumber - 1);
  }

  // Questions (for custom questions)
  static Future<void> saveQuestions(List<Question> questions) async {
    final jsonList = questions.map((q) => q.toJson()).toList();
    await _prefs?.setString('custom_questions', jsonEncode(jsonList));
  }

  static List<Question> loadQuestions() {
    final jsonString = _prefs?.getString('custom_questions');
    if (jsonString == null) return [];
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => Question.fromJson(json)).toList();
  }

  // Reset
  static Future<void> resetAllProgress() async {
    await _prefs?.clear();
  }

  static Future<void> resetCategoryProgress(String categoryId) async {
    final keys =
        _prefs?.getKeys().where((key) => key.contains(categoryId)) ?? [];
    for (final key in keys) {
      await _prefs?.remove(key);
    }
  }

  // Onboarding
  static Future<void> saveOnboardingSeen() async {
    await _prefs?.setBool('onboarding_seen', true);
  }

  static bool isOnboardingSeen() {
    return _prefs?.getBool('onboarding_seen') ?? false;
  }
  
  // ============ PROFILE MANAGEMENT ============
  
  /// Save all profiles as JSON string
  static Future<void> saveProfilesJson(String json) async {
    final prefs = await _instance;
    await prefs.setString('player_profiles', json);
  }
  
  /// Get profiles JSON string
  static String? getProfilesJson() {
    return _prefs?.getString('player_profiles');
  }
  
  /// Set active profile ID
  static Future<void> setActiveProfileId(String profileId) async {
    final prefs = await _instance;
    await prefs.setString('active_profile_id', profileId);
  }
  
  /// Get active profile ID
  static String? getActiveProfileId() {
    return _prefs?.getString('active_profile_id');
  }
  
  /// Check if profile setup is complete
  static bool isProfileSetupComplete() {
    return _prefs?.getBool('profile_setup_complete') ?? false;
  }
  
  /// Mark profile setup as complete
  static Future<void> setProfileSetupComplete(bool complete) async {
    final prefs = await _instance;
    await prefs.setBool('profile_setup_complete', complete);
  }

  // ============ NOTIFICATIONS ============

  static const String _keyDailyNotificationsScheduled =
      'daily_notifications_scheduled_v3';

  static bool areDailyNotificationsScheduled() {
    return _prefs?.getBool(_keyDailyNotificationsScheduled) ?? false;
  }

  static Future<void> setDailyNotificationsScheduled(bool scheduled) async {
    final prefs = await _instance;
    await prefs.setBool(_keyDailyNotificationsScheduled, scheduled);
  }

  // ============ APP CONTROL & PLAYER CODE CACHE ============

  static const String _keyDevicePlayerCode = 'device_player_code';
  static const String _keyCachedConfigVersion = 'cached_config_version';
  static const String _keyCachedAppControlJson = 'cached_app_control_json';
  static const String _keyLastAppControlSyncMs = 'last_app_control_sync_ms';
  static const String _keySeenAnnouncementIds = 'seen_announcement_ids';
  static const String _keyOptionalUpdateLastPromptMs =
      'optional_update_last_prompt_ms';
  static const String _keyLastDirectorySyncMs = 'last_directory_sync_ms';
  static const String _keyCachedCmsVersion = 'cached_cms_version';
  static const String _keyCachedCmsBundleJson = 'cached_cms_bundle_json';

  static String? getDevicePlayerCode() {
    final code = _prefs?.getString(_keyDevicePlayerCode);
    return PlayerProfile.isValidPlayerCode(code) ? code!.trim().toUpperCase() : null;
  }

  static Future<void> setDevicePlayerCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!PlayerProfile.isValidPlayerCode(normalized)) return;
    final prefs = await _instance;
    await prefs.setString(_keyDevicePlayerCode, normalized);
  }

  static Future<String> getOrCreateDevicePlayerCode() async {
    final existing = getDevicePlayerCode();
    if (existing != null) return existing;
    final created = PlayerProfile.generatePlayerCode();
    await setDevicePlayerCode(created);
    return created;
  }

  static int getCachedConfigVersion() {
    return _prefs?.getInt(_keyCachedConfigVersion) ?? 0;
  }

  static Future<void> setCachedConfigVersion(int version) async {
    final prefs = await _instance;
    await prefs.setInt(_keyCachedConfigVersion, version);
  }

  static String? getCachedAppControlJson() {
    return _prefs?.getString(_keyCachedAppControlJson);
  }

  static Future<void> setCachedAppControlJson(String json) async {
    final prefs = await _instance;
    await prefs.setString(_keyCachedAppControlJson, json);
  }

  static int getLastAppControlSyncMs() {
    return _prefs?.getInt(_keyLastAppControlSyncMs) ?? 0;
  }

  static Future<void> setLastAppControlSyncMs(int ms) async {
    final prefs = await _instance;
    await prefs.setInt(_keyLastAppControlSyncMs, ms);
  }

  static Set<String> getSeenAnnouncementIds() {
    return (_prefs?.getStringList(_keySeenAnnouncementIds) ?? const <String>[])
        .toSet();
  }

  static Future<void> markAnnouncementSeen(String announcementId) async {
    final clean = announcementId.trim();
    if (clean.isEmpty) return;
    final prefs = await _instance;
    final current = getSeenAnnouncementIds()..add(clean);
    // Bound stored IDs cleanly to prevent unbounded SharedPreferences growth.
    final list = current.toList();
    final bounded = list.length > 100 ? list.sublist(list.length - 100) : list;
    await prefs.setStringList(_keySeenAnnouncementIds, bounded);
  }

  static int getOptionalUpdateLastPromptMs() {
    return _prefs?.getInt(_keyOptionalUpdateLastPromptMs) ?? 0;
  }

  static Future<void> setOptionalUpdateLastPromptMs(int ms) async {
    final prefs = await _instance;
    await prefs.setInt(_keyOptionalUpdateLastPromptMs, ms);
  }

  static int getLastDirectorySyncMs() {
    return _prefs?.getInt(_keyLastDirectorySyncMs) ?? 0;
  }

  static Future<void> setLastDirectorySyncMs(int ms) async {
    final prefs = await _instance;
    await prefs.setInt(_keyLastDirectorySyncMs, ms);
  }

  static int getCachedCmsVersion() {
    return _prefs?.getInt(_keyCachedCmsVersion) ?? 0;
  }

  static Future<void> setCachedCmsVersion(int version) async {
    final prefs = await _instance;
    await prefs.setInt(_keyCachedCmsVersion, version);
  }

  static String? getCachedCmsBundleJson() {
    return _prefs?.getString(_keyCachedCmsBundleJson);
  }

  static Future<void> setCachedCmsBundleJson(String json) async {
    final prefs = await _instance;
    await prefs.setString(_keyCachedCmsBundleJson, json);
  }
}