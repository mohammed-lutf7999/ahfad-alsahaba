import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/supabase_config.dart';
import '../../local/shared_prefs_service.dart';
import '../../models/cms_models.dart';

/// Top-level Isolate function decoding either raw Gzipped bytes (verified by
/// Gzip Magic Bytes `0x1f 0x8b`) or plain UTF-8 JSON bytes into a Map.
/// Prevents Double-Gzip corruption if a CDN or proxy serves plain JSON.
Map<String, dynamic> decodeQuestionPackBytes(Uint8List bytes) {
  final bool isGzip =
      bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  final List<int> rawJsonBytes = isGzip ? gzip.decode(bytes) : bytes;
  final String jsonStr = utf8.decode(rawJsonBytes);
  final dynamic decoded = jsonDecode(jsonStr);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return <String, dynamic>{};
}

typedef QuestionPackBytesFetcher = Future<Uint8List?> Function(
  String storagePath,
);

/// Offline-first, version-gated Gzip CDN Question Pack cache service (Plan 20).
///
/// - Downloads `.json.gz` packs from public Supabase Storage `question-packs`
///   bucket ONLY when `category.packVersion > cachedPackVersion`.
/// - Decodes Gzip via Magic Bytes check inside an Isolate (`compute`).
/// - Persists decoded JSON locally so subsequent launches work 100% offline
///   with zero PostgreSQL queries.
class QuestionPackCacheService {
  static final QuestionPackCacheService instance =
      QuestionPackCacheService._internal();
  QuestionPackCacheService._internal();

  final Map<String, Map<String, dynamic>> _memoryCache = {};
  final Map<String, Future<Map<String, dynamic>?>> _inFlightDownloads = {};

  @visibleForTesting
  QuestionPackBytesFetcher? packBytesFetcherOverride;

  @visibleForTesting
  bool disableDiskCacheForTesting = false;

  @visibleForTesting
  void resetForTesting() {
    _memoryCache.clear();
    _inFlightDownloads.clear();
    packBytesFetcherOverride = null;
    disableDiskCacheForTesting = false;
  }

  /// Synchronous memory lookup for an already hydrated pack.
  Map<String, dynamic>? getCachedPackInMemory(String categoryId) =>
      _memoryCache[categoryId];

  /// Clears in-memory pack cache (for testing or forced reload).
  void clearMemoryCache([String? categoryId]) {
    if (categoryId != null) {
      _memoryCache.remove(categoryId);
    } else {
      _memoryCache.clear();
    }
  }

  /// Ensures the latest pack for [category] is hydrated in memory & disk when
  /// `packVersion > 0` and `packStoragePath` is non-empty.
  /// Always falls back safely to local disk cache or `null` when offline.
  Future<Map<String, dynamic>?> ensurePackLoaded(
    DynamicQuizCategoryData category,
  ) async {
    final catId = category.id.trim();
    if (catId.isEmpty ||
        category.packVersion <= 0 ||
        category.packStoragePath.trim().isEmpty) {
      return null;
    }

    final cachedVersion = SharedPrefsService.getCategoryPackVersion(catId);
    if (cachedVersion >= category.packVersion) {
      if (_memoryCache.containsKey(catId)) {
        return _memoryCache[catId];
      }
      final fromDisk = await _readPackFromDisk(catId);
      if (fromDisk != null) {
        _memoryCache[catId] = fromDisk;
        return fromDisk;
      }
    }

    final inFlight = _inFlightDownloads[catId];
    if (inFlight != null) return inFlight;

    final task = _downloadAndCachePack(category);
    _inFlightDownloads[catId] = task;
    try {
      return await task;
    } finally {
      _inFlightDownloads.remove(catId);
    }
  }

  Future<Map<String, dynamic>?> _downloadAndCachePack(
    DynamicQuizCategoryData category,
  ) async {
    final catId = category.id.trim();
    final path = category.packStoragePath.trim();
    try {
      final Uint8List? bytes = packBytesFetcherOverride != null
          ? await packBytesFetcherOverride!(path)
          : await _fetchPackBytesFromStorage(path);
      if (bytes == null || bytes.isEmpty) {
        return _fallbackToLocalDisk(catId);
      }

      final Map<String, dynamic> decoded =
          await compute(decodeQuestionPackBytes, bytes);
      if (decoded.isEmpty || decoded['levels'] is! Map) {
        return _fallbackToLocalDisk(catId);
      }

      _memoryCache[catId] = decoded;
      await _writePackToDisk(catId, decoded);
      await SharedPrefsService.setCategoryPackVersion(
        catId,
        category.packVersion,
      );
      return decoded;
    } catch (e) {
      debugPrint('QuestionPackCacheService offline fallback for $catId: $e');
      return _fallbackToLocalDisk(catId);
    }
  }

  Future<Map<String, dynamic>?> _fallbackToLocalDisk(String catId) async {
    if (_memoryCache.containsKey(catId)) return _memoryCache[catId];
    final diskPack = await _readPackFromDisk(catId);
    if (diskPack != null) {
      _memoryCache[catId] = diskPack;
    }
    return diskPack;
  }

  Future<Uint8List?> _fetchPackBytesFromStorage(String storagePath) async {
    final cleanPath = storagePath.replaceFirst(RegExp(r'^/+'), '');
    final uri = Uri.parse(
      '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/question-packs/$cleanPath',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..autoUncompress = false;
    try {
      final request = await client.getUrl(uri).timeout(
            const Duration(seconds: 8),
          );
      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode != 200) {
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  Future<File?> _packFile(String catId) async {
    if (kIsWeb || disableDiskCacheForTesting) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final packsDir = Directory('${dir.path}${Platform.pathSeparator}question_packs');
      if (!await packsDir.exists()) {
        await packsDir.create(recursive: true);
      }
      return File('${packsDir.path}${Platform.pathSeparator}$catId.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePackToDisk(
    String catId,
    Map<String, dynamic> decoded,
  ) async {
    final file = await _packFile(catId);
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode(decoded), flush: true);
    } catch (e) {
      debugPrint('QuestionPackCacheService write notice: $e');
    }
  }

  Future<Map<String, dynamic>?> _readPackFromDisk(String catId) async {
    final file = await _packFile(catId);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
