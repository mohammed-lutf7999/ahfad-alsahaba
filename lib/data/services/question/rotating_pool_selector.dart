import 'dart:math';

import '../../local/shared_prefs_service.dart';
import '../../models/question_model.dart';

/// Result returned by [RotatingPoolSelector.selectForLevel].
class RotatingPoolSelection {
  final List<Question> selected;
  final Set<String> updatedSeenIds;
  final bool didResetPool;

  const RotatingPoolSelection({
    required this.selected,
    required this.updatedSeenIds,
    required this.didResetPool,
  });
}

/// Pure, duplicate-free `rotating_pool` selector with automatic seen-pool
/// rollover (`Auto-Reset Seen Pool`, Plan 20).
///
/// Safeguards:
/// - Deduplicates duplicate question IDs in [pool] defensively.
/// - Prunes stale IDs from [seenIds] that no longer exist in [pool].
/// - Preserves [seenIds] untouched when [pool] is temporarily empty.
/// - On rollover (when unseen `< questionsPerLevel`):
///   1. Takes ALL remaining unseen questions first.
///   2. Fills remaining slots from the rest of [pool] excluding already-picked IDs.
///   3. Shuffles the combined [selected] round so remaining & recycled questions
///      are interleaved evenly.
///   4. Sets `updatedSeenIds = selected.map((q) => q.id).toSet()` so the
///      remaining questions just played are NOT immediately repeated in the next round.
class RotatingPoolSelector {
  RotatingPoolSelector._();

  static RotatingPoolSelection selectForLevel({
    required List<Question> pool,
    required int questionsPerLevel,
    required Set<String> seenIds,
    Random? random,
  }) {
    if (pool.isEmpty) {
      return RotatingPoolSelection(
        selected: const [],
        updatedSeenIds: Set<String>.from(seenIds),
        didResetPool: false,
      );
    }

    // Defensive deduplication by ID (preserves first occurrence)
    final uniquePool = <Question>[];
    final validIds = <String>{};
    for (final q in pool) {
      if (validIds.add(q.id)) {
        uniquePool.add(q);
      }
    }

    // Prune stale seen IDs that no longer exist in the current pool
    final cleanSeen = seenIds.intersection(validIds);

    final rng = random ?? Random();
    final int target = questionsPerLevel.clamp(1, uniquePool.length);

    final unseen = uniquePool.where((q) => !cleanSeen.contains(q.id)).toList()
      ..shuffle(rng);

    // Case A: Enough unseen questions remain — no reset needed.
    if (unseen.length >= target) {
      final picked = unseen.take(target).toList();
      final nextSeen = <String>{
        ...cleanSeen,
        for (final q in picked) q.id,
      };
      return RotatingPoolSelection(
        selected: picked,
        updatedSeenIds: nextSeen,
        didResetPool: false,
      );
    }

    // Case B: Pool exhausted (fewer than target unseen remain).
    // Take all remaining unseen first, fill remaining slots excluding picked IDs,
    // shuffle combined selection, and mark ALL selected IDs as seen for the new cycle.
    final selected = List<Question>.from(unseen);
    final pickedIds = selected.map((q) => q.id).toSet();
    final needed = target - selected.length;

    final refillCandidates = uniquePool
        .where((q) => !pickedIds.contains(q.id))
        .toList()
      ..shuffle(rng);
    final refill = refillCandidates.take(needed).toList();
    selected.addAll(refill);
    selected.shuffle(rng);

    final nextSeen = selected.map((q) => q.id).toSet();

    return RotatingPoolSelection(
      selected: selected,
      updatedSeenIds: nextSeen,
      didResetPool: true,
    );
  }

  /// Stateful convenience wrapper reading & persisting seen IDs in [SharedPrefsService].
  static Future<List<Question>> selectAndPersist({
    required String categoryId,
    required int levelNumber,
    required List<Question> pool,
    required int questionsPerLevel,
    Random? random,
  }) async {
    if (pool.isEmpty) return const [];
    final seen = SharedPrefsService.getRotatingPoolSeenIds(
      categoryId,
      levelNumber,
    );
    final result = selectForLevel(
      pool: pool,
      questionsPerLevel: questionsPerLevel,
      seenIds: seen,
      random: random,
    );
    await SharedPrefsService.setRotatingPoolSeenIds(
      categoryId,
      levelNumber,
      result.updatedSeenIds,
    );
    return result.selected;
  }
}
