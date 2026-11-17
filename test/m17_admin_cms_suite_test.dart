import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/models/category_model.dart';
import 'package:ahfad_alsahaba/data/models/cms_models.dart';
import 'package:ahfad_alsahaba/data/models/store_item_model.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/data/services/cloud_sync_service.dart';
import 'package:ahfad_alsahaba/data/services/cms_cache_service.dart';
import 'package:ahfad_alsahaba/data/services/store_service.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_cms_manager_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_players_support_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_telemetry_security_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin_dashboard_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/category_item.dart';

Widget _wrap360(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(
      size: Size(360, 800),
      padding: EdgeInsets.only(top: 48, bottom: 48),
      viewPadding: EdgeInsets.only(top: 48, bottom: 48),
    ),
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    AdminService().resetForTesting();
    AppControlService.instance.resetForTesting();
  });

  tearDown(() {
    AdminService().resetForTesting();
    AppControlService.instance.resetForTesting();
  });

  group('Phase 7: Admin CMS, Player Support & Telemetry Suite', () {
    test('AdminOverview parses CMS metrics, ghosts & version_breakdown', () {
      final ov = AdminOverview.fromJson({
        'total_accounts': 52,
        'directory_players': 60,
        'guest_players': 14,
        'active_24h': 19,
        'active_events': 1,
        'active_announcements': 2,
        'cms_version': 9,
        'store_items_count': 24,
        'library_items_count': 31,
        'quiz_questions_count': 45,
        'total_ghosts': 18,
        'active_ghosts': 15,
        'human_ghosts': 12,
        'version_breakdown': [
          {'version_code': 20, 'app_version': '1.0.19', 'players_count': 38},
          {'version_code': 19, 'app_version': '1.0.18', 'players_count': 22},
        ],
        'release_config': {
          'platform': 'android',
          'min_version_code': 1,
          'latest_version_code': 20,
          'latest_version_name': '1.0.19',
          'cms_version': 9,
        },
      });

      expect(ov.cmsVersion, equals(9));
      expect(ov.storeItemsCount, equals(24));
      expect(ov.libraryItemsCount, equals(31));
      expect(ov.quizQuestionsCount, equals(45));
      expect(ov.totalGhosts, equals(18));
      expect(ov.activeGhosts, equals(15));
      expect(ov.humanGhosts, equals(12));
      expect(ov.versionBreakdown.length, equals(2));
      expect(ov.versionBreakdown.first.versionCode, equals(20));
      expect(ov.versionBreakdown.first.playersCount, equals(38));
    });

    test('AdminService enforces compensation bounds and question integrity before RPC', () async {
      final admin = AdminService();
      Map<String, dynamic>? recordedComp;
      admin.playerCompensationOverride = ({
        required String userId,
        required int coinsDelta,
        required int gemsDelta,
        required int xpDelta,
        required String reason,
      }) async {
        recordedComp = {
          'user_id': userId,
          'coins': coinsDelta,
          'gems': gemsDelta,
          'xp': xpDelta,
          'reason': reason,
        };
        return {'ok': true};
      };

      await expectLater(
        () => admin.grantPlayerCompensation(
          userId: 'u1',
          coinsDelta: 10001,
          reason: 'تعويض مستحق',
        ),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        () => admin.grantPlayerCompensation(
          userId: 'u1',
          gemsDelta: 101,
          reason: 'تعويض مستحق',
        ),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        () => admin.grantPlayerCompensation(
          userId: 'u1',
          xpDelta: 5001,
          reason: 'تعويض مستحق',
        ),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        () => admin.grantPlayerCompensation(
          userId: 'u1',
          coinsDelta: 100,
          reason: 'ok',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final res = await admin.grantPlayerCompensation(
        userId: 'u1',
        coinsDelta: 500,
        gemsDelta: 10,
        xpDelta: 250,
        reason: 'تعويض انقطاع مباراة أونلاين',
      );
      expect(res?['ok'], isTrue);
      expect(recordedComp?['coins'], equals(500));

      await expectLater(
        () => admin.upsertQuizQuestion(
          categoryId: 'quran',
          levelNumber: 11,
          questionText: 'سؤال تجريبي',
          options: const ['أ', 'ب', 'ج'],
          correctIndex: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('AdminDashboardScreen renders upgraded stats & CMS/Support cards cleanly on 360x800dp', (tester) async {
      AdminService().overviewFetcherOverride = () async => AdminOverview(
            totalAccounts: 44,
            directoryPlayers: 50,
            guestPlayers: 10,
            active24h: 12,
            activeEvents: 1,
            activeAnnouncements: 1,
            cmsVersion: 4,
            storeItemsCount: 22,
            libraryItemsCount: 15,
            quizQuestionsCount: 30,
            totalGhosts: 9,
            activeGhosts: 8,
            humanGhosts: 7,
            versionBreakdown: const [
              AdminVersionBreakdown(
                versionCode: 20,
                appVersion: '1.0.19',
                playersCount: 35,
              ),
              AdminVersionBreakdown(
                versionCode: 19,
                appVersion: '1.0.18',
                playersCount: 15,
              ),
            ],
            releaseConfig: const AppReleaseConfig(
              minVersionCode: 1,
              latestVersionCode: 20,
              latestVersionName: '1.0.19',
              cmsVersion: 4,
            ),
          );

      await tester.pumpWidget(_wrap360(const AdminDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_nav_cms_manager')), findsOneWidget);
      expect(find.byKey(const Key('admin_nav_players_support')), findsOneWidget);
      expect(find.byKey(const Key('admin_nav_telemetry')), findsOneWidget);
      expect(find.textContaining('22 / 30'), findsOneWidget);
      expect(find.textContaining('8 / 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminCmsManagerScreen, AdminPlayersSupportScreen & AdminTelemetrySecurityScreen render cleanly on 360x800dp', (tester) async {
      final admin = AdminService();
      admin.storeItemsFetcherOverride = () async => [
            StoreItemModel(
              id: 'title_test_champion',
              title: 'وسام الفاتح',
              description: 'وسام اختباري',
              category: StoreItemCategory.title,
              priceCoins: 300,
              assetKey: 'وسام الفاتح',
              previewColor: const Color(0xFFF3C644),
              icon: Icons.military_tech_rounded,
              isVisible: true,
            ),
          ];
      admin.libraryContentFetcherOverride = ({String? sectionId}) async => (
            sections: const [
              DynamicLibrarySectionData(id: 'stories', title: 'قصص الصحابة'),
            ],
            items: const [
              DynamicLibraryItemData(
                id: 'lib_1',
                sectionId: 'stories',
                title: 'بطولة خالد بن الوليد',
                content: 'نص القصة',
              ),
            ],
          );
      admin.quizContentFetcherOverride =
          ({String? categoryId, int? levelNumber, int limit = 100}) async => (
                categories: const [
                  DynamicQuizCategoryData(
                    id: 'quran',
                    name: 'القرآن الكريم',
                    totalLevels: 12,
                  ),
                ],
                questions: const [
                  DynamicQuizQuestionData(
                    id: 'cq_1',
                    categoryId: 'quran',
                    levelNumber: 11,
                    questionText: 'ما السورة التي تسمى عروس القرآن؟',
                    options: ['الرحمن', 'يس', 'الملك', 'الواقعة'],
                    correctIndex: 0,
                  ),
                ],
              );

      bool toggledVisibility = false;
      admin.visibilitySetterOverride = ({
        required String entityType,
        required String id,
        required bool isVisible,
      }) async {
        toggledVisibility = entityType == 'store_item' && id == 'title_test_champion' && !isVisible;
        return true;
      };

      Map<String, dynamic>? savedStoreParams;
      admin.storeItemUpserterOverride = (params) async {
        savedStoreParams = params;
        return StoreItemModel.fromCloudJson({
          'id': params['p_id'],
          'title': params['p_title'],
          'category': params['p_category'],
          'price_coins': params['p_price_coins'],
          'price_gems': params['p_price_gems'],
          'min_level': params['p_min_level'],
          'is_visible': params['p_is_visible'],
          'metadata': params['p_metadata'],
        });
      };

      await tester.pumpWidget(_wrap360(const AdminCmsManagerScreen()));
      await tester.pumpAndSettle();
      expect(find.text('وسام الفاتح'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(toggledVisibility, isTrue);

      // Verify in-app Store Editor modal allows creating a Theme with color presets
      await tester.tap(find.text('إضافة عنصر متجر جديد'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'theme_mobile_test',
      );
      await tester.tap(find.byType(DropdownButtonFormField<StoreItemCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ثيم').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'الاسم المعروض'),
        'ثيم الهاتف الملكي',
      );
      await tester.ensureVisible(find.text('زمردي'));
      await tester.tap(find.text('زمردي'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('حفظ العنصر'));
      await tester.tap(find.text('حفظ العنصر'));
      await tester.pumpAndSettle();

      expect(savedStoreParams?['p_id'], equals('theme_mobile_test'));
      expect(savedStoreParams?['p_category'], equals('theme'));
      final savedMeta = savedStoreParams?['p_metadata'] as Map<String, dynamic>?;
      expect(savedMeta?['sovereignAccent'], equals('#10B981'));
      expect(savedMeta?['deepBackground'], isNotNull);
      expect(tester.takeException(), isNull);

      admin.userSearcherOverride = ({required String query, int limit = 20}) async =>
          [
            const AdminPlayerSearchResult(
              userId: 'user_abc',
              playerCode: 'SAH-9999',
              displayName: 'عبدالله الفارس',
              email: 'knight@example.com',
              trophies: 1450,
              playerLevel: 18,
            ),
          ];
      admin.playerDetailFetcherOverride = ({String? userId, String? playerCode}) async =>
          const AdminPlayerDetail(
            userId: 'user_abc',
            playerCode: 'SAH-9999',
            directory: {'display_name': 'عبدالله الفارس'},
            progress: {'coins': 1200, 'gems': 25, 'total_score': 8400, 'player_level': 18},
            leaderboard: {'trophies': 1450},
          );

      await tester.pumpWidget(_wrap360(const AdminPlayersSupportScreen()));
      await tester.pumpAndSettle();
      expect(find.text('عبدالله الفارس'), findsOneWidget);
      await tester.tap(find.text('عبدالله الفارس'));
      await tester.pumpAndSettle();
      expect(find.text('ملف اللاعب: عبدالله الفارس'), findsOneWidget);

      admin.ghostsFetcherOverride = ({int limit = 30}) async => const [
            AdminGhostSummary(
              id: 'ghost_1',
              displayName: 'شبح بدر',
              playerLevel: 22,
              trophies: 1320,
              useCount: 4,
              isActive: true,
              isHuman: true,
            ),
          ];
      admin.auditLogsFetcherOverride = ({int limit = 50}) async => const [];
      admin.adminsFetcherOverride = () async => const AdminRosterSnapshot(
            isOwner: true,
            admins: [AdminRosterEntry(email: 'dia666111@gmail.com', role: 'owner')],
          );

      await tester.pumpWidget(_wrap360(const AdminTelemetrySecurityScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('شبح بدر'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('resolveEquippedHonorTitle preserves dynamic store titles while filtering rank tiers', () async {
      CmsCacheService.instance.resetForTesting();
      StoreService.instance.resetForTesting();

      // 1. Legacy built-in honor title is preserved
      expect(
        CloudSyncService.resolveEquippedHonorTitle('صقر الأندلس'),
        equals('صقر الأندلس'),
      );

      // 2. Standard rank-tier labels and generic placeholders resolve to null
      expect(CloudSyncService.resolveEquippedHonorTitle('طالب علم'), isNull);
      expect(CloudSyncService.resolveEquippedHonorTitle('نخبة الأحفاد 👑'), isNull);
      expect(CloudSyncService.resolveEquippedHonorTitle('مشارك'), isNull);

      // 3. New dynamic store honor title from inventory before CMS bundle finishes syncing
      expect(
        CloudSyncService.resolveEquippedHonorTitle(
          'سيف الله',
          unlockedItemIds: const ['theme_andalusian_gold', 'title_sayf_allah'],
        ),
        equals('سيف الله'),
      );

      // 4. New dynamic store honor title registered in CmsCacheService catalog
      CmsCacheService.instance.bundleFetcherOverride = ({
        required int clientCmsVersion,
        List<String> ownedItemIds = const [],
      }) async =>
          {
            'changed': true,
            'cms_version': 2,
            'store_items': [
              {
                'id': 'custom_royal_honor',
                'title': 'وسام القائد',
                'category': 'title',
                'asset_key': 'وسام القائد',
                'price_coins': 500,
                'is_visible': true,
              },
            ],
            'library_sections': const [],
            'library_items': const [],
            'quiz_categories': const [],
            'quiz_questions': const [],
          };
      await CmsCacheService.instance.syncIfNeeded(serverCmsVersion: 2);
      expect(
        CloudSyncService.resolveEquippedHonorTitle('وسام القائد'),
        equals('وسام القائد'),
      );
    });

    testWidgets('CategoryItem shows lock badge when category.isLocked is true', (tester) async {
      bool tapped = false;
      final lockedCategory = Category(
        id: 'fiqh',
        name: 'الفقه الإسلامي',
        description: 'مقفل مؤقتاً',
        icon: Icons.balance,
        totalLevels: 10,
        unlockedLevels: 3,
        isLocked: true,
        color: const Color(0xFF4A148C),
      );

      await tester.pumpWidget(
        _wrap360(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 170,
                height: 220,
                child: CategoryItem(
                  category: lockedCategory,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مقفل مؤقتاً'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);

      await tester.tap(find.byType(CategoryItem));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
