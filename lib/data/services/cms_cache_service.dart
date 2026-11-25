import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_constants.dart';
import '../../core/cms_icon_registry.dart';
import '../local/shared_prefs_service.dart';
import '../models/cms_models.dart';
import '../models/store_item_model.dart';
import 'profile_service.dart';
import 'question/question_cms_merger.dart';

typedef CmsBundleFetcher = Future<Map<String, dynamic>?> Function({
  required int clientCmsVersion,
  required List<String> ownedItemIds,
});

/// Resolution result for locating the next visible level after a completed level,
/// automatically skipping `hidden` levels and distinguishing `coming_soon` levels.
class NextLevelResolution {
  final int? levelNumber;
  final bool isComingSoon;
  final String message;

  const NextLevelResolution({
    this.levelNumber,
    this.isComingSoon = false,
    this.message = '',
  });

  bool get hasNext => levelNumber != null;
  bool get isPlayable => levelNumber != null && !isComingSoon;
}

/// Cache-first, version-gated dynamic CMS orchestrator for Store items,
/// Library sections/articles, and Solo Quiz categories/questions.
///
/// - Hydrates at 0ms from SharedPreferences (`initFromCache`).
/// - Fetches only when server `cms_version > cachedCmsVersion` (or `force: true`).
/// - Always supplies `p_owned_item_ids` so guests and offline-booted players
///   never lose access to previously purchased items that are later hidden.
class CmsCacheService extends ChangeNotifier {
  static final CmsCacheService instance = CmsCacheService._internal();
  CmsCacheService._internal() {
    CmsCategoryBounds.totalLevelsResolver = getTotalLevelsForCategory;
    CmsCategoryBounds.questionsPerLevelResolver =
        getQuestionsPerLevelForCategory;
    CmsCategoryBounds.drawModeResolver = getDrawModeForCategory;
  }

  CmsCacheSnapshot _snapshot = CmsCacheSnapshot.empty();
  CmsCacheSnapshot get snapshot => _snapshot;

  int get cachedCmsVersion => _snapshot.cmsVersion;
  bool _initialized = false;
  Future<bool>? _inFlightSync;

  @visibleForTesting
  CmsBundleFetcher? bundleFetcherOverride;

  /// Non-test getter checking if a deterministic test bundle fetcher is active.
  bool get hasBundleFetcherOverride => bundleFetcherOverride != null;

  /// Optional test/service callback invoked after CMS snapshot changes
  /// (e.g., invalidating QuestionService merged cache).
  final List<VoidCallback> _onBundleAppliedCallbacks = [];

  void registerOnBundleApplied(VoidCallback callback) {
    if (!_onBundleAppliedCallbacks.contains(callback)) {
      _onBundleAppliedCallbacks.add(callback);
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _inFlightSync = null;
    bundleFetcherOverride = null;
    _snapshot = CmsCacheSnapshot.empty();
    notifyListeners();
  }

  SupabaseClient? _safeSupabase() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` ONLY when Supabase reports that `get_cms_bundle_v2` is not
  /// yet deployed (`PGRST202` or PostgreSQL `42883`), preventing redundant
  /// fallback retries on network / timeout failures.
  @visibleForTesting
  static bool isCmsV2MissingError(Object error) {
    if (error is PostgrestException) {
      return error.code == 'PGRST202' || error.code == '42883';
    }
    return false;
  }

  /// Hydrates cached CMS deltas from SharedPreferences in ~0ms.
  Future<void> initFromCache() async {
    await SharedPrefsService.init();
    final rawJson = SharedPrefsService.getCachedCmsBundleJson();
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final map = jsonDecode(rawJson) as Map<String, dynamic>;
        _snapshot = CmsCacheSnapshot.fromJson(map);
      } catch (e) {
        debugPrint('CmsCacheService cache decode failed: $e');
        _snapshot = CmsCacheSnapshot.empty();
      }
    } else {
      _snapshot = CmsCacheSnapshot.empty();
    }
    _initialized = true;
    notifyListeners();
  }

  /// Collects local owned item IDs so `get_cms_bundle` preserves hidden owned items
  /// even before auth session restoration completes or for guest profiles.
  List<String> collectLocalOwnedItemIds([List<String>? extraOwnedIds]) {
    final ids = <String>{};
    final active = ProfileService.instance.activeProfile;
    if (active != null) {
      ids.addAll(active.unlockedItemIds);
    }
    if (extraOwnedIds != null) {
      ids.addAll(extraOwnedIds);
    }
    return ids.where((id) => id.trim().isNotEmpty).toList();
  }

  /// Synchronizes dynamic CMS deltas only if [serverCmsVersion] exceeds local cache
  /// or [force] is `true`. Returns `true` when new data was applied.
  Future<bool> syncIfNeeded({
    required int serverCmsVersion,
    List<String>? ownedItemIds,
    bool force = false,
  }) async {
    if (!_initialized) {
      await initFromCache();
    }

    final needsSchemaUpgrade = _snapshot.cacheSchemaVersion <
        CmsCacheSnapshot.currentCacheSchemaVersion;

    if (!force &&
        !needsSchemaUpgrade &&
        serverCmsVersion <= _snapshot.cmsVersion &&
        _snapshot.cmsVersion > 0) {
      return false;
    }

    if (_inFlightSync != null) {
      return _inFlightSync!;
    }

    final future = _performSync(
      ownedIds: collectLocalOwnedItemIds(ownedItemIds),
      force: force || needsSchemaUpgrade,
    );
    _inFlightSync = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightSync, future)) {
        _inFlightSync = null;
      }
    }
  }

  Future<bool> _performSync({
    required List<String> ownedIds,
    required bool force,
  }) async {
    final clientVer = force ? 0 : _snapshot.cmsVersion;
    try {
      Map<String, dynamic>? rpcResult;
      if (bundleFetcherOverride != null) {
        rpcResult = await bundleFetcherOverride!(
          clientCmsVersion: clientVer,
          ownedItemIds: ownedIds,
        ).timeout(const Duration(seconds: 5));
      } else {
        final client = _safeSupabase();
        if (client == null) return false;
        dynamic raw;
        try {
          raw = await client.rpc(
            'get_cms_bundle_v2',
            params: {
              'p_client_cms_version': clientVer,
              'p_owned_item_ids': ownedIds,
            },
          ).timeout(const Duration(seconds: 5));
        } on PostgrestException catch (v2Err) {
          if (isCmsV2MissingError(v2Err)) {
            debugPrint('CmsCacheService get_cms_bundle_v2 missing (${v2Err.code}), falling back to v1');
            raw = await client.rpc(
              'get_cms_bundle',
              params: {
                'p_client_cms_version': clientVer,
                'p_owned_item_ids': ownedIds,
              },
            ).timeout(const Duration(seconds: 5));
          } else {
            rethrow;
          }
        }
        if (raw is Map) {
          rpcResult = Map<String, dynamic>.from(raw);
        }
      }

      if (rpcResult == null) return false;
      final changed = rpcResult['changed'] as bool? ?? false;
      if (!changed) {
        final serverVer =
            (rpcResult['cms_version'] as num?)?.toInt() ?? _snapshot.cmsVersion;
        if (serverVer > _snapshot.cmsVersion) {
          _snapshot = CmsCacheSnapshot(
            cmsVersion: serverVer,
            storeItems: _snapshot.storeItems,
            librarySections: _snapshot.librarySections,
            libraryItems: _snapshot.libraryItems,
            quizCategories: _snapshot.quizCategories,
            quizQuestions: _snapshot.quizQuestions,
            syncedAt: DateTime.now().toUtc(),
          );
          await _persistSnapshot();
        }
        return false;
      }

      _snapshot = _snapshot.mergeBundle(rpcResult, DateTime.now().toUtc());
      await _persistSnapshot();
      for (final cb in _onBundleAppliedCallbacks) {
        try {
          cb();
        } catch (e) {
          debugPrint('CmsCacheService callback error: $e');
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CmsCacheService sync skipped (offline-safe): $e');
      return false;
    }
  }

  Future<void> _persistSnapshot() async {
    await SharedPrefsService.setCachedCmsVersion(_snapshot.cmsVersion);
    await SharedPrefsService.setCachedCmsBundleJson(
      jsonEncode(_snapshot.toJson()),
    );
  }

  /// Directly sets snapshot state in unit tests without disk overhead.
  @visibleForTesting
  void setSnapshotForTesting(CmsCacheSnapshot snapshot) {
    _initialized = true;
    _snapshot = snapshot;
    for (final cb in _onBundleAppliedCallbacks) {
      cb();
    }
    notifyListeners();
  }

  /// Resolves a cloud-defined Store item by [assetKey] and [category].
  StoreItemModel? findStoreItemByAssetKey(
    String assetKey, {
    StoreItemCategory? category,
  }) {
    for (final item in _snapshot.storeItems.values) {
      if (item.assetKey == assetKey &&
          (category == null || item.category == category)) {
        return item;
      }
    }
    return null;
  }

  /// Resolves dynamic `totalLevels` for [categoryId] (defaulting to 10 for built-in defaults).
  int getTotalLevelsForCategory(String categoryId) {
    final cat = _snapshot.quizCategories[categoryId];
    if (cat != null && cat.totalLevels > 0) {
      return cat.totalLevels.clamp(1, 100);
    }
    return AppConstants.levelsPerCategory;
  }

  /// Resolves dynamic `questionsPerLevel` for [categoryId] (defaulting to 10).
  int getQuestionsPerLevelForCategory(String categoryId) {
    final cat = _snapshot.quizCategories[categoryId];
    if (cat != null && cat.questionsPerLevel > 0) {
      return cat.questionsPerLevel.clamp(1, 100);
    }
    return AppConstants.questionsPerLevel;
  }

  /// Resolves dynamic `levelDrawMode` (`fixed` or `rotating_pool`) for [categoryId].
  String getDrawModeForCategory(String categoryId) {
    final cat = _snapshot.quizCategories[categoryId];
    if (cat != null && cat.levelDrawMode == 'rotating_pool') {
      return 'rotating_pool';
    }
    return 'fixed';
  }

  /// Resolves category display title from dynamic CMS first, falling back to AppConstants.
  String getCategoryDisplayName(String categoryId) {
    final dynamicCat = _snapshot.quizCategories[categoryId];
    if (dynamicCat != null && dynamicCat.name.trim().isNotEmpty) {
      return dynamicCat.name;
    }
    return AppConstants.getCategoryName(categoryId);
  }

  /// Resolves availability status (`open` / `coming_soon` / `hidden`) for [categoryId].
  CategoryAvailabilityStatus getCategoryAvailability(String categoryId) {
    final cat = _snapshot.quizCategories[categoryId];
    if (cat == null) return CategoryAvailabilityStatus.open;
    if (!cat.isVisible) return CategoryAvailabilityStatus.hidden;
    return cat.availability;
  }

  /// Returns optional teasing message configured for a `coming_soon` category.
  String getCategoryComingSoonMessage(String categoryId) {
    return _snapshot.quizCategories[categoryId]?.comingSoonMessage ?? '';
  }

  /// Returns per-level override (`coming_soon` / `hidden` + message) if configured.
  LevelOverrideConfig? getLevelOverride(String categoryId, int levelNumber) {
    return _snapshot.quizCategories[categoryId]?.overrideForLevel(levelNumber);
  }

  /// Whether [levelNumber] in [categoryId] is hidden from players.
  bool isLevelHidden(String categoryId, int levelNumber) {
    return getLevelOverride(categoryId, levelNumber)?.isHidden ?? false;
  }

  /// Whether [levelNumber] in [categoryId] is marked `coming_soon`.
  bool isLevelComingSoon(String categoryId, int levelNumber) {
    return getLevelOverride(categoryId, levelNumber)?.isComingSoon ?? false;
  }

  /// Returns teasing message for a `coming_soon` level (falls back to category message).
  String getLevelComingSoonMessage(String categoryId, int levelNumber) {
    final lvMsg = getLevelOverride(categoryId, levelNumber)?.message ?? '';
    if (lvMsg.isNotEmpty) return lvMsg;
    return getCategoryComingSoonMessage(categoryId);
  }

  /// Resolves displayable total levels for [categoryId], including any future
  /// `coming_soon` level overrides configured above `totalLevels`.
  int getDisplayTotalLevelsForCategory(String categoryId) {
    final baseTotal = getTotalLevelsForCategory(categoryId);
    final cat = _snapshot.quizCategories[categoryId];
    if (cat == null) return baseTotal;
    final maxCs = cat.maxComingSoonOverrideLevel;
    return (maxCs > baseTotal ? maxCs : baseTotal).clamp(1, 100);
  }

  /// Collects all hidden question IDs for [categoryId] via [QuestionCmsMerger].
  Set<String> getHiddenQuestionIds(String categoryId) {
    return QuestionCmsMerger.collectHiddenQuestionIds(
      categoryId,
      snapshot: _snapshot,
    );
  }

  /// Scans forward from `afterLevel + 1` up to display total levels, skipping
  /// `hidden` levels, and returns the first non-hidden level along with whether
  /// it is `coming_soon` (unplayable) or `open` (playable).
  NextLevelResolution resolveNextVisibleLevel(
    String categoryId,
    int afterLevel,
  ) {
    final total = getDisplayTotalLevelsForCategory(categoryId);
    for (var lv = afterLevel + 1; lv <= total; lv++) {
      if (isLevelHidden(categoryId, lv)) continue;
      if (isLevelComingSoon(categoryId, lv)) {
        return NextLevelResolution(
          levelNumber: lv,
          isComingSoon: true,
          message: getLevelComingSoonMessage(categoryId, lv),
        );
      }
      return NextLevelResolution(levelNumber: lv);
    }
    return const NextLevelResolution();
  }
}
