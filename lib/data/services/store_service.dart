import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/sound_service.dart';
import '../local/shared_prefs_service.dart';
import '../models/store_item_model.dart';
import 'profile_service.dart';
import 'progression_service.dart';

/// Service managing «سوق الفرسان» (Knight's Store) catalog, atomic cloud purchases,
/// and instant theme/frame/title/power-up equipping.
class StoreService extends ChangeNotifier {
  static final StoreService instance = StoreService._();
  StoreService._();

  List<StoreItemModel> _catalog = List<StoreItemModel>.from(
    StoreItemModel.defaultCatalog,
  );

  /// Current store catalog (all 20 items across 4 categories).
  List<StoreItemModel> get catalog => _catalog;

  /// Filters catalog items by [category].
  List<StoreItemModel> itemsByCategory(StoreItemCategory category) {
    return _catalog.where((item) => item.category == category).toList();
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

  /// Syncs catalog metadata from Supabase `public.store_items` if online,
  /// preserving rich local icons and preview colors.
  Future<List<StoreItemModel>> syncCatalogFromCloud() async {
    try {
      final client = Supabase.instance.client;
      final rows = await client.from('store_items').select();
      final Map<String, Map<String, dynamic>> serverMap = {};
      for (final r in (rows as List<dynamic>)) {
        final map = r as Map<String, dynamic>;
        final id = map['id']?.toString();
        if (id != null) {
          serverMap[id] = map;
        }
      }

      if (serverMap.isNotEmpty) {
        _catalog = StoreItemModel.defaultCatalog.map((localItem) {
          final srv = serverMap[localItem.id];
          if (srv == null) return localItem;
          return StoreItemModel(
            id: localItem.id,
            title: srv['title']?.toString() ?? localItem.title,
            description:
                srv['description']?.toString() ?? localItem.description,
            category: localItem.category,
            priceCoins:
                (srv['price_coins'] as num?)?.toInt() ?? localItem.priceCoins,
            priceGems:
                (srv['price_gems'] as num?)?.toInt() ?? localItem.priceGems,
            minLevel: (srv['min_level'] as num?)?.toInt() ?? localItem.minLevel,
            assetKey: srv['asset_key']?.toString() ?? localItem.assetKey,
            previewColor: localItem.previewColor,
            icon: localItem.icon,
            isDefaultFree: localItem.isDefaultFree,
          );
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('StoreService: Using local catalog (offline/uninitialized): $e');
    }
    return _catalog;
  }

  /// Purchases an unowned item or equips an already owned item.
  Future<({bool success, String message})> purchaseOrEquip(
    StoreItemModel item,
  ) async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) {
      return (success: false, message: 'لم يتم العثور على ملف شخصي نشط');
    }

    // 1. If already owned, equip it immediately
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

    // 2. If authenticated online, execute atomic `purchase_store_item` RPC first
    // before local save & sync so server and local balances never conflict.
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.rpc(
          'purchase_store_item',
          params: {
            'p_user_id': userId,
            'p_item_id': item.id,
          },
        );
      }
    } catch (e) {
      debugPrint('StoreService: Cloud RPC sync notice: $e');
    }

    // 3. Validate, deduct, equip, and sync via ProgressionService
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
    } catch (_) {}

    try {
      if (isPurchase) {
        SoundService().playLevelComplete();
      } else {
        SoundService().playClick();
      }
    } catch (_) {}
  }
}

