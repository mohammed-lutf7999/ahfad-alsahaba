import 'dart:convert';

import 'package:ahfad_alsahaba/core/app_constants.dart';
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
import 'package:flutter/services.dart';
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

  group('M25 — Full Mobile Admin Parity (Hardened 11-Point Audit)', () {
    test('BulkQuestionJsonValidator strips Windows UTF-8 BOM, rejects decimal correct indices, & keeps omitted meta fields null', () {
      // Leading UTF-8 BOM (\uFEFF) + omitted questionsPerLevel/levelDrawMode -> must stay null!
      final bomJson = '\uFEFF${jsonEncode({
        'category_id': 'seerah',
        'levels': {
          '1': [
            {
              'id': 'bom_q_01',
              'question': 'في أي سنة وقعت غزوة بدر الكبرى؟',
              'options': ['1 هـ', '2 هـ', '3 هـ', '4 هـ'],
              'correct': 1,
              'explanation': 'وقعت في رمضان سنة 2 هـ.',
            },
          ],
        },
      })}';

      final bomRes = BulkQuestionJsonValidator.parseAndValidateJsonString(bomJson);
      expect(bomRes.isValid, isTrue);
      expect(bomRes.meta?.categoryId, equals('seerah'));
      expect(bomRes.meta?.questionsPerLevel, isNull);
      expect(bomRes.meta?.levelDrawMode, isNull);
      expect(bomRes.meta?.totalLevels, isNull);

      // Strictly reject non-integer decimal like "correct": 1.5
      final decimalJson = jsonEncode([
        {
          'id': 'dec_01',
          'level_number': 1,
          'question': 'سؤال بقيمة عشرية خاطئة؟',
          'options': ['أ', 'ب', 'ج', 'د'],
          'correct': 1.5,
        },
      ]);
      final decRes = BulkQuestionJsonValidator.parseAndValidateJsonString(decimalJson);
      expect(decRes.isValid, isFalse);
      expect(decRes.errors.first, contains('فهرس الإجابة الصحيحة'));
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

    test('buildPlayersCsv includes UTF-8 BOM, strips standalone CR & blocks leading-whitespace formula injection', () {
      final players = [
        const AdminPlayerSearchResult(
          userId: 'u1',
          displayName: '  =CMD|" /C calc"!A0\rline2',
          email: ' +evil@example.com',
          playerCode: 'SAH-1234',
          totalScore: 500,
          trophies: 120,
          playerLevel: 5,
          isGuest: false,
          platform: 'android',
          appVersion: '1.2.1',
        ),
      ];
      final csv = BulkQuestionJsonValidator.buildPlayersCsv(players);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('"\'  =CMD'));
      expect(csv, contains('"\' +evil@example.com"'));
      expect(csv.contains('\r'), isFalse);
      expect(csv, contains('"SAH-1234"'));
    });

    test('AdminService.bulkUpsertQuizQuestions chunks 450 questions into 200+200+50 and rejects empty categoryId', () async {
      expect(
        () => AdminService().bulkUpsertQuizQuestions(
          categoryId: '   ',
          questions: const [],
        ),
        throwsArgumentError,
      );

      final chunkSizes = <int>[];
      final progressLog = <int>[];

      AdminService().bulkQuizQuestionsUpserterOverride = (catId, chunk) async {
        expect(catId, equals('seerah'));
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

    testWidgets('AdminBulkPackManagerScreen (RTL 360x800dp) preserves seerah config on clipboard paste, uploads, saves config & updates v2->v3 on publish', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Mock Clipboard with JSON targeting `seerah` WITHOUT questionsPerLevel/levelDrawMode
      final clipboardJson = jsonEncode({
        'categoryId': 'seerah',
        'levels': {
          '11': [
            {
              'id': 'sr_l11_q1',
              'question': 'في أي عام كان صلح الحديبية؟',
              'options': ['5 هـ', '6 هـ', '7 هـ', '8 هـ'],
              'correct': 1,
              'explanation': 'كان في ذي القعدة سنة 6 هـ.',
            },
          ],
        },
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardJson};
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

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

      String? uploadedCat;
      int uploadedCount = 0;
      Map<String, dynamic>? savedConfigParams;
      String? publishedCat;

      AdminService().bulkQuizQuestionsUpserterOverride = (catId, chunk) async {
        uploadedCat = catId;
        uploadedCount += chunk.length;
        return chunk.length;
      };
      AdminService().quizCategoryConfigUpdaterOverride = (params) async {
        savedConfigParams = params;
        return DynamicQuizCategoryData(
          id: params['p_category_id'] as String,
          name: 'السيرة النبوية',
          totalLevels: (params['p_total_levels'] as int?) ?? 20,
          questionsPerLevel: (params['p_questions_per_level'] as int?) ?? 15,
          levelDrawMode: (params['p_level_draw_mode'] as String?) ?? 'rotating_pool',
          packVersion: 2,
        );
      };
      AdminService().gzipPackPublisherOverride = (catId) async {
        publishedCat = catId;
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
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 800),
                padding: EdgeInsets.only(top: 48, bottom: 48),
              ),
              child: AdminBulkPackManagerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Paste JSON targeting `seerah` -> switches dropdown to `seerah` & preserves 20 / 15 / rotating_pool!
      await tester.scrollUntilVisible(
        find.byKey(const Key('btn_paste_json_clipboard')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_paste_json_clipboard')));
      // Wait deterministically for the real `compute(...)` Isolate to finish under any CPU load
      for (int attempt = 0; attempt < 40; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.textContaining('سؤالاً').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();

      // Scroll to action buttons and run Upload -> Save Config -> Publish Gzip
      await tester.scrollUntilVisible(
        find.byKey(const Key('btn_mobile_publish_gzip')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_mobile_bulk_upload')));
      await tester.pumpAndSettle();
      expect(uploadedCat, equals('seerah'));
      expect(uploadedCount, equals(1));

      await tester.tap(find.byKey(const Key('btn_mobile_save_config')));
      await tester.pumpAndSettle();
      expect(savedConfigParams?['p_category_id'], equals('seerah'));
      expect(savedConfigParams?['p_total_levels'], equals(20));
      expect(savedConfigParams?['p_questions_per_level'], equals(15));
      expect(savedConfigParams?['p_level_draw_mode'], equals('rotating_pool'));

      await tester.tap(find.byKey(const Key('btn_mobile_publish_gzip')));
      await tester.pumpAndSettle();
      expect(publishedCat, equals('seerah'));
      // Dropdown immediately reflects updated packVersion v3
      await tester.scrollUntilVisible(
        find.byKey(const Key('bulk_existing_category_dropdown')),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('السيرة النبوية (seerah) — v3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminPlayersSupportScreen (RTL 360x800dp) displays CSV export button cleanly', (tester) async {
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
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(360, 800),
                padding: EdgeInsets.only(top: 48, bottom: 48),
              ),
              child: AdminPlayersSupportScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_export_players_csv')), findsOneWidget);
      expect(find.text('تصدير CSV (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Unified Version Bump is 1.2.1+23', () {
      expect(AppConstants.appVersion, equals('1.2.1'));
      expect(AppConstants.appBuildNumber, equals(23));
    });
  });
}
