import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/question_model.dart';

Map<String, dynamic> _decodeQuestionJson(String jsonString) {
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

/// Service for loading questions from JSON files
/// Implements caching and background-isolate JSON decoding
class QuestionService {
  // Singleton pattern
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;
  QuestionService._internal();

  // Cache for loaded category data
  final Map<String, dynamic> _cache = {};

  // Coalesces concurrent loads/preloads for the same category
  final Map<String, Future<void>> _inFlightLoads = {};

  // Random generator for shuffling
  final Random _random = Random();

  Future<void> _ensureCategoryLoaded(String categoryId) async {
    if (_cache.containsKey(categoryId)) return;

    final existingFuture = _inFlightLoads[categoryId];
    if (existingFuture != null) {
      await existingFuture;
      return;
    }

    final loadFuture = () async {
      final jsonString = await rootBundle.loadString(
        'assets/questions/$categoryId.json',
      );
      _cache[categoryId] = await compute(_decodeQuestionJson, jsonString);
    }();

    _inFlightLoads[categoryId] = loadFuture;
    try {
      await loadFuture;
    } finally {
      _inFlightLoads.remove(categoryId);
    }
  }

  /// Returns [question] with its options deterministically or randomly shuffled
  /// when [optionRandom] is supplied.
  Question _withOptionRandom(Question question, Random? optionRandom) {
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
      );
    }

    final safeCorrect = originalCorrectIndex.clamp(0, originalOptions.length - 1);
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
    );
  }

  /// Maps a raw JSON question entry into a [Question], optionally shuffling
  /// options with [optionRandom] (pass a seeded [Random] for synchronized PvP/Ghost).
  Question _mapQuestionEntry(
    Map<String, dynamic> q, {
    required String categoryId,
    required int levelNumber,
    Random? optionRandom,
  }) {
    final originalOptions = List<String>.from(q['options'] ?? []);
    final originalCorrectIndex = (q['correct'] as num?)?.toInt() ?? 0;
    final baseQuestion = Question(
      id: q['id'] ?? '',
      categoryId: categoryId,
      levelNumber: levelNumber,
      questionText: q['question'] ?? '',
      options: originalOptions,
      correctAnswerIndex: originalCorrectIndex,
      explanation: q['explanation'],
    );
    return _withOptionRandom(baseQuestion, optionRandom);
  }

  /// Loads a single deterministic question by `category:level:index` specification
  /// WITHOUT shuffling the level list, guaranteeing Device A, Device B, and Ghost Replays
  /// receive the exact same question and option ordering.
  Future<Question?> loadQuestionBySpec({
    required String categoryId,
    required int levelNumber,
    required int questionIndex,
    int? seed,
    int slotOffset = 0,
  }) async {
    try {
      await _ensureCategoryLoaded(categoryId);
    } catch (e) {
      debugPrint('QuestionService: Failed loading $categoryId spec: $e');
      return null;
    }

    final data = _cache[categoryId];
    if (data == null) return null;
    final levels = data['levels'] as Map<String, dynamic>?;
    final levelList = levels?[levelNumber.toString()] as List?;
    if (levelList == null || levelList.isEmpty) return null;

    final safeIdx = questionIndex.clamp(0, levelList.length - 1);
    final raw = levelList[safeIdx] as Map<String, dynamic>;
    final optionRng = seed != null
        ? Random(seed + levelNumber * 31 + safeIdx + slotOffset * 17)
        : null;

    return _mapQuestionEntry(
      raw,
      categoryId: categoryId,
      levelNumber: levelNumber,
      optionRandom: optionRng,
    );
  }

  /// Load questions for a specific level from a category
  /// Returns a list of Question objects
  Future<List<Question>> loadQuestions({
    required String categoryId,
    required int levelNumber,
  }) async {
    try {
      await _ensureCategoryLoaded(categoryId);
    } catch (e) {
      throw Exception('Failed to load questions for $categoryId: $e');
    }

    // Extract questions for the specified level
    final data = _cache[categoryId];
    final levels = data['levels'] as Map<String, dynamic>;
    final levelKey = levelNumber.toString();

    if (!levels.containsKey(levelKey)) {
      throw Exception('Level $levelNumber not found in $categoryId');
    }

    final levelQuestions = levels[levelKey] as List;

    // Convert to Question objects with shuffled options
    final questions = levelQuestions
        .map(
          (q) => _mapQuestionEntry(
            q as Map<String, dynamic>,
            categoryId: categoryId,
            levelNumber: levelNumber,
            optionRandom: _random,
          ),
        )
        .toList();

    // Shuffle the questions to randomize their order
    questions.shuffle(_random);

    return questions;
  }

  /// Load all questions from all levels for a specific category
  Future<List<Question>> loadAllQuestionsForCategory(
    String categoryId, {
    bool shuffleQuestions = true,
    bool shuffleOptions = true,
    Random? optionRandom,
  }) async {
    try {
      await _ensureCategoryLoaded(categoryId);
    } catch (e) {
      debugPrint('❌ Failed to load questions for $categoryId: $e');
      return [];
    }

    final data = _cache[categoryId];
    final levels = data['levels'] as Map<String, dynamic>;
    final allQuestions = <Question>[];
    final effectiveOptionRng = shuffleOptions ? (optionRandom ?? _random) : null;

    for (var levelKey in levels.keys) {
      final levelNumber = int.tryParse(levelKey) ?? 1;
      final levelQuestions = levels[levelKey] as List;

      allQuestions.addAll(
        levelQuestions.map(
          (q) => _mapQuestionEntry(
            q as Map<String, dynamic>,
            categoryId: categoryId,
            levelNumber: levelNumber,
            optionRandom: effectiveOptionRng,
          ),
        ),
      );
    }

    if (shuffleQuestions) {
      allQuestions.shuffle(_random);
    }
    return allQuestions;
  }

  /// Get the total number of questions for a category
  Future<int> getTotalQuestionsForCategory(String categoryId) async {
    try {
      await _ensureCategoryLoaded(categoryId);
    } catch (e) {
      return 0;
    }

    final data = _cache[categoryId];
    final levels = data['levels'] as Map<String, dynamic>;
    int total = 0;

    for (var level in levels.values) {
      total += (level as List).length;
    }

    return total;
  }

  /// Check if a specific level exists
  Future<bool> levelExists(String categoryId, int levelNumber) async {
    // ... (rest is same, ensuring consistency)
    if (!_cache.containsKey(categoryId)) {
        await preloadCategory(categoryId);
    }
    final data = _cache[categoryId];
    if (data == null) return false;
    final levels = data['levels'] as Map<String, dynamic>;
    return levels.containsKey(levelNumber.toString());
  }

  /// Clear cache for a specific category or all categories
  void clearCache([String? categoryId]) {
    if (categoryId != null) {
      _cache.remove(categoryId);
    } else {
      _cache.clear();
    }
  }

  /// Check if a category is cached
  bool isCached(String categoryId) {
    return _cache.containsKey(categoryId);
  }

  /// Preloads a category into cache in background isolate if not already loaded
  Future<void> preloadCategory(String categoryId) async {
    try {
      await _ensureCategoryLoaded(categoryId);
    } catch (e) {
      debugPrint('Error preloading category $categoryId: $e');
    }
  }

  /// Get 5 deterministic questions for multiplayer based on a seed
  Future<List<Question>> getQuestionsForMultiplayer(int seed) async {
    const categories = ['quran', 'hadith', 'fiqh', 'seerah', 'history', 'aqeedah'];
    final allQuestions = <Question>[];

    // Load all questions with unshuffled options first so option order
    // remains strictly deterministic per [seed] across clients.
    for (final cat in categories) {
      final questions = await loadAllQuestionsForCategory(
        cat,
        shuffleQuestions: false,
        shuffleOptions: false,
      );
      allQuestions.addAll(questions);
    }

    if (allQuestions.isEmpty) return [];

    // 1. Sort by ID to ensure consistent initial order across devices
    allQuestions.sort((a, b) => a.id.compareTo(b.id));

    // 2. Shuffle using the provided seed
    final r = Random(seed);
    allQuestions.shuffle(r);

    // 3. Take top 5 and shuffle each slot's options deterministically
    final selected = allQuestions.take(5).toList();
    return List<Question>.generate(
      selected.length,
      (slot) => _withOptionRandom(selected[slot], Random(seed + slot * 31)),
    );
  }
}
