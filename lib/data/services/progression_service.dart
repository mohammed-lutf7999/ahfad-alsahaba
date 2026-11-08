import 'package:flutter/material.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../ui/dialogs/arena_promotion_dialog.dart';
import '../../ui/dialogs/level_up_celebration_dialog.dart';
import '../models/arena_model.dart';
import '../models/player_level_model.dart';
import '../models/store_item_model.dart';
import 'profile_service.dart';

/// Snapshot of a player's score & trophies before a game round or reward grant.
class ProgressionSnapshot {
  final int score;
  final int trophies;
  final int level;
  final int arenaId;

  const ProgressionSnapshot({
    required this.score,
    required this.trophies,
    required this.level,
    required this.arenaId,
  });
}

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

  /// Captures a [ProgressionSnapshot] of the active profile's current score and trophies.
  ProgressionSnapshot captureSnapshot() {
    final profile = ProfileService.instance.activeProfile;
    final score = profile?.totalScore ?? 0;
    final trophies = profile?.trophies ?? 1000;
    return ProgressionSnapshot(
      score: score,
      trophies: trophies,
      level: PlayerLevelInfo.fromTotalScore(score).level,
      arenaId: ArenaModel.fromTrophies(trophies).id,
    );
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

  /// Checks if the active player leveled up or promoted to a new arena since [before]
  /// and sequentially presents [LevelUpCelebrationDialog] and/or [ArenaPromotionDialog].
  Future<void> checkAndTriggerCelebrations(
    BuildContext context, {
    required ProgressionSnapshot before,
    int? overrideNewScore,
    int? overrideNewTrophies,
  }) async {
    final profile = ProfileService.instance.activeProfile;
    final newScore = overrideNewScore ?? profile?.totalScore ?? before.score;
    final newTrophies =
        overrideNewTrophies ?? profile?.trophies ?? before.trophies;

    final levelUp = evaluateScoreTransition(
      oldScore: before.score,
      newScore: newScore,
    );
    if (levelUp != null && context.mounted) {
      await LevelUpCelebrationDialog.show(context, transition: levelUp);
    }

    final arenaPromo = evaluateArenaTransition(
      oldTrophies: before.trophies,
      newTrophies: newTrophies,
    );
    if (arenaPromo != null && context.mounted) {
      await ArenaPromotionDialog.show(context, transition: arenaPromo);
    }
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

  /// Checks if the active profile currently owns a specific item or power-up.
  bool hasItem(String itemId) {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return false;
    return profile.unlockedItemIds.contains(itemId);
  }

  /// Consumes `powerup_insight` («بصيرة القائد 💡») from the active profile's inventory
  /// and syncs to local storage & cloud. Returns `true` if successfully consumed.
  Future<bool> consumeCommanderInsight() async {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return false;
    if (!profile.unlockedItemIds.contains('powerup_insight')) {
      return false;
    }
    profile.unlockedItemIds.remove('powerup_insight');
    await ProfileService.instance.saveActiveProfileAndSync();
    notifyListeners();
    return true;
  }

  /// Applies a match outcome (Online, Bot, or Single-Player) to the active profile, honoring:
  /// - `powerup_xp_banner` (doubles earned XP and consumes the banner).
  /// - `powerup_shield` (absorbs trophy loss `-12 -> 0` and preserves `winStreak` on loss, consuming the shield).
  /// - Arena coin multiplier (`calculateMatchCoins`).
  ({
    int effectiveXpAdded,
    int trophiesDelta,
    int coinsEarned,
    bool shieldConsumed,
    bool xpBannerConsumed,
  }) applyMatchOutcome({
    required int rawMatchScore,
    required int correctAnswers,
    required bool isWin,
    required bool isDraw,
    int? serverTotalTrophies,
    int? serverTrophiesDelta,
    bool updateTrophies = true,
  }) {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) {
      return (
        effectiveXpAdded: rawMatchScore,
        trophiesDelta: 0,
        coinsEarned: 0,
        shieldConsumed: false,
        xpBannerConsumed: false,
      );
    }

    bool xpBannerConsumed = false;
    int effectiveXp = rawMatchScore > 0 ? rawMatchScore : 0;
    if (effectiveXp > 0 &&
        profile.unlockedItemIds.contains('powerup_xp_banner')) {
      profile.unlockedItemIds.remove('powerup_xp_banner');
      effectiveXp *= 2;
      xpBannerConsumed = true;
    }

    bool shieldConsumed = false;
    int trophiesDelta = 0;
    if (updateTrophies) {
      if (isDraw) {
        trophiesDelta = serverTrophiesDelta ?? 5;
      } else if (isWin) {
        profile.winStreak += 1;
        trophiesDelta =
            serverTrophiesDelta ??
            ArenaModel.calculateTrophyDelta(
              isWin: true,
              isDraw: false,
              winStreak: profile.winStreak,
            );
      } else {
        // Loss: check if player owns `powerup_shield`
        if (profile.unlockedItemIds.contains('powerup_shield')) {
          profile.unlockedItemIds.remove('powerup_shield');
          shieldConsumed = true;
          trophiesDelta = 0; // Shield absorbs -12 loss and preserves winStreak!
        } else {
          profile.winStreak = 0;
          trophiesDelta = serverTrophiesDelta ?? -12;
        }
      }

      profile.trophies = ArenaModel.clampTrophies(
        serverTotalTrophies ?? (profile.trophies + trophiesDelta),
      );
    }

    final arena = ArenaModel.fromTrophies(profile.trophies);
    final coinsEarned = arena.calculateMatchCoins(
      correctAnswers: correctAnswers,
    );
    profile.coins += coinsEarned;
    profile.addScore(effectiveXp);

    notifyListeners();
    return (
      effectiveXpAdded: effectiveXp,
      trophiesDelta: trophiesDelta,
      coinsEarned: coinsEarned,
      shieldConsumed: shieldConsumed,
      xpBannerConsumed: xpBannerConsumed,
    );
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
