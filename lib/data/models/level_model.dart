class Level {
  final String id;
  final String categoryId;
  final int levelNumber;
  final String title;
  final int totalQuestions;
  final bool isLocked;
  final bool isCompleted;
  final int highScore;
  final int stars; // 0-3 stars based on performance

  Level({
    required this.id,
    required this.categoryId,
    required this.levelNumber,
    required this.title,
    required this.totalQuestions,
    this.isLocked = true,
    this.isCompleted = false,
    this.highScore = 0,
    this.stars = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'levelNumber': levelNumber,
      'title': title,
      'totalQuestions': totalQuestions,
      'isLocked': isLocked,
      'isCompleted': isCompleted,
      'highScore': highScore,
      'stars': stars,
    };
  }

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'],
      categoryId: json['categoryId'],
      levelNumber: json['levelNumber'],
      title: json['title'],
      totalQuestions: json['totalQuestions'],
      isLocked: json['isLocked'] ?? true,
      isCompleted: json['isCompleted'] ?? false,
      highScore: json['highScore'] ?? 0,
      stars: json['stars'] ?? 0,
    );
  }

  Level copyWith({
    String? id,
    String? categoryId,
    int? levelNumber,
    String? title,
    int? totalQuestions,
    bool? isLocked,
    bool? isCompleted,
    int? highScore,
    int? stars,
  }) {
    return Level(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      levelNumber: levelNumber ?? this.levelNumber,
      title: title ?? this.title,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      isLocked: isLocked ?? this.isLocked,
      isCompleted: isCompleted ?? this.isCompleted,
      highScore: highScore ?? this.highScore,
      stars: stars ?? this.stars,
    );
  }
}
