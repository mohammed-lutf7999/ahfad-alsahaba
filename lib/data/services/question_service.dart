import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/cms_icon_registry.dart';
import '../models/cms_models.dart';
import '../models/question_model.dart';
import 'cms_cache_service.dart';
import 'question/question_asset_loader.dart';
import 'question/question_cms_merger.dart';
import 'question/question_pack_cache_service.dart';
import 'question/rotating_pool_selector.dart';

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

  /// Resolves the primary solo question dataset for [categoryId]:
  /// 1. Loads bundled `assets/questions/<categoryId>.json` if it exists.
  /// 2. If a published Gzip CDN pack exists (`packVersion > 0 && packStoragePath`),
  ///    hydrates it via [QuestionPackCacheService] (with offline disk fallback)
  ///    and MERGES it over the bundled asset levels so built-in levels 1..10
  ///    remain intact when levels 11..20+ are added via a Gzip pack.
  Future<Map<String, dynamic>?> _resolveCategorySourceData(
    String categoryId, {
    bool allowPack = true,
  }) async {
    await _ensureBaseCategoryLoaded(categoryId);
    final assetData = _assetLoader.getCached(categoryId);

    if (!allowPack) {
      return assetData;
    }

    final dynCat = CmsCacheService.instance.snapshot.quizCategories[categoryId];
    if (dynCat == null ||
        dynCat.packVersion <= 0 ||
        dynCat.packStoragePath.isEmpty) {
      return assetData;
    }

    final pack =
        await QuestionPackCacheService.instance.ensurePackLoaded(dynCat);
    if (pack == null || pack['levels'] is! Map) {
      return assetData;
    }

    if (assetData == null || assetData['levels'] is! Map) {
      return pack;
    }

    return _mergePackOverAsset(assetData, pack);
  }

  Map<String, dynamic> _mergePackOverAsset(
    Map<String, dynamic> assetData,
    Map<String, dynamic> packData,
  ) {
    final mergedLevels = <String, dynamic>{};
    final assetLevels = assetData['levels'] as Map<String, dynamic>;
    for (final entry in assetLevels.entries) {
      if (entry.value is List) {
        mergedLevels[entry.key] = List<dynamic>.from(entry.value as List);
      }
    }

    final packLevels = packData['levels'] as Map<String, dynamic>;
    for (final entry in packLevels.entries) {
      final rawPackList = entry.value;
      if (rawPackList is! List) continue;
      final existing = mergedLevels[entry.key];
      if (existing is! List) {
        mergedLevels[entry.key] = List<dynamic>.from(rawPackList);
        continue;
      }

      // Merge by question id: pack overrides matching id, appends new questions
      final combined = List<dynamic>.from(existing);
      final indexById = <String, int>{};
      for (var i = 0; i < combined.length; i++) {
        final item = combined[i];
        if (item is Map) {
          final id = (item['id'] ?? '').toString().trim();
          if (id.isNotEmpty) indexById[id] = i;
        }
      }
      for (final rawItem in rawPackList) {
        if (rawItem is! Map) continue;
        final id = (rawItem['id'] ?? '').toString().trim();
        final existingIdx = id.isNotEmpty ? indexById[id] : null;
        if (existingIdx != null) {
          combined[existingIdx] = rawItem;
        } else {
          if (id.isNotEmpty) indexById[id] = combined.length;
          combined.add(rawItem);
        }
      }
      mergedLevels[entry.key] = combined;
    }

    return <String, dynamic>{
      ...assetData,
      ...packData,
      'levels': mergedLevels,
    };
  }

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
  /// Gzip CDN pack (or local asset JSON) with dynamic overrides & additions
  /// from [CmsCacheService], applying `questions_per_level` and `rotating_pool`
  /// rules when configured.
  Future<List<Question>> loadQuestions({
    required String categoryId,
    required int levelNumber,
  }) async {
    final baseData = await _resolveCategorySourceData(categoryId);
    final levels = baseData?['levels'] as Map<String, dynamic>?;
    final levelKey = levelNumber.toString();
    final rawBaseList = levels?[levelKey] as List?;

    // Track cloud overrides/additions & hidden question IDs for this category
    final cmsSnapshot = CmsCacheService.instance.snapshot;
    final hiddenIds = QuestionCmsMerger.collectHiddenQuestionIds(
      categoryId,
      snapshot: cmsSnapshot,
      packData: baseData,
    );
    final cloudQuestions = cmsSnapshot.quizQuestions.values
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
        final rawId = (rawMap['id'] ?? '').toString().trim();
        final override = rawId.isNotEmpty ? cloudById[rawId] : null;
        if (override != null) {
          seenIds.add(rawId);
          if (override.isVisible &&
              !hiddenIds.contains(rawId) &&
              override.levelNumber == levelNumber) {
            merged.add((
              sortOrder: override.sortOrder,
              question: _mapDynamicQuestion(override, optionRandom: _random),
            ));
          }
          continue;
        }
        if (rawId.isNotEmpty) {
          seenIds.add(rawId);
          if (hiddenIds.contains(rawId)) continue;
        }
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
      if (hiddenIds.contains(q.id)) continue;
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

    final qPerLevel = CmsCategoryBounds.questionsPerLevelFor(categoryId);
    final drawMode = CmsCategoryBounds.drawModeFor(categoryId);

    if (drawMode == 'rotating_pool' && questions.length > qPerLevel) {
      return RotatingPoolSelector.selectAndPersist(
        categoryId: categoryId,
        levelNumber: levelNumber,
        pool: questions,
        questionsPerLevel: qPerLevel,
        random: _random,
      );
    }

    questions.shuffle(_random);
    final hasDynamicCategory =
        CmsCacheService.instance.snapshot.quizCategories.containsKey(categoryId);
    if (hasDynamicCategory && questions.length > qPerLevel) {
      return questions.take(qPerLevel).toList();
    }
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
    final baseData = await _resolveCategorySourceData(
      categoryId,
      allowPack: includeCloudSoloQuestions,
    );
    final levels = baseData?['levels'] as Map<String, dynamic>?;
    final effectiveOptionRng = shuffleOptions ? (optionRandom ?? _random) : null;

    final hiddenIds = includeCloudSoloQuestions
        ? QuestionCmsMerger.collectHiddenQuestionIds(
            categoryId,
            snapshot: CmsCacheService.instance.snapshot,
            packData: baseData,
          )
        : const <String>{};
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
          final rawId = (rawMap['id'] ?? '').toString().trim();
          final override = rawId.isNotEmpty ? cloudById[rawId] : null;
          if (override != null) {
            seenIds.add(rawId);
            if (override.isVisible && !hiddenIds.contains(rawId)) {
              allQuestions.add(
                _mapDynamicQuestion(override, optionRandom: effectiveOptionRng),
              );
            }
            continue;
          }
          if (rawId.isNotEmpty) {
            seenIds.add(rawId);
            if (hiddenIds.contains(rawId)) continue;
          }
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
      if (hiddenIds.contains(q.id)) continue;
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

  /// Check if a specific level has visible (non-hidden) questions in [categoryId].
  Future<bool> levelExists(String categoryId, int levelNumber) async {
    final cmsSnapshot = CmsCacheService.instance.snapshot;
    final baseData = await _resolveCategorySourceData(categoryId);
    final hiddenIds = QuestionCmsMerger.collectHiddenQuestionIds(
      categoryId,
      snapshot: cmsSnapshot,
      packData: baseData,
    );

    final hasCloudForLevel = cmsSnapshot.quizQuestions.values.any((q) =>
        q.categoryId == categoryId &&
        q.levelNumber == levelNumber &&
        q.isVisible &&
        !hiddenIds.contains(q.id) &&
        q.options.length == 4);
    if (hasCloudForLevel) return true;

    final levels = baseData?['levels'] as Map<String, dynamic>?;
    final list = levels?[levelNumber.toString()] as List?;
    if (list == null || list.isEmpty) return false;
    for (final item in list) {
      if (item is Map) {
        final id = (item['id'] ?? '').toString().trim();
        if (id.isEmpty || !hiddenIds.contains(id)) return true;
      }
    }
    return false;
  }

  /// Clears cached JSON asset & Gzip pack memory data.
  void clearCache([String? categoryId]) {
    _assetLoader.clear(categoryId);
    QuestionPackCacheService.instance.clearMemoryCache(categoryId);
  }

  bool isCached(String categoryId) =>
      _assetLoader.isCached(categoryId) ||
      QuestionPackCacheService.instance.getCachedPackInMemory(categoryId) !=
          null;

  Future<void> preloadCategory(String categoryId) async {
    await _resolveCategorySourceData(categoryId);
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
