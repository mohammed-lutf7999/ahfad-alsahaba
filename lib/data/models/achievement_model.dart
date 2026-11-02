import 'dart:convert';

/// فئة الإنجاز
enum AchievementCategory {
  learning,    // تعلم
  mastery,     // إتقان
  categories,  // فئات
  perfection,  // كمال
  speed,       // سرعة
  dedication,  // مثابرة
  points,      // نقاط
}

/// ندرة الإنجاز
enum AchievementRarity {
  common,      // شائع (برونزي)
  rare,        // نادر (فضي)
  epic,        // ملحمي (ذهبي)
  legendary,   // أسطوري (ماسي)
}

/// نموذج الإنجاز
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final int targetValue;
  final bool isSecret;
  
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.rarity,
    required this.targetValue,
    this.isSecret = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'category': category.index,
    'rarity': rarity.index,
    'targetValue': targetValue,
    'isSecret': isSecret,
  };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    icon: json['icon'],
    category: AchievementCategory.values[json['category']],
    rarity: AchievementRarity.values[json['rarity']],
    targetValue: json['targetValue'],
    isSecret: json['isSecret'] ?? false,
  );
}

/// حالة تقدم الإنجاز للاعب
class AchievementProgress {
  final String achievementId;
  int currentValue;
  bool isUnlocked;
  DateTime? unlockedAt;
  bool hasBeenSeen; // هل شاهد اللاعب إشعار الإنجاز

  AchievementProgress({
    required this.achievementId,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    this.hasBeenSeen = false,
  });

  Map<String, dynamic> toJson() => {
    'achievementId': achievementId,
    'currentValue': currentValue,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'hasBeenSeen': hasBeenSeen,
  };

  factory AchievementProgress.fromJson(Map<String, dynamic> json) => AchievementProgress(
    achievementId: json['achievementId'],
    currentValue: json['currentValue'] ?? 0,
    isUnlocked: json['isUnlocked'] ?? false,
    unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
    hasBeenSeen: json['hasBeenSeen'] ?? false,
  );

  static String progressListToJson(List<AchievementProgress> list) {
    return jsonEncode(list.map((p) => p.toJson()).toList());
  }

  static List<AchievementProgress> progressListFromJson(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    return list.map((json) => AchievementProgress.fromJson(json)).toList();
  }
}

/// حدث يمكن أن يؤدي إلى فتح إنجاز
class AchievementEvent {
  final AchievementEventType type;
  final Map<String, dynamic> data;

  AchievementEvent._(this.type, this.data);

  /// إكمال مستوى
  factory AchievementEvent.levelCompleted({
    required String categoryId,
    required int levelNumber,
    required int stars,
    required int score,
    required bool perfectScore,
    required int timeRemaining,
  }) => AchievementEvent._(
    AchievementEventType.levelCompleted,
    {
      'categoryId': categoryId,
      'levelNumber': levelNumber,
      'stars': stars,
      'score': score,
      'perfectScore': perfectScore,
      'timeRemaining': timeRemaining,
    },
  );

  /// فتح التطبيق (للتحقق من streak)
  factory AchievementEvent.appOpened() => AchievementEvent._(
    AchievementEventType.appOpened,
    {},
  );

  /// إجابة سريعة
  factory AchievementEvent.fastAnswer({required int secondsRemaining}) => AchievementEvent._(
    AchievementEventType.fastAnswer,
    {'secondsRemaining': secondsRemaining},
  );
}

enum AchievementEventType {
  levelCompleted,
  appOpened,
  fastAnswer,
}

/// قائمة جميع الإنجازات المتاحة
class AchievementDefinitions {
  static const List<Achievement> all = [
    // === إنجازات التعلم (Learning) ===
    Achievement(
      id: 'first_level',
      title: 'البداية',
      description: 'أكمل أول مستوى',
      icon: '🌱',
      category: AchievementCategory.learning,
      rarity: AchievementRarity.common,
      targetValue: 1,
    ),
    Achievement(
      id: 'student',
      title: 'طالب العلم',
      description: 'أكمل 10 مستويات',
      icon: '📖',
      category: AchievementCategory.learning,
      rarity: AchievementRarity.common,
      targetValue: 10,
    ),
    Achievement(
      id: 'scholar',
      title: 'العالم',
      description: 'أكمل 30 مستوى',
      icon: '🎓',
      category: AchievementCategory.learning,
      rarity: AchievementRarity.rare,
      targetValue: 30,
    ),
    Achievement(
      id: 'sheikh',
      title: 'الشيخ',
      description: 'أكمل جميع المستويات',
      icon: '🏛️',
      category: AchievementCategory.learning,
      rarity: AchievementRarity.legendary,
      targetValue: 60,
    ),

    // === إنجازات الإتقان (Mastery) ===
    Achievement(
      id: 'first_star',
      title: 'نجم واحد',
      description: 'احصل على أول نجمة',
      icon: '⭐',
      category: AchievementCategory.mastery,
      rarity: AchievementRarity.common,
      targetValue: 1,
    ),
    Achievement(
      id: 'star_collector',
      title: 'جامع النجوم',
      description: 'اجمع 30 نجمة',
      icon: '🌟',
      category: AchievementCategory.mastery,
      rarity: AchievementRarity.rare,
      targetValue: 30,
    ),
    Achievement(
      id: 'shining',
      title: 'متألق',
      description: 'اجمع 100 نجمة',
      icon: '✨',
      category: AchievementCategory.mastery,
      rarity: AchievementRarity.epic,
      targetValue: 100,
    ),
    Achievement(
      id: 'constellation',
      title: 'كوكبة',
      description: 'اجمع 180 نجمة (كل النجوم)',
      icon: '💫',
      category: AchievementCategory.mastery,
      rarity: AchievementRarity.legendary,
      targetValue: 180,
    ),

    // === إنجازات الفئات ===
    Achievement(
      id: 'quran_master',
      title: 'حافظ القرآن',
      description: 'أكمل جميع مستويات القرآن',
      icon: '📖',
      category: AchievementCategory.categories,
      rarity: AchievementRarity.epic,
      targetValue: 10,
    ),
    Achievement(
      id: 'hadith_master',
      title: 'راوي الأحاديث',
      description: 'أكمل جميع مستويات الحديث',
      icon: '📜',
      category: AchievementCategory.categories,
      rarity: AchievementRarity.epic,
      targetValue: 10,
    ),
    Achievement(
      id: 'fiqh_master',
      title: 'فقيه',
      description: 'أكمل جميع مستويات الفقه',
      icon: '⚖️',
      category: AchievementCategory.categories,
      rarity: AchievementRarity.epic,
      targetValue: 10,
    ),
    Achievement(
      id: 'seerah_master',
      title: 'سيرة النبي',
      description: 'أكمل جميع مستويات السيرة',
      icon: '📚',
      category: AchievementCategory.categories,
      rarity: AchievementRarity.epic,
      targetValue: 10,
    ),
    Achievement(
      id: 'history_master',
      title: 'مؤرخ',
      description: 'أكمل جميع مستويات التاريخ',
      icon: '🏰',
      category: AchievementCategory.categories,
      rarity: AchievementRarity.epic,
      targetValue: 10,
    ),
    Achievement(
      id: 'aqeedah_master',
      title: 'موحد',
      description: 'أكمل جميع مستويات العقيدة',
      icon: '✨',
      category: AchievementCategory.categories,
      rarity: AchievementRarity.epic,
      targetValue: 10,
    ),

    // === إنجازات الدقة (Perfection) ===
    Achievement(
      id: 'no_mistakes',
      title: 'لا أخطاء',
      description: 'أكمل مستوى بدون أخطاء',
      icon: '✅',
      category: AchievementCategory.perfection,
      rarity: AchievementRarity.common,
      targetValue: 1,
    ),
    Achievement(
      id: 'sniper',
      title: 'قناص',
      description: 'أكمل 5 مستويات بدون أخطاء',
      icon: '🎯',
      category: AchievementCategory.perfection,
      rarity: AchievementRarity.rare,
      targetValue: 5,
    ),
    Achievement(
      id: 'perfectionist',
      title: 'كمال',
      description: 'أكمل 10 مستويات بدون أخطاء',
      icon: '💯',
      category: AchievementCategory.perfection,
      rarity: AchievementRarity.epic,
      targetValue: 10,
    ),

    // === إنجازات السرعة (Speed) ===
    Achievement(
      id: 'fast',
      title: 'سريع',
      description: 'أجب على سؤال في أقل من 3 ثواني',
      icon: '⚡',
      category: AchievementCategory.speed,
      rarity: AchievementRarity.common,
      targetValue: 1,
    ),
    Achievement(
      id: 'rocket',
      title: 'صاروخ',
      description: 'أجب على 10 أسئلة بسرعة',
      icon: '🚀',
      category: AchievementCategory.speed,
      rarity: AchievementRarity.rare,
      targetValue: 10,
    ),

    // === إنجازات المثابرة (Dedication) ===
    Achievement(
      id: 'one_day',
      title: 'يوم واحد',
      description: 'العب يوم واحد',
      icon: '📅',
      category: AchievementCategory.dedication,
      rarity: AchievementRarity.common,
      targetValue: 1,
    ),
    Achievement(
      id: 'week_streak',
      title: 'أسبوع متواصل',
      description: 'العب 7 أيام متتالية',
      icon: '🔥',
      category: AchievementCategory.dedication,
      rarity: AchievementRarity.rare,
      targetValue: 7,
    ),
    Achievement(
      id: 'month_dedication',
      title: 'شهر المثابرة',
      description: 'العب 30 يوم',
      icon: '💪',
      category: AchievementCategory.dedication,
      rarity: AchievementRarity.epic,
      targetValue: 30,
    ),

    // === إنجازات النقاط ===
    Achievement(
      id: 'beginner_points',
      title: 'مبتدئ',
      description: 'اجمع 100 نقطة',
      icon: '💰',
      category: AchievementCategory.points,
      rarity: AchievementRarity.common,
      targetValue: 100,
    ),
    Achievement(
      id: 'rich_points',
      title: 'ثري',
      description: 'اجمع 1000 نقطة',
      icon: '💎',
      category: AchievementCategory.points,
      rarity: AchievementRarity.rare,
      targetValue: 1000,
    ),
    Achievement(
      id: 'king_points',
      title: 'غني العلم',
      description: 'اجمع 5000 نقطة',
      icon: '👑',
      category: AchievementCategory.points,
      rarity: AchievementRarity.epic,
      targetValue: 5000,
    ),
  ];

  /// الحصول على إنجاز بالمعرف
  static Achievement? getById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// الحصول على إنجازات بالفئة
  static List<Achievement> getByCategory(AchievementCategory category) {
    return all.where((a) => a.category == category).toList();
  }
}
