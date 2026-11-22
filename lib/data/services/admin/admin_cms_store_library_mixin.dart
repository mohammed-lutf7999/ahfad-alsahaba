import 'package:flutter/foundation.dart';

import '../../models/cms_models.dart';
import '../../models/store_item_model.dart';
import 'admin_service_base.dart';

/// Admin CMS domain mixin for Knights Store items, Library sections/items,
/// and global non-destructive visibility toggling.
mixin AdminCmsStoreLibraryMixin on AdminServiceBase {
  @visibleForTesting
  Future<List<StoreItemModel>> Function()? storeItemsFetcherOverride;

  @visibleForTesting
  Future<StoreItemModel?> Function(Map<String, dynamic> params)?
      storeItemUpserterOverride;

  @visibleForTesting
  Future<bool> Function({
    required String entityType,
    required String id,
    required bool isVisible,
  })? visibilitySetterOverride;

  @visibleForTesting
  Future<({List<DynamicLibrarySectionData> sections, List<DynamicLibraryItemData> items})>
      Function({String? sectionId})? libraryContentFetcherOverride;

  @visibleForTesting
  Future<DynamicLibrarySectionData?> Function(Map<String, dynamic> params)?
      librarySectionUpserterOverride;

  @visibleForTesting
  Future<DynamicLibraryItemData?> Function(Map<String, dynamic> params)?
      libraryItemUpserterOverride;

  @protected
  void resetCmsStoreLibraryForTesting() {
    storeItemsFetcherOverride = null;
    storeItemUpserterOverride = null;
    visibilitySetterOverride = null;
    libraryContentFetcherOverride = null;
    librarySectionUpserterOverride = null;
    libraryItemUpserterOverride = null;
  }

  Future<List<StoreItemModel>> listStoreItems() async {
    if (storeItemsFetcherOverride != null) {
      return storeItemsFetcherOverride!();
    }
    final client = supabaseClient;
    if (client == null) return [];
    final res = await client
        .rpc('admin_list_store_items')
        .timeout(const Duration(seconds: 6));
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) =>
              StoreItemModel.fromCloudJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<StoreItemModel?> upsertStoreItem({
    required String id,
    required String title,
    String description = '',
    required StoreItemCategory category,
    int priceCoins = 0,
    int priceGems = 0,
    int minLevel = 1,
    String assetKey = '',
    bool isVisible = true,
    int sortOrder = 100,
    Map<String, dynamic> metadata = const {},
  }) async {
    final params = <String, dynamic>{
      'p_id': id.trim().toLowerCase(),
      'p_title': title.trim(),
      'p_description': description.trim(),
      'p_category': category.name,
      'p_price_coins': priceCoins.clamp(0, 1000000),
      'p_price_gems': priceGems.clamp(0, 100000),
      'p_min_level': minLevel.clamp(1, 100),
      'p_asset_key': assetKey.trim(),
      'p_is_visible': isVisible,
      'p_sort_order': sortOrder,
      'p_metadata': metadata,
    };
    if (storeItemUpserterOverride != null) {
      return storeItemUpserterOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_store_item', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final parsed =
          StoreItemModel.fromCloudJson(Map<String, dynamic>.from(res));
      syncAndBroadcastAll();
      return parsed;
    }
    return null;
  }

  Future<bool> setContentVisibility({
    required String entityType,
    required String id,
    required bool isVisible,
  }) async {
    if (visibilitySetterOverride != null) {
      return visibilitySetterOverride!(
        entityType: entityType,
        id: id,
        isVisible: isVisible,
      );
    }
    final client = supabaseClient;
    if (client == null) return false;
    final res = await client.rpc(
      'admin_set_content_visibility',
      params: {
        'p_entity_type': entityType,
        'p_id': id,
        'p_is_visible': isVisible,
      },
    ).timeout(const Duration(seconds: 6));
    final ok = res is Map && res['ok'] == true;
    if (ok) {
      syncAndBroadcastAll();
    }
    return ok;
  }

  Future<
      ({
        List<DynamicLibrarySectionData> sections,
        List<DynamicLibraryItemData> items,
      })> listLibraryContent({String? sectionId}) async {
    if (libraryContentFetcherOverride != null) {
      return libraryContentFetcherOverride!(sectionId: sectionId);
    }
    final client = supabaseClient;
    if (client == null) return (sections: <DynamicLibrarySectionData>[], items: <DynamicLibraryItemData>[]);
    final res = await client.rpc(
      'admin_list_library_content',
      params: {'p_section_id': sectionId},
    ).timeout(const Duration(seconds: 6));
    if (res is Map) {
      final secRaw = res['sections'] as List? ?? const [];
      final itemRaw = res['items'] as List? ?? const [];
      return (
        sections: secRaw
            .whereType<Map>()
            .map((e) => DynamicLibrarySectionData.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(),
        items: itemRaw
            .whereType<Map>()
            .map((e) =>
                DynamicLibraryItemData.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    return (sections: <DynamicLibrarySectionData>[], items: <DynamicLibraryItemData>[]);
  }

  Future<DynamicLibrarySectionData?> upsertLibrarySection({
    required String id,
    required String title,
    String iconName = 'auto_stories_rounded',
    String colorHex = '#D4AF37',
    int sortOrder = 100,
    bool isVisible = true,
  }) async {
    final params = <String, dynamic>{
      'p_id': id.trim().toLowerCase(),
      'p_title': title.trim(),
      'p_icon_name': iconName,
      'p_color_hex': colorHex.trim(),
      'p_sort_order': sortOrder,
      'p_is_visible': isVisible,
    };
    if (librarySectionUpserterOverride != null) {
      return librarySectionUpserterOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_library_section', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final sec = DynamicLibrarySectionData.fromJson(
          Map<String, dynamic>.from(res));
      syncAndBroadcastAll();
      return sec;
    }
    return null;
  }

  Future<DynamicLibraryItemData?> upsertLibraryItem({
    String? id,
    required String sectionId,
    required String title,
    String subtitle = '',
    required String content,
    String sourceRef = '',
    int sortOrder = 100,
    bool isVisible = true,
  }) async {
    final params = <String, dynamic>{
      'p_id': (id == null || id.trim().isEmpty) ? null : id.trim(),
      'p_section_id': sectionId.trim().toLowerCase(),
      'p_title': title.trim(),
      'p_subtitle': subtitle.trim(),
      'p_content': content.trim(),
      'p_source_ref': sourceRef.trim(),
      'p_sort_order': sortOrder,
      'p_is_visible': isVisible,
    };
    if (libraryItemUpserterOverride != null) {
      return libraryItemUpserterOverride!(params);
    }
    final client = supabaseClient;
    if (client == null) return null;
    final res = await client
        .rpc('admin_upsert_library_item', params: params)
        .timeout(const Duration(seconds: 6));
    if (res is Map) {
      final item =
          DynamicLibraryItemData.fromJson(Map<String, dynamic>.from(res));
      syncAndBroadcastAll();
      return item;
    }
    return null;
  }
}
