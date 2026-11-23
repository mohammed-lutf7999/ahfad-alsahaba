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

typedef CmsBundleFetcher = Future<Map<String, dynamic>?> Function({
  required int clientCmsVersion,
  required List<String> ownedItemIds,
});

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

    if (!force && serverCmsVersion <= _snapshot.cmsVersion && _snapshot.cmsVersion > 0) {
      return false;
    }

    if (_inFlightSync != null) {
      return _inFlightSync!;
    }

    final future = _performSync(
      ownedIds: collectLocalOwnedItemIds(ownedItemIds),
      force: force,
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
        } catch (v2Err) {
          debugPrint('CmsCacheService get_cms_bundle_v2 fallback to v1: $v2Err');
          raw = await client.rpc(
            'get_cms_bundle',
            params: {
              'p_client_cms_version': clientVer,
              'p_owned_item_ids': ownedIds,
            },
          ).timeout(const Duration(seconds: 5));
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
}
