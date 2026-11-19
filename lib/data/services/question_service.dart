import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/cms_models.dart';
import '../models/question_model.dart';
import 'cms_cache_service.dart';

Map<String, dynamic> _decodeQuestionJson(String jsonString) {
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

/// Service for loading questions from local JSON assets merged with dynamic
/// solo Quiz additions/edits/visibility rules cached in [CmsCacheService].
///
/// Multiplayer & Ghost replays (`loadQuestionBySpec` / `getQuestionsForMultiplayer`)
/// continue reading immutable base assets cleanly so matches never desync across versions.
class QuestionService {
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;
  QuestionService._internal() {
    CmsCacheService.instance.registerOnBundleApplied(() => clearCache());
  }

  /// Raw decoded asset data per built-in category (immutable once loaded).
  final Map<String, Map<String, dynamic>?> _baseAssetCache = {};

  /// Coalesces concurrent asset loads per category.
  final Map<String, Future<void>> _inFlightLoads = {};

  final Random _random = Random();

  Future<void> _ensureBaseCategoryLoaded(String categoryId) async {
    if (_baseAssetCache.containsKey(categoryId)) return;

    final existingFuture = _inFlightLoads[categoryId];
    if (existingFuture != null) {
      await existingFuture;
      return;
    }

    final loadFuture = () async {
      try {
        final jsonString = await rootBundle.loadString(
          'assets/questions/$categoryId.json',
        );
        _baseAssetCache[categoryId] =
            await compute(_decodeQuestionJson, jsonString);
      } catch (_) {
        // Cloud-only categories have no bundled asset file; record null cleanly
        // so level lookups proceed smoothly from CmsCacheService.
        _baseAssetCache[categoryId] = null;
      }
    }();

    _inFlightLoads[categoryId] = loadFuture;
    try {
      await loadFuture;
    } finally {
      _inFlightLoads.remove(categoryId);
    }
  }

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

  Question _mapQuestionEntry(
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
    return _withOptionRandom(baseQuestion, optionRandom);
  }

  Question _mapDynamicQuestion(
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
    return _withOptionRandom(base, optionRandom);
  }

  /// Loads a single deterministic question by `category:level:index` specification
  /// WITHOUT shifting base list ordering, guaranteeing Device A, Device B, and
  /// Ghost Replays receive the exact same question and option ordering.
  Future<Question?> loadQuestionBySpec({
    required String categoryId,
    required int levelNumber,
    required int questionIndex,
    int? seed,
    int slotOffset = 0,
  }) async {
    await _ensureBaseCategoryLoaded(categoryId);
    final data = _baseAssetCache[categoryId];
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

  /// Loads an ordered list of questions deterministically from `category:level:index` specs.
  Future<List<Question>> loadQuestionsBySpecs(
    List<String> specs, {
    int? seed,
    String? fallbackCategoryId,
  }) async {
    final questions = <Question>[];
    for (var slot = 0; slot < specs.length; slot++) {
      final parts = specs[slot].split(':');
      if (parts.length < 3) continue;
      final q = await loadQuestionBySpec(
        categoryId: parts[0],
        levelNumber: int.tryParse(parts[1]) ?? 1,
        questionIndex: int.tryParse(parts[2]) ?? 0,
        seed: seed,
        slotOffset: slot,
      );
      if (q != null) questions.add(q);
    }
    if (questions.isEmpty && fallbackCategoryId != null) {
      final fallback = await loadQuestions(
        categoryId: fallbackCategoryId,
        levelNumber: 1,
      );
      return fallback.take(8).toList();
    }
    return questions;
  }

  /// Builds visible solo questions for `(categoryId, levelNumber)` merging
  /// local asset JSON with dynamic overrides & additions from [CmsCacheService].
  Future<List<Question>> loadQuestions({
    required String categoryId,
    required int levelNumber,
  }) async {
    await _ensureBaseCategoryLoaded(categoryId);

    final baseData = _baseAssetCache[categoryId];
    final levels = baseData?['levels'] as Map<String, dynamic>?;
    final levelKey = levelNumber.toString();
    final rawBaseList = levels?[levelKey] as List?;

    // Track cloud overrides/additions for this category
    final cloudQuestions = CmsCacheService.instance.snapshot.quizQuestions.values
        .where((q) => q.categoryId == categoryId)
        .toList();
    final cloudById = <String, DynamicQuizQuestionData>{
      for (final q in cloudQuestions) q.id: q,
    };

    final List<({int sortOrder, Question question})> merged = [];
    final seenIds = <String>{};

    if (rawBaseList != null) {
      for (var i = 0; i < rawBaseList.length; i++) {
        final rawMap = Map<String, dynamic>.from(rawBaseList[i] as Map);
        final rawId = (rawMap['id'] ?? '').toString();
        final override = rawId.isNotEmpty ? cloudById[rawId] : null;
        if (override != null) {
          seenIds.add(rawId);
          if (override.isVisible && override.levelNumber == levelNumber) {
            merged.add((
              sortOrder: override.sortOrder,
              question: _mapDynamicQuestion(override, optionRandom: _random),
            ));
          }
          continue;
        }
        if (rawId.isNotEmpty) seenIds.add(rawId);
        merged.add((
          sortOrder: 100 + i,
          question: _mapQuestionEntry(
            rawMap,
            categoryId: categoryId,
            levelNumber: levelNumber,
            optionRandom: _random,
          ),
        ));
      }
    }

    // Add newly created cloud questions for this category & level
    for (final q in cloudQuestions) {
      if (seenIds.contains(q.id)) continue;
      if (q.levelNumber == levelNumber && q.isVisible && q.options.length == 4) {
        merged.add((
          sortOrder: q.sortOrder,
          question: _mapDynamicQuestion(q, optionRandom: _random),
        ));
      }
    }

    if (merged.isEmpty) {
      throw Exception('Level $levelNumber not found in $categoryId');
    }

    merged.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final questions = merged.map((e) => e.question).toList();
    questions.shuffle(_random);
    return questions;
  }

  /// Load all visible solo questions from all levels for [categoryId].
  Future<List<Question>> loadAllQuestionsForCategory(
    String categoryId, {
    bool shuffleQuestions = true,
    bool shuffleOptions = true,
    Random? optionRandom,
    bool includeCloudSoloQuestions = true,
  }) async {
    await _ensureBaseCategoryLoaded(categoryId);

    final baseData = _baseAssetCache[categoryId];
    final levels = baseData?['levels'] as Map<String, dynamic>?;
    final effectiveOptionRng = shuffleOptions ? (optionRandom ?? _random) : null;

    final cloudQuestions = includeCloudSoloQuestions
        ? CmsCacheService.instance.snapshot.quizQuestions.values
            .where((q) => q.categoryId == categoryId)
            .toList()
        : const <DynamicQuizQuestionData>[];
    final cloudById = {for (final q in cloudQuestions) q.id: q};

    final allQuestions = <Question>[];
    final seenIds = <String>{};

    if (levels != null) {
      for (final levelKey in levels.keys) {
        final levelNumber = int.tryParse(levelKey) ?? 1;
        final levelQuestions = levels[levelKey] as List;
        for (final raw in levelQuestions) {
          final rawMap = Map<String, dynamic>.from(raw as Map);
          final rawId = (rawMap['id'] ?? '').toString();
          final override = rawId.isNotEmpty ? cloudById[rawId] : null;
          if (override != null) {
            seenIds.add(rawId);
            if (override.isVisible) {
              allQuestions.add(
                _mapDynamicQuestion(override, optionRandom: effectiveOptionRng),
              );
            }
            continue;
          }
          if (rawId.isNotEmpty) seenIds.add(rawId);
          allQuestions.add(
            _mapQuestionEntry(
              rawMap,
              categoryId: categoryId,
              levelNumber: levelNumber,
              optionRandom: effectiveOptionRng,
            ),
          );
        }
      }
    }

    for (final q in cloudQuestions) {
      if (seenIds.contains(q.id)) continue;
      if (q.isVisible && q.options.length == 4) {
        allQuestions.add(
          _mapDynamicQuestion(q, optionRandom: effectiveOptionRng),
        );
      }
    }

    if (shuffleQuestions) {
      allQuestions.shuffle(_random);
    }
    return allQuestions;
  }

  /// Get the total number of visible solo questions for [categoryId].
  Future<int> getTotalQuestionsForCategory(String categoryId) async {
    final questions = await loadAllQuestionsForCategory(
      categoryId,
      shuffleQuestions: false,
      shuffleOptions: false,
    );
    return questions.length;
  }

  /// Check if a specific level has visible questions in [categoryId].
  Future<bool> levelExists(String categoryId, int levelNumber) async {
    await _ensureBaseCategoryLoaded(categoryId);
    final hasCloudForLevel = CmsCacheService.instance.snapshot.quizQuestions.values
        .any((q) =>
            q.categoryId == categoryId &&
            q.levelNumber == levelNumber &&
            q.isVisible &&
            q.options.length == 4);
    if (hasCloudForLevel) return true;

    final baseData = _baseAssetCache[categoryId];
    final levels = baseData?['levels'] as Map<String, dynamic>?;
    final list = levels?[levelNumber.toString()] as List?;
    return list != null && list.isNotEmpty;
  }

  /// Clears cached JSON asset data (only needed explicitly in memory cleanup/tests).
  void clearCache([String? categoryId]) {
    if (categoryId != null) {
      _baseAssetCache.remove(categoryId);
    } else {
      _baseAssetCache.clear();
    }
  }

  bool isCached(String categoryId) => _baseAssetCache.containsKey(categoryId);

  Future<void> preloadCategory(String categoryId) async {
    await _ensureBaseCategoryLoaded(categoryId);
  }

  /// Get 5 deterministic questions for multiplayer based on a seed.
  /// Strictly uses built-in base categories (`includeCloudSoloQuestions: false`)
  /// so devices on different CMS revisions never desync on question indices.
  Future<List<Question>> getQuestionsForMultiplayer(int seed) async {
    const categories = ['quran', 'hadith', 'fiqh', 'seerah', 'history', 'aqeedah'];
    final allQuestions = <Question>[];

    for (final cat in categories) {
      final questions = await loadAllQuestionsForCategory(
        cat,
        shuffleQuestions: false,
        shuffleOptions: false,
        includeCloudSoloQuestions: false,
      );
      allQuestions.addAll(questions);
    }

    if (allQuestions.isEmpty) return [];

    allQuestions.sort((a, b) => a.id.compareTo(b.id));
    final r = Random(seed);
    allQuestions.shuffle(r);

    final selected = allQuestions.take(5).toList();
    return List<Question>.generate(
      selected.length,
      (slot) => _withOptionRandom(selected[slot], Random(seed + slot * 31)),
    );
  }
}
