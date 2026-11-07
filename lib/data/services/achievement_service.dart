import 'package:flutter/material.dart';
import '../models/achievement_model.dart';
import '../models/player_profile_model.dart';
import '../../core/sound_service.dart';
import 'profile_service.dart';

/// خدمة إدارة الإنجازات
class AchievementService extends ChangeNotifier {
  static AchievementService? _instance;
  static AchievementService get instance {
    _instance ??= AchievementService._();
    return _instance!;
  }
  AchievementService._();

  /// الإنجازات الجديدة التي تنتظر العرض
  final List<Achievement> _pendingUnlocks = [];
  List<Achievement> get pendingUnlocks => List.unmodifiable(_pendingUnlocks);

  /// الحصول على الإنجاز التالي للعرض
  Achievement? popNextPendingUnlock() {
    if (_pendingUnlocks.isEmpty) return null;
    final achievement = _pendingUnlocks.removeAt(0);
    notifyListeners();
    return achievement;
  }

  /// عدد الإنجازات الجديدة غير المشاهدة
  int get newAchievementsCount {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return 0;
    return profile.achievementProgress.values
        .where((p) => p.isUnlocked && !p.hasBeenSeen)
        .length;
  }

  /// الحصول على تقدم كل الإنجازات مع تسوية ومزامنة فورية للقيم
  List<AchievementWithProgress> getAllAchievementsWithProgress() {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return [];

    // مزامنة فورية في الذاكرة حتى تظهر أرقام التقدم بدقة 100%
    _syncInMemoryValues(profile);

    return AchievementDefinitions.all.map((achievement) {
      final progress = profile.getAchievementProgress(achievement.id);
      return AchievementWithProgress(
        achievement: achievement,
        progress: progress,
      );
    }).toList();
  }

  /// تسوية ومزامنة شاملة لجميع الإنجازات مع بيانات الملف الشخصي وحفظها
  Future<List<Achievement>> reconcileAchievements() async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return [];

    final newlyUnlocked = _syncInMemoryValues(profile);
    _pendingUnlocks.addAll(newlyUnlocked);

    if (newlyUnlocked.isNotEmpty) {
      await ProfileService.instance.saveActiveProfileAndSync();
      SoundService().playRankUp();
      notifyListeners();
    }

    return newlyUnlocked;
  }

  /// مزامنة القيم الحسابية للإنجازات في الذاكرة (النقاط، المستويات، النجوم، الفئات، المثابرة)
  List<Achievement> _syncInMemoryValues(PlayerProfile profile) {
    final newlyUnlocked = <Achievement>[];

    // 1. حساب المستويات المكتملة وإجمالي النجوم
    final completedLevels = _countCompletedLevels(profile);
    final totalStars = _countTotalStars(profile);

    // إنجازات التعلم
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'first_level', completedLevels));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'student', completedLevels));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'scholar', completedLevels));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'sheikh', completedLevels));

    // إنجازات الإتقان والنجوم
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'first_star', totalStars));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'star_collector', totalStars));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'shining', totalStars));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'constellation', totalStars));

    // 2. إنجازات الفئات الست
    final categoryAchievementMap = {
      'quran': 'quran_master',
      'hadith': 'hadith_master',
      'fiqh': 'fiqh_master',
      'seerah': 'seerah_master',
      'history': 'history_master',
      'aqeedah': 'aqeedah_master',
    };
    for (final entry in categoryAchievementMap.entries) {
      final catLevels = _countCategoryCompletedLevels(profile, entry.key);
      newlyUnlocked.addAll(_checkAndUnlock(profile, entry.value, catLevels));
    }

    // 3. إنجازات النقاط (تشمل نقاط المسابقات الجماعية والفردية)
    final totalScore = profile.totalScore;
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'beginner_points', totalScore));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'rich_points', totalScore));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'king_points', totalScore));

    // 4. إنجازات الكمال والدقة من المستويات المحققة لثلاث نجوم
    final perfectLevels = _countPerfectLevels(profile);
    final currentNoMistakes = _getProgress(profile, 'no_mistakes');
    if (perfectLevels > currentNoMistakes) {
      profile.getAchievementProgress('no_mistakes').currentValue = perfectLevels;
      profile.getAchievementProgress('sniper').currentValue = perfectLevels;
      profile.getAchievementProgress('perfectionist').currentValue = perfectLevels;
    }
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'no_mistakes', _getProgress(profile, 'no_mistakes')));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'sniper', _getProgress(profile, 'sniper')));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'perfectionist', _getProgress(profile, 'perfectionist')));

    // 5. إنجازات المثابرة
    if (profile.totalDaysPlayed == 0 && (profile.totalScore > 0 || completedLevels > 0)) {
      profile.totalDaysPlayed = 1;
      profile.currentStreak = 1;
    }
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'one_day', profile.totalDaysPlayed));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'week_streak', profile.currentStreak));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'month_dedication', profile.totalDaysPlayed));

    return newlyUnlocked;
  }

  /// الحصول على إنجازات بفئة معينة
  List<AchievementWithProgress> getByCategory(AchievementCategory category) {
    return getAllAchievementsWithProgress()
        .where((a) => a.achievement.category == category)
        .toList();
  }

  /// نسبة الإنجاز الكلية
  double get overallProgress {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return 0;
    
    final total = AchievementDefinitions.all.length;
    final unlocked = profile.achievementProgress.values
        .where((p) => p.isUnlocked)
        .length;
    
    return total > 0 ? unlocked / total : 0;
  }

  /// عدد الإنجازات المفتوحة
  int get unlockedCount {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return 0;
    return profile.achievementProgress.values
        .where((p) => p.isUnlocked)
        .length;
  }

  /// التحقق من الإنجازات بعد حدث معين
  Future<List<Achievement>> checkAchievements(AchievementEvent event) async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return [];

    final newlyUnlocked = <Achievement>[];

    switch (event.type) {
      case AchievementEventType.levelCompleted:
        newlyUnlocked.addAll(await _checkLevelCompletedAchievements(profile, event.data));
        break;
      case AchievementEventType.appOpened:
        newlyUnlocked.addAll(await _checkDailyStreak(profile));
        break;
      case AchievementEventType.fastAnswer:
        newlyUnlocked.addAll(await _checkSpeedAchievements(profile, event.data));
        break;
    }

    // إضافة للقائمة المنتظرة للعرض
    _pendingUnlocks.addAll(newlyUnlocked);
    
    // حفظ التغييرات
    if (newlyUnlocked.isNotEmpty) {
      await ProfileService.instance.saveActiveProfileAndSync();
      SoundService().playRankUp();
      notifyListeners();
    }

    return newlyUnlocked;
  }

  /// التحقق من إنجازات إكمال المستوى
  Future<List<Achievement>> _checkLevelCompletedAchievements(
    PlayerProfile profile,
    Map<String, dynamic> data,
  ) async {
    final newlyUnlocked = <Achievement>[];
    final categoryId = data['categoryId'] as String;
    final perfectScore = data['perfectScore'] as bool;
    final score = data['score'] as int;

    // حساب المستويات المكتملة
    final completedLevels = _countCompletedLevels(profile);
    final totalStars = _countTotalStars(profile);
    final categoryLevels = _countCategoryCompletedLevels(profile, categoryId);

    // === إنجازات التعلم ===
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'first_level', completedLevels));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'student', completedLevels));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'scholar', completedLevels));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'sheikh', completedLevels));

    // === إنجازات النجوم ===
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'first_star', totalStars));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'star_collector', totalStars));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'shining', totalStars));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'constellation', totalStars));

    // === إنجازات الكمال ===
    if (perfectScore) {
      _incrementProgress(profile, 'no_mistakes');
      _incrementProgress(profile, 'sniper');
      _incrementProgress(profile, 'perfectionist');
    }
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'no_mistakes', _getProgress(profile, 'no_mistakes')));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'sniper', _getProgress(profile, 'sniper')));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'perfectionist', _getProgress(profile, 'perfectionist')));

    // === إنجازات الفئات ===
    final categoryAchievementMap = {
      'quran': 'quran_master',
      'hadith': 'hadith_master',
      'fiqh': 'fiqh_master',
      'seerah': 'seerah_master',
      'history': 'history_master',
      'aqeedah': 'aqeedah_master',
    };
    
    if (categoryAchievementMap.containsKey(categoryId)) {
      final achievementId = categoryAchievementMap[categoryId]!;
      newlyUnlocked.addAll(_checkAndUnlock(profile, achievementId, categoryLevels));
    }

    // === إنجازات النقاط ===
    final totalScore = profile.totalScore + score;
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'beginner_points', totalScore));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'rich_points', totalScore));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'king_points', totalScore));

    return newlyUnlocked;
  }

  /// التحقق من إنجازات السرعة
  Future<List<Achievement>> _checkSpeedAchievements(
    PlayerProfile profile,
    Map<String, dynamic> data,
  ) async {
    final newlyUnlocked = <Achievement>[];
    final secondsRemaining = data['secondsRemaining'] as int;

    // إجابة في أقل من 3 ثوانٍ (سواء كان مؤقت السؤال 20 ثانية أو 15 ثانية)
    final timeTaken = data['timeTaken'] as int? ?? (20 - secondsRemaining);
    final isFast = timeTaken <= 3 || secondsRemaining >= 17 || (data['totalTime'] == 15 && secondsRemaining >= 12);
    if (isFast) {
      _incrementProgress(profile, 'fast');
      _incrementProgress(profile, 'rocket');
    }

    newlyUnlocked.addAll(_checkAndUnlock(profile, 'fast', _getProgress(profile, 'fast')));
    newlyUnlocked.addAll(_checkAndUnlock(profile, 'rocket', _getProgress(profile, 'rocket')));

    return newlyUnlocked;
  }

  /// التحقق من streak يومي
  Future<List<Achievement>> _checkDailyStreak(PlayerProfile profile) async {
    final newlyUnlocked = <Achievement>[];
    final today = DateTime.now();
    final lastPlayed = profile.lastPlayedAt;

    // التحقق مما إذا كان اللعب في يوم جديد
    if (!_isSameDay(today, lastPlayed)) {
      final daysDifference = today.difference(lastPlayed).inDays;
      
      if (daysDifference == 1) {
        // استمرار الـ streak
        profile.currentStreak++;
      } else if (daysDifference > 1) {
        // انقطاع الـ streak
        profile.currentStreak = 1;
      }

      profile.totalDaysPlayed++;

      // تحديث إنجازات المثابرة
      newlyUnlocked.addAll(_checkAndUnlock(profile, 'one_day', profile.totalDaysPlayed));
      newlyUnlocked.addAll(_checkAndUnlock(profile, 'week_streak', profile.currentStreak));
      newlyUnlocked.addAll(_checkAndUnlock(profile, 'month_dedication', profile.totalDaysPlayed));
    }

    return newlyUnlocked;
  }

  /// فحص وفتح إنجاز مع الحفاظ على أعلى قيمة محققة دائماً
  List<Achievement> _checkAndUnlock(PlayerProfile profile, String achievementId, int currentValue) {
    final achievement = AchievementDefinitions.getById(achievementId);
    if (achievement == null) return [];

    final progress = profile.getAchievementProgress(achievementId);
    
    // تحديث التقدم بأخذ القيمة الأعلى دائماً
    if (currentValue > progress.currentValue) {
      progress.currentValue = currentValue;
    }

    // التحقق من الفتح
    if (!progress.isUnlocked && progress.currentValue >= achievement.targetValue) {
      progress.isUnlocked = true;
      progress.unlockedAt = DateTime.now();
      progress.hasBeenSeen = false;
      return [achievement];
    }

    return [];
  }

  /// زيادة تقدم إنجاز
  void _incrementProgress(PlayerProfile profile, String achievementId) {
    final progress = profile.getAchievementProgress(achievementId);
    progress.currentValue++;
  }

  /// الحصول على تقدم إنجاز
  int _getProgress(PlayerProfile profile, String achievementId) {
    return profile.getAchievementProgress(achievementId).currentValue;
  }

  /// حساب المستويات المكتملة
  int _countCompletedLevels(PlayerProfile profile) {
    return profile.levelStars.values.where((stars) => stars > 0).length;
  }

  /// حساب إجمالي النجوم
  int _countTotalStars(PlayerProfile profile) {
    return profile.levelStars.values.fold(0, (sum, stars) => sum + stars);
  }

  /// حساب المستويات الكاملة (100%)
  int _countPerfectLevels(PlayerProfile profile) {
    return profile.levelStars.values.where((stars) => stars == 3).length;
  }

  /// حساب مستويات فئة معينة
  int _countCategoryCompletedLevels(PlayerProfile profile, String categoryId) {
    return profile.levelStars.entries
        .where((e) => e.key.startsWith(categoryId) && e.value > 0)
        .length;
  }

  /// التحقق من نفس اليوم
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// تحديد أن الإنجاز تمت مشاهدته
  Future<void> markAsSeen(String achievementId) async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return;

    final progress = profile.getAchievementProgress(achievementId);
    progress.hasBeenSeen = true;
    
    await ProfileService.instance.saveActiveProfileAndSync();
    notifyListeners();
  }
}

/// بيانات الإنجاز مع تقدمه
class AchievementWithProgress {
  final Achievement achievement;
  final AchievementProgress progress;

  AchievementWithProgress({
    required this.achievement,
    required this.progress,
  });

  bool get isUnlocked => progress.isUnlocked;
  double get progressPercent {
    if (achievement.targetValue == 0) return 0;
    return (progress.currentValue / achievement.targetValue).clamp(0.0, 1.0);
  }
}
