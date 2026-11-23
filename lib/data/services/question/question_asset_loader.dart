import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Map<String, dynamic> _decodeQuestionJsonIsolate(String jsonString) {
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

/// Isolate-backed loader and in-memory cache for built-in question JSON assets.
class QuestionAssetLoader {
  final Map<String, Map<String, dynamic>?> _baseAssetCache = {};
  final Map<String, Future<void>> _inFlightLoads = {};

  bool isCached(String categoryId) => _baseAssetCache.containsKey(categoryId);

  Map<String, dynamic>? getCached(String categoryId) =>
      _baseAssetCache[categoryId];

  void clear([String? categoryId]) {
    if (categoryId != null) {
      _baseAssetCache.remove(categoryId);
    } else {
      _baseAssetCache.clear();
    }
  }

  Future<void> ensureLoaded(String categoryId) async {
    if (_baseAssetCache.containsKey(categoryId)) return;

    final existingFuture = _inFlightLoads[categoryId];
    if (existingFuture != null) {
      await existingFuture;
      return;
    }

    final loadFuture = () async {
      try {
        final jsonString = await rootBundle.loadString(
          'assets/questions/$categoryId.json',
        );
        _baseAssetCache[categoryId] =
            await compute(_decodeQuestionJsonIsolate, jsonString);
      } catch (_) {
        // Cloud-only categories have no bundled asset file; record null cleanly
        // so level lookups proceed smoothly from CmsCacheService.
        _baseAssetCache[categoryId] = null;
      }
    }();

    _inFlightLoads[categoryId] = loadFuture;
    try {
      await loadFuture;
    } finally {
      _inFlightLoads.remove(categoryId);
    }
  }
}
