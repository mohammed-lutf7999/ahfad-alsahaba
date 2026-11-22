import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/cms_models.dart';
import '../models/question_model.dart';
import 'cms_cache_service.dart';
import 'question/question_asset_loader.dart';
import 'question/question_cms_merger.dart';

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

  final QuestionAssetLoader _assetLoader = QuestionAssetLoader();
  final Random _random = Random();

  Future<void> _ensureBaseCategoryLoaded(String categoryId) =>
      _assetLoader.ensureLoaded(categoryId);

  Question _withOptionRandom(Question question, Random? optionRandom) =>
      QuestionCmsMerger.withOptionRandom(question, optionRandom);

  Question _mapQuestionEntry(
    Map<String, dynamic> q, {
    required String categoryId,
    required int levelNumber,
    Random? optionRandom,
  }) =>
      QuestionCmsMerger.mapQuestionEntry(
        q,
        categoryId: categoryId,
        levelNumber: levelNumber,
        optionRandom: optionRandom,
      );

  Question _mapDynamicQuestion(
    DynamicQuizQuestionData q, {
    Random? optionRandom,
  }) =>
      QuestionCmsMerger.mapDynamicQuestion(q, optionRandom: optionRandom);

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
    final data = _assetLoader.getCached(categoryId);
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

  /// Loads an ordered list of questions deterministically from `category:level:index`
  /// and `cms:<questionId>` specs.
  Future<List<Question>> loadQuestionsBySpecs(
    List<String> specs, {
    int? seed,
    String? fallbackCategoryId,
  }) async {
    final cmsSpecs = specs.where((s) => s.startsWith('cms:')).toList();
    if (cmsSpecs.isNotEmpty) {
      final hasMissingCms = cmsSpecs.any((spec) {
        final id = spec.substring(4).trim();
        return id.isNotEmpty &&
            !CmsCacheService.instance.snapshot.quizQuestions.containsKey(id);
      });
      if (hasMissingCms) {
        try {
          await CmsCacheService.instance.syncIfNeeded(
            serverCmsVersion: CmsCacheService.instance.snapshot.cmsVersion + 1,
            force: true,
          );
        } catch (e) {
          debugPrint('QuestionService CMS spec sync notice: $e');
        }
      }
    }

    final questions = <Question>[];
    final cmsMap = CmsCacheService.instance.snapshot.quizQuestions;
    for (var slot = 0; slot < specs.length; slot++) {
      final rawSpec = specs[slot].trim();
      if (rawSpec.startsWith('cms:')) {
        final cmsId = rawSpec.substring(4).trim();
        final dynQ = cmsMap[cmsId];
        if (dynQ != null && dynQ.options.length >= 2) {
          final optionRng = seed != null ? Random(seed + slot * 31) : null;
          questions.add(_mapDynamicQuestion(dynQ, optionRandom: optionRng));
        }
        continue;
      }
      final parts = rawSpec.split(':');
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
      try {
        final fallback = await loadAllQuestionsForCategory(
          fallbackCategoryId,
          shuffleQuestions: true,
          shuffleOptions: true,
        );
        return fallback.take(8).toList();
      } catch (_) {
        return const [];
      }
    }
    return questions;
  }

  /// Builds shareable question specs (`category:level:slot` and `cms:<id>`)
  /// for Live Arena host sessions across built-in and cloud CMS categories.
  Future<List<String>> buildLiveArenaQuestionSpecs({
    required String categoryId,
    int? levelNumber,
    int count = 8,
  }) async {
    await _ensureBaseCategoryLoaded(categoryId);
    final specs = <String>[];
    final baseData = _assetLoader.getCached(categoryId);
    final levels = baseData?['levels'] as Map<String, dynamic>?;

    final cloudQuestions = CmsCacheService.instance.snapshot.quizQuestions.values
        .where((q) =>
            q.categoryId == categoryId &&
            q.isVisible &&
            q.options.length == 4 &&
            (levelNumber == null || q.levelNumber == levelNumber))
        .toList();
    final cloudById = {for (final q in cloudQuestions) q.id: q};
    final seenCloudIds = <String>{};

    if (levels != null) {
      final targetKeys = levelNumber != null
          ? [levelNumber.toString()]
          : levels.keys.toList();
      for (final lk in targetKeys) {
        final lv = int.tryParse(lk) ?? 1;
        final list = levels[lk] as List?;
        if (list == null) continue;
        for (var i = 0; i < list.length; i++) {
          final raw = list[i] as Map;
          final rawId = (raw['id'] ?? '').toString();
          final override = rawId.isNotEmpty ? cloudById[rawId] : null;
          if (override != null) {
            seenCloudIds.add(rawId);
            if (override.isVisible) {
              specs.add('cms:${override.id}');
            }
            continue;
          }
          specs.add('$categoryId:$lv:$i');
        }
      }
    }

    for (final q in cloudQuestions) {
      if (seenCloudIds.contains(q.id)) continue;
      specs.add('cms:${q.id}');
    }

    specs.shuffle(_random);
    return specs.take(count.clamp(1, 20)).toList();
  }

  /// Builds visible solo questions for `(categoryId, levelNumber)` merging
  /// local asset JSON with dynamic overrides & additions from [CmsCacheService].
  Future<List<Question>> loadQuestions({
    required String categoryId,
    required int levelNumber,
  }) async {
    await _ensureBaseCategoryLoaded(categoryId);

    final baseData = _assetLoader.getCached(categoryId);
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

    final baseData = _assetLoader.getCached(categoryId);
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

    final baseData = _assetLoader.getCached(categoryId);
    final levels = baseData?['levels'] as Map<String, dynamic>?;
    final list = levels?[levelNumber.toString()] as List?;
    return list != null && list.isNotEmpty;
  }

  /// Clears cached JSON asset data (only needed explicitly in memory cleanup/tests).
  void clearCache([String? categoryId]) => _assetLoader.clear(categoryId);

  bool isCached(String categoryId) => _assetLoader.isCached(categoryId);

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
