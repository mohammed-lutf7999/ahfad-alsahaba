import 'dart:convert';
import 'store_item_model.dart';

/// Dynamic Library section record mirrored from `public.library_sections`.
class DynamicLibrarySectionData {
  final String id;
  final String title;
  final String iconName;
  final String colorHex;
  final int sortOrder;
  final bool isVisible;
  final int cmsRevision;

  const DynamicLibrarySectionData({
    required this.id,
    required this.title,
    this.iconName = 'auto_stories_rounded',
    this.colorHex = '#D4AF37',
    this.sortOrder = 100,
    this.isVisible = true,
    this.cmsRevision = 1,
  });

  factory DynamicLibrarySectionData.fromJson(Map<String, dynamic> json) {
    return DynamicLibrarySectionData(
      id: (json['id'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString(),
      iconName: (json['icon_name'] ?? json['iconName'] ?? 'auto_stories_rounded')
          .toString(),
      colorHex: (json['color_hex'] ?? json['colorHex'] ?? '#D4AF37').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ??
          (json['sortOrder'] as num?)?.toInt() ??
          100,
      isVisible: (json['is_visible'] as bool?) ??
          (json['isVisible'] as bool?) ??
          true,
      cmsRevision: (json['cms_revision'] as num?)?.toInt() ??
          (json['cmsRevision'] as num?)?.toInt() ??
          1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon_name': iconName,
        'color_hex': colorHex,
        'sort_order': sortOrder,
        'is_visible': isVisible,
        'cms_revision': cmsRevision,
      };
}

/// Dynamic Library item record mirrored from `public.library_items`.
class DynamicLibraryItemData {
  final String id;
  final String sectionId;
  final String title;
  final String subtitle;
  final String content;
  final String sourceRef;
  final int sortOrder;
  final bool isVisible;
  final int cmsRevision;

  const DynamicLibraryItemData({
    required this.id,
    required this.sectionId,
    required this.title,
    this.subtitle = '',
    required this.content,
    this.sourceRef = '',
    this.sortOrder = 100,
    this.isVisible = true,
    this.cmsRevision = 1,
  });

  factory DynamicLibraryItemData.fromJson(Map<String, dynamic> json) {
    return DynamicLibraryItemData(
      id: (json['id'] ?? '').toString().trim(),
      sectionId: (json['section_id'] ?? json['sectionId'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      sourceRef: (json['source_ref'] ?? json['sourceRef'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ??
          (json['sortOrder'] as num?)?.toInt() ??
          100,
      isVisible: (json['is_visible'] as bool?) ??
          (json['isVisible'] as bool?) ??
          true,
      cmsRevision: (json['cms_revision'] as num?)?.toInt() ??
          (json['cmsRevision'] as num?)?.toInt() ??
          1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'section_id': sectionId,
        'title': title,
        'subtitle': subtitle,
        'content': content,
        'source_ref': sourceRef,
        'sort_order': sortOrder,
        'is_visible': isVisible,
        'cms_revision': cmsRevision,
      };
}

/// Availability status for a Quiz category or individual level (`024`).
enum CategoryAvailabilityStatus {
  open,
  comingSoon,
  hidden;

  String get wireValue {
    switch (this) {
      case CategoryAvailabilityStatus.open:
        return 'open';
      case CategoryAvailabilityStatus.comingSoon:
        return 'coming_soon';
      case CategoryAvailabilityStatus.hidden:
        return 'hidden';
    }
  }

  static CategoryAvailabilityStatus fromWire(Object? raw) {
    final normalized = (raw ?? '').toString().trim().toLowerCase();
    switch (normalized) {
      case 'coming_soon':
      case 'comingsoon':
        return CategoryAvailabilityStatus.comingSoon;
      case 'hidden':
        return CategoryAvailabilityStatus.hidden;
      default:
        return CategoryAvailabilityStatus.open;
    }
  }
}

/// Per-level override (`coming_soon` / `hidden` + optional teasing message).
class LevelOverrideConfig {
  final CategoryAvailabilityStatus status;
  final String message;

  const LevelOverrideConfig({
    this.status = CategoryAvailabilityStatus.open,
    this.message = '',
  });

  bool get isComingSoon => status == CategoryAvailabilityStatus.comingSoon;
  bool get isHidden => status == CategoryAvailabilityStatus.hidden;

  factory LevelOverrideConfig.fromJson(Map<String, dynamic> json) {
    return LevelOverrideConfig(
      status: CategoryAvailabilityStatus.fromWire(json['status']),
      message: (json['message'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.wireValue,
        if (message.isNotEmpty) 'message': message,
      };
}

/// Dynamic Quiz category record mirrored from `public.quiz_categories`.
class DynamicQuizCategoryData {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final String colorHex;
  final int totalLevels;
  final int questionsPerLevel;
  final String levelDrawMode;
  final int packVersion;
  final String packStoragePath;
  final int sortOrder;
  final bool isVisible;
  final bool isLocked;
  final String availabilityStatus;
  final String comingSoonMessage;
  final Map<int, LevelOverrideConfig> levelOverrides;
  final List<String> hiddenQuestionIds;
  final List<String> hiddenLocalQuestionIds;
  final bool packNeedsRepublish;
  final int cmsRevision;

  const DynamicQuizCategoryData({
    required this.id,
    required this.name,
    this.description = '',
    this.iconName = 'quiz_rounded',
    this.colorHex = '#1B5E20',
    this.totalLevels = 10,
    this.questionsPerLevel = 10,
    this.levelDrawMode = 'fixed',
    this.packVersion = 0,
    this.packStoragePath = '',
    this.sortOrder = 100,
    this.isVisible = true,
    this.isLocked = false,
    this.availabilityStatus = 'open',
    this.comingSoonMessage = '',
    this.levelOverrides = const {},
    this.hiddenQuestionIds = const [],
    this.hiddenLocalQuestionIds = const [],
    this.packNeedsRepublish = false,
    this.cmsRevision = 1,
  });

  CategoryAvailabilityStatus get availability =>
      CategoryAvailabilityStatus.fromWire(availabilityStatus);

  bool get isComingSoon => availability == CategoryAvailabilityStatus.comingSoon;

  bool get isHiddenByAvailability =>
      !isVisible || availability == CategoryAvailabilityStatus.hidden;

  LevelOverrideConfig? overrideForLevel(int levelNumber) =>
      levelOverrides[levelNumber];

  /// Highest level number referenced by any non-open override (e.g. future `coming_soon`).
  int get maxOverrideLevel {
    var maxLv = 0;
    for (final lv in levelOverrides.keys) {
      if (lv > maxLv) maxLv = lv;
    }
    return maxLv;
  }

  /// Highest `coming_soon` level number configured in [levelOverrides].
  int get maxComingSoonOverrideLevel {
    var maxLv = 0;
    for (final entry in levelOverrides.entries) {
      if (entry.value.isComingSoon && entry.key > maxLv) {
        maxLv = entry.key;
      }
    }
    return maxLv;
  }

  static Map<int, LevelOverrideConfig> _parseLevelOverrides(dynamic raw) {
    if (raw is! Map) return const {};
    final parsed = <int, LevelOverrideConfig>{};
    for (final entry in raw.entries) {
      final lv = int.tryParse(entry.key.toString().trim());
      if (lv == null || lv < 1 || lv > 100) continue;
      if (entry.value is Map) {
        final cfg = LevelOverrideConfig.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (cfg.status != CategoryAvailabilityStatus.open ||
            cfg.message.isNotEmpty) {
          parsed[lv] = cfg;
        }
      }
    }
    return parsed;
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final s = item.toString().trim();
      if (s.isNotEmpty && seen.add(s)) {
        out.add(s);
      }
    }
    return out;
  }

  factory DynamicQuizCategoryData.fromJson(Map<String, dynamic> json) {
    final rawMode =
        (json['level_draw_mode'] ?? json['levelDrawMode'] ?? 'fixed')
            .toString()
            .trim();
    final safeMode =
        rawMode == 'rotating_pool' ? 'rotating_pool' : 'fixed';
    final isVisibleVal = (json['is_visible'] as bool?) ??
        (json['isVisible'] as bool?) ??
        true;
    final rawStatus =
        json['availability_status'] ?? json['availabilityStatus'];
    final resolvedStatus = rawStatus != null
        ? CategoryAvailabilityStatus.fromWire(rawStatus).wireValue
        : (isVisibleVal ? 'open' : 'hidden');

    return DynamicQuizCategoryData(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      iconName: (json['icon_name'] ?? json['iconName'] ?? 'quiz_rounded')
          .toString(),
      colorHex: (json['color_hex'] ?? json['colorHex'] ?? '#1B5E20').toString(),
      totalLevels: ((json['total_levels'] as num?)?.toInt() ??
              (json['totalLevels'] as num?)?.toInt() ??
              10)
          .clamp(1, 100),
      questionsPerLevel: ((json['questions_per_level'] as num?)?.toInt() ??
              (json['questionsPerLevel'] as num?)?.toInt() ??
              10)
          .clamp(1, 100),
      levelDrawMode: safeMode,
      packVersion: ((json['pack_version'] as num?)?.toInt() ??
              (json['packVersion'] as num?)?.toInt() ??
              0)
          .clamp(0, 1000000000),
      packStoragePath:
          (json['pack_storage_path'] ?? json['packStoragePath'] ?? '')
              .toString()
              .trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ??
          (json['sortOrder'] as num?)?.toInt() ??
          100,
      isVisible: isVisibleVal,
      isLocked: (json['is_locked'] as bool?) ??
          (json['isLocked'] as bool?) ??
          false,
      availabilityStatus: resolvedStatus,
      comingSoonMessage: (json['coming_soon_message'] ??
              json['comingSoonMessage'] ??
              '')
          .toString()
          .trim(),
      levelOverrides: _parseLevelOverrides(
        json['level_overrides'] ?? json['levelOverrides'],
      ),
      hiddenQuestionIds: _parseStringList(
        json['hidden_question_ids'] ?? json['hiddenQuestionIds'],
      ),
      hiddenLocalQuestionIds: _parseStringList(
        json['hidden_local_question_ids'] ?? json['hiddenLocalQuestionIds'],
      ),
      packNeedsRepublish: (json['pack_needs_republish'] as bool?) ??
          (json['packNeedsRepublish'] as bool?) ??
          false,
      cmsRevision: (json['cms_revision'] as num?)?.toInt() ??
          (json['cmsRevision'] as num?)?.toInt() ??
          1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon_name': iconName,
        'color_hex': colorHex,
        'total_levels': totalLevels,
        'questions_per_level': questionsPerLevel,
        'level_draw_mode': levelDrawMode,
        'pack_version': packVersion,
        'pack_storage_path': packStoragePath,
        'sort_order': sortOrder,
        'is_visible': isVisible,
        'is_locked': isLocked,
        'availability_status': availabilityStatus,
        'coming_soon_message': comingSoonMessage,
        'level_overrides': {
          for (final e in levelOverrides.entries) '${e.key}': e.value.toJson(),
        },
        'hidden_question_ids': hiddenQuestionIds,
        'hidden_local_question_ids': hiddenLocalQuestionIds,
        'pack_needs_republish': packNeedsRepublish,
        'cms_revision': cmsRevision,
      };
}

/// Dynamic Quiz question record mirrored from `public.quiz_questions`.
class DynamicQuizQuestionData {
  final String id;
  final String categoryId;
  final int levelNumber;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String syncScope;
  final int sortOrder;
  final bool isVisible;
  final int cmsRevision;

  const DynamicQuizQuestionData({
    required this.id,
    required this.categoryId,
    required this.levelNumber,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.syncScope = 'solo_only',
    this.sortOrder = 100,
    this.isVisible = true,
    this.cmsRevision = 1,
  });

  factory DynamicQuizQuestionData.fromJson(Map<String, dynamic> json) {
    dynamic rawOpts = json['options'];
    if (rawOpts is String) {
      try {
        rawOpts = jsonDecode(rawOpts);
      } catch (_) {
        rawOpts = const <String>[];
      }
    }
    final opts = rawOpts is List
        ? rawOpts.map((e) => e.toString()).toList()
        : const <String>[];
    return DynamicQuizQuestionData(
      id: (json['id'] ?? '').toString().trim(),
      categoryId:
          (json['category_id'] ?? json['categoryId'] ?? '').toString().trim(),
      levelNumber: ((json['level_number'] as num?)?.toInt() ??
              (json['levelNumber'] as num?)?.toInt() ??
              1)
          .clamp(1, 100),
      questionText:
          (json['question_text'] ?? json['questionText'] ?? '').toString(),
      options: opts,
      correctIndex: ((json['correct_index'] as num?)?.toInt() ??
              (json['correctIndex'] as num?)?.toInt() ??
              0)
          .clamp(0, opts.isEmpty ? 0 : opts.length - 1),
      explanation: (json['explanation'] ?? '').toString(),
      syncScope:
          (json['sync_scope'] ?? json['syncScope'] ?? 'solo_only').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ??
          (json['sortOrder'] as num?)?.toInt() ??
          100,
      isVisible: (json['is_visible'] as bool?) ??
          (json['isVisible'] as bool?) ??
          true,
      cmsRevision: (json['cms_revision'] as num?)?.toInt() ??
          (json['cmsRevision'] as num?)?.toInt() ??
          1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'level_number': levelNumber,
        'question_text': questionText,
        'options': options,
        'correct_index': correctIndex,
        'explanation': explanation,
        'sync_scope': syncScope,
        'sort_order': sortOrder,
        'is_visible': isVisible,
        'cms_revision': cmsRevision,
      };
}

/// Paginated response from `admin_browse_quiz_questions` (`024b`).
class AdminQuestionBrowserPage {
  final int totalCount;
  final int page;
  final int pageSize;
  final bool packNeedsRepublish;
  final List<String> hiddenLocalQuestionIds;
  final List<DynamicQuizQuestionData> questions;

  const AdminQuestionBrowserPage({
    this.totalCount = 0,
    this.page = 1,
    this.pageSize = 25,
    this.packNeedsRepublish = false,
    this.hiddenLocalQuestionIds = const [],
    this.questions = const [],
  });

  int get totalPages => totalCount <= 0
      ? 1
      : ((totalCount + pageSize - 1) ~/ (pageSize <= 0 ? 25 : pageSize));

  factory AdminQuestionBrowserPage.fromJson(Map<String, dynamic> json) {
    final rawQs = json['questions'];
    final qs = <DynamicQuizQuestionData>[];
    if (rawQs is List) {
      for (final item in rawQs) {
        if (item is Map) {
          qs.add(
            DynamicQuizQuestionData.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    final rawHiddenLocal =
        json['hidden_local_question_ids'] ?? json['hiddenLocalQuestionIds'];
    final hiddenLocal = <String>[];
    if (rawHiddenLocal is List) {
      for (final item in rawHiddenLocal) {
        final s = item.toString().trim();
        if (s.isNotEmpty) hiddenLocal.add(s);
      }
    }
    return AdminQuestionBrowserPage(
      totalCount: (json['total_count'] as num?)?.toInt() ??
          (json['totalCount'] as num?)?.toInt() ??
          qs.length,
      page: ((json['page'] as num?)?.toInt() ?? 1).clamp(1, 100000),
      pageSize: ((json['page_size'] as num?)?.toInt() ??
              (json['pageSize'] as num?)?.toInt() ??
              25)
          .clamp(1, 100),
      packNeedsRepublish: (json['pack_needs_republish'] as bool?) ??
          (json['packNeedsRepublish'] as bool?) ??
          false,
      hiddenLocalQuestionIds: hiddenLocal,
      questions: qs,
    );
  }
}

/// Persisted snapshot of all CMS overrides & additions returned by `get_cms_bundle_v2`.
class CmsCacheSnapshot {
  /// Schema version stored in SharedPreferences cache:
  /// - `1` (or absent): legacy 1.1.0+21 cache before Plan 20 pack metadata.
  /// - `2`: 1.2.0+22 cache with `questions_per_level`, `level_draw_mode`,
  ///        `pack_version`, `pack_storage_path`, and pack-pruned `quizQuestions`.
  /// - `3`: 024 cache with `availability_status`, `coming_soon_message`,
  ///        `level_overrides`, `hidden_question_ids`, and `pack_needs_republish`.
  static const int currentCacheSchemaVersion = 3;

  final int cmsVersion;
  final int cacheSchemaVersion;
  final Map<String, StoreItemModel> storeItems;
  final Map<String, DynamicLibrarySectionData> librarySections;
  final Map<String, DynamicLibraryItemData> libraryItems;
  final Map<String, DynamicQuizCategoryData> quizCategories;
  final Map<String, DynamicQuizQuestionData> quizQuestions;
  final DateTime? syncedAt;

  const CmsCacheSnapshot({
    this.cmsVersion = 0,
    this.cacheSchemaVersion = currentCacheSchemaVersion,
    this.storeItems = const {},
    this.librarySections = const {},
    this.libraryItems = const {},
    this.quizCategories = const {},
    this.quizQuestions = const {},
    this.syncedAt,
  });

  factory CmsCacheSnapshot.empty() => const CmsCacheSnapshot();

  factory CmsCacheSnapshot.fromJson(Map<String, dynamic> json) {
    final storeMap = <String, StoreItemModel>{};
    final rawStore = json['store_items'];
    if (rawStore is List) {
      for (final item in rawStore) {
        if (item is Map) {
          final parsed = StoreItemModel.fromCloudJson(
            Map<String, dynamic>.from(item),
          );
          if (parsed.id.isNotEmpty) storeMap[parsed.id] = parsed;
        }
      }
    }

    final secMap = <String, DynamicLibrarySectionData>{};
    final rawSecs = json['library_sections'];
    if (rawSecs is List) {
      for (final item in rawSecs) {
        if (item is Map) {
          final parsed = DynamicLibrarySectionData.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (parsed.id.isNotEmpty) secMap[parsed.id] = parsed;
        }
      }
    }

    final libItemMap = <String, DynamicLibraryItemData>{};
    final rawLibItems = json['library_items'];
    if (rawLibItems is List) {
      for (final item in rawLibItems) {
        if (item is Map) {
          final parsed = DynamicLibraryItemData.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (parsed.id.isNotEmpty) libItemMap[parsed.id] = parsed;
        }
      }
    }

    final catMap = <String, DynamicQuizCategoryData>{};
    final rawCats = json['quiz_categories'];
    if (rawCats is List) {
      for (final item in rawCats) {
        if (item is Map) {
          final parsed = DynamicQuizCategoryData.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (parsed.id.isNotEmpty) catMap[parsed.id] = parsed;
        }
      }
    }

    final qMap = <String, DynamicQuizQuestionData>{};
    final rawQs = json['quiz_questions'];
    if (rawQs is List) {
      for (final item in rawQs) {
        if (item is Map) {
          final parsed = DynamicQuizQuestionData.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (parsed.id.isNotEmpty && parsed.options.length == 4) {
            qMap[parsed.id] = parsed;
          }
        }
      }
    }

    return CmsCacheSnapshot(
      cmsVersion: (json['cms_version'] as num?)?.toInt() ?? 0,
      cacheSchemaVersion: (json['cache_schema_version'] as num?)?.toInt() ?? 1,
      storeItems: storeMap,
      librarySections: secMap,
      libraryItems: libItemMap,
      quizCategories: catMap,
      quizQuestions: qMap,
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'cms_version': cmsVersion,
        'cache_schema_version': cacheSchemaVersion,
        'store_items': storeItems.values.map((e) => e.toCloudJson()).toList(),
        'library_sections':
            librarySections.values.map((e) => e.toJson()).toList(),
        'library_items': libraryItems.values.map((e) => e.toJson()).toList(),
        'quiz_categories':
            quizCategories.values.map((e) => e.toJson()).toList(),
        'quiz_questions': quizQuestions.values.map((e) => e.toJson()).toList(),
        if (syncedAt != null) 'synced_at': syncedAt!.toUtc().toIso8601String(),
      };

  static Map<String, DynamicQuizQuestionData> _prunePackedCategoryQuestions(
    Map<String, DynamicQuizQuestionData> questions,
    Map<String, DynamicQuizCategoryData> categories,
  ) {
    final packedCatIds = <String>{
      for (final entry in categories.entries)
        if (entry.value.packVersion > 0) entry.key,
    };
    if (packedCatIds.isEmpty) return questions;
    return Map<String, DynamicQuizQuestionData>.from(questions)
      ..removeWhere((_, q) => packedCatIds.contains(q.categoryId));
  }

  /// Merges either a full snapshot (`incremental == false`) or delta rows (`incremental == true`),
  /// upgrading `cacheSchemaVersion` to [currentCacheSchemaVersion] and pruning raw
  /// `quizQuestions` for categories that now have a published Gzip CDN pack (`packVersion > 0`).
  CmsCacheSnapshot mergeBundle(Map<String, dynamic> rpcResult, DateTime nowUtc) {
    final nextVersion = (rpcResult['cms_version'] as num?)?.toInt() ?? cmsVersion;
    final incremental = rpcResult['incremental'] as bool? ?? false;
    final incoming = CmsCacheSnapshot.fromJson(rpcResult);

    if (!incremental) {
      // Full refresh: replace entity maps cleanly while preserving any previously
      // cached store item definition if it still exists in `storeItems` and was
      // hidden from non-auth callers.
      final mergedStore = Map<String, StoreItemModel>.from(storeItems)
        ..addAll(incoming.storeItems);
      final prunedQuestions = _prunePackedCategoryQuestions(
        incoming.quizQuestions,
        incoming.quizCategories,
      );
      return CmsCacheSnapshot(
        cmsVersion: nextVersion,
        cacheSchemaVersion: currentCacheSchemaVersion,
        storeItems: mergedStore,
        librarySections: incoming.librarySections,
        libraryItems: incoming.libraryItems,
        quizCategories: incoming.quizCategories,
        quizQuestions: prunedQuestions,
        syncedAt: nowUtc,
      );
    }

    final mergedCats =
        Map<String, DynamicQuizCategoryData>.from(quizCategories)
          ..addAll(incoming.quizCategories);
    // For non-Gzip categories (`packVersion == 0`) that changed in this delta,
    // `get_cms_bundle_v2` (024c) sends all currently visible questions for that
    // category — purge stale cached rows first so hard-deleted questions never linger.
    final changedUnpackedCatIds = <String>{
      for (final entry in incoming.quizCategories.entries)
        if (entry.value.packVersion == 0) entry.key,
    };
    final mergedQuestions =
        Map<String, DynamicQuizQuestionData>.from(quizQuestions);
    if (changedUnpackedCatIds.isNotEmpty) {
      mergedQuestions
          .removeWhere((_, q) => changedUnpackedCatIds.contains(q.categoryId));
    }
    mergedQuestions.addAll(incoming.quizQuestions);
    final prunedQuestions = _prunePackedCategoryQuestions(
      mergedQuestions,
      mergedCats,
    );

    return CmsCacheSnapshot(
      cmsVersion: nextVersion,
      cacheSchemaVersion: currentCacheSchemaVersion,
      storeItems: Map<String, StoreItemModel>.from(storeItems)
        ..addAll(incoming.storeItems),
      librarySections:
          Map<String, DynamicLibrarySectionData>.from(librarySections)
            ..addAll(incoming.librarySections),
      libraryItems: Map<String, DynamicLibraryItemData>.from(libraryItems)
        ..addAll(incoming.libraryItems),
      quizCategories: mergedCats,
      quizQuestions: prunedQuestions,
      syncedAt: nowUtc,
    );
  }
}
