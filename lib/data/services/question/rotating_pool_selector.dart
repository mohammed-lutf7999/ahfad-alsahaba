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
/// When fewer than [questionsPerLevel] unseen questions remain:
/// 1. Takes ALL remaining unseen questions first.
/// 2. Resets the seen set for this level (`didResetPool = true`).
/// 3. Fills the remaining slots from the rest of [pool] while strictly
///    excluding IDs already picked in step 1 so zero duplicates appear in a round.
class RotatingPoolSelector {
  RotatingPoolSelector._();

  static RotatingPoolSelection selectForLevel({
    required List<Question> pool,
    required int questionsPerLevel,
    required Set<String> seenIds,
    Random? random,
  }) {
    if (pool.isEmpty) {
      return const RotatingPoolSelection(
        selected: [],
        updatedSeenIds: {},
        didResetPool: false,
      );
    }

    final rng = random ?? Random();
    final int target = questionsPerLevel.clamp(1, pool.length);

    final unseen = pool.where((q) => !seenIds.contains(q.id)).toList()
      ..shuffle(rng);

    // Case A: Enough unseen questions remain — no reset needed.
    if (unseen.length >= target) {
      final picked = unseen.take(target).toList();
      final nextSeen = <String>{
        ...seenIds,
        for (final q in picked) q.id,
      };
      return RotatingPoolSelection(
        selected: picked,
        updatedSeenIds: nextSeen,
        didResetPool: false,
      );
    }

    // Case B: Pool exhausted (or fewer than target unseen remain).
    // Take all remaining unseen first, then reset seen pool and fill the rest
    // strictly excluding already-picked IDs to guarantee ZERO duplicates in this round.
    final selected = List<Question>.from(unseen);
    final pickedIds = selected.map((q) => q.id).toSet();
    final needed = target - selected.length;

    final refillCandidates = pool
        .where((q) => !pickedIds.contains(q.id))
        .toList()
      ..shuffle(rng);
    final refill = refillCandidates.take(needed).toList();
    selected.addAll(refill);

    // Mark only the newly recycled refill IDs as seen for the fresh cycle
    // (or all selected IDs if every question in pool was needed in one round).
    final nextSeen = refill.isNotEmpty
        ? refill.map((q) => q.id).toSet()
        : selected.map((q) => q.id).toSet();

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
