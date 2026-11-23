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
import 'package:ahfad_alsahaba/data/services/question/question_pack_cache_service.dart';
import 'package:ahfad_alsahaba/data/services/question/rotating_pool_selector.dart';
import 'package:ahfad_alsahaba/data/services/question_service.dart';
import 'package:ahfad_alsahaba/logic/game_controller.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _buildSyntheticPack({
  required String categoryId,
  required int totalLevels,
  required int questionsPerLevelInBank,
}) {
  final levels = <String, List<Map<String, dynamic>>>{};
  for (var lv = 1; lv <= totalLevels; lv++) {
    final list = <Map<String, dynamic>>[];
    for (var i = 1; i <= questionsPerLevelInBank; i++) {
      final qNum = (lv - 1) * questionsPerLevelInBank + i;
      list.add({
        'id': '${categoryId}_l${lv}_q$i',
        'question': 'سؤال تاريخي إسلامي رقم $qNum في المستوى $lv من قسم $categoryId؟',
        'options': [
          'الإجابة الصحيحة رقم $qNum',
          'خيار بديل أول $qNum',
          'خيار بديل ثانٍ $qNum',
          'خيار بديل ثالث $qNum',
        ],
        'correctIndex': 0,
        'explanation': 'توضيح علمي موثق للسؤال رقم $qNum.',
        'difficulty': 'medium',
      });
    }
    levels['$lv'] = list;
  }
  return {
    'categoryId': categoryId,
    'packVersion': 1,
    'totalLevels': totalLevels,
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
      correctAnswerIndex: 0,
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
    test('1,000-question Gzip CDN pack decodes via Isolate with Magic Bytes & compact size', () async {
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
      for (final list in levels.values) {
        totalDecoded += (list as List).length;
      }

      // ignore: avoid_print
      print(
        'M24 Benchmark [1,000 questions]: raw=${rawKb.toStringAsFixed(1)}KB -> '
        'gzip=${compressedKb.toStringAsFixed(1)}KB, decode=${sw.elapsedMilliseconds}ms',
      );

      expect(levels.length, equals(40));
      expect(totalDecoded, equals(1000));
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

    test('QuestionPackCacheService caches by packVersion and falls back cleanly when offline', () async {
      var fetchCount = 0;
      final packV1 = _buildSyntheticPack(
        categoryId: 'offline_test',
        totalLevels: 3,
        questionsPerLevelInBank: 10,
      );
      final gzV1 = Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(packV1))));

      QuestionPackCacheService.instance.packBytesFetcherOverride = (path) async {
        fetchCount++;
        return gzV1;
      };

      const catV1 = DynamicQuizCategoryData(
        id: 'offline_test',
        name: 'اختبار الكاش',
        totalLevels: 3,
        packVersion: 1,
        packStoragePath: 'packs/offline_test_v1.json.gz',
      );

      final first = await QuestionPackCacheService.instance.ensurePackLoaded(catV1);
      expect(first, isNotNull);
      expect(fetchCount, equals(1));
      expect(SharedPrefsService.getCategoryPackVersion('offline_test'), equals(1));

      // Same version -> served from memory without network fetch
      final second = await QuestionPackCacheService.instance.ensurePackLoaded(catV1);
      expect(second, isNotNull);
      expect(fetchCount, equals(1));

      // Newer version fails due to offline error -> falls back cleanly to cached memory pack
      QuestionPackCacheService.instance.packBytesFetcherOverride = (path) async {
        fetchCount++;
        throw const SocketException('No internet');
      };
      const catV2 = DynamicQuizCategoryData(
        id: 'offline_test',
        name: 'اختبار الكاش',
        totalLevels: 3,
        packVersion: 2,
        packStoragePath: 'packs/offline_test_v2.json.gz',
      );
      final offlineFallback =
          await QuestionPackCacheService.instance.ensurePackLoaded(catV2);
      expect(fetchCount, equals(2));
      expect(offlineFallback, isNotNull);
      expect((offlineFallback!['levels'] as Map).length, equals(3));
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

    test('RotatingPoolSelector Auto-Reset Seen Pool guarantees ZERO duplicates per round on rollover', () {
      final pool = _buildPool(25);
      final rng = Random(42);
      var seen = <String>{};

      // Round 1: 10 unseen
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
      expect(seen.length, equals(5));

      // Round 4 & Round 5 continue cleanly with zero duplicates
      for (var round = 4; round <= 5; round++) {
        final next = RotatingPoolSelector.selectForLevel(
          pool: pool,
          questionsPerLevel: 10,
          seenIds: seen,
          random: rng,
        );
        expect(next.selected.length, equals(10));
        expect(next.selected.map((q) => q.id).toSet().length, equals(10));
        seen = next.updatedSeenIds;
      }
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
              packStoragePath: 'packs/rotating_pack_v1.json.gz',
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

    test('Unified Version Bump is 1.2.0+22', () {
      expect(AppConstants.appVersion, equals('1.2.0'));
      expect(AppConstants.appBuildNumber, equals(22));
    });
  });
}
