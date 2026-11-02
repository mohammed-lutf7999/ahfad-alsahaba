import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/question_model.dart';

/// Service for loading questions from JSON files
/// Implements caching to avoid reloading files
class QuestionService {
  // Singleton pattern
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;
  QuestionService._internal();

  // Cache for loaded category data
  final Map<String, dynamic> _cache = {};

  // Loading state tracking
  bool _isLoading = false;
  String? _currentLoadingCategory;
  
  // Random generator for shuffling
  final Random _random = Random();

  /// Load questions for a specific level from a category
  /// Returns a list of Question objects
  Future<List<Question>> loadQuestions({
    required String categoryId,
    required int levelNumber,
  }) async {
    // Wait if another load is in progress for the same category
    while (_isLoading && _currentLoadingCategory == categoryId) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Check cache first
    if (!_cache.containsKey(categoryId)) {
      _isLoading = true;
      _currentLoadingCategory = categoryId;

      try {
        // Load JSON file from assets
        final jsonString = await rootBundle.loadString(
          'assets/questions/$categoryId.json',
        );
        _cache[categoryId] = jsonDecode(jsonString);
      } catch (e) {
        _isLoading = false;
        _currentLoadingCategory = null;
        throw Exception('Failed to load questions for $categoryId: $e');
      }

      _isLoading = false;
      _currentLoadingCategory = null;
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
    final questions = levelQuestions.map((q) {
      final originalOptions = List<String>.from(q['options'] ?? []);
      final originalCorrectIndex = q['correct'] ?? 0;
      
      // Get the correct answer text before shuffling
      final correctAnswer = originalOptions.isNotEmpty && originalCorrectIndex < originalOptions.length
          ? originalOptions[originalCorrectIndex]
          : '';
      
      // Create a list of indices and shuffle them
      final indices = List<int>.generate(originalOptions.length, (i) => i);
      indices.shuffle(_random);
      
      // Create shuffled options based on shuffled indices
      final shuffledOptions = indices.map((i) => originalOptions[i]).toList();
      
      // Find the new index of the correct answer
      final newCorrectIndex = shuffledOptions.indexOf(correctAnswer);
      
      return Question(
        id: q['id'] ?? '',
        categoryId: categoryId,
        levelNumber: levelNumber,
        questionText: q['question'] ?? '',
        options: shuffledOptions,
        correctAnswerIndex: newCorrectIndex >= 0 ? newCorrectIndex : 0,
        explanation: q['explanation'],
      );
    }).toList();

    // Shuffle the questions to randomize their order
    questions.shuffle(_random);

    return questions;
  }

  /// Load all questions from all levels for a specific category
  Future<List<Question>> loadAllQuestionsForCategory(String categoryId) async {
    // Check cache first
    if (!_cache.containsKey(categoryId)) {
      try {
        final jsonString = await rootBundle.loadString(
          'assets/questions/$categoryId.json',
        );
        _cache[categoryId] = jsonDecode(jsonString);
      } catch (e) {
        debugPrint('❌ Failed to load questions for $categoryId: $e');
        return [];
      }
    }

    final data = _cache[categoryId];
    final levels = data['levels'] as Map<String, dynamic>;
    final allQuestions = <Question>[];

    for (var levelKey in levels.keys) {
      final levelNumber = int.tryParse(levelKey) ?? 1;
      final levelQuestions = levels[levelKey] as List;

      allQuestions.addAll(levelQuestions.map((q) {
        final originalOptions = List<String>.from(q['options'] ?? []);
        final originalCorrectIndex = q['correct'] ?? 0;
        
        // Get the correct answer text before shuffling
        final correctAnswer = originalOptions.isNotEmpty && originalCorrectIndex < originalOptions.length
            ? originalOptions[originalCorrectIndex]
            : '';
        
        // Create a list of indices and shuffle them
        final indices = List<int>.generate(originalOptions.length, (i) => i);
        indices.shuffle(_random);
        
        // Create shuffled options based on shuffled indices
        final shuffledOptions = indices.map((i) => originalOptions[i]).toList();
        
        // Find the new index of the correct answer
        final newCorrectIndex = shuffledOptions.indexOf(correctAnswer);
        
        return Question(
          id: q['id'] ?? '',
          categoryId: categoryId,
          levelNumber: levelNumber,
          questionText: q['question'] ?? '',
          options: shuffledOptions,
          correctAnswerIndex: newCorrectIndex >= 0 ? newCorrectIndex : 0,
          explanation: q['explanation'],
        );
      }));
    }

    // Shuffle all questions
    allQuestions.shuffle(_random);
    return allQuestions;
  }

  /// Get the total number of questions for a category
  Future<int> getTotalQuestionsForCategory(String categoryId) async {
    if (!_cache.containsKey(categoryId)) {
      try {
        final jsonString = await rootBundle.loadString(
          'assets/questions/$categoryId.json',
        );
        _cache[categoryId] = jsonDecode(jsonString);
      } catch (e) {
        return 0;
      }
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

  /// Preloads a category into cache if not already loaded
  Future<void> preloadCategory(String categoryId) async {
    if (_cache.containsKey(categoryId)) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/questions/$categoryId.json',
      );
      _cache[categoryId] = jsonDecode(jsonString);
    } catch (e) {
      debugPrint('Error preloading category $categoryId: $e');
    }
  }

  /// Get 5 deterministic questions for multiplayer based on a seed
  Future<List<Question>> getQuestionsForMultiplayer(int seed) async {
    const categories = ['quran', 'hadith', 'fiqh', 'seerah', 'history', 'aqeedah'];
    final allQuestions = <Question>[];

    // Load all questions
    for (final cat in categories) {
      final questions = await loadAllQuestionsForCategory(cat);
      allQuestions.addAll(questions);
    }

    if (allQuestions.isEmpty) return [];

    // 1. Sort by ID to ensure consistent initial order across devices
    allQuestions.sort((a, b) => a.id.compareTo(b.id));

    // 2. Shuffle using the provided seed
    final r = Random(seed);
    allQuestions.shuffle(r);

    // 3. Take top 5
    return allQuestions.take(5).toList();
  }
}
