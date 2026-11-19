import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/data/services/guild_service.dart';
import 'package:ahfad_alsahaba/data/services/live_tournament_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/question_service.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/admin_resources_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/guilds/guild_dashboard_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/live_arena/host_control_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/live_arena/student_participant_screen.dart';

Widget _wrap360(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 800),
        padding: EdgeInsets.only(top: 48, bottom: 48),
        viewPadding: EdgeInsets.only(top: 48, bottom: 48),
      ),
      child: child,
    ),
  );
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    await ProfileService.instance.init();
    await ProfileService.instance.createProfile(name: 'قائد الكتيبة', avatarIndex: 0);
    AppControlService.instance.resetForTesting();
    AdminService().resetForTesting();
    GuildService.instance.resetForTesting();
    LiveTournamentService.instance.resetForTesting();
  });

  group('M13: Guilds (Friday Grand Battle) & Live Kahoot Arenas (100p)', () {
    test('GuildService creates guild, fetches Friday Battle leaderboard, and contributes score cleanly', () async {
      GuildService.instance.isAuthenticatedOverride = true;
      String? lastRpc;
      int contributed = 0;

      GuildService.instance.overviewFetcherOverride = ({int limit = 25}) async => {
            'my_guild': {
              'id': 'g1',
              'name': 'فرسان الهدى',
              'description': 'راية التنافس المعرفي',
              'banner_icon': 0,
              'weekly_score': 350 + contributed,
              'total_score': 1200 + contributed,
              'max_members': 30,
              'members_count': 6,
              'leader_id': 'u1',
            },
            'my_members': [
              {
                'guild_id': 'g1',
                'user_id': 'u1',
                'display_name': 'أبو بكر',
                'avatar_index': 1,
                'role': 'قائد',
                'weekly_contribution': 200 + contributed,
              },
            ],
            'leaderboard': [
              {
                'id': 'g1',
                'name': 'فرسان الهدى',
                'description': 'راية التنافس المعرفي',
                'banner_icon': 0,
                'weekly_score': 350 + contributed,
                'total_score': 1200 + contributed,
                'max_members': 30,
                'members_count': 6,
                'leader_id': 'u1',
              },
            ],
          };

      GuildService.instance.rpcOverride = (name, params) async {
        lastRpc = name;
        if (name == 'contribute_guild_score') {
          contributed += (params['p_points'] as num).toInt();
        }
        return {'ok': true};
      };

      final err = await GuildService.instance.createGuild(name: 'فرسان الهدى');
      expect(err, isNull);
      expect(lastRpc, equals('create_guild'));
      expect(GuildService.instance.overview.myGuild?.name, equals('فرسان الهدى'));

      await GuildService.instance.contributeScore(45);
      expect(contributed, equals(45));
    });

    testWidgets('GuildDashboardScreen renders My Guild & Friday Battle leaderboard cleanly on 360dp', (tester) async {
      _setPhoneViewport(tester);
      GuildService.instance.overviewFetcherOverride = ({int limit = 25}) async => {
            'my_guild': {
              'id': 'g1',
              'name': 'شباب المسجد',
              'description': 'التسابق إلى الخيرات',
              'banner_icon': 1,
              'weekly_score': 900,
              'total_score': 2400,
              'max_members': 30,
              'members_count': 12,
              'leader_id': 'u1',
            },
            'my_members': [
              {
                'guild_id': 'g1',
                'user_id': 'u1',
                'display_name': 'عمر الفاروق',
                'avatar_index': 2,
                'role': 'قائد',
                'weekly_contribution': 420,
              },
            ],
            'leaderboard': [
              {
                'id': 'g1',
                'name': 'شباب المسجد',
                'banner_icon': 1,
                'weekly_score': 900,
                'total_score': 2400,
                'max_members': 30,
                'members_count': 12,
                'leader_id': 'u1',
              },
            ],
          };

      await tester.pumpWidget(_wrap360(const GuildDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('شباب المسجد'), findsOneWidget);
      expect(find.text('عمر الفاروق'), findsOneWidget);

      await tester.tap(find.text('معركة الجمعة 🏆'));
      await tester.pumpAndSettle();
      expect(find.textContaining('900 نقطة أسبوعية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HostControlScreen & StudentParticipantScreen render 360dp & clean channel on dispose', (tester) async {
      _setPhoneViewport(tester);
      await tester.runAsync(() => QuestionService().preloadCategory('quran'));
      LiveTournamentService.instance.isAuthenticatedOverride = true;
      LiveTournamentService.instance.rpcOverride = (name, params) async {
        if (name == 'create_live_quiz_session') {
          return {
            'id': 'sess_1',
            'pin_code': '54321',
            'title': params['p_title'],
            'category_id': params['p_category_id'],
            'host_id': 'host_1',
            'status': 'waiting',
            'current_question_index': 0,
            'question_ids': params['p_question_ids'],
            'participants_count': 0,
          };
        }
        if (name == 'update_live_quiz_session_state') {
          return {
            'id': 'sess_1',
            'pin_code': '54321',
            'title': 'بطولة الفرسان المعرفية',
            'category_id': 'quran',
            'host_id': 'host_1',
            'status': params['p_status'],
            'current_question_index': params['p_question_index'],
            'question_ids': const ['quran:1:0'],
            'participants_count': 1,
          };
        }
        if (name == 'join_live_quiz_session') {
          return {
            'session': {
              'id': 'sess_1',
              'pin_code': '54321',
              'title': 'بطولة الفرسان المعرفية',
              'category_id': 'quran',
              'host_id': 'host_1',
              'status': 'waiting',
              'current_question_index': 0,
              'question_ids': const ['quran:1:0'],
              'participants_count': 1,
            },
            'participants': [
              {
                'session_id': 'sess_1',
                'user_id': 'u_stu_1',
                'display_name': 'طالب مجتهد',
                'avatar_index': 0,
                'score': 0,
                'correct_count': 0,
              },
            ],
          };
        }
        return {'ok': true};
      };

      await tester.pumpWidget(_wrap360(const HostControlScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('host_create_arena_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('host_arena_pin_text')), findsOneWidget);
      expect(find.text('54321'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(LiveTournamentService.instance.activeSession, isNull);
      expect(LiveTournamentService.instance.hasActiveChannel, isFalse);

      // Now test StudentParticipantScreen on 360dp
      await tester.pumpWidget(_wrap360(const StudentParticipantScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('student_arena_pin_input')), '54321');
      await tester.tap(find.byKey(const Key('student_join_arena_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('انتظار ضغط المعلم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminResourcesScreen supports expired_live_sessions cleanup on 360dp', (tester) async {
      _setPhoneViewport(tester);
      AdminService().resourceHealthFetcherOverride = () async => const AdminResourceHealth(
            dbSizeBytes: 15728640,
            dbLimitBytes: 524288000,
            dbUsagePercent: 3.0,
            activeMatchesNow: 2,
            activePlayers5m: 3,
            activePlayers60m: 6,
            activePlayers24h: 12,
            totalDirectoryPlayers: 15,
            cleanableOldMatches: 5,
            cleanableExpiredReceipts: 4,
            tables: [],
          );
      String? cleanedAction;
      AdminService().resourceCleanupOverride = ({required String action, int olderThanDays = 30}) async {
        cleanedAction = action;
        return {'ok': true, 'deleted_count': 3};
      };

      await tester.pumpWidget(_wrap360(const AdminResourcesScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('cleanup_sessions_btn')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cleanup_sessions_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تنفيذ التنظيف'));
      await tester.pumpAndSettle();

      expect(cleanedAction, equals('expired_live_sessions'));
      expect(tester.takeException(), isNull);
    });

    test('QuestionService.loadQuestionsBySpecs returns deterministic identical questions for Host & 100 Students', () async {
      final specs = ['quran:1:0', 'quran:1:2', 'quran:1:4'];
      final hostQuestions = await QuestionService().loadQuestionsBySpecs(
        specs,
        seed: 54321.hashCode,
      );
      final studentQuestions = await QuestionService().loadQuestionsBySpecs(
        specs,
        seed: 54321.hashCode,
      );
      expect(hostQuestions.length, equals(3));
      expect(
        hostQuestions.map((q) => q.id).toList(),
        equals(studentQuestions.map((q) => q.id).toList()),
      );
      expect(
        hostQuestions.map((q) => q.questionText).toList(),
        equals(studentQuestions.map((q) => q.questionText).toList()),
      );
      expect(
        hostQuestions.first.options,
        equals(studentQuestions.first.options),
      );
    });
  });
}
