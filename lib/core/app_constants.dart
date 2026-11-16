class AppConstants {
  // Timer settings
  static const int defaultQuestionTime = 20; // seconds
  static const int minQuestionTime = 10;
  static const int maxQuestionTime = 60;

  // Points settings
  static const int correctAnswerPoints = 10;
  static const int bonusTimePoints = 5; // Bonus for fast answers
  static const int fastAnswerThreshold = 5; // seconds remaining for bonus

  // Level settings
  static const int questionsPerLevel = 10;
  static const int levelsPerCategory = 10;
  static const int passingScore = 50; // percentage to pass level هنا تغيير نسبة الفتح للمستويات

  /// Unified star calculation used across GameController and ResultScreen
  static int calculateStars(double percentage) {
    if (percentage >= 90) return 3;
    if (percentage >= 70) return 2;
    if (percentage >= passingScore) return 1;
    return 0;
  }

  /// Unified Arabic display name for all category IDs
  static String getCategoryName(String categoryId) {
    switch (categoryId) {
      case quranCategory:
        return 'القرآن الكريم';
      case hadithCategory:
        return 'الحديث الشريف';
      case fiqhCategory:
        return 'الفقه الإسلامي';
      case seerahCategory:
        return 'السيرة النبوية';
      case historyCategory:
      case 'islamic_history':
        return 'التاريخ الإسلامي';
      case aqeedahCategory:
        return 'العقيدة الإسلامية';
      default:
        return 'المسابقة الإسلامية';
    }
  }

  // Animation durations
  static const int splashDuration = 0; // milliseconds (instant Local-First SWR launch)
  static const int transitionDuration = 300; // milliseconds
  static const int answerRevealDuration = 1500; // milliseconds

  // Storage keys
  static const String progressKey = 'game_progress';
  static const String settingsKey = 'game_settings';
  static const String questionsKey = 'questions_data';
  static const String highScoreKey = 'high_score';

  // Category IDs
  static const String quranCategory = 'quran';
  static const String hadithCategory = 'hadith';
  static const String fiqhCategory = 'fiqh';
  static const String seerahCategory = 'seerah';
  static const String historyCategory = 'history';
  static const String aqeedahCategory = 'aqeedah';

  // App & Developer info
  static const String appName = 'معركة أحفاد الصحابة';
  static const String storeTitle = 'معركة أحفاد الصحابة: مسابقات';
  static const String appVersion = '1.0.18';
  static const int appBuildNumber = 19;
  static const String playStorePackageId = 'com.ahfad.alsahaba.battle';
  static const String playStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$playStorePackageId';
  static const String playStoreMarketUri = 'market://details?id=$playStorePackageId';
  static const int appControlSyncCooldownMinutes = 15;
  static const String developerName = 'م. محمد لطف';
}
