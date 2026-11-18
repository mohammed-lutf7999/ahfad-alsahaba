import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahfad_alsahaba/core/profanity_filter.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/chat_message_model.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/data/services/chat_service.dart';
import 'package:ahfad_alsahaba/data/services/multiplayer_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/ui/screens/chat/global_chat_bottom_sheet.dart';
import 'package:ahfad_alsahaba/ui/screens/chat/widgets/quick_phrases_bar.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/challenge_menu_screen.dart';

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
    await ProfileService.instance.init();
    await ProfileService.instance.createProfile(name: 'فارس الاختبار', avatarIndex: 1);
    AppControlService.instance.resetForTesting();
    ChatService.instance.resetForTesting();
  });

  group('M11: Diwan Al-Ahfad Chat, Ethics Moderation & Quick Phrases', () {
    test('ProfanityFilter blocks obfuscated profanity and external spam links while allowing polite greetings', () {
      expect(ProfanityFilter.containsInappropriateContent('السلام عليكم ورحمة الله'), isFalse);
      expect(ProfanityFilter.containsInappropriateContent('ما شاء الله، إجابة ذكية!'), isFalse);
      expect(ProfanityFilter.containsInappropriateContent('كـلـب'), isTrue);
      expect(ProfanityFilter.containsInappropriateContent('تفضلوا https://spam.example.com'), isTrue);
      expect(ProfanityFilter.containsInappropriateContent('t.me/fake_group'), isTrue);
      expect(ProfanityFilter.validateMessage('   '), isNotNull);
    });

    test('ChatService enforces auth, 3s cooldown rate limit, profanity check & challenge invite creation', () async {
      var fakeNow = DateTime.utc(2026, 11, 18, 12, 0, 0);
      ChatService.instance.nowProvider = () => fakeNow;
      ChatService.instance.messagesFetcherOverride = ({required String channel, int limit = 40}) async => [];

      // Unauthenticated user cannot send
      ChatService.instance.isAuthenticatedOverride = false;
      final guestErr = await ChatService.instance.sendMessage('السلام عليكم');
      expect(guestErr, contains('Google'));

      // Authenticated user sends clean message
      ChatService.instance.isAuthenticatedOverride = true;
      var sendCount = 0;
      ChatService.instance.messageSenderOverride = ({
        required String content,
        required String channel,
        required String displayName,
        required int avatarIndex,
        required String userRank,
        String? playerCode,
        required String messageKind,
        String? inviteRoomCode,
      }) async {
        sendCount++;
        return {
          'id': 'msg_$sendCount',
          'user_id': 'u_1',
          'display_name': displayName,
          'avatar_index': avatarIndex,
          'user_rank': userRank,
          'content': content,
          'channel': channel,
          'message_kind': messageKind,
          'invite_room_code': inviteRoomCode,
          'created_at': fakeNow.toIso8601String(),
        };
      };

      await ChatService.instance.openChannel('global');
      expect(await ChatService.instance.sendMessage('السلام عليكم ورحمة الله'), isNull);
      expect(ChatService.instance.messages.length, equals(1));

      // Within 3s -> blocked by client cooldown
      fakeNow = fakeNow.add(const Duration(seconds: 2));
      final rateErr = await ChatService.instance.sendMessage('رسالة سريعة');
      expect(rateErr, contains('3 ثوان'));
      expect(sendCount, equals(1));

      // Advance past 3s & send challenge invite
      fakeNow = fakeNow.add(const Duration(seconds: 2));
      ChatService.instance.challengeCreatorOverride = () async => PrivateRoomResult(
            success: true,
            matchId: 'match_priv_1',
            roomCode: '654321',
            seed: 4242,
          );
      final inviteRes = await ChatService.instance.sendChallengeInvite();
      expect(inviteRes.success, isTrue);
      expect(inviteRes.roomCode, equals('654321'));
      expect(ChatService.instance.messages.last.isChallengeInvite, isTrue);
    });

    testWidgets('QuickPhrasesBar renders all 4 chivalric phrases cleanly on 360dp', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _wrap360(
          Scaffold(
            body: Center(
              child: QuickPhrasesBar(
                compact: true,
                onPhraseSelected: (p) => picked = p,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(QuickChivalricPhrases.all.first), findsOneWidget);
      await tester.tap(find.text(QuickChivalricPhrases.all.first));
      await tester.pump();
      expect(picked, equals(QuickChivalricPhrases.all.first));
      expect(tester.takeException(), isNull);
    });

    testWidgets('GlobalChatBottomSheet renders 360x800dp, sends messages, displays invite cards & closes channel cleanly', (tester) async {
      ChatService.instance.isAuthenticatedOverride = true;
      ChatService.instance.messagesFetcherOverride = ({required String channel, int limit = 40}) async => [
            {
              'id': 'm1',
              'user_id': 'other_user',
              'display_name': 'خالد الفارس',
              'avatar_index': 2,
              'user_rank': 'صقر الأندلس',
              'content': 'أدعوكم لنزال معرفي شريف! انضموا عبر الرمز #654321',
              'channel': 'global',
              'message_kind': 'challenge_invite',
              'invite_room_code': '654321',
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
          ];
      ChatService.instance.messageSenderOverride = ({
        required String content,
        required String channel,
        required String displayName,
        required int avatarIndex,
        required String userRank,
        String? playerCode,
        required String messageKind,
        String? inviteRoomCode,
      }) async =>
          {
            'id': 'm2',
            'user_id': 'me',
            'display_name': displayName,
            'avatar_index': avatarIndex,
            'user_rank': userRank,
            'content': content,
            'channel': channel,
            'message_kind': messageKind,
            'invite_room_code': inviteRoomCode,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          };

      await tester.pumpWidget(_wrap360(const Scaffold(body: GlobalChatBottomSheet())));
      await tester.pumpAndSettle();

      expect(find.text('ديوان الأحفاد 💬'), findsOneWidget);
      expect(find.text('قبول التحدي الآن (654321)'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('diwan_message_input')), 'حياكم الله إخواني');
      await tester.tap(find.byKey(const Key('diwan_send_btn')));
      await tester.pumpAndSettle();

      expect(find.text('حياكم الله إخواني'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount triggers dispose() -> closeChannel() cleanly with zero active sockets
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(ChatService.instance.hasActiveChannel, isFalse);
    });

    testWidgets('ChallengeMenuScreen exposes Diwan Al-Ahfad without overflow on 360x800dp', (tester) async {
      await tester.pumpWidget(_wrap360(const ChallengeMenuScreen()));
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text('ديوان الأحفاد 💬'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
