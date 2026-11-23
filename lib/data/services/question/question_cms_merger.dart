import 'dart:math';
import '../../models/cms_models.dart';
import '../../models/question_model.dart';

/// Pure mapper and merger combining bundled asset questions with dynamic
/// cloud CMS question overrides, visibility toggles, and option shuffling.
class QuestionCmsMerger {
  QuestionCmsMerger._();

  static Question withOptionRandom(Question question, Random? optionRandom) {
    final originalOptions = question.options;
    final originalCorrectIndex = question.correctAnswerIndex;
    if (optionRandom == null || originalOptions.isEmpty) {
      return Question(
        id: question.id,
        categoryId: question.categoryId,
        levelNumber: question.levelNumber,
        questionText: question.questionText,
        options: List<String>.from(originalOptions),
        correctAnswerIndex: originalCorrectIndex.clamp(
          0,
          originalOptions.isEmpty ? 0 : originalOptions.length - 1,
        ),
        explanation: question.explanation,
        syncScope: question.syncScope,
        isVisible: question.isVisible,
      );
    }

    final safeCorrect =
        originalCorrectIndex.clamp(0, originalOptions.length - 1);
    final correctAnswer = originalOptions[safeCorrect];
    final indices = List<int>.generate(originalOptions.length, (i) => i);
    indices.shuffle(optionRandom);

    final shuffledOptions = indices.map((i) => originalOptions[i]).toList();
    final newCorrectIndex = shuffledOptions.indexOf(correctAnswer);

    return Question(
      id: question.id,
      categoryId: question.categoryId,
      levelNumber: question.levelNumber,
      questionText: question.questionText,
      options: shuffledOptions,
      correctAnswerIndex: newCorrectIndex >= 0 ? newCorrectIndex : 0,
      explanation: question.explanation,
      syncScope: question.syncScope,
      isVisible: question.isVisible,
    );
  }

  static Question mapQuestionEntry(
    Map<String, dynamic> q, {
    required String categoryId,
    required int levelNumber,
    Random? optionRandom,
  }) {
    final originalOptions = List<String>.from(q['options'] ?? []);
    final originalCorrectIndex = (q['correct'] as num?)?.toInt() ?? 0;
    final baseQuestion = Question(
      id: (q['id'] ?? '').toString(),
      categoryId: categoryId,
      levelNumber: levelNumber,
      questionText: (q['question'] ?? '').toString(),
      options: originalOptions,
      correctAnswerIndex: originalCorrectIndex,
      explanation: q['explanation']?.toString(),
      syncScope: 'all_with_fallback',
      isVisible: true,
    );
    return withOptionRandom(baseQuestion, optionRandom);
  }

  static Question mapDynamicQuestion(
    DynamicQuizQuestionData q, {
    Random? optionRandom,
  }) {
    final base = Question(
      id: q.id,
      categoryId: q.categoryId,
      levelNumber: q.levelNumber,
      questionText: q.questionText,
      options: List<String>.from(q.options),
      correctAnswerIndex: q.correctIndex,
      explanation: q.explanation,
      syncScope: q.syncScope,
      isVisible: q.isVisible,
    );
    return withOptionRandom(base, optionRandom);
  }
}
