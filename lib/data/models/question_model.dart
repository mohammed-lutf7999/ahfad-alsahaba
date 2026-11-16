class Question {
  final String id;
  final String categoryId;
  final int levelNumber;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;
  final String syncScope;
  final bool isVisible;

  Question({
    required this.id,
    required this.categoryId,
    required this.levelNumber,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
    this.syncScope = 'solo_only',
    this.isVisible = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'levelNumber': levelNumber,
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'syncScope': syncScope,
      'isVisible': isVisible,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      categoryId: json['categoryId'],
      levelNumber: json['levelNumber'],
      questionText: json['questionText'],
      options: List<String>.from(json['options']),
      correctAnswerIndex: json['correctAnswerIndex'],
      explanation: json['explanation'],
      syncScope: json['syncScope'] ?? 'solo_only',
      isVisible: json['isVisible'] ?? true,
    );
  }

  Question copyWith({
    String? id,
    String? categoryId,
    int? levelNumber,
    String? questionText,
    List<String>? options,
    int? correctAnswerIndex,
    String? explanation,
    String? syncScope,
    bool? isVisible,
  }) {
    return Question(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      levelNumber: levelNumber ?? this.levelNumber,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      explanation: explanation ?? this.explanation,
      syncScope: syncScope ?? this.syncScope,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}