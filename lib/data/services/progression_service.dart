import 'package:flutter/foundation.dart';
import '../../core/theme/app_custom_theme.dart';
import '../models/arena_model.dart';
import '../models/player_level_model.dart';
import '../models/store_item_model.dart';
import 'profile_service.dart';

/// Represents a detected level-up event for triggering celebration dialogs.
class LevelUpTransition {
  final PlayerLevelInfo oldLevel;
  final PlayerLevelInfo newLevel;
  final int coinsAwarded;
  final bool isNewTitleUnlocked;

  const LevelUpTransition({
    required this.oldLevel,
    required this.newLevel,
    required this.coinsAwarded,
    required this.isNewTitleUnlocked,
  });
}

/// Represents a detected arena promotion event when crossing trophy thresholds.
class ArenaPromotionTransition {
  final ArenaModel oldArena;
  final ArenaModel newArena;
  final int currentTrophies;

  const ArenaPromotionTransition({
    required this.oldArena,
    required this.newArena,
    required this.currentTrophies,
  });
}

/// Central Progression & Economy Service managing levels, arenas, themes, and store items.
class ProgressionService extends ChangeNotifier {
  static final ProgressionService instance = ProgressionService._();
  ProgressionService._();

  /// Active player's computed 100-Level Mastery info.
  PlayerLevelInfo get currentLevelInfo {
    final score = ProfileService.instance.activeProfile?.totalScore ?? 0;
    return PlayerLevelInfo.fromTotalScore(score);
  }

  /// Active player's computed Competitive Arena info.
  ArenaModel get currentArena {
    final trophies = ProfileService.instance.activeProfile?.trophies ?? 1000;
    return ArenaModel.fromTrophies(trophies);
  }

  /// Active player's equipped visual theme.
  AppCustomTheme get activeTheme {
    final themeId = ProfileService.instance.activeProfile?.equippedTheme;
    return AppCustomTheme.fromId(themeId);
  }

  /// Evaluates if increasing score from [oldScore] to [newScore] resulted in a Level Up.
  LevelUpTransition? evaluateScoreTransition({
    required int oldScore,
    required int newScore,
  }) {
    if (newScore <= oldScore) return null;
    final oldInfo = PlayerLevelInfo.fromTotalScore(oldScore);
    final newInfo = PlayerLevelInfo.fromTotalScore(newScore);
    if (newInfo.level <= oldInfo.level) return null;

    final coinsAwarded = PlayerLevelInfo.totalCoinsGrantedBetweenLevels(
      oldInfo.level,
      newInfo.level,
    );

    return LevelUpTransition(
      oldLevel: oldInfo,
      newLevel: newInfo,
      coinsAwarded: coinsAwarded,
      isNewTitleUnlocked: oldInfo.title != newInfo.title,
    );
  }

  /// Evaluates if changing trophies from [oldTrophies] to [newTrophies] promoted the player to a higher arena.
  ArenaPromotionTransition? evaluateArenaTransition({
    required int oldTrophies,
    required int newTrophies,
  }) {
    if (newTrophies <= oldTrophies) return null;
    final oldArena = ArenaModel.fromTrophies(oldTrophies);
    final newArena = ArenaModel.fromTrophies(newTrophies);
    if (newArena.id <= oldArena.id) return null;

    return ArenaPromotionTransition(
      oldArena: oldArena,
      newArena: newArena,
      currentTrophies: newTrophies,
    );
  }

  /// Equips a theme by [themeId] on the active profile and notifies listeners.
  Future<void> equipTheme(String themeId) async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return;
    profile.equippedTheme = themeId;
    await ProfileService.instance.saveActiveProfileAndSync();
    notifyListeners();
  }

  /// Equips an avatar frame by [frameKey] on the active profile and notifies listeners.
  Future<void> equipFrame(String frameKey) async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return;
    profile.equippedFrame = frameKey;
    await ProfileService.instance.saveActiveProfileAndSync();
    notifyListeners();
  }

  /// Purchases an item from «سوق الفرسان» using the active profile's coins/gems.
  Future<({bool success, String message})> purchaseStoreItem(
    StoreItemModel item,
  ) async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) {
      return (success: false, message: 'لم يتم العثور على ملف شخصي نشط');
    }

    if (profile.unlockedItemIds.contains(item.id) || item.isDefaultFree) {
      return (success: false, message: 'تمتلك هذا العنصر مسبقاً في خزانتك');
    }

    final currentLevel = profile.levelInfo.level;
    if (currentLevel < item.minLevel) {
      return (
        success: false,
        message: 'يتطلب الوصول إلى المستوى ${item.minLevel} لفتح هذا العنصر',
      );
    }

    if (profile.coins < item.priceCoins) {
      return (
        success: false,
        message: 'رصيد دنانير الفتح غير كافٍ (${profile.coins}/${item.priceCoins})',
      );
    }

    if (profile.gems < item.priceGems) {
      return (
        success: false,
        message: 'رصيد ياقوت النخبة غير كافٍ (${profile.gems}/${item.priceGems})',
      );
    }

    profile.coins -= item.priceCoins;
    profile.gems -= item.priceGems;
    profile.unlockedItemIds.add(item.id);

    if (item.category == StoreItemCategory.theme) {
      profile.equippedTheme = item.assetKey;
    } else if (item.category == StoreItemCategory.frame) {
      profile.equippedFrame = item.assetKey;
    }

    await ProfileService.instance.saveActiveProfileAndSync();
    notifyListeners();

    return (success: true, message: 'تم اقتناء «${item.title}» وتفعيله بنجاح!');
  }
}
