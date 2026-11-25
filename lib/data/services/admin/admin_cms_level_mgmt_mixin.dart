import 'package:flutter/foundation.dart';

import '../../models/cms_models.dart';
import 'admin_service_base.dart';

/// Admin CMS domain mixin for Migration 024b RPCs:
/// - Paginated cloud question browser (`admin_browse_quiz_questions`)
/// - Single question hard delete (`admin_delete_quiz_question`)
/// - Scoped bulk question management (`admin_bulk_manage_questions`)
/// - Category availability & `coming_soon` (`admin_upsert_category_availability`)
/// - Level range overrides (`admin_bulk_set_level_overrides`)
/// - Bundled local question ID hide/unhide (`admin_toggle_hidden_local_question`)
mixin AdminCmsLevelMgmtMixin on AdminServiceBase {
  @visibleForTesting
  Future<AdminQuestionBrowserPage> Function(Map<String, dynamic> params)?
      questionBrowserFetcherOverride;

  @visibleForTesting
  Future<bool> Function(String questionId)? questionDeleterOverride;

  @visibleForTesting
  Future<int> Function(Map<String, dynamic> params)?
      bulkManageQuestionsOverride;

  @visibleForTesting
  Future<DynamicQuizCategoryData?> Function(Map<String, dynamic> params)?
      categoryAvailabilityUpdaterOverride;

  @visibleForTesting
  Future<DynamicQuizCategoryData?> Function(Map<String, dynamic> params)?
      levelOverridesUpdaterOverride;

  @visibleForTesting
  Future<List<String>> Function(Map<String, dynamic> params)?
      hiddenLocalQuestionTogglerOverride;

  @protected
  void resetCmsLevelMgmtForTesting() {
    questionBrowserFetcherOverride = null;
    questionDeleterOverride = null;
    bulkManageQuestionsOverride = null;
    categoryAvailabilityUpdaterOverride = null;
    levelOverridesUpdaterOverride = null;
    hiddenLocalQuestionTogglerOverride = null;
  }

  Future<AdminQuestionBrowserPage> browseQuizQuestions({
    String? categoryId,
    int? levelNumber,
    String visibility = 'all',
    String? search,
    int page = 1,
    int pageSize = 25,
  }) async {
    final cleanCat = categoryId?.trim().toLowerCase();
    final cleanSearch = search?.trim();
    final params = <String, dynamic>{
      'p_category_id': (cleanCat == null || cleanCat.isEmpty) ? null : cleanCat,
      'p_level_number': levelNumber,
      'p_visibility': visibility,
      'p_search':
          (cleanSearch == null || cleanSearch.isEmpty) ? null : cleanSearch,
      'p_page': page.clamp(1, 100000),
      'p_page_size': pageSize.clamp(1, 100),
    };
    if (questionBrowserFetcherOverride != null) {
      return questionBrowserFetcherOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return const AdminQuestionBrowserPage();
    final res = await client
        .rpc('admin_browse_quiz_questions', params: params)
        .timeout(const Duration(seconds: 10));
    if (res is Map) {
      return AdminQuestionBrowserPage.fromJson(Map<String, dynamic>.from(res));
    }
    return const AdminQuestionBrowserPage();
  }

  Future<bool> deleteQuizQuestion(String questionId) async {
    final cleanId = questionId.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError('معرّف السؤال مطلوب للحذف');
    }
    if (questionDeleterOverride != null) {
      return questionDeleterOverride!(cleanId);
    }
    final client = supabaseClient;
    if (client == null) return false;
    final res = await client.rpc(
      'admin_delete_quiz_question',
      params: {'p_question_id': cleanId},
    ).timeout(const Duration(seconds: 8));
    final deleted = res is Map ? (res['deleted'] as bool? ?? true) : true;
    if (deleted) {
      syncAndBroadcastAll();
    }
    return deleted;
  }

  Future<int> bulkManageQuestions({
    required String categoryId,
    required String action,
    List<String>? questionIds,
    int? fromLevel,
    int? toLevel,
    int? targetLevel,
  }) async {
    final cleanCat = categoryId.trim().toLowerCase();
    if (cleanCat.isEmpty) {
      throw ArgumentError('معرّف القسم مطلوب للإجراء الجماعي');
    }
    final cleanIds = questionIds
            ?.map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final hasValidRange =
        fromLevel != null && toLevel != null && fromLevel >= 1 && toLevel >= fromLevel;
    if (cleanIds.isEmpty && !hasValidRange) {
      throw ArgumentError(
        'يجب تحديد سؤال واحد على الأقل أو نطاق مستويات صالح (من <= إلى)',
      );
    }
    final params = <String, dynamic>{
      'p_category_id': cleanCat,
      'p_action': action.trim().toLowerCase(),
      'p_question_ids': cleanIds.isNotEmpty ? cleanIds : null,
      'p_from_level': cleanIds.isEmpty ? fromLevel : null,
      'p_to_level': cleanIds.isEmpty ? toLevel : null,
      'p_target_level': action == 'move_level' ? targetLevel : null,
    };
    if (bulkManageQuestionsOverride != null) {
      return bulkManageQuestionsOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return 0;
    final res = await client
        .rpc('admin_bulk_manage_questions', params: params)
        .timeout(const Duration(seconds: 12));
    final affected =
        res is Map ? ((res['affected_count'] as num?)?.toInt() ?? 0) : 0;
    syncAndBroadcastAll();
    return affected;
  }

  Future<DynamicQuizCategoryData?> upsertCategoryAvailability({
    required String categoryId,
    required String availabilityStatus,
    String comingSoonMessage = '',
  }) async {
    final cleanCat = categoryId.trim().toLowerCase();
    if (cleanCat.isEmpty) {
      throw ArgumentError('معرّف القسم مطلوب لتحديث حالة التوفر');
    }
    final params = <String, dynamic>{
      'p_category_id': cleanCat,
      'p_availability_status': availabilityStatus.trim().toLowerCase(),
      'p_coming_soon_message': comingSoonMessage.trim(),
    };
    if (categoryAvailabilityUpdaterOverride != null) {
      return categoryAvailabilityUpdaterOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_category_availability', params: params)
        .timeout(const Duration(seconds: 8));
    if (res is Map) {
      final updated =
          DynamicQuizCategoryData.fromJson(Map<String, dynamic>.from(res));
      syncAndBroadcastAll();
      return updated;
    }
    return null;
  }

  Future<DynamicQuizCategoryData?> bulkSetLevelOverrides({
    required String categoryId,
    required int fromLevel,
    required int toLevel,
    required String status,
    String message = '',
  }) async {
    final cleanCat = categoryId.trim().toLowerCase();
    if (cleanCat.isEmpty) {
      throw ArgumentError('معرّف القسم مطلوب لتحديث المستويات');
    }
    if (fromLevel < 1 || toLevel < fromLevel || toLevel > 100) {
      throw ArgumentError('نطاق المستويات غير صالح (1..100)');
    }
    final params = <String, dynamic>{
      'p_category_id': cleanCat,
      'p_from_level': fromLevel,
      'p_to_level': toLevel,
      'p_status': status.trim().toLowerCase(),
      'p_message': message.trim(),
    };
    if (levelOverridesUpdaterOverride != null) {
      return levelOverridesUpdaterOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client
        .rpc('admin_bulk_set_level_overrides', params: params)
        .timeout(const Duration(seconds: 8));
    if (res is Map) {
      final updated =
          DynamicQuizCategoryData.fromJson(Map<String, dynamic>.from(res));
      syncAndBroadcastAll();
      return updated;
    }
    return null;
  }

  Future<List<String>> toggleHiddenLocalQuestion({
    required String categoryId,
    required String questionId,
    required bool hide,
  }) async {
    final cleanCat = categoryId.trim().toLowerCase();
    final cleanQId = questionId.trim();
    if (cleanCat.isEmpty || cleanQId.isEmpty) {
      throw ArgumentError('معرّف القسم ومعرّف السؤال مطلوبان');
    }
    final params = <String, dynamic>{
      'p_category_id': cleanCat,
      'p_question_id': cleanQId,
      'p_hide': hide,
    };
    if (hiddenLocalQuestionTogglerOverride != null) {
      return hiddenLocalQuestionTogglerOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return const [];
    final res = await client
        .rpc('admin_toggle_hidden_local_question', params: params)
        .timeout(const Duration(seconds: 8));
    syncAndBroadcastAll();
    if (res is Map && res['hidden_local_question_ids'] is List) {
      return (res['hidden_local_question_ids'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
