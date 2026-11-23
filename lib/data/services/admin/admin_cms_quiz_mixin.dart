import 'package:flutter/foundation.dart';

import '../../models/cms_models.dart';
import 'admin_service_base.dart';

/// Admin CMS domain mixin for Quiz categories and dynamic question management.
mixin AdminCmsQuizMixin on AdminServiceBase {
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

  @protected
  void resetCmsQuizForTesting() {
    quizContentFetcherOverride = null;
    quizCategoryUpserterOverride = null;
    quizQuestionUpserterOverride = null;
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
}
