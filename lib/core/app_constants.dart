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
  static const int passingScore = 50; // percentage to pass level هنا تغيير نسبة الفتح للمستويات

  // Animation durations
  static const int splashDuration = 2500; // milliseconds
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
  static const String appVersion = '1.0.5';
  static const String developerName = 'م. محمد لطف';
}
