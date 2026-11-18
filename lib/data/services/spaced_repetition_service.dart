import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../local/shared_prefs_service.dart';
import 'app_control_service.dart';

class SpacedRepetitionEntry {
  final String questionId;
  final String categoryId;
  final int stage; // 0: 24h, 1: 3d, 2: 7d
  final DateTime nextReviewAt;

  const SpacedRepetitionEntry({
    required this.questionId,
    required this.categoryId,
    this.stage = 0,
    required this.nextReviewAt,
  });

  factory SpacedRepetitionEntry.fromJson(Map<String, dynamic> json) {
    return SpacedRepetitionEntry(
      questionId: (json['question_id'] ?? '').toString(),
      categoryId: (json['category_id'] ?? '').toString(),
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      nextReviewAt: DateTime.tryParse((json['next_review_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'category_id': categoryId,
        'stage': stage,
        'next_review_at': nextReviewAt.toUtc().toIso8601String(),
      };
}

/// Offline-only «المعلم الحكيم» Spaced Repetition tracker (`24h -> 3d -> 7d`)
/// governed by both the remote `wise_teacher_mode` feature flag and the
/// player's local preference in `SettingsScreen`. Zero Supabase calls.
class SpacedRepetitionService extends ChangeNotifier {
  static final SpacedRepetitionService instance = SpacedRepetitionService._();
  SpacedRepetitionService._();

  static const String _storageKey = 'wise_teacher_review_queue_v1';
  final Map<String, SpacedRepetitionEntry> _entries = {};
  bool _loaded = false;

  @visibleForTesting
  DateTime Function()? nowProvider;

  DateTime _nowUtc() => (nowProvider?.call() ?? DateTime.now()).toUtc();

  /// True only when both the Admin cloud flag and the player's local toggle are ON.
  bool get isEffectivelyEnabled =>
      AppControlService.instance.featureFlagsNotifier.value.wiseTeacherMode &&
      SharedPrefsService.getWiseTeacherEnabled();

  bool get isAdminBlocked =>
      !AppControlService.instance.featureFlagsNotifier.value.wiseTeacherMode;

  int get dueCount {
    final now = _nowUtc();
    return _entries.values.where((e) => !e.nextReviewAt.isAfter(now)).length;
  }

  @visibleForTesting
  void resetForTesting() {
    _entries.clear();
    _loaded = false;
    nowProvider = null;
  }

  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    await SharedPrefsService.init();
    final prefs = await SharedPrefsService.getRawPrefs();
    final raw = prefs?.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        for (final row in decoded.whereType<Map>()) {
          final entry =
              SpacedRepetitionEntry.fromJson(Map<String, dynamic>.from(row));
          if (entry.questionId.isNotEmpty) {
            _entries[entry.questionId] = entry;
          }
        }
      } catch (e) {
        debugPrint('SpacedRepetitionService parse notice: $e');
      }
    }
  }

  Future<void> recordAnswer({
    required String questionId,
    required String categoryId,
    required bool isCorrect,
  }) async {
    if (!isEffectivelyEnabled || questionId.trim().isEmpty) return;
    await init();
    final now = _nowUtc();
    final existing = _entries[questionId];

    if (isCorrect) {
      if (existing == null) return;
      final nextStage = existing.stage + 1;
      if (nextStage > 2) {
        _entries.remove(questionId);
      } else {
        final days = nextStage == 1 ? 3 : 7;
        _entries[questionId] = SpacedRepetitionEntry(
          questionId: questionId,
          categoryId: categoryId,
          stage: nextStage,
          nextReviewAt: now.add(Duration(days: days)),
        );
      }
    } else {
      _entries[questionId] = SpacedRepetitionEntry(
        questionId: questionId,
        categoryId: categoryId,
        stage: 0,
        nextReviewAt: now.add(const Duration(hours: 24)),
      );
    }

    await _persist();
    notifyListeners();
  }

  List<String> getDueQuestionIds(String categoryId) {
    if (!isEffectivelyEnabled) return const [];
    final now = _nowUtc();
    return _entries.values
        .where(
          (e) =>
              e.categoryId == categoryId && !e.nextReviewAt.isAfter(now),
        )
        .map((e) => e.questionId)
        .toList();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPrefsService.getRawPrefs();
      if (prefs == null) return;
      final bounded = _entries.values.take(120).map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(bounded));
    } catch (e) {
      debugPrint('SpacedRepetitionService persist notice: $e');
    }
  }
}
