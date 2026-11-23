import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ahfad_alsahaba/core/app_constants.dart';
import 'package:ahfad_alsahaba/core/cms_icon_registry.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/category_model.dart';
import 'package:ahfad_alsahaba/data/models/cms_models.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/models/question_model.dart';
import 'package:ahfad_alsahaba/data/services/cms_cache_service.dart';
import 'package:ahfad_alsahaba/data/services/question/question_cms_merger.dart';
import 'package:ahfad_alsahaba/data/services/question/question_pack_cache_service.dart';
import 'package:ahfad_alsahaba/data/services/question/rotating_pool_selector.dart';
import 'package:ahfad_alsahaba/data/services/question_service.dart';
import 'package:ahfad_alsahaba/logic/game_controller.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _buildSyntheticPack({
  required String categoryId,
  int startLevel = 1,
  required int totalLevels,
  required int questionsPerLevelInBank,
}) {
  final levels = <String, List<Map<String, dynamic>>>{};
  for (var lv = startLevel; lv < startLevel + totalLevels; lv++) {
    final list = <Map<String, dynamic>>[];
    for (var i = 0; i < questionsPerLevelInBank; i++) {
      final qNum = (lv - 1) * questionsPerLevelInBank + i + 1;
      final correctIdx = i % 4;
      list.add({
        'id': '${categoryId}_l${lv}_q${i + 1}',
        'question': 'سؤال تاريخي إسلامي رقم $qNum في المستوى $lv من قسم $categoryId؟',
        'options': [
          'خيار 0 للسؤال $qNum',
          'خيار 1 للسؤال $qNum',
          'خيار 2 للسؤال $qNum',
          'خيار 3 للسؤال $qNum',
        ],
        // Matches `admin_export_category_pack_payload` contract (`correct` = 0..3)
        'correct': correctIdx,
        'explanation': 'توضيح علمي موثق للسؤال رقم $qNum.',
        'difficulty': 'medium',
      });
    }
    levels['$lv'] = list;
  }
  return {
    'categoryId': categoryId,
    'packVersion': 1,
    'totalLevels': startLevel + totalLevels - 1,
    'questionsPerLevel': questionsPerLevelInBank,
    'levelDrawMode': 'rotating_pool',
    'levels': levels,
  };
}

List<Question> _buildPool(int count, {String prefix = 'q'}) {
  return List<Question>.generate(
    count,
    (i) => Question(
      id: '${prefix}_${i + 1}',
      categoryId: 'sahaba_mega',
      levelNumber: 1,
      questionText: 'سؤال ${i + 1}',
      options: const ['أ', 'ب', 'ج', 'د'],
      correctAnswerIndex: i % 4,
      explanation: 'شرح ${i + 1}',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    CmsCacheService.instance.resetForTesting();
    QuestionPackCacheService.instance.resetForTesting();
    QuestionPackCacheService.instance.disableDiskCacheForTesting = true;
    QuestionService().clearCache();
  });

  group('M24 — Plan 20: Gzip CDN Packs, Dynamic Levels & Rotating Pool', () {
    test('1,000-question Gzip CDN pack decodes via Isolate with Magic Bytes, compact size & real correct indices (0..3)', () async {
      final packMap = _buildSyntheticPack(
        categoryId: 'mega_sahaba',
        totalLevels: 40,
        questionsPerLevelInBank: 25,
      );
      final rawJsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(packMap)));
      final gzBytes = Uint8List.fromList(gzip.encode(rawJsonBytes));

      // Verify Gzip Magic Bytes 0x1f 0x8b
      expect(gzBytes.length, greaterThan(2));
      expect(gzBytes[0], equals(0x1f));
      expect(gzBytes[1], equals(0x8b));

      final compressedKb = gzBytes.length / 1024.0;
      final rawKb = rawJsonBytes.length / 1024.0;
      expect(compressedKb, lessThan(120.0));
      expect(gzBytes.length, lessThan(rawJsonBytes.length));

      final sw = Stopwatch()..start();
      final decoded = await compute(decodeQuestionPackBytes, gzBytes);
      sw.stop();

      final levels = decoded['levels'] as Map<String, dynamic>;
      var totalDecoded = 0;
      final seenCorrectIndices = <int>{};
      for (final entry in levels.entries) {
        final lv = int.parse(entry.key);
        for (final rawQ in (entry.value as List)) {
          totalDecoded++;
          final mapped = QuestionCmsMerger.mapQuestionEntry(
            Map<String, dynamic>.from(rawQ as Map),
            categoryId: 'mega_sahaba',
            levelNumber: lv,
            optionRandom: null,
          );
          seenCorrectIndices.add(mapped.correctAnswerIndex);
        }
      }

      // ignore: avoid_print
      print(
        'M24 Benchmark [1,000 questions]: raw=${rawKb.toStringAsFixed(1)}KB -> '
        'gzip=${compressedKb.toStringAsFixed(1)}KB, decode=${sw.elapsedMilliseconds}ms',
      );

      expect(levels.length, equals(40));
      expect(totalDecoded, equals(1000));
      // Explicit contract check: `correct` produces real 0, 1, 2, 3 values (never stuck at 0)
      expect(seenCorrectIndices, equals({0, 1, 2, 3}));
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    test('decodeQuestionPackBytes handles plain UTF-8 JSON safely (prevents Double-Gzip crash)', () {
      final payload = _buildSyntheticPack(
        categoryId: 'plain_cat',
        totalLevels: 2,
        questionsPerLevelInBank: 5,
      );
      final plainBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      expect(plainBytes[0] == 0x1f && plainBytes[1] == 0x8b, isFalse);

      final decoded = decodeQuestionPackBytes(plainBytes);
      expect(decoded['categoryId'], equals('plain_cat'));
      expect((decoded['levels'] as Map).length, equals(2));
    });

    test('QuestionPackCacheService caches by packVersion, uses exact storagePath & falls back cleanly on offline/502 HTML/corrupt bytes', () async {
      var fetchCount = 0;
      String? requestedPath;
      final packV1 = _buildSyntheticPack(
        categoryId: 'offline_test',
        totalLevels: 3,
        questionsPerLevelInBank: 10,
      );
      final gzV1 = Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(packV1))));

      QuestionPackCacheService.instance.packBytesFetcherOverride = (path) async {
        fetchCount++;
        requestedPath = path;
        return gzV1;
      };

      const catV1 = DynamicQuizCategoryData(
        id: 'offline_test',
        name: 'اختبار الكاش',
        totalLevels: 3,
        packVersion: 1,
        packStoragePath: 'offline_test_v1.json.gz',
      );

      final first = await QuestionPackCacheService.instance.ensurePackLoaded(catV1);
      expect(first, isNotNull);
      expect(fetchCount, equals(1));
      expect(requestedPath, equals('offline_test_v1.json.gz'));
      expect(SharedPrefsService.getCategoryPackVersion('offline_test'), equals(1));

      // Same version -> served from memory without network fetch
      final second = await QuestionPackCacheService.instance.ensurePackLoaded(catV1);
      expect(second, isNotNull);
      expect(fetchCount, equals(1));

      // Newer version fails due to SocketException -> falls back cleanly to cached v1 pack
      QuestionPackCacheService.instance.packBytesFetcherOverride = (path) async {
        fetchCount++;
        throw const SocketException('No internet');
      };
      const catV2 = DynamicQuizCategoryData(
        id: 'offline_test',
        name: 'اختبار الكاش',
        totalLevels: 3,
        packVersion: 2,
        packStoragePath: 'offline_test_v2.json.gz',
      );
      final offlineFallback =
          await QuestionPackCacheService.instance.ensurePackLoaded(catV2);
      expect(fetchCount, equals(2));
      expect(offlineFallback, isNotNull);
      expect((offlineFallback!['levels'] as Map).length, equals(3));

      // HTML 502 Bad Gateway response -> safe fallback without crash
      QuestionPackCacheService.instance.resetForTesting();
      QuestionPackCacheService.instance.disableDiskCacheForTesting = true;
      QuestionPackCacheService.instance.packBytesFetcherOverride = (_) async =>
          Uint8List.fromList(utf8.encode('<html><body>502 Bad Gateway</body></html>'));
      const htmlCat = DynamicQuizCategoryData(
        id: 'bad_502_cat',
        name: 'اختبار 502',
        totalLevels: 2,
        packVersion: 1,
        packStoragePath: 'bad_502_cat_v1.json.gz',
      );
      final htmlResult =
          await QuestionPackCacheService.instance.ensurePackLoaded(htmlCat);
      expect(htmlResult, isNull);

      // Corrupted Gzip bytes (valid magic bytes 0x1f 0x8b followed by garbage) -> safe fallback
      QuestionPackCacheService.instance.packBytesFetcherOverride = (_) async =>
          Uint8List.fromList([0x1f, 0x8b, 0x08, 0xff, 0x00, 0xde, 0xad, 0xbe, 0xef]);
      final corruptResult =
          await QuestionPackCacheService.instance.ensurePackLoaded(htmlCat);
      expect(corruptResult, isNull);
    });

    test('Gzip pack merges cleanly over legacy assets/questions/quran.json (levels 1-10 intact + levels 11-20 added)', () async {
      // Pack contains ONLY cloud-added levels 11..20 for built-in `quran` category
      final extraPack = _buildSyntheticPack(
        categoryId: 'quran',
        startLevel: 11,
        totalLevels: 10,
        questionsPerLevelInBank: 10,
      );
      final gzBytes =
          Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(extraPack))));
      QuestionPackCacheService.instance.packBytesFetcherOverride =
          (_) async => gzBytes;

      CmsCacheService.instance.setSnapshotForTesting(
        const CmsCacheSnapshot(
          cmsVersion: 20,
          quizCategories: {
            'quran': DynamicQuizCategoryData(
              id: 'quran',
              name: 'القرآن الكريم',
              totalLevels: 20,
              questionsPerLevel: 10,
              levelDrawMode: 'fixed',
              packVersion: 1,
              packStoragePath: 'quran_v1.json.gz',
            ),
          },
        ),
      );

      final qs = QuestionService();
      // Legacy built-in levels 1 and 10 from assets/questions/quran.json MUST remain intact!
      final level1 = await qs.loadQuestions(categoryId: 'quran', levelNumber: 1);
      final level10 = await qs.loadQuestions(categoryId: 'quran', levelNumber: 10);
      expect(level1.length, equals(10));
      expect(level10.length, equals(10));

      // New levels 11 and 20 MUST load seamlessly from the Gzip pack!
      final level11 = await qs.loadQuestions(categoryId: 'quran', levelNumber: 11);
      final level20 = await qs.loadQuestions(categoryId: 'quran', levelNumber: 20);
      expect(level11.length, equals(10));
      expect(level20.length, equals(10));
      expect(level11.first.id, startsWith('quran_l11_'));
      expect(level20.first.id, startsWith('quran_l20_'));

      // Verify `correct` contract preserved across loadAllQuestionsForCategory (without option shuffle)
      final allUnshuffled = await qs.loadAllQuestionsForCategory(
        'quran',
        shuffleQuestions: false,
        shuffleOptions: false,
      );
      final level11Unshuffled =
          allUnshuffled.where((q) => q.levelNumber == 11).toList();
      expect(
        level11Unshuffled.map((q) => q.correctAnswerIndex).toSet(),
        equals({0, 1, 2, 3}),
      );
    });

    test('Backward compatibility: legacy 10-level categories & JSON payloads default safely', () {
      final legacyCat = DynamicQuizCategoryData.fromJson({
        'id': 'quran',
        'name': 'القرآن الكريم',
        'total_levels': 10,
      });
      expect(legacyCat.totalLevels, equals(10));
      expect(legacyCat.questionsPerLevel, equals(10));
      expect(legacyCat.levelDrawMode, equals('fixed'));
      expect(legacyCat.packVersion, equals(0));
      expect(legacyCat.packStoragePath, isEmpty);

      expect(CmsCategoryBounds.maxLevelsFor('quran'), equals(10));
      expect(CmsCategoryBounds.questionsPerLevelFor('quran'), equals(10));
      expect(CmsCategoryBounds.drawModeFor('quran'), equals('fixed'));

      final legacyCategoryModel = Category.fromJson({
        'id': 'quran',
        'name': 'القرآن الكريم',
        'description': 'وصف',
        'iconCodePoint': Icons.menu_book.codePoint,
        'totalLevels': 10,
      });
      expect(legacyCategoryModel.questionsPerLevel, equals(10));
      expect(legacyCategoryModel.levelDrawMode, equals('fixed'));
    });

    test('Flexible Dynamic Levels (20, 30, 40 levels x 20 questions/level) across Bounds, GameController & Profile', () {
      CmsCacheService.instance.setSnapshotForTesting(
        CmsCacheSnapshot(
          cmsVersion: 12,
          quizCategories: {
            'cat_20': const DynamicQuizCategoryData(
              id: 'cat_20',
              name: 'سيرة 20',
              totalLevels: 20,
              questionsPerLevel: 20,
              levelDrawMode: 'fixed',
            ),
            'cat_30': const DynamicQuizCategoryData(
              id: 'cat_30',
              name: 'فقه 30',
              totalLevels: 30,
              questionsPerLevel: 20,
              levelDrawMode: 'rotating_pool',
            ),
            'cat_40': const DynamicQuizCategoryData(
              id: 'cat_40',
              name: 'تاريخ 40',
              totalLevels: 40,
              questionsPerLevel: 20,
              levelDrawMode: 'rotating_pool',
            ),
          },
        ),
      );

      expect(CmsCategoryBounds.maxLevelsFor('cat_20'), equals(20));
      expect(CmsCategoryBounds.questionsPerLevelFor('cat_20'), equals(20));
      expect(CmsCategoryBounds.drawModeFor('cat_20'), equals('fixed'));

      expect(CmsCategoryBounds.maxLevelsFor('cat_30'), equals(30));
      expect(CmsCategoryBounds.drawModeFor('cat_30'), equals('rotating_pool'));

      expect(CmsCategoryBounds.maxLevelsFor('cat_40'), equals(40));
      expect(CmsCategoryBounds.questionsPerLevelFor('cat_40'), equals(20));

      final gc = GameController();
      gc.initializeCategories();
      final levels40 = gc.getLevelsForCategory('cat_40');
      expect(levels40.length, equals(40));
      expect(levels40.first.totalQuestions, equals(20));
      expect(levels40.last.levelNumber, equals(40));

      final profile = PlayerProfile(
        id: 'p1',
        name: 'أنس',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      profile.setCategoryUnlockedLevels('cat_40', 35);
      expect(profile.getCategoryUnlockedLevels('cat_40'), equals(35));
      profile.setCategoryUnlockedLevels('cat_40', 99);
      expect(profile.getCategoryUnlockedLevels('cat_40'), equals(40));
    });

    test('RotatingPoolSelector Auto-Reset Seen Pool guarantees ZERO duplicates, prevents immediate repeat of remaining5, & preserves state on empty pool', () async {
      final pool = _buildPool(25);
      final rng = Random(42);
      var seen = <String>{'stale_deleted_id_999'};

      // Round 1: 10 unseen (stale_deleted_id_999 pruned automatically)
      final r1 = RotatingPoolSelector.selectForLevel(
        pool: pool,
        questionsPerLevel: 10,
        seenIds: seen,
        random: rng,
      );
      expect(r1.selected.length, equals(10));
      expect(r1.selected.map((q) => q.id).toSet().length, equals(10));
      expect(r1.didResetPool, isFalse);
      seen = r1.updatedSeenIds;
      expect(seen.length, equals(10));
      expect(seen.contains('stale_deleted_id_999'), isFalse);

      // Round 2: 10 unseen (completely disjoint from Round 1)
      final r2 = RotatingPoolSelector.selectForLevel(
        pool: pool,
        questionsPerLevel: 10,
        seenIds: seen,
        random: rng,
      );
      expect(r2.selected.length, equals(10));
      expect(r2.selected.map((q) => q.id).toSet().length, equals(10));
      expect(
        r2.selected.map((q) => q.id).toSet().intersection(
              r1.selected.map((q) => q.id).toSet(),
            ),
        isEmpty,
      );
      expect(r2.didResetPool, isFalse);
      seen = r2.updatedSeenIds;
      expect(seen.length, equals(20));

      // Remaining 5 unseen IDs before Round 3 rollover
      final remaining5 = pool.map((q) => q.id).toSet().difference(seen);
      expect(remaining5.length, equals(5));

      // Round 3: takes all 5 remaining unseen + resets pool + fills 5 without ANY duplicate!
      final r3 = RotatingPoolSelector.selectForLevel(
        pool: pool,
        questionsPerLevel: 10,
        seenIds: seen,
        random: rng,
      );
      final r3Ids = r3.selected.map((q) => q.id).toList();
      expect(r3.selected.length, equals(10));
      expect(r3Ids.toSet().length, equals(10), reason: 'Zero duplicates in rollover round');
      expect(r3Ids.toSet().containsAll(remaining5), isTrue);
      expect(r3.didResetPool, isTrue);
      seen = r3.updatedSeenIds;
      // ALL 10 questions played in r3 are now marked seen (NOT just refill 5)
      expect(seen.length, equals(10));
      expect(seen.containsAll(remaining5), isTrue);

      // Round 4 MUST NOT immediately repeat ANY of remaining5 (or any r3 question!)
      final r4 = RotatingPoolSelector.selectForLevel(
        pool: pool,
        questionsPerLevel: 10,
        seenIds: seen,
        random: rng,
      );
      final r4Ids = r4.selected.map((q) => q.id).toSet();
      expect(r4Ids.length, equals(10));
      expect(r4Ids.intersection(remaining5), isEmpty);
      expect(r4Ids.intersection(r3Ids.toSet()), isEmpty);
      expect(r4.didResetPool, isFalse);

      // Empty pool MUST preserve existing seenIds in both pure & SharedPrefs wrappers
      final emptyRes = RotatingPoolSelector.selectForLevel(
        pool: const [],
        questionsPerLevel: 10,
        seenIds: seen,
        random: rng,
      );
      expect(emptyRes.selected, isEmpty);
      expect(emptyRes.updatedSeenIds, equals(seen));

      await SharedPrefsService.setRotatingPoolSeenIds('preserve_cat', 1, {'a', 'b'});
      final persistedEmpty = await RotatingPoolSelector.selectAndPersist(
        categoryId: 'preserve_cat',
        levelNumber: 1,
        pool: const [],
        questionsPerLevel: 10,
      );
      expect(persistedEmpty, isEmpty);
      expect(
        SharedPrefsService.getRotatingPoolSeenIds('preserve_cat', 1),
        equals({'a', 'b'}),
      );

      // Duplicate IDs inside pool are deduplicated defensively
      final dupPool = [pool[0], pool[0], pool[1], pool[1], pool[2]];
      final dedupRes = RotatingPoolSelector.selectForLevel(
        pool: dupPool,
        questionsPerLevel: 5,
        seenIds: const {},
        random: rng,
      );
      expect(dedupRes.selected.length, equals(3));
      expect(dedupRes.selected.map((q) => q.id).toSet().length, equals(3));
    });

    test('QuestionService integrates Gzip pack + rotating_pool persistence end-to-end', () async {
      final pack = _buildSyntheticPack(
        categoryId: 'rotating_pack',
        totalLevels: 2,
        questionsPerLevelInBank: 15,
      );
      final gzBytes = Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(pack))));
      QuestionPackCacheService.instance.packBytesFetcherOverride =
          (_) async => gzBytes;

      CmsCacheService.instance.setSnapshotForTesting(
        const CmsCacheSnapshot(
          cmsVersion: 15,
          quizCategories: {
            'rotating_pack': DynamicQuizCategoryData(
              id: 'rotating_pack',
              name: 'حزمة متجددة',
              totalLevels: 2,
              questionsPerLevel: 10,
              levelDrawMode: 'rotating_pool',
              packVersion: 1,
              packStoragePath: 'rotating_pack_v1.json.gz',
            ),
          },
        ),
      );

      final qs = QuestionService();
      final round1 = await qs.loadQuestions(
        categoryId: 'rotating_pack',
        levelNumber: 1,
      );
      expect(round1.length, equals(10));
      expect(round1.map((q) => q.id).toSet().length, equals(10));

      final round2 = await qs.loadQuestions(
        categoryId: 'rotating_pack',
        levelNumber: 1,
      );
      expect(round2.length, equals(10));
      expect(round2.map((q) => q.id).toSet().length, equals(10));

      // Verify all 15 questions were covered across Round 1 + Round 2 rollover
      final unionIds = {
        ...round1.map((q) => q.id),
        ...round2.map((q) => q.id),
      };
      expect(unionIds.length, equals(15));
    });

    test('CmsCacheService cache_schema_version=2 forces one-time upgrade sync, prunes packed quizQuestions & restricts v1 fallback to PGRST202/42883', () async {
      // 1. Seed a legacy 1.1.0+21 cache (no `cache_schema_version` -> defaults to 1)
      //    with cms_version = 10 and a raw question belonging to a category that will become packed.
      await SharedPrefsService.setCachedCmsVersion(10);
      await SharedPrefsService.setCachedCmsBundleJson(
        jsonEncode({
          'cms_version': 10,
          'store_items': [],
          'library_sections': [],
          'library_items': [],
          'quiz_categories': [
            {'id': 'seerah', 'name': 'السيرة النبوية', 'total_levels': 10},
            {'id': 'fiqh', 'name': 'الفقه', 'total_levels': 10},
          ],
          'quiz_questions': [
            {
              'id': 'raw_seerah_1',
              'category_id': 'seerah',
              'level_number': 1,
              'question_text': 'سؤال خام قديم للسيرة؟',
              'options': ['أ', 'ب', 'ج', 'د'],
              'correct_index': 1,
            },
            {
              'id': 'raw_fiqh_1',
              'category_id': 'fiqh',
              'level_number': 1,
              'question_text': 'سؤال خام للفقه بدون حزمة؟',
              'options': ['أ', 'ب', 'ج', 'د'],
              'correct_index': 2,
            },
          ],
        }),
      );

      await CmsCacheService.instance.initFromCache();
      expect(CmsCacheService.instance.snapshot.cacheSchemaVersion, equals(1));
      expect(CmsCacheService.instance.snapshot.cmsVersion, equals(10));

      int? requestedClientVer;
      var syncCalls = 0;
      CmsCacheService.instance.bundleFetcherOverride = ({
        required int clientCmsVersion,
        required List<String> ownedItemIds,
      }) async {
        syncCalls++;
        requestedClientVer = clientCmsVersion;
        return {
          'changed': true,
          'incremental': false,
          'cms_version': 10,
          'store_items': [],
          'library_sections': [],
          'library_items': [],
          'quiz_categories': [
            {
              'id': 'seerah',
              'name': 'السيرة النبوية',
              'total_levels': 20,
              'questions_per_level': 15,
              'level_draw_mode': 'rotating_pool',
              'pack_version': 1,
              'pack_storage_path': 'seerah_v1.json.gz',
            },
            {
              'id': 'fiqh',
              'name': 'الفقه',
              'total_levels': 10,
              'pack_version': 0,
              'pack_storage_path': '',
            },
          ],
          // Even if a fallback payload still included a raw question for packed `seerah`,
          // mergeBundle MUST prune it while keeping unpacked `fiqh`!
          'quiz_questions': [
            {
              'id': 'raw_seerah_1',
              'category_id': 'seerah',
              'level_number': 1,
              'question_text': 'سؤال خام قديم للسيرة؟',
              'options': ['أ', 'ب', 'ج', 'د'],
              'correct_index': 1,
            },
            {
              'id': 'raw_fiqh_1',
              'category_id': 'fiqh',
              'level_number': 1,
              'question_text': 'سؤال خام للفقه بدون حزمة؟',
              'options': ['أ', 'ب', 'ج', 'د'],
              'correct_index': 2,
            },
          ],
        };
      };

      // Even though serverCmsVersion == 10 (same as cached), schema_version < 2 MUST force full sync (clientVer = 0)
      final didSync = await CmsCacheService.instance.syncIfNeeded(
        serverCmsVersion: 10,
      );
      expect(didSync, isTrue);
      expect(syncCalls, equals(1));
      expect(requestedClientVer, equals(0));
      expect(
        CmsCacheService.instance.snapshot.cacheSchemaVersion,
        equals(CmsCacheSnapshot.currentCacheSchemaVersion),
      );
      // Packed category raw questions pruned; unpacked category raw questions preserved
      expect(
        CmsCacheService.instance.snapshot.quizQuestions.containsKey('raw_seerah_1'),
        isFalse,
      );
      expect(
        CmsCacheService.instance.snapshot.quizQuestions.containsKey('raw_fiqh_1'),
        isTrue,
      );

      // Subsequent sync with same cmsVersion=10 is skipped cleanly (no redundant network call)
      final secondSync = await CmsCacheService.instance.syncIfNeeded(
        serverCmsVersion: 10,
      );
      expect(secondSync, isFalse);
      expect(syncCalls, equals(1));

      // Incremental merge when `fiqh` later publishes a pack MUST also prune `raw_fiqh_1`
      final afterIncrementalPack = CmsCacheService.instance.snapshot.mergeBundle(
        {
          'changed': true,
          'incremental': true,
          'cms_version': 11,
          'quiz_categories': [
            {
              'id': 'fiqh',
              'name': 'الفقه',
              'total_levels': 15,
              'pack_version': 1,
              'pack_storage_path': 'fiqh_v1.json.gz',
            },
          ],
          'quiz_questions': [],
        },
        DateTime.utc(2026, 11, 23),
      );
      expect(afterIncrementalPack.quizQuestions.containsKey('raw_fiqh_1'), isFalse);

      // 2. Verify v1 fallback guard ONLY triggers for PGRST202 / 42883 (never timeouts or network errors)
      expect(
        CmsCacheService.isCmsV2MissingError(
          const PostgrestException(message: 'Not found', code: 'PGRST202'),
        ),
        isTrue,
      );
      expect(
        CmsCacheService.isCmsV2MissingError(
          const PostgrestException(message: 'Undefined function', code: '42883'),
        ),
        isTrue,
      );
      expect(
        CmsCacheService.isCmsV2MissingError(
          const PostgrestException(message: 'Permission denied', code: '42501'),
        ),
        isFalse,
      );
      expect(
        CmsCacheService.isCmsV2MissingError(TimeoutException('timeout')),
        isFalse,
      );
      expect(
        CmsCacheService.isCmsV2MissingError(const SocketException('offline')),
        isFalse,
      );
    });

    test('Unified Version Bump is 1.2.0+22', () {
      expect(AppConstants.appVersion, equals('1.2.0'));
      expect(AppConstants.appBuildNumber, equals(22));
    });
  });
}
