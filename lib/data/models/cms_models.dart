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
    this.cmsRevision = 1,
  });

  factory DynamicQuizCategoryData.fromJson(Map<String, dynamic> json) {
    final rawMode =
        (json['level_draw_mode'] ?? json['levelDrawMode'] ?? 'fixed')
            .toString()
            .trim();
    final safeMode =
        rawMode == 'rotating_pool' ? 'rotating_pool' : 'fixed';
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
      isVisible: (json['is_visible'] as bool?) ??
          (json['isVisible'] as bool?) ??
          true,
      isLocked: (json['is_locked'] as bool?) ??
          (json['isLocked'] as bool?) ??
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

/// Persisted snapshot of all CMS overrides & additions returned by `get_cms_bundle`.
class CmsCacheSnapshot {
  final int cmsVersion;
  final Map<String, StoreItemModel> storeItems;
  final Map<String, DynamicLibrarySectionData> librarySections;
  final Map<String, DynamicLibraryItemData> libraryItems;
  final Map<String, DynamicQuizCategoryData> quizCategories;
  final Map<String, DynamicQuizQuestionData> quizQuestions;
  final DateTime? syncedAt;

  const CmsCacheSnapshot({
    this.cmsVersion = 0,
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
        'store_items': storeItems.values.map((e) => e.toCloudJson()).toList(),
        'library_sections':
            librarySections.values.map((e) => e.toJson()).toList(),
        'library_items': libraryItems.values.map((e) => e.toJson()).toList(),
        'quiz_categories':
            quizCategories.values.map((e) => e.toJson()).toList(),
        'quiz_questions': quizQuestions.values.map((e) => e.toJson()).toList(),
        if (syncedAt != null) 'synced_at': syncedAt!.toUtc().toIso8601String(),
      };

  /// Merges either a full snapshot (`incremental == false`) or delta rows (`incremental == true`).
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
      return CmsCacheSnapshot(
        cmsVersion: nextVersion,
        storeItems: mergedStore,
        librarySections: incoming.librarySections,
        libraryItems: incoming.libraryItems,
        quizCategories: incoming.quizCategories,
        quizQuestions: incoming.quizQuestions,
        syncedAt: nowUtc,
      );
    }

    return CmsCacheSnapshot(
      cmsVersion: nextVersion,
      storeItems: Map<String, StoreItemModel>.from(storeItems)
        ..addAll(incoming.storeItems),
      librarySections:
          Map<String, DynamicLibrarySectionData>.from(librarySections)
            ..addAll(incoming.librarySections),
      libraryItems: Map<String, DynamicLibraryItemData>.from(libraryItems)
        ..addAll(incoming.libraryItems),
      quizCategories:
          Map<String, DynamicQuizCategoryData>.from(quizCategories)
            ..addAll(incoming.quizCategories),
      quizQuestions: Map<String, DynamicQuizQuestionData>.from(quizQuestions)
        ..addAll(incoming.quizQuestions),
      syncedAt: nowUtc,
    );
  }
}
