import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/cms_models.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/cms_cache_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/question/question_pack_cache_service.dart';
import 'package:ahfad_alsahaba/data/services/question_service.dart';
import 'package:ahfad_alsahaba/logic/game_controller.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/cms/admin_level_question_manager_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/categories_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/levels_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/result/widgets/result_action_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapRtlApp(
  Widget home, {
  RouteFactory? onGenerateRoute,
}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      extensions: const [AppCustomTheme.andalusianGold],
    ),
    onGenerateRoute: onGenerateRoute,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: home,
    ),
  );
}

Future<void> _setActiveTestProfile(PlayerProfile profile) async {
  await SharedPrefsService.saveProfilesJson(
    PlayerProfile.profilesToJson([profile]),
  );
  await SharedPrefsService.setActiveProfileId(profile.id);
  await ProfileService.instance.init();
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
    AdminService().resetForTesting();
    await _setActiveTestProfile(
      PlayerProfile(id: 'p_m27', name: 'بطل الاختبار'),
    );
  });

  group('M27 — Migration 024: Level & Question Management + Coming Soon', () {
    test(
      'CmsCacheSnapshot v3 parses availability_status, level_overrides, hidden_question_ids & pack_needs_republish',
      () {
        expect(CmsCacheSnapshot.currentCacheSchemaVersion, equals(3));

        final snap = CmsCacheSnapshot.fromJson({
          'cms_version': 42,
          'cache_schema_version': 3,
          'quiz_categories': [
            {
              'id': 'quran',
              'name': 'القرآن الكريم',
              'total_levels': 20,
              'availability_status': 'open',
              'level_overrides': {
                '3': {'status': 'hidden'},
                '11': {'status': 'coming_soon', 'message': 'قريباً في رمضان ⏳'},
              },
              'hidden_question_ids': ['q_1_1', 'cloud_q_9'],
              'hidden_local_question_ids': ['q_1_1'],
              'pack_needs_republish': true,
            },
            {
              'id': 'sahaba_new',
              'name': 'الصحابة الكرام',
              'total_levels': 10,
              'availability_status': 'coming_soon',
              'coming_soon_message': 'يُفتح قريباً بإذن الله ⏳',
              'is_locked': true,
            },
          ],
        });

        final quran = snap.quizCategories['quran']!;
        expect(quran.packNeedsRepublish, isTrue);
        expect(quran.overrideForLevel(3)?.isHidden, isTrue);
        expect(quran.overrideForLevel(11)?.isComingSoon, isTrue);
        expect(quran.overrideForLevel(11)?.message, equals('قريباً في رمضان ⏳'));
        expect(quran.hiddenQuestionIds, containsAll(['q_1_1', 'cloud_q_9']));
        expect(quran.hiddenLocalQuestionIds, equals(['q_1_1']));

        final sahaba = snap.quizCategories['sahaba_new']!;
        expect(sahaba.isComingSoon, isTrue);
        expect(sahaba.comingSoonMessage, equals('يُفتح قريباً بإذن الله ⏳'));

        // Round-trip serialization preserves all 024 fields
        final roundTripped = CmsCacheSnapshot.fromJson(snap.toJson());
        expect(
          roundTripped.quizCategories['quran']!.overrideForLevel(11)?.message,
          equals('قريباً في رمضان ⏳'),
        );
        expect(
          roundTripped.quizCategories['quran']!.packNeedsRepublish,
          isTrue,
        );
      },
    );

    test(
      'QuestionService hides bundled Level 1-10 question via hiddenQuestionIds while preserving loadQuestionBySpec determinism',
      () async {
        // Capture slot 0 deterministic question ID and baseline count
        final slot0 = await QuestionService().loadQuestionBySpec(
          categoryId: 'quran',
          levelNumber: 1,
          questionIndex: 0,
        );
        expect(slot0, isNotNull);
        final targetId = slot0!.id;
        expect(targetId, isNotEmpty);

        final baseline = await QuestionService().loadQuestions(
          categoryId: 'quran',
          levelNumber: 1,
        );
        expect(baseline.any((q) => q.id == targetId), isTrue);

        // Hide that bundled question via CMS hidden_local_question_ids
        CmsCacheService.instance.setSnapshotForTesting(
          CmsCacheSnapshot(
            cmsVersion: 10,
            quizCategories: {
              'quran': DynamicQuizCategoryData(
                id: 'quran',
                name: 'القرآن الكريم',
                hiddenQuestionIds: [targetId],
                hiddenLocalQuestionIds: [targetId],
              ),
            },
          ),
        );

        final filtered = await QuestionService().loadQuestions(
          categoryId: 'quran',
          levelNumber: 1,
        );
        expect(filtered.any((q) => q.id == targetId), isFalse);
        expect(filtered.length, equals(baseline.length - 1));

        // Multiplayer/Ghost deterministic loader MUST remain 100% untouched
        final specQ = await QuestionService().loadQuestionBySpec(
          categoryId: 'quran',
          levelNumber: 1,
          questionIndex: 0,
        );
        expect(specQ, isNotNull);
        expect(specQ!.id, equals(targetId));
      },
    );

    test(
      'GameController skips hidden levels and unlocks Level 4 automatically when Level 2 is completed and Level 3 is hidden',
      () async {
        final profile = PlayerProfile(
          id: 'p_skip',
          name: 'لاعب',
          categoryProgress: {'quran': 2},
          levelStars: {'quran_1': 3, 'quran_2': 3},
        );
        await _setActiveTestProfile(profile);

        CmsCacheService.instance.setSnapshotForTesting(
          CmsCacheSnapshot(
            cmsVersion: 12,
            quizCategories: {
              'quran': DynamicQuizCategoryData(
                id: 'quran',
                name: 'القرآن الكريم',
                totalLevels: 6,
                levelOverrides: {
                  3: const LevelOverrideConfig(
                    status: CategoryAvailabilityStatus.hidden,
                  ),
                  5: const LevelOverrideConfig(
                    status: CategoryAvailabilityStatus.comingSoon,
                    message: 'المستوى 5 قادم قريباً ⏳',
                  ),
                },
              ),
              'hidden_cat': const DynamicQuizCategoryData(
                id: 'hidden_cat',
                name: 'قسم مخفي',
                availabilityStatus: 'hidden',
                isVisible: false,
              ),
            },
          ),
        );

        final ctrl = GameController();
        ctrl.initializeCategories();

        // Hidden category is excluded
        expect(ctrl.categories.any((c) => c.id == 'hidden_cat'), isFalse);

        // Levels list skips Level 3 completely
        final levels = ctrl.getLevelsForCategory('quran');
        expect(levels.map((l) => l.levelNumber).toList(), equals([1, 2, 4, 5, 6]));

        // Level 4 is unlocked because its immediately preceding visible level (2) is completed!
        final lv4 = levels.firstWhere((l) => l.levelNumber == 4);
        expect(lv4.isLocked, isFalse);

        // Level 5 is marked coming_soon & non-playable
        final lv5 = levels.firstWhere((l) => l.levelNumber == 5);
        expect(lv5.isComingSoon, isTrue);
        expect(lv5.isLocked, isTrue);
        expect(lv5.comingSoonMessage, equals('المستوى 5 قادم قريباً ⏳'));

        // resolveNextVisibleLevel skips 3 -> returns playable 4; after 4 -> returns coming_soon 5
        final nextAfter2 =
            CmsCacheService.instance.resolveNextVisibleLevel('quran', 2);
        expect(nextAfter2.levelNumber, equals(4));
        expect(nextAfter2.isPlayable, isTrue);

        final nextAfter4 =
            CmsCacheService.instance.resolveNextVisibleLevel('quran', 4);
        expect(nextAfter4.levelNumber, equals(5));
        expect(nextAfter4.isComingSoon, isTrue);
        expect(nextAfter4.isPlayable, isFalse);
      },
    );

    testWidgets(
      'CategoriesScreen (360x800 RTL) displays royal «قريباً ⏳» badge & teasing SnackBar without navigating',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        CmsCacheService.instance.setSnapshotForTesting(
          const CmsCacheSnapshot(
            cmsVersion: 15,
            quizCategories: {
              'quran': DynamicQuizCategoryData(
                id: 'quran',
                name: 'القرآن الكريم',
                availabilityStatus: 'coming_soon',
                comingSoonMessage: 'يُفتح مطلع الأسبوع القادم ⏳',
                isLocked: true,
              ),
              'hadith': DynamicQuizCategoryData(
                id: 'hadith',
                name: 'الحديث المخفي',
                availabilityStatus: 'hidden',
                isVisible: false,
              ),
            },
          ),
        );

        await tester.pumpWidget(_wrapRtlApp(const CategoriesScreen()));
        await tester.pumpAndSettle();

        expect(find.text('الحديث المخفي'), findsNothing);
        expect(find.text('القرآن الكريم'), findsOneWidget);
        expect(find.text('قريباً ⏳'), findsOneWidget);

        await tester.tap(find.text('القرآن الكريم'));
        await tester.pumpAndSettle();

        expect(find.text('يُفتح مطلع الأسبوع القادم ⏳'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LevelsScreen & ResultActionButtons (360x800 RTL) handle hidden skipping & coming_soon gracefully',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        CmsCacheService.instance.setSnapshotForTesting(
          CmsCacheSnapshot(
            cmsVersion: 18,
            quizCategories: {
              'quran': DynamicQuizCategoryData(
                id: 'quran',
                name: 'القرآن الكريم',
                totalLevels: 4,
                levelOverrides: {
                  2: const LevelOverrideConfig(
                    status: CategoryAvailabilityStatus.hidden,
                  ),
                  3: const LevelOverrideConfig(
                    status: CategoryAvailabilityStatus.comingSoon,
                    message: 'المستوى 3 قيد الإعداد ⏳',
                  ),
                },
              ),
            },
          ),
        );

        await tester.pumpWidget(
          _wrapRtlApp(const LevelsScreen(categoryId: 'quran')),
        );
        await tester.pumpAndSettle();

        expect(find.text('المستوى 2'), findsNothing);
        expect(find.text('المستوى 3'), findsOneWidget);
        expect(find.text('قريباً ⏳'), findsOneWidget);

        await tester.tap(find.text('المستوى 3'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text('المستوى 3 قيد الإعداد ⏳'),
          ),
          findsOneWidget,
        );

        // ResultActionButtons after passing Level 1: Level 2 is hidden, Level 3 is coming_soon
        String? pushedRoute;
        Map<String, dynamic>? pushedArgs;
        await tester.pumpWidget(
          _wrapRtlApp(
            const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: ResultActionButtons(
                  categoryId: 'quran',
                  currentLevelNumber: 1,
                  isPassed: true,
                  isSmall: false,
                ),
              ),
            ),
            onGenerateRoute: (settings) {
              pushedRoute = settings.name;
              pushedArgs = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute<void>(
                builder: (_) => const SizedBox.shrink(),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('المستوى القادم قريباً ⏳'), findsOneWidget);
        expect(find.text('إعادة المستوى'), findsOneWidget);
        expect(find.text('المستوى التالي'), findsNothing);

        // Tapping «المستوى القادم قريباً ⏳» shows teasing SnackBar instead of opening QuizScreen
        await tester.tap(find.text('المستوى القادم قريباً ⏳'));
        await tester.pumpAndSettle();
        expect(find.text('المستوى 3 قيد الإعداد ⏳'), findsOneWidget);
        expect(pushedRoute, isNull);

        // Now mark Level 3 open while Level 2 stays hidden -> Next button skips straight to Level 3!
        CmsCacheService.instance.setSnapshotForTesting(
          CmsCacheSnapshot(
            cmsVersion: 19,
            quizCategories: {
              'quran': DynamicQuizCategoryData(
                id: 'quran',
                name: 'القرآن الكريم',
                totalLevels: 4,
                levelOverrides: {
                  2: const LevelOverrideConfig(
                    status: CategoryAvailabilityStatus.hidden,
                  ),
                },
              ),
            },
          ),
        );
        await tester.pumpWidget(
          _wrapRtlApp(
            const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: ResultActionButtons(
                  categoryId: 'quran',
                  currentLevelNumber: 1,
                  isPassed: true,
                  isSmall: false,
                ),
              ),
            ),
            onGenerateRoute: (settings) {
              pushedRoute = settings.name;
              pushedArgs = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute<void>(
                builder: (_) => const SizedBox.shrink(),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('المستوى التالي'), findsOneWidget);
        await tester.tap(find.text('المستوى التالي'));
        await tester.pumpAndSettle();
        expect(pushedRoute, equals(AppRoutes.quiz));
        expect(pushedArgs?['levelNumber'], equals(3));
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'AdminService.bulkManageQuestions safety guard rejects unscoped delete/update calls',
      () async {
        await expectLater(
          AdminService().bulkManageQuestions(
            categoryId: 'quran',
            action: 'delete',
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    testWidgets(
      'AdminLevelQuestionManagerScreen (360x800 RTL) exercises availability save, level overrides, paginated browser, local ID hide & delete confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        Map<String, dynamic>? savedAvail;
        Map<String, dynamic>? savedLocalToggle;
        String? deletedQId;

        final admin = AdminService();
        admin.quizContentFetcherOverride = ({
          String? categoryId,
          int? levelNumber,
          int limit = 100,
        }) async {
          return (
            categories: [
              const DynamicQuizCategoryData(
                id: 'quran',
                name: 'القرآن الكريم',
                totalLevels: 12,
                availabilityStatus: 'open',
                packNeedsRepublish: true,
              ),
            ],
            questions: <DynamicQuizQuestionData>[],
          );
        };
        admin.categoryAvailabilityUpdaterOverride = (params) async {
          savedAvail = params;
          return const DynamicQuizCategoryData(
            id: 'quran',
            name: 'القرآن الكريم',
            availabilityStatus: 'coming_soon',
          );
        };
        admin.questionBrowserFetcherOverride = (params) async {
          return const AdminQuestionBrowserPage(
            totalCount: 1,
            page: 1,
            pageSize: 25,
            packNeedsRepublish: true,
            hiddenLocalQuestionIds: ['q_1_1'],
            questions: [
              DynamicQuizQuestionData(
                id: 'cloud_q_1',
                categoryId: 'quran',
                levelNumber: 11,
                questionText: 'ما أطول سورة في القرآن الكريم؟',
                options: ['البقرة', 'آل عمران', 'النساء', 'المائدة'],
                correctIndex: 0,
              ),
            ],
          );
        };
        admin.hiddenLocalQuestionTogglerOverride = (params) async {
          savedLocalToggle = params;
          return const [];
        };
        admin.questionDeleterOverride = (qid) async {
          deletedQId = qid;
          return true;
        };

        await tester.pumpWidget(
          _wrapRtlApp(const AdminLevelQuestionManagerScreen()),
        );
        await tester.pumpAndSettle();

        // Tab 1: warning banner & save availability
        expect(find.textContaining('إعادة نشر Gzip CDN'), findsOneWidget);
        await tester.tap(find.text('حفظ حالة القسم'));
        await tester.pumpAndSettle();
        expect(savedAvail?['p_category_id'], equals('quran'));

        // Switch to Tab 2: Question Browser
        await tester.tap(find.text('متصفح الأسئلة'));
        await tester.pumpAndSettle();

        final listScrollable = find.byType(Scrollable).last;
        final localChip = find.text('q_1_1');
        await tester.scrollUntilVisible(
          localChip,
          250,
          scrollable: listScrollable,
        );
        expect(localChip, findsOneWidget);

        // Unhide local ID chip
        final chipDeleteIcon = find.descendant(
          of: find.byType(InputChip),
          matching: find.byType(Icon),
        );
        await tester.ensureVisible(chipDeleteIcon);
        await tester.pumpAndSettle();
        await tester.tap(chipDeleteIcon);
        await tester.pumpAndSettle();
        expect(savedLocalToggle?['p_question_id'], equals('q_1_1'));
        expect(savedLocalToggle?['p_hide'], isFalse);

        // Scroll to cloud question & delete with confirmation dialog
        final cloudQFinder = find.text('ما أطول سورة في القرآن الكريم؟');
        await tester.scrollUntilVisible(
          cloudQFinder,
          250,
          scrollable: listScrollable,
        );
        await tester.ensureVisible(cloudQFinder);
        await tester.pumpAndSettle();
        expect(cloudQFinder, findsOneWidget);

        final delIcon = find.byIcon(Icons.delete_outline_rounded);
        await tester.ensureVisible(delIcon);
        await tester.pumpAndSettle();
        await tester.tap(delIcon);
        await tester.pumpAndSettle();
        expect(find.text('تأكيد حذف السؤال'), findsOneWidget);
        await tester.tap(find.text('تأكيد'));
        await tester.pumpAndSettle();
        expect(deletedQId, equals('cloud_q_1'));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
