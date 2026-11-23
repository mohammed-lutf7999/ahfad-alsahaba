import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cms_models.dart';
import 'admin_service_base.dart';
import 'bulk_question_json_validator.dart';

/// Result of publishing a compressed Gzip CDN question pack from mobile admin.
class AdminGzipPackPublishResult {
  final String categoryId;
  final String storagePath;
  final int packVersion;
  final int questionsCount;
  final int rawBytesLength;
  final int gzipBytesLength;

  const AdminGzipPackPublishResult({
    required this.categoryId,
    required this.storagePath,
    required this.packVersion,
    required this.questionsCount,
    required this.rawBytesLength,
    required this.gzipBytesLength,
  });
}

/// Admin CMS domain mixin for Quiz categories, dynamic questions, bulk JSON
/// import, flexible level config, and Gzip CDN pack publishing.
mixin AdminCmsQuizMixin on AdminServiceBase {
  static const int bulkUpsertChunkSize = 200;
  static const String questionPacksBucket = 'question-packs';

  @visibleForTesting
  Future<({List<DynamicQuizCategoryData> categories, List<DynamicQuizQuestionData> questions})>
      Function({String? categoryId, int? levelNumber, int limit})?
      quizContentFetcherOverride;

  @visibleForTesting
  Future<DynamicQuizCategoryData?> Function(Map<String, dynamic> params)?
      quizCategoryUpserterOverride;

  @visibleForTesting
  Future<DynamicQuizQuestionData?> Function(Map<String, dynamic> params)?
      quizQuestionUpserterOverride;

  @visibleForTesting
  Future<DynamicQuizCategoryData?> Function(Map<String, dynamic> params)?
      quizCategoryConfigUpdaterOverride;

  @visibleForTesting
  Future<int> Function(String categoryId, List<Map<String, dynamic>> chunk)?
      bulkQuizQuestionsUpserterOverride;

  @visibleForTesting
  Future<AdminGzipPackPublishResult?> Function(String categoryId)?
      gzipPackPublisherOverride;

  @protected
  void resetCmsQuizForTesting() {
    quizContentFetcherOverride = null;
    quizCategoryUpserterOverride = null;
    quizQuestionUpserterOverride = null;
    quizCategoryConfigUpdaterOverride = null;
    bulkQuizQuestionsUpserterOverride = null;
    gzipPackPublisherOverride = null;
  }

  Future<
      ({
        List<DynamicQuizCategoryData> categories,
        List<DynamicQuizQuestionData> questions,
      })> listQuizContent({
    String? categoryId,
    int? levelNumber,
    int limit = 100,
  }) async {
    if (quizContentFetcherOverride != null) {
      return quizContentFetcherOverride!(
        categoryId: categoryId,
        levelNumber: levelNumber,
        limit: limit,
      );
    }
    final client = supabaseClient;
    if (client == null) {
      return (
        categories: <DynamicQuizCategoryData>[],
        questions: <DynamicQuizQuestionData>[],
      );
    }
    final res = await client.rpc(
      'admin_list_quiz_content',
      params: {
        'p_category_id': categoryId,
        'p_level_number': levelNumber,
        'p_limit': limit.clamp(1, 250),
      },
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      final catRaw = res['categories'] as List? ?? const [];
      final qRaw = res['questions'] as List? ?? const [];
      return (
        categories: catRaw
            .whereType<Map>()
            .map((e) => DynamicQuizCategoryData.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(),
        questions: qRaw
            .whereType<Map>()
            .map((e) => DynamicQuizQuestionData.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    return (
      categories: <DynamicQuizCategoryData>[],
      questions: <DynamicQuizQuestionData>[],
    );
  }

  Future<DynamicQuizCategoryData?> upsertQuizCategory({
    required String id,
    required String name,
    String description = '',
    String iconName = 'quiz_rounded',
    String colorHex = '#1B5E20',
    int totalLevels = 10,
    int sortOrder = 100,
    bool isVisible = true,
    bool isLocked = false,
  }) async {
    final params = <String, dynamic>{
      'p_id': id.trim().toLowerCase(),
      'p_name': name.trim(),
      'p_description': description.trim(),
      'p_icon_name': iconName,
      'p_color_hex': colorHex.trim(),
      'p_total_levels': totalLevels.clamp(1, 100),
      'p_sort_order': sortOrder,
      'p_is_visible': isVisible,
      'p_is_locked': isLocked,
    };
    if (quizCategoryUpserterOverride != null) {
      return quizCategoryUpserterOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_quiz_category', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final cat =
          DynamicQuizCategoryData.fromJson(Map<String, dynamic>.from(res));
      syncAndBroadcastAll();
      return cat;
    }
    return null;
  }

  Future<DynamicQuizQuestionData?> upsertQuizQuestion({
    String? id,
    required String categoryId,
    required int levelNumber,
    required String questionText,
    required List<String> options,
    required int correctIndex,
    String explanation = '',
    String syncScope = 'solo_only',
    int sortOrder = 100,
    bool isVisible = true,
  }) async {
    if (options.length != 4 || options.any((o) => o.trim().isEmpty)) {
      throw ArgumentError('يجب توفير 4 خيارات غير فارغة للسؤال');
    }
    if (correctIndex < 0 || correctIndex > 3) {
      throw ArgumentError('رقم الإجابة الصحيحة يجب أن يكون بين 0 و 3');
    }
    final params = <String, dynamic>{
      'p_id': (id == null || id.trim().isEmpty) ? null : id.trim(),
      'p_category_id': categoryId.trim().toLowerCase(),
      'p_level_number': levelNumber.clamp(1, 100),
      'p_question_text': questionText.trim(),
      'p_options': options.map((e) => e.trim()).toList(),
      'p_correct_index': correctIndex,
      'p_explanation': explanation.trim(),
      'p_sync_scope': syncScope,
      'p_sort_order': sortOrder,
      'p_is_visible': isVisible,
    };
    if (quizQuestionUpserterOverride != null) {
      return quizQuestionUpserterOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_quiz_question', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final q =
          DynamicQuizQuestionData.fromJson(Map<String, dynamic>.from(res));
      syncAndBroadcastAll();
      return q;
    }
    return null;
  }

  /// Updates flexible level count, questions-per-level, and draw mode
  /// (`fixed` or `rotating_pool`) via migration 023 RPC.
  Future<DynamicQuizCategoryData?> updateQuizCategoryConfig({
    required String categoryId,
    int? totalLevels,
    int? questionsPerLevel,
    String? levelDrawMode,
  }) async {
    final cleanCat = categoryId.trim().toLowerCase();
    if (cleanCat.isEmpty) {
      throw ArgumentError('معرّف القسم مطلوب لتحديث الإعدادات');
    }
    final cleanMode = levelDrawMode?.trim().toLowerCase();
    if (cleanMode != null &&
        cleanMode.isNotEmpty &&
        cleanMode != 'fixed' &&
        cleanMode != 'rotating_pool') {
      throw ArgumentError('نمط السحب يجب أن يكون fixed أو rotating_pool');
    }

    final params = <String, dynamic>{
      'p_category_id': cleanCat,
      'p_total_levels': totalLevels?.clamp(1, 100),
      'p_questions_per_level': questionsPerLevel?.clamp(1, 100),
      'p_level_draw_mode': cleanMode,
    };
    if (quizCategoryConfigUpdaterOverride != null) {
      return quizCategoryConfigUpdaterOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client
        .rpc('admin_update_quiz_category_config', params: params)
        .timeout(const Duration(seconds: 8));
    if (res is Map) {
      final updated =
          DynamicQuizCategoryData.fromJson(Map<String, dynamic>.from(res));
      syncAndBroadcastAll();
      return updated;
    }
    return null;
  }

  /// Atomically upserts [questions] in chunks of 200 via
  /// `admin_bulk_upsert_quiz_questions` without overwriting existing category
  /// draw-mode config (server auto-expands `total_levels` via `GREATEST`).
  Future<int> bulkUpsertQuizQuestions({
    required String categoryId,
    required List<Map<String, dynamic>> questions,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final cleanCat = categoryId.trim().toLowerCase();
    if (cleanCat.isEmpty) {
      throw ArgumentError('معرّف القسم مطلوب للاستيراد الجماعي');
    }
    if (questions.isEmpty) return 0;

    final total = questions.length;
    var uploaded = 0;

    try {
      for (var i = 0; i < total; i += bulkUpsertChunkSize) {
        final end = (i + bulkUpsertChunkSize).clamp(0, total);
        final chunk = questions.sublist(i, end);

        if (bulkQuizQuestionsUpserterOverride != null) {
          uploaded += await bulkQuizQuestionsUpserterOverride!(cleanCat, chunk);
        } else {
          final client = supabaseClient;
          if (client == null) {
            throw StateError('عميل Supabase غير متصل');
          }
          await client.rpc(
            'admin_bulk_upsert_quiz_questions',
            params: {
              'p_category_id': cleanCat,
              'p_questions': chunk,
            },
          ).timeout(const Duration(seconds: 15));
          uploaded += chunk.length;
        }
        onProgress?.call(uploaded, total);
      }
    } finally {
      // Ensure partial batch uploads still sync CMS & notify clients cleanly
      if (uploaded > 0 && bulkQuizQuestionsUpserterOverride == null) {
        syncAndBroadcastAll();
      }
    }
    return uploaded;
  }

  /// Exports all visible cloud questions for [categoryId], compresses them via
  /// native `dart:io` `gzip.encode` inside an Isolate (`compute`), uploads to
  /// `question-packs` as `application/octet-stream` (NO `Content-Encoding: gzip`
  /// to prevent Double-Gzip), and calls `admin_publish_category_pack`.
  Future<AdminGzipPackPublishResult?> exportAndPublishGzipPack({
    required String categoryId,
    void Function(String stage)? onStage,
  }) async {
    final cleanCat = categoryId.trim().toLowerCase();
    if (cleanCat.isEmpty) {
      throw ArgumentError('معرّف القسم مطلوب لنشر حزمة Gzip');
    }
    if (gzipPackPublisherOverride != null) {
      return gzipPackPublisherOverride!(cleanCat);
    }
    final client = supabaseClient;
    if (client == null) return null;

    onStage?.call('جارٍ تصدير أسئلة القسم ($cleanCat) من القاعدة...');
    final rawPayload = await client
        .rpc(
          'admin_export_category_pack_payload',
          params: {'p_category_id': cleanCat},
        )
        .timeout(const Duration(seconds: 15));
    if (rawPayload is! Map) {
      throw StateError('استجابة تصدير غير صالحة من السيرفر.');
    }
    final payload = Map<String, dynamic>.from(rawPayload);
    final qCount = (payload['questionsCount'] as num?)?.toInt() ?? 0;
    if (qCount <= 0) {
      throw StateError(
        'لا توجد أسئلة سحابية مرئية في هذا القسم لتصديرها كحزمة.',
      );
    }

    onStage?.call('جارٍ ضغط $qCount سؤالاً عبر Gzip Isolate...');
    final compressed = await compute(encodeJsonToGzipBytes, payload);
    final expectedPackVer = (payload['packVersion'] as num?)?.toInt() ?? 1;
    final storagePath = '${cleanCat}_v$expectedPackVer.json.gz';

    onStage?.call(
      'جارٍ رفع الحزمة $storagePath (${(compressed.gzBytes.length / 1024).toStringAsFixed(1)} KB)...',
    );
    await client.storage
        .from(questionPacksBucket)
        .uploadBinary(
          storagePath,
          compressed.gzBytes,
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            cacheControl: '31536000',
            upsert: true,
          ),
        )
        .timeout(const Duration(seconds: 30));

    onStage?.call('جارٍ اعتماد رقم الحزمة وبث التحديث للاعبين...');
    final pubRes = await client.rpc(
      'admin_publish_category_pack',
      params: {
        'p_category_id': cleanCat,
        'p_pack_storage_path': storagePath,
        'p_questions_count': qCount,
      },
    ).timeout(const Duration(seconds: 10));

    final actualPackVer = pubRes is Map
        ? ((pubRes['pack_version'] as num?)?.toInt() ?? expectedPackVer)
        : expectedPackVer;

    syncAndBroadcastAll();

    return AdminGzipPackPublishResult(
      categoryId: cleanCat,
      storagePath: storagePath,
      packVersion: actualPackVer,
      questionsCount: qCount,
      rawBytesLength: compressed.rawBytes.length,
      gzipBytesLength: compressed.gzBytes.length,
    );
  }
}
