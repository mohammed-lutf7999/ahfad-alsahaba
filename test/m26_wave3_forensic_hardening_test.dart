import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/models/cms_models.dart';
import 'package:ahfad_alsahaba/data/models/store_item_model.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_cms_manager_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_resources_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_telemetry_security_screen.dart';

Widget _wrap360(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(
      size: Size(360, 800),
      padding: EdgeInsets.only(top: 48, bottom: 48),
      viewPadding: EdgeInsets.only(top: 48, bottom: 48),
    ),
    child: MaterialApp(home: child),
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

  group('Wave 3 Forensic Hardening Regression Suite', () {
    testWidgets(
      'AdminCmsManagerScreen reloads only affected tab on toggle and surfaces explicit error on false/null',
      (tester) async {
        final admin = AdminService();
        int storeHits = 0;
        int libHits = 0;
        int quizHits = 0;

        admin.storeItemsFetcherOverride = () async {
          storeHits++;
          return const [
            StoreItemModel(
              id: 'title_test_champion',
              title: 'وسام الفاتح',
              description: 'وسام تجريبي',
              category: StoreItemCategory.title,
              priceCoins: 300,
              priceGems: 0,
              minLevel: 1,
              assetKey: '',
              icon: Icons.military_tech_rounded,
              previewColor: Color(0xFFD4AF37),
              isVisible: true,
            ),
          ];
        };
        admin.libraryContentFetcherOverride = ({String? sectionId}) async {
          libHits++;
          return (
            sections: const <DynamicLibrarySectionData>[],
            items: const <DynamicLibraryItemData>[],
          );
        };
        admin.quizContentFetcherOverride =
            ({String? categoryId, int? levelNumber, int limit = 100}) async {
          quizHits++;
          return (
            categories: const <DynamicQuizCategoryData>[],
            questions: const <DynamicQuizQuestionData>[],
          );
        };

        bool nextVisibilityOk = true;
        admin.visibilitySetterOverride = ({
          required String entityType,
          required String id,
          required bool isVisible,
        }) async =>
            nextVisibilityOk;

        admin.storeItemUpserterOverride = (params) async => null;

        await tester.pumpWidget(_wrap360(const AdminCmsManagerScreen()));
        await tester.pumpAndSettle();
        expect(storeHits, 1);
        expect(libHits, 1);
        expect(quizHits, 1);

        // Toggle store item visibility -> reloads ONLY store tab (+1), NOT library/quiz
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(storeHits, 2);
        expect(libHits, 1);
        expect(quizHits, 1);

        // When setContentVisibility returns false -> explicit error, NOT silent failure
        nextVisibilityOk = false;
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('تعذر تحديث حالة الظهور'),
          findsOneWidget,
        );
        expect(storeHits, 2);

        // When upsertStoreItem returns null -> must NOT show false success
        await tester.tap(find.text('إضافة عنصر متجر جديد'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'null_fail_item',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'الاسم المعروض'),
          'عنصر اختباري',
        );
        await tester.ensureVisible(find.text('حفظ العنصر'));
        await tester.tap(find.text('حفظ العنصر'));
        await tester.pumpAndSettle();

        expect(find.textContaining('تم حفظ عنصر المتجر بنجاح'), findsNothing);
        expect(find.textContaining('لم يتم حفظ العنصر'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AdminTelemetrySecurityScreen reports error when toggleGhost returns false or manageAdmin returns null',
      (tester) async {
        final admin = AdminService();
        admin.ghostsFetcherOverride = ({int limit = 30}) async => const [
              AdminGhostSummary(
                id: 'ghost_1',
                displayName: 'فارس الأندلس',
                trophies: 1200,
                isActive: true,
              ),
            ];
        admin.auditLogsFetcherOverride = ({int limit = 50}) async => const [];
        admin.adminsFetcherOverride = () async => const AdminRosterSnapshot(
              isOwner: true,
              admins: [
                AdminRosterEntry(email: 'owner@test.com', role: 'owner'),
              ],
            );
        admin.ghostTogglerOverride = (id, active) async => false;
        admin.adminManagerOverride = ({
          required String action,
          required String email,
          String role = 'admin',
        }) async =>
            null;

        await tester.pumpWidget(_wrap360(const AdminTelemetrySecurityScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(find.textContaining('تعذر تحديث حالة الشبح'), findsOneWidget);

        // Switch to Admins tab and try adding admin when RPC returns null
        await tester.tap(find.text('المشرفون'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'new@admin.com');
        await tester.tap(find.text('إضافة كمشرف'));
        await tester.pumpAndSettle();

        expect(find.textContaining('تمت إضافة المشرف بنجاح'), findsNothing);
        expect(find.textContaining('تعذر إضافة المشرف'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AdminResourcesScreen reports error when cleanupStaleResources returns null',
      (tester) async {
        final admin = AdminService();
        admin.resourceHealthFetcherOverride = () async =>
            const AdminResourceHealth(
              dbSizeBytes: 12 * 1024 * 1024,
              dbLimitBytes: 500 * 1024 * 1024,
              dbUsagePercent: 2.4,
              activeMatchesNow: 1,
              cleanableOldMatches: 4,
              cleanableExpiredReceipts: 0,
              tables: [],
            );
        admin.resourceCleanupOverride = ({
          required String action,
          int olderThanDays = 30,
        }) async =>
            null;

        await tester.pumpWidget(_wrap360(const AdminResourcesScreen()));
        await tester.pumpAndSettle();

        final cleanBtn = find.byKey(const Key('cleanup_matches_btn'));
        await tester.ensureVisible(cleanBtn);
        await tester.tap(cleanBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('تنفيذ التنظيف'));
        await tester.pumpAndSettle();

        expect(find.textContaining('تم تنظيف 0 سجل'), findsNothing);
        expect(find.textContaining('تعذر تنفيذ التنظيف'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
