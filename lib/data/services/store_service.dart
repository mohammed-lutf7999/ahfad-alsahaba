import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/sound_service.dart';
import '../local/shared_prefs_service.dart';
import '../models/store_item_model.dart';
import 'app_control_service.dart';
import 'cms_cache_service.dart';
import 'profile_service.dart';
import 'progression_service.dart';

typedef StorePurchaseRpcSender = Future<Map<String, dynamic>?> Function({
  required String userId,
  required String itemId,
});

/// Service managing «سوق الفرسان» (Knight's Store) catalog, atomic cloud purchases,
/// hidden-but-owned protection, and instant theme/frame/title/power-up equipping.
class StoreService extends ChangeNotifier {
  static final StoreService instance = StoreService._();
  StoreService._() {
    _rebuildCatalogFromCache();
    CmsCacheService.instance.addListener(_rebuildCatalogFromCache);
  }

  List<StoreItemModel> _catalog = List<StoreItemModel>.from(
    StoreItemModel.defaultCatalog,
  );

  @visibleForTesting
  StorePurchaseRpcSender? purchaseRpcOverride;

  @visibleForTesting
  void resetForTesting() {
    purchaseRpcOverride = null;
    _rebuildCatalogFromCache();
  }

  void _rebuildCatalogFromCache() {
    final Map<String, StoreItemModel> merged = {
      for (final item in StoreItemModel.defaultCatalog) item.id: item,
    };

    for (final entry in CmsCacheService.instance.snapshot.storeItems.entries) {
      final cloudItem = entry.value;
      merged[entry.key] = cloudItem.withFallback(merged[entry.key]);
    }

    final list = merged.values.toList()
      ..sort((a, b) {
        final cmpSort = a.sortOrder.compareTo(b.sortOrder);
        if (cmpSort != 0) return cmpSort;
        final cmpLevel = a.minLevel.compareTo(b.minLevel);
        if (cmpLevel != 0) return cmpLevel;
        return a.id.compareTo(b.id);
      });

    _catalog = list;
    notifyListeners();
  }

  /// Current merged Store catalog (default 20 + dynamic cloud items).
  List<StoreItemModel> get catalog => _catalog;

  /// Filters catalog items by [category], hiding unowned hidden items while always
  /// preserving items the player already owns.
  List<StoreItemModel> itemsByCategory(
    StoreItemCategory category, {
    bool includeHiddenUnowned = false,
  }) {
    return _catalog
        .where(
          (item) =>
              item.category == category &&
              (includeHiddenUnowned || item.isVisible || isItemOwned(item)),
        )
        .toList();
  }

  /// Checks if the active player owns or has unlocked [item].
  bool isItemOwned(StoreItemModel item) {
    if (item.isDefaultFree) return true;
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return false;
    if (profile.unlockedItemIds.contains(item.id)) return true;

    // Frames also unlock automatically when reaching their historical tier level
    if (item.category == StoreItemCategory.frame &&
        profile.levelInfo.level >= item.minLevel) {
      return true;
    }
    return false;
  }

  /// Checks if [item] is currently equipped on the active profile.
  bool isItemEquipped(StoreItemModel item) {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) {
      return item.id == 'theme_andalusian_gold' || item.id == 'item_frame_wood';
    }
    switch (item.category) {
      case StoreItemCategory.theme:
        return profile.equippedTheme == item.assetKey;
      case StoreItemCategory.frame:
        return profile.equippedFrame == item.assetKey;
      case StoreItemCategory.title:
        return profile.effectiveTitle == item.assetKey;
      case StoreItemCategory.powerup:
        return profile.unlockedItemIds.contains(item.id);
    }
  }

  /// Syncs store metadata via `CmsCacheService` delta bundle only when needed,
  /// avoiding unnecessary direct table queries.
  Future<List<StoreItemModel>> syncCatalogFromCloud() async {
    try {
      final serverVer = AppControlService.instance.snapshot.cmsVersion;
      await CmsCacheService.instance.syncIfNeeded(
        serverCmsVersion: serverVer > 0 ? serverVer : 1,
      );
      _rebuildCatalogFromCache();
    } catch (e) {
      debugPrint('StoreService: Using local catalog (offline/uninitialized): $e');
    }
    return _catalog;
  }

  /// Purchases an unowned visible item (validating server response when signed in)
  /// or equips an already owned item (even if later hidden in store).
  Future<({bool success, String message})> purchaseOrEquip(
    StoreItemModel item,
  ) async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) {
      return (success: false, message: 'لم يتم العثور على ملف شخصي نشط');
    }

    // 1. If already owned, equip it immediately regardless of current store visibility
    if (isItemOwned(item)) {
      if (item.category == StoreItemCategory.theme) {
        await ProgressionService.instance.equipTheme(item.assetKey);
        _triggerFeedback(isPurchase: false);
        notifyListeners();
        return (
          success: true,
          message: 'تم تفعيل «${item.title}» وتغيير مظهر التطبيق فوراً! 🎨',
        );
      } else if (item.category == StoreItemCategory.frame) {
        await ProgressionService.instance.equipFrame(item.assetKey);
        _triggerFeedback(isPurchase: false);
        notifyListeners();
        return (
          success: true,
          message: 'تم تفعيل «${item.title}» حول صورتك الرمزية! 🛡️',
        );
      } else if (item.category == StoreItemCategory.powerup) {
        return (
          success: true,
          message: '«${item.title}» مفعّل وجاهز في خزانتك للمباراة القادمة! ⚡',
        );
      } else {
        await ProgressionService.instance.equipTitle(item.assetKey);
        _triggerFeedback(isPurchase: false);
        notifyListeners();
        return (
          success: true,
          message: 'تم تفعيل «${item.title}» في أوسمتك الشرفية! 👑',
        );
      }
    }

    // 2. Reject purchasing unowned hidden items locally before any RPC round-trip
    if (!item.isVisible) {
      return (success: false, message: 'هذا العنصر مخفي حالياً عن الشراء');
    }

    // Pre-check local eligibility to save RPC round-trips on invalid taps
    if (profile.levelInfo.level < item.minLevel) {
      return (
        success: false,
        message: 'يتطلب فتح هذا العنصر الوصول إلى المستوى ${item.minLevel}',
      );
    }
    if (profile.coins < item.priceCoins || profile.gems < item.priceGems) {
      return (
        success: false,
        message: 'رصيد الدنانير أو الياقوت غير كافٍ لاقتناء «${item.title}»',
      );
    }

    // 3. When signed in (or mocked in test), enforce authoritative server `purchase_store_item`
    try {
      String? userId;
      SupabaseClient? client;
      if (purchaseRpcOverride != null) {
        userId = profile.linkedUserId ?? 'test_user';
      } else {
        client = Supabase.instance.client;
        userId = client.auth.currentUser?.id;
      }

      if (userId != null && (purchaseRpcOverride != null || client != null)) {
        final raw = purchaseRpcOverride != null
            ? await purchaseRpcOverride!(userId: userId, itemId: item.id)
            : await client!
                .rpc(
                  'purchase_store_item',
                  params: {
                    'p_user_id': userId,
                    'p_item_id': item.id,
                  },
                )
                .timeout(const Duration(seconds: 6));

        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          if (map['success'] == false) {
            return (
              success: false,
              message:
                  map['error']?.toString() ?? 'تعذر إتمام الشراء من الخادم',
            );
          }
        }
      }
    } on PostgrestException catch (e) {
      return (
        success: false,
        message: 'تعذر إتمام الشراء من الخادم: ${e.message}',
      );
    } catch (e) {
      debugPrint('StoreService: Offline purchase notice (fallback to local sync): $e');
    }

    // 4. Deduct, equip, save locally, and sync via ProgressionService
    final result = await ProgressionService.instance.purchaseStoreItem(item);
    if (!result.success) {
      return result;
    }

    _triggerFeedback(isPurchase: true);
    notifyListeners();
    return result;
  }

  void _triggerFeedback({required bool isPurchase}) {
    try {
      if (SharedPrefsService.getVibrationEnabled()) {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('StoreService haptic error: $e');
    }

    try {
      if (isPurchase) {
        SoundService().playLevelComplete();
      } else {
        SoundService().playClick();
      }
    } catch (e) {
      debugPrint('StoreService sound error: $e');
    }
  }
}
