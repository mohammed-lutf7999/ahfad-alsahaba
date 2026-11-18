import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahfad_alsahaba/core/app_constants.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/data/services/royal_inbox_service.dart';
import 'package:ahfad_alsahaba/data/services/spaced_repetition_service.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_resources_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/royal_inbox_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/historical_insight_sheet.dart';
import 'package:ahfad_alsahaba/data/models/question_model.dart';
import 'package:ahfad_alsahaba/logic/game_controller.dart';

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
    AppControlService.instance.resetForTesting();
    AdminService().resetForTesting();
    RoyalInboxService.instance.resetForTesting();
    SpacedRepetitionService.instance.resetForTesting();
  });

  group('Plan 10 (M9, M10, M12): Royal Inbox, Live Ping, Resource Health & Wise Teacher', () {
    test('AppConstants cooldown is 3 minutes and handleControlPingPayload triggers sync', () async {
      expect(AppConstants.appControlSyncCooldownMinutes, equals(3));

      int syncCalls = 0;
      AppControlService.instance.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async {
        syncCalls++;
        return {
          'changed': true,
          'config_version': 50 + syncCalls,
          'cms_version': 1,
          'is_admin': false,
          'release_config': {
            'platform': 'android',
            'min_version_code': 1,
            'latest_version_code': 20,
            'feature_flags': {'live_announcement_ping': true},
          },
          'announcements': const [],
        };
      };

      await AppControlService.instance.syncControlState(force: true);
      expect(syncCalls, equals(1));

      // Matching global ping bypasses cooldown immediately
      await AppControlService.instance.handleControlPingPayload({'target_code': 'ALL'});
      expect(syncCalls, equals(2));

      // Non-matching player code ping is ignored (0 wasted RPCs)
      await AppControlService.instance.handleControlPingPayload({'target_code': 'SAH-OTHER'});
      expect(syncCalls, equals(2));
    });

    testWidgets('RoyalInboxScreen renders tabs, unread badge & marks all read cleanly at 360dp', (tester) async {
      RoyalInboxService.instance.inboxFetcherOverride = ({String? playerCode, int limit = 25}) async => [
            {
              'id': 'ann_1',
              'title': 'رسالة إدارية هامة',
              'body': 'مرحباً بكم في التحديث الجديد.',
              'message_type': 'admin',
              'target_scope': 'all',
              'is_read': false,
              'is_reward_notice': false,
            },
            {
              'id': 'ann_gift',
              'title': '🎁 هدية وتعويض من الإدارة',
              'body': 'تمت إضافة 500 دينار 🪙',
              'message_type': 'admin',
              'target_scope': 'single_user',
              'cta_label': 'سوق الفرسان',
              'cta_route': '/knights-store',
              'is_read': false,
              'is_reward_notice': true,
            },
          ];

      int markedCount = 0;
      RoyalInboxService.instance.markAllReaderOverride = ({String? playerCode}) async {
        markedCount = 2;
        return 2;
      };

      await tester.pumpWidget(_wrap360(const RoyalInboxScreen()));
      await tester.pumpAndSettle();

      expect(find.text('صندوق البريد الملكي 📬'), findsOneWidget);
      expect(find.text('رسالة إدارية هامة'), findsOneWidget);
      expect(RoyalInboxService.instance.unreadCount, equals(2));

      await tester.tap(find.byKey(const Key('inbox_mark_all_read_btn')));
      await tester.pumpAndSettle();
      expect(markedCount, equals(2));
      expect(RoyalInboxService.instance.unreadCount, equals(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminResourcesScreen renders DB health metrics & executes confirmed cleanup cleanly', (tester) async {
      AdminService().resourceHealthFetcherOverride = () async => const AdminResourceHealth(
            dbSizeBytes: 31457280, // 30 MB
            dbLimitBytes: 524288000, // 500 MB
            dbUsagePercent: 6.0,
            activeMatchesNow: 4,
            activePlayers5m: 12,
            activePlayers24h: 85,
            cleanableOldMatches: 14,
            cleanableExpiredReceipts: 9,
            tables: [
              AdminTableMetric(tableName: 'matches', sizeBytes: 5242880, rowEstimate: 450),
              AdminTableMetric(tableName: 'user_progress', sizeBytes: 2097152, rowEstimate: 120),
            ],
          );

      String? cleanedAction;
      AdminService().resourceCleanupOverride = ({required String action, int olderThanDays = 30}) async {
        cleanedAction = action;
        return {'ok': true, 'deleted_count': 14};
      };

      await tester.pumpWidget(_wrap360(const AdminResourcesScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('30.0 MB'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('matches'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('matches'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('cleanup_matches_btn')));
      await tester.tap(find.byKey(const Key('cleanup_matches_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تنفيذ التنظيف'));
      await tester.pumpAndSettle();

      expect(cleanedAction, equals('finished_matches'));
      expect(tester.takeException(), isNull);
    });

    test('SpacedRepetitionService honors both Admin wiseTeacherMode flag & local Settings toggle', () async {
      await SpacedRepetitionService.instance.recordAnswer(
        questionId: 'q_test_1',
        categoryId: 'quran',
        isCorrect: false,
      );
      expect(SpacedRepetitionService.instance.dueCount, equals(0)); // not due yet (+24h)

      // Turn off local setting -> effectively disabled
      await SharedPrefsService.setWiseTeacherEnabled(false);
      expect(SpacedRepetitionService.instance.isEffectivelyEnabled, isFalse);

      // Re-enable local, but disable Admin flag -> blocked by Admin
      await SharedPrefsService.setWiseTeacherEnabled(true);
      AppControlService.instance.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async =>
          {
            'changed': true,
            'config_version': 99,
            'cms_version': 1,
            'release_config': {
              'feature_flags': {'wise_teacher_mode': false},
            },
          };
      await AppControlService.instance.syncControlState(force: true);
      expect(SpacedRepetitionService.instance.isAdminBlocked, isTrue);
      expect(SpacedRepetitionService.instance.isEffectivelyEnabled, isFalse);
    });

    testWidgets('HistoricalInsightSheet renders Wise Teacher insight cleanly on 360dp', (tester) async {
      final q = Question(
        id: 'q_insight_1',
        categoryId: 'seerah',
        levelNumber: 1,
        questionText: 'من هو الصحابي الملقب بسيف الله المسلول؟',
        options: const ['خالد بن الوليد', 'سعد بن أبي وقاص', 'عمرو بن العاص', 'أبو عبيدة'],
        correctAnswerIndex: 0,
        explanation: 'لقبه النبي صلى الله عليه وسلم بسيف الله المسلول في غزوة مؤتة.',
      );
      await tester.pumpWidget(
        _wrap360(Scaffold(body: HistoricalInsightSheet(question: q))),
      );
      await tester.pumpAndSettle();
      expect(find.text('إضاءة المعلم الحكيم'), findsOneWidget);
      expect(find.textContaining('خالد بن الوليد'), findsOneWidget);
      expect(find.text('فهمت، متابعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('SpacedRepetitionService schedules 24h -> 3d -> 7d -> cleared & GameController prioritizes due questions', () async {
      var fakeNow = DateTime.utc(2026, 11, 18, 12, 0);
      SpacedRepetitionService.instance.nowProvider = () => fakeNow;

      // Record wrong answer for a quran level 2 question while playing level 1
      await SpacedRepetitionService.instance.recordAnswer(
        questionId: 'q2_1',
        categoryId: 'quran',
        isCorrect: false,
      );
      expect(SpacedRepetitionService.instance.dueCount, equals(0));
      expect(SpacedRepetitionService.instance.getDueQuestionIds('quran'), isEmpty);

      // Advance 25 hours -> q2_1 becomes due and is injected into GameController level 1
      fakeNow = fakeNow.add(const Duration(hours: 25));
      expect(SpacedRepetitionService.instance.dueCount, equals(1));
      expect(SpacedRepetitionService.instance.getDueQuestionIds('quran'), contains('q2_1'));

      final controller = GameController();
      await controller.loadQuestionsForLevel('quran', 1);
      expect(controller.currentQuestions, isNotEmpty);
      expect(controller.currentQuestions.first.id, equals('q2_1'));

      // Answer right -> scheduled +3d (stage 1)
      await SpacedRepetitionService.instance.recordAnswer(
        questionId: 'q2_1',
        categoryId: 'quran',
        isCorrect: true,
      );
      expect(SpacedRepetitionService.instance.dueCount, equals(0));

      // Advance +3d + 1h -> due again
      fakeNow = fakeNow.add(const Duration(days: 3, hours: 1));
      expect(SpacedRepetitionService.instance.dueCount, equals(1));

      // Answer right -> scheduled +7d (stage 2)
      await SpacedRepetitionService.instance.recordAnswer(
        questionId: 'q2_1',
        categoryId: 'quran',
        isCorrect: true,
      );
      expect(SpacedRepetitionService.instance.dueCount, equals(0));

      // Advance +7d + 1h -> due again, then third right answer graduates/clears it
      fakeNow = fakeNow.add(const Duration(days: 7, hours: 1));
      expect(SpacedRepetitionService.instance.dueCount, equals(1));
      await SpacedRepetitionService.instance.recordAnswer(
        questionId: 'q2_1',
        categoryId: 'quran',
        isCorrect: true,
      );
      expect(SpacedRepetitionService.instance.dueCount, equals(0));
      expect(SpacedRepetitionService.instance.getDueQuestionIds('quran'), isEmpty);
    });
  });
}
