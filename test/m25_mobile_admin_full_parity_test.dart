import 'dart:convert';

import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/models/cms_models.dart';
import 'package:ahfad_alsahaba/data/services/admin/admin_cms_quiz_mixin.dart';
import 'package:ahfad_alsahaba/data/services/admin/bulk_question_json_validator.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/cms_cache_service.dart';
import 'package:ahfad_alsahaba/data/services/question/question_pack_cache_service.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_bulk_pack_manager_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_players_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    CmsCacheService.instance.resetForTesting();
    AdminService().resetForTesting();
  });

  group('M25 — Full Mobile Admin Parity (Bulk JSON, Gzip Publish & CSV Export)', () {
    test('BulkQuestionJsonValidator validates levels & snake_case, catches bad IDs/options/duplicates', () {
      final validJson = jsonEncode({
        'category_id': 'ghazawat',
        'category_name': 'الغزوات الكبرى',
        'total_levels': 25,
        'questions_per_level': 15,
        'level_draw_mode': 'rotating_pool',
        'levels': {
          '1': [
            {
              'id': 'ghz_001',
              'question': 'في أي سنة وقعت غزوة بدر الكبرى؟',
              'options': ['1 هـ', '2 هـ', '3 هـ', '4 هـ'],
              'correct': 1,
              'explanation': 'وقعت في رمضان سنة 2 هـ.',
              'sync_scope': 'all_with_fallback',
              'is_visible': true,
            },
            {
              'id': 'ghz_002',
              'question': 'في اي سنه وقعت غزوة بدر الكبرى؟',
              'options': ['2 هـ', '3 هـ', '4 هـ', '5 هـ'],
              'correct_index': 0,
            },
          ],
        },
      });

      final res = BulkQuestionJsonValidator.parseAndValidateJsonString(validJson);
      expect(res.isValid, isTrue);
      expect(res.errors, isEmpty);
      expect(res.normalizedQuestions.length, equals(2));
      expect(res.meta?.categoryId, equals('ghazawat'));
      expect(res.meta?.totalLevels, equals(25));
      expect(res.meta?.questionsPerLevel, equals(15));
      expect(res.meta?.levelDrawMode, equals('rotating_pool'));
      // Duplicate normalized Arabic text + missing explanation produce non-blocking warnings
      expect(res.warnings.length, greaterThanOrEqualTo(2));

      // Invalid payload: duplicate ID + empty option + out-of-range correct
      final invalidJson = jsonEncode([
        {
          'id': 'dup_01',
          'level_number': 1,
          'question': 'سؤال أول؟',
          'options': ['أ', 'ب', 'ج', ''],
          'correct': 1,
        },
        {
          'id': 'dup_02',
          'level_number': 1,
          'question': 'سؤال ثانٍ؟',
          'options': ['أ', 'ب', 'ج', 'د'],
          'correct': 5,
        },
        {
          'id': 'dup_03',
          'level_number': 1,
          'question': 'سؤال ثالث؟',
          'options': ['أ', 'ب', 'ج', 'د'],
          'correct': 0,
        },
        {
          'id': 'dup_03',
          'level_number': 2,
          'question': 'سؤال رابع؟',
          'options': ['أ', 'ب', 'ج', 'د'],
          'correct': 2,
        },
      ]);
      final bad = BulkQuestionJsonValidator.parseAndValidateJsonString(invalidJson);
      expect(bad.isValid, isFalse);
      expect(bad.errors.length, greaterThanOrEqualTo(3));
    });

    test('encodeJsonToGzipBytes produces valid Gzip Magic Bytes & round-trips through decodeQuestionPackBytes', () {
      final payload = <String, dynamic>{
        'categoryId': 'mobile_pack',
        'packVersion': 3,
        'levels': {
          '1': [
            {
              'id': 'mp_1',
              'question': 'من هو أول الخلفاء الراشدين؟',
              'options': ['أبو بكر الصديق', 'عمر بن الخطاب', 'عثمان بن عفان', 'علي بن أبي طالب'],
              'correct': 0,
            },
          ],
        },
      };
      final encoded = encodeJsonToGzipBytes(payload);
      expect(encoded.gzBytes[0], equals(0x1f));
      expect(encoded.gzBytes[1], equals(0x8b));

      final decoded = decodeQuestionPackBytes(encoded.gzBytes);
      expect(decoded['categoryId'], equals('mobile_pack'));
      expect((decoded['levels'] as Map)['1'], hasLength(1));
    });

    test('buildPlayersCsv includes UTF-8 BOM and neutralizes CSV formula injection', () {
      final players = [
        AdminPlayerSearchResult(
          userId: 'u1',
          displayName: '=CMD|" /C calc"!A0',
          email: '+evil@example.com',
          playerCode: 'SAH-1234',
          totalScore: 500,
          trophies: 120,
          playerLevel: 5,
          isGuest: false,
          platform: 'android',
          appVersion: '1.2.0',
        ),
      ];
      final csv = BulkQuestionJsonValidator.buildPlayersCsv(players);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('"\'=CMD'));
      expect(csv, contains('"\'+evil@example.com"'));
      expect(csv, contains('"SAH-1234"'));
    });

    test('AdminService.bulkUpsertQuizQuestions chunks 450 questions into 200+200+50 batches', () async {
      final chunkSizes = <int>[];
      final progressLog = <int>[];

      AdminService().bulkQuizQuestionsUpserterOverride = (catId, chunk) async {
        chunkSizes.add(chunk.length);
        return chunk.length;
      };

      final questions = List<Map<String, dynamic>>.generate(
        450,
        (i) => {
          'id': 'batch_q_$i',
          'level_number': (i ~/ 25) + 1,
          'question_text': 'سؤال دفعة $i',
          'options': const ['أ', 'ب', 'ج', 'د'],
          'correct_index': i % 4,
        },
      );

      final totalUploaded = await AdminService().bulkUpsertQuizQuestions(
        categoryId: 'seerah',
        questions: questions,
        onProgress: (done, _) => progressLog.add(done),
      );

      expect(totalUploaded, equals(450));
      expect(chunkSizes, equals([200, 200, 50]));
      expect(progressLog, equals([200, 400, 450]));
    });

    testWidgets('AdminBulkPackManagerScreen renders cleanly on 360x800dp with SafeArea and saves config / publishes pack', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CmsCacheService.instance.setSnapshotForTesting(
        const CmsCacheSnapshot(
          cmsVersion: 10,
          quizCategories: {
            'seerah': DynamicQuizCategoryData(
              id: 'seerah',
              name: 'السيرة النبوية',
              totalLevels: 20,
              questionsPerLevel: 15,
              levelDrawMode: 'rotating_pool',
              packVersion: 2,
              packStoragePath: 'seerah_v2.json.gz',
            ),
          },
        ),
      );

      var configSaved = false;
      var packPublished = false;
      AdminService().quizCategoryConfigUpdaterOverride = (params) async {
        configSaved = true;
        return DynamicQuizCategoryData(
          id: params['p_category_id'] as String,
          name: 'السيرة النبوية',
          totalLevels: (params['p_total_levels'] as int?) ?? 20,
          questionsPerLevel: (params['p_questions_per_level'] as int?) ?? 15,
          levelDrawMode: (params['p_level_draw_mode'] as String?) ?? 'rotating_pool',
        );
      };
      AdminService().gzipPackPublisherOverride = (catId) async {
        packPublished = true;
        return AdminGzipPackPublishResult(
          categoryId: catId,
          storagePath: '${catId}_v3.json.gz',
          packVersion: 3,
          questionsCount: 250,
          rawBytesLength: 96000,
          gzipBytesLength: 14200,
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppCustomTheme.andalusianGold],
          ),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              padding: EdgeInsets.only(top: 48, bottom: 48),
            ),
            child: AdminBulkPackManagerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_pick_json_file')), findsOneWidget);
      expect(find.byKey(const Key('btn_paste_json_clipboard')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('btn_mobile_publish_gzip')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_mobile_save_config')));
      await tester.pumpAndSettle();
      expect(configSaved, isTrue);

      await tester.tap(find.byKey(const Key('btn_mobile_publish_gzip')));
      await tester.pumpAndSettle();
      expect(packPublished, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminPlayersSupportScreen displays CSV export button cleanly on 360x800dp', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AdminService().userSearcherOverride = ({required String query, int limit = 20}) async {
        return const [
          AdminPlayerSearchResult(
            userId: 'u1',
            displayName: 'فارس القادسية',
            email: 'faris@example.com',
            playerCode: 'SAH-9988',
            totalScore: 1200,
            trophies: 320,
            playerLevel: 8,
            isGuest: false,
          ),
        ];
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AppCustomTheme.andalusianGold],
          ),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              padding: EdgeInsets.only(top: 48, bottom: 48),
            ),
            child: AdminPlayersSupportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_export_players_csv')), findsOneWidget);
      expect(find.text('تصدير CSV (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
