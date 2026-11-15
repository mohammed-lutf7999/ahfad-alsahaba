import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ahfad_alsahaba/core/app_constants.dart';
import 'package:ahfad_alsahaba/core/app_routes.dart';
import 'package:ahfad_alsahaba/core/app_theme.dart';
import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/achievement_model.dart';
import 'package:ahfad_alsahaba/data/models/challenge_config.dart';
import 'package:ahfad_alsahaba/data/models/multiplayer_player.dart';
import 'package:ahfad_alsahaba/data/models/player_level_model.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/models/question_model.dart';
import 'package:ahfad_alsahaba/data/models/quote_model.dart';
import 'package:ahfad_alsahaba/data/services/challenge_game_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/ui/dialogs/app_dialogs.dart';
import 'package:ahfad_alsahaba/ui/screens/creative_empire_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/global_ranking_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/glory/glory_road_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/glory/widgets/glory_level_step_card.dart';
import 'package:ahfad_alsahaba/ui/screens/home_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/challenge_result_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/lobby_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/private_room_hub_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/waiting_room_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/multiplayer/widgets/game_match_result_dialog.dart';
import 'package:ahfad_alsahaba/ui/screens/onboarding_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/profile_setup_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/result/widgets/quiz_review_dialog.dart';
import 'package:ahfad_alsahaba/ui/screens/result_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/settings_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/splash_screen.dart';
import 'package:ahfad_alsahaba/ui/screens/store/knights_store_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/achievement_popup.dart';
import 'package:ahfad_alsahaba/ui/widgets/coach_mark_overlay.dart';
import 'package:ahfad_alsahaba/ui/widgets/islamic_quote_card.dart';
import 'package:ahfad_alsahaba/ui/widgets/navigation/royal_bottom_nav_bar.dart';
import 'package:ahfad_alsahaba/ui/widgets/result_card.dart';

void _configureAndroid15EdgeToEdgeViewport(WidgetTester tester) {
  // 1080x2400 px @ 3.0 DPR = 360x800 dp with 48dp top cutout/status bar & 48dp 3-button nav bar
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = const FakeViewPadding(top: 144, bottom: 144);
  tester.view.viewPadding = const FakeViewPadding(top: 144, bottom: 144);
  addTearDown(() {
    tester.view.resetPadding();
    tester.view.resetViewPadding();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _seedActiveProfile() async {
  final profile = PlayerProfile(
    id: 'edge_test_profile',
    name: 'فارس الحافة',
    totalScore: 4200,
    highScore: 100,
    coins: 950,
    gems: 25,
    trophies: 1320,
    winStreak: 2,
  );
  await SharedPrefsService.init();
  await SharedPrefsService.saveSoundEnabled(false);
  await SharedPrefsService.saveVibrationEnabled(false);
  await SharedPrefsService.saveOnboardingSeen();
  await SharedPrefsService.setHasSeenTutorial(true);
  await SharedPrefsService.saveProfilesJson(PlayerProfile.profilesToJson([profile]));
  await SharedPrefsService.setActiveProfileId(profile.id);
  await ProfileService.instance.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('nearby_connections'),
      (call) async => true,
    );

    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
      'onboarding_seen': true,
      'has_seen_tutorial': true,
    });
    await SharedPrefsService.init();

    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key-edge',
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false,
          autoRefreshToken: false,
        ),
      );
    } catch (_) {
      // Already initialized when running full test suite
    }
  });

  setUp(() async {
    await _seedActiveProfile();
  });

  group('Android 15 (SDK 35/36) Native & Play Console Edge-to-Edge Compliance', () {
    test('MainActivity.kt routes API 35+ away from deprecated color setters and enables edge-to-edge cleanly', () {
      final mainActivityFile = File(
        'android/app/src/main/kotlin/com/ahfad/alsahaba/battle/MainActivity.kt',
      );
      expect(mainActivityFile.existsSync(), isTrue);
      final source = mainActivityFile.readAsStringSync();

      expect(source, contains('import androidx.activity.enableEdgeToEdge'));
      expect(source, contains('import androidx.activity.SystemBarStyle'));
      expect(source, contains('import androidx.core.view.WindowCompat'));
      expect(source, contains('import androidx.core.view.WindowInsetsControllerCompat'));
      expect(source, contains('class MainActivity : FlutterFragmentActivity()'));
      expect(source, contains('Build.VERSION_CODES.VANILLA_ICE_CREAM'));
      expect(source, contains('WindowCompat.setDecorFitsSystemWindows(window, false)'));
      expect(source, contains('isNavigationBarContrastEnforced = false'));
      expect(source.contains('isStatusBarContrastEnforced'), isFalse);
      expect(source, contains('LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS'));
      expect(source, contains('enableEdgeToEdge('));
      expect(source, contains('SystemBarStyle.dark(Color.TRANSPARENT)'));

      // Ensure zero manual deprecated Android bar setters exist in MainActivity
      expect(source.contains('statusBarColor'), isFalse);
      expect(source.contains('navigationBarColor'), isFalse);
    });

    test('Manifest, Gradle & Android styles declare activity-ktx, cutout=always, remove WebViewActivity & omit deprecated XML bar attributes', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);
      final gradleSource = gradleFile.readAsStringSync();
      expect(gradleSource, contains('compileSdk = 36'));
      expect(gradleSource, contains('targetSdk = 36'));
      expect(gradleSource, contains('androidx.activity:activity-ktx:'));

      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final manifestSource = manifestFile.readAsStringSync();
      expect(manifestSource, contains('xmlns:tools="http://schemas.android.com/tools"'));
      expect(manifestSource, contains('io.flutter.plugins.urllauncher.WebViewActivity'));
      expect(manifestSource, contains('tools:node="remove"'));
      expect(manifestSource.contains('Theme.NoTitleBar.Fullscreen'), isFalse);

      for (final path in [
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
        'android/app/src/main/res/values-v30/styles.xml',
        'android/app/src/main/res/values-v31/styles.xml',
        'android/app/src/main/res/values-night-v31/styles.xml',
      ]) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        final xml = file.readAsStringSync();
        expect(xml.contains('android:statusBarColor'), isFalse, reason: path);
        expect(xml.contains('android:navigationBarColor'), isFalse, reason: path);
        expect(xml.contains('windowTranslucentStatus'), isFalse, reason: path);
        expect(xml.contains('windowTranslucentNavigation'), isFalse, reason: path);
      }

      for (final cutoutPath in [
        'android/app/src/main/res/values-v30/styles.xml',
        'android/app/src/main/res/values-v31/styles.xml',
        'android/app/src/main/res/values-night-v31/styles.xml',
      ]) {
        final xml = File(cutoutPath).readAsStringSync();
        expect(
          xml,
          contains('<item name="android:windowLayoutInDisplayCutoutMode">always</item>'),
          reason: cutoutPath,
        );
      }

      final nightV31 = File('android/app/src/main/res/values-night-v31/styles.xml').readAsStringSync();
      expect(nightV31, contains('android:windowSplashScreenBackground'));
    });

    test('main.dart and AppTheme omit deprecated statusBarColor/systemNavigationBarColor and enable edgeToEdge', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource, contains('SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)'));
      expect(mainSource, contains('AppTheme.royalOverlayStyle'));

      // Assert zero deprecated color parameters in overlay styles
      for (final style in [
        AppTheme.royalOverlayStyle,
        AppTheme.lightSurfaceOverlayStyle,
        AppTheme.getThemeFor(AppCustomTheme.andalusianGold).appBarTheme.systemOverlayStyle,
      ]) {
        expect(style, isNotNull);
        expect(style!.statusBarColor, isNull);
        expect(style.systemNavigationBarColor, isNull);
        expect(style.systemNavigationBarDividerColor, isNull);
        expect(style.systemNavigationBarContrastEnforced, isFalse);
      }

      expect(AppTheme.royalOverlayStyle.statusBarIconBrightness, Brightness.light);
      expect(AppTheme.royalOverlayStyle.systemNavigationBarIconBrightness, Brightness.light);
      expect(AppTheme.lightSurfaceOverlayStyle.statusBarIconBrightness, Brightness.dark);
      expect(AppTheme.lightSurfaceOverlayStyle.systemNavigationBarIconBrightness, Brightness.dark);
    });
  });

  group('Flutter UI SafeArea & MediaQuery Inset Protection (360x800dp, 48dp Top + 48dp Bottom Bars)', () {
    testWidgets('HomeScreen paints edge-to-edge background while keeping RoyalBottomNavBar above bottom system bar', (tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          onGenerateRoute: AppRoutes.generateRoute,
          home: const HomeScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final scaffoldSize = tester.getSize(find.byType(Scaffold));
      expect(scaffoldSize, const Size(360, 800));

      final navBarRect = tester.getRect(find.byType(RoyalBottomNavBar));
      expect(
        navBarRect.bottom,
        lessThanOrEqualTo(752.0), // 800 - 48dp bottom system nav bar
        reason: 'RoyalBottomNavBar must clear 48dp system navigation bar on Android 15',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('SplashScreen keeps bottom branding above 48dp system navigation bar', (tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          onGenerateRoute: AppRoutes.generateRoute,
          home: const SplashScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      final versionFinder = find.text('الإصدار ${AppConstants.appVersion}');
      expect(versionFinder, findsOneWidget);
      final versionRect = tester.getRect(versionFinder);
      expect(
        versionRect.bottom,
        lessThanOrEqualTo(752.0),
        reason: 'SplashScreen bottom version text must clear 48dp 3-button nav bar',
      );

      // Drain any zero-duration child timers triggered on route warm-up before unmounting
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('GloryRoadScreen protects 100-level & arena lists with bottom SafeArea', (tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const GloryRoadScreen(),
        ),
      );
      await tester.pump();

      final listRect = tester.getRect(find.byKey(const Key('glory_road_levels_list')));
      expect(
        listRect.bottom,
        lessThanOrEqualTo(752.0),
        reason: 'GloryRoadScreen list viewport must stay above bottom system bar',
      );

      // Switch to Tab 2 (6 Arenas) and check its list viewport too
      await tester.tap(find.text('الميادين الستة (6)'));
      await tester.pumpAndSettle();

      final arenasRect = tester.getRect(find.byKey(const Key('glory_road_arenas_list')));
      expect(arenasRect.bottom, lessThanOrEqualTo(752.0));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('KnightsStoreScreen protects store catalog cards above 48dp bottom system bar', (tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const KnightsStoreScreen(),
        ),
      );
      await tester.pump();

      final storeListRect = tester.getRect(find.byKey(const Key('store_tab_themes')));
      expect(
        storeListRect.bottom,
        lessThanOrEqualTo(752.0),
        reason: 'KnightsStoreScreen catalog must clear 48dp bottom system bar',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('GlobalRankingScreen keeps TabBarView inside SafeArea above bottom system bar', (tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const GlobalRankingScreen(),
        ),
      );
      await tester.pump();

      final tabBarViewRect = tester.getRect(find.byType(TabBarView));
      expect(
        tabBarViewRect.bottom,
        lessThanOrEqualTo(752.0),
        reason: 'GlobalRankingScreen leaderboard list must clear 48dp bottom system bar',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('CreativeEmpireScreen protects top header, bio modal sheet & toggles overlay icon brightness cleanly', (tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const CreativeEmpireScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Top back button must clear 48dp status bar / cutout
      final backRect = tester.getRect(find.byIcon(Icons.arrow_forward_ios_rounded));
      expect(backRect.top, greaterThanOrEqualTo(48.0));

      // Verify AnnotatedRegion uses non-deprecated royalOverlayStyle in dark mode
      final regionFinder = find.descendant(
        of: find.byType(CreativeEmpireScreen),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(regionFinder, findsOneWidget);
      expect(
        tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(regionFinder).value,
        AppTheme.royalOverlayStyle,
      );

      // Toggle light mode FAB -> flips overlay icon brightness to dark without setting statusBarColor
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(
        tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(regionFinder).value,
        AppTheme.lightSurfaceOverlayStyle,
      );

      // Scroll down to Team section (_TeamMemberTile has unique trailing info_outline icon)
      for (int i = 0; i < 15 && find.byIcon(Icons.info_outline_rounded).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
      await tester.pump(const Duration(milliseconds: 50));

      final tileTextColumn = find.descendant(
        of: find.ancestor(
          of: find.byIcon(Icons.info_outline_rounded).first,
          matching: find.byType(Row),
        ).first,
        matching: find.byType(Column),
      ).first;
      await tester.ensureVisible(tileTextColumn);
      await tester.pump();
      await tester.tap(tileTextColumn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final bioTexts = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Text),
      );
      expect(bioTexts, findsAtLeastNWidgets(3));
      expect(
        tester.getRect(bioTexts.last).bottom,
        lessThanOrEqualTo(752.0),
        reason: 'Team member bio modal sheet must stay clear of bottom system nav bar',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('IslamicQuoteCard bottom sheet & CoachMarkOverlay keep bottom CTA controls clear of 48dp system nav bar', (tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      final sampleQuote = Quote(
        id: 'q1',
        title: 'نور العلم',
        author: 'الإمام الشافعي',
        text: 'العلم ما نفع، ليس العلم ما حُفظ.',
        reference: 'حلية الأولياء',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Scaffold(
            body: Center(
              child: IslamicQuoteCard(quotes: [sampleQuote]),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.textContaining('العلم ما نفع').first);
      await tester.pumpAndSettle();

      final copyButton = find.text('نسخ الحكمة المباركة');
      expect(copyButton, findsOneWidget);
      expect(
        tester.getRect(copyButton).bottom,
        lessThanOrEqualTo(752.0),
        reason: 'Quote modal copy button must stay above 48dp system navigation bar',
      );

      // Close sheet cleanly before testing CoachMarkOverlay
      Navigator.of(tester.element(copyButton)).pop();
      await tester.pumpAndSettle();

      final targetKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: SizedBox(
                    key: targetKey,
                    width: 120,
                    height: 48,
                  ),
                ),
                CoachMarkOverlay(
                  steps: [
                    CoachMarkStep(
                      key: targetKey,
                      title: 'مرحبا بك',
                      description: 'خطوة تجريبية للتأكد من سلامة الحواف السفلية.',
                    ),
                  ],
                  onFinished: () {},
                  onSkipped: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final skipRect = tester.getRect(find.text('تخطي'));
      final startRect = tester.getRect(find.text('ابدأ'));
      expect(skipRect.bottom, lessThanOrEqualTo(752.0));
      expect(startRect.bottom, lessThanOrEqualTo(752.0));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('GloryRoadScreen (Level 15+) & GloryLevelStepCard(level 10) equip button render cleanly on 360dp', (WidgetTester tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);
      final highProfile = PlayerProfile(
        id: 'glory_l15_profile',
        name: 'فارس المجد',
        totalScore: PlayerLevelInfo.cumulativeXpForLevel(15),
        highScore: 100,
        coins: 5000,
        gems: 50,
        trophies: 2400,
      );
      await SharedPrefsService.saveProfilesJson(PlayerProfile.profilesToJson([highProfile]));
      await SharedPrefsService.setActiveProfileId(highProfile.id);
      await ProfileService.instance.init();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const GloryRoadScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GloryLevelStepCard(
                    level: 10,
                    currentLevelInfo: PlayerLevelInfo.fromTotalScore(
                      PlayerLevelInfo.cumulativeXpForLevel(15),
                    ),
                    equippedFrame: '',
                    customTheme: AppCustomTheme.andalusianGold,
                    onEquipFrame: (_, __) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('تفعيل الإطار'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('KnightsStoreScreen switches across all 4 tabs without overflow on 360dp', (WidgetTester tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const KnightsStoreScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);

      for (final tabLabel in const [
        'الأطر المتوهجة (10)',
        'أوسمة الفرسان',
        'وسائل المساعدة',
        'الثيمات الملكية (4)',
      ]) {
        final tabFinder = find.text(tabLabel);
        await tester.ensureVisible(tabFinder);
        await tester.pump();
        await tester.tap(tabFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: 'Overflow/exception on tab $tabLabel');
      }

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('PrivateRoomHubScreen PIN boxes, WaitingRoomScreen GridView & compact LobbyScreen do not overflow on 360dp', (WidgetTester tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const PrivateRoomHubScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);

      await ChallengeGameService.instance.initAsHost(
        ChallengeConfig(
          challengeId: 'CH_EDGE_TEST',
          hostName: 'فارس الميدان الطويل جداً',
          hostAvatarIndex: '0',
          type: ChallengeType.bruteForce,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const WaitingRoomScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Compact height check for LobbyScreen (360x640dp with 48dp+48dp insets)
      tester.view.physicalSize = const Size(1080, 1920);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const LobbyScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await ChallengeGameService.instance.reset();
    });

    testWidgets('ResultScreen (landscape horizontal cutout + userAnswers) & QuizReviewDialog keep controls safe and overflow-free', (WidgetTester tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);
      // 30dp left/right display cutout + 48dp top/bottom insets
      tester.view.padding = const FakeViewPadding(left: 90, right: 90, top: 144, bottom: 144);
      tester.view.viewPadding = const FakeViewPadding(left: 90, right: 90, top: 144, bottom: 144);

      final sampleQuestion = Question(
        id: 'q1',
        categoryId: 'quraan',
        levelNumber: 1,
        questionText: 'كم عدد سور القرآن الكريم؟',
        options: ['112', '113', '114', '115'],
        correctAnswerIndex: 2,
        explanation: 'عدد سور القرآن الكريم مائة وأربع عشرة سورة.',
      );
      final sampleAnswers = [
        {
          'question': sampleQuestion,
          'selectedOptionIndex': 2,
          'isCorrect': true,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: ResultScreen(
            correctAnswers: 4,
            totalQuestions: 5,
            totalScore: 420,
            categoryId: 'quraan',
            levelId: 'quraan_1',
            levelNumber: 1,
            userAnswers: sampleAnswers,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.takeException(), isNull);

      final shareFinder = find.byIcon(Icons.share_rounded);
      expect(shareFinder, findsOneWidget);
      final shareRect = tester.getRect(shareFinder);
      expect(shareRect.left, greaterThanOrEqualTo(30.0));

      // Open QuizReviewDialog under same tight cutout viewport
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    QuizReviewDialog.show(
                      ctx,
                      userAnswers: sampleAnswers,
                    );
                  },
                  child: const Text('مراجعة'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('مراجعة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('مراجعة الإجابات'), findsOneWidget);
      final reviewHeaderRect = tester.getRect(find.text('مراجعة الإجابات'));
      expect(reviewHeaderRect.left, greaterThanOrEqualTo(30.0));
      expect(reviewHeaderRect.right, lessThanOrEqualTo(330.0));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('ResultCard, ChallengeResultScreen & GameMatchResultDialog render safely without clipping or overflow on 360dp', (WidgetTester tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);
      final winner = MultiplayerPlayer(
        id: 'p1',
        name: 'الفارس الأول صاحب الاسم الطويل',
        avatarIndex: 0,
        isHost: true,
        score: 1250,
        correctAnswers: 10,
        totalTimeMs: 24500,
      );
      final runnerUp = MultiplayerPlayer(
        id: 'p2',
        name: 'الفارس الثاني المنافس القوي',
        avatarIndex: 1,
        score: 980,
        correctAnswers: 8,
        totalTimeMs: 31200,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ResultCard(
                      player: winner,
                      rank: 1,
                      totalQuestions: 10,
                      isLocalPlayer: true,
                      isWinner: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 274,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          ResultCard(
                            player: runnerUp,
                            rank: 2,
                            totalQuestions: 10,
                            isLocalPlayer: false,
                            isWinner: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const ChallengeResultScreen(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    GameMatchResultDialog.show(
                      ctx,
                      isWinner: true,
                      isDraw: false,
                      effectiveDelta: 24,
                      totalTrophies: 1344,
                      coinsEarned: 50,
                      myScore: 900,
                      opponentScore: 720,
                      opponentName: 'فارس الأندلس طويل الاسم',
                      isBot: true,
                      onDismiss: () {},
                    );
                  },
                  child: const Text('فتح النتيجة'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('فتح النتيجة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('OnboardingScreen, ProfileSetupScreen, Settings dialogs, AppDialogs, AchievementPopup, CreativeEmpire _ProjectPopup & CoachMarkOverlay handle 360dp & cutouts safely', (WidgetTester tester) async {
      _configureAndroid15EdgeToEdgeViewport(tester);

      // 1. OnboardingScreen
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const OnboardingScreen(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 2. ProfileSetupScreen (create + edit modes)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const ProfileSetupScreen(isFirstTime: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: ProfileSetupScreen(
            existingProfile: ProfileService.instance.activeProfile,
            isFirstTime: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // 3. SettingsScreen + all 3 AlertDialogs
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const SettingsScreen(),
        ),
      );
      await tester.pump();
      for (final tileTitle in const [
        'إعادة تعيين التقدم',
        'حذف الحساب والبيانات',
        'سياسة الخصوصية وأمان البيانات',
      ]) {
        final finder = find.text(tileTitle);
        await tester.scrollUntilVisible(
          finder,
          220.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(finder);
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Settings dialog failed for $tileTitle');
        await tester.tapAt(const Offset(10, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }

      // 4. AppDialogs.showExitConfirmationDialog & AchievementPopup.show
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => AppDialogs.showExitConfirmationDialog(ctx),
                    child: const Text('حوار الخروج'),
                  ),
                  ElevatedButton(
                    onPressed: () => AchievementPopup.show(
                      ctx,
                      const Achievement(
                        id: 'ach_edge_test',
                        title: 'فاتح الآفاق الإسلامية الكبرى',
                        description: 'أكملت تحدي التخطيط والتنسيق على جميع قياسات أندرويد 15 بنجاح تام',
                        icon: '🏆',
                        category: AchievementCategory.mastery,
                        rarity: AchievementRarity.legendary,
                        targetValue: 1,
                      ),
                    ),
                    child: const Text('حوار الإنجاز'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('حوار الخروج'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 100));
      await tester.pump();

      await tester.tap(find.text('حوار الإنجاز'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('فاتح الآفاق الإسلامية الكبرى'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // 5. CreativeEmpireScreen -> scroll down to lazy sliver project card & open _ProjectPopup
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('creative_empire_popup_test'),
          theme: AppTheme.getThemeFor(AppCustomTheme.andalusianGold),
          home: const CreativeEmpireScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final gridFinder = find.byType(GridView);
      await tester.scrollUntilVisible(
        gridFinder,
        300.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final firstProjectCard = find.descendant(
        of: gridFinder.first,
        matching: find.byType(GestureDetector),
      ).first;
      await tester.ensureVisible(firstProjectCard);
      await tester.pump();
      await tester.tap(firstProjectCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.takeException(), isNull);

      // 6. CoachMarkOverlay first-frame unattached GlobalKey guard + horizontal 30dp cutout clearance
      tester.view.padding = const FakeViewPadding(left: 90, right: 90, top: 144, bottom: 144);
      tester.view.viewPadding = const FakeViewPadding(left: 90, right: 90, top: 144, bottom: 144);
      final deferredKey = GlobalKey();
      bool attachTarget = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (ctx, setState) {
              return Scaffold(
                body: Stack(
                  children: [
                    if (attachTarget)
                      Positioned(
                        left: 16,
                        bottom: 90,
                        child: Container(
                          key: deferredKey,
                          width: 48,
                          height: 48,
                          color: Colors.amber,
                        ),
                      ),
                    CoachMarkOverlay(
                      steps: [
                        CoachMarkStep(
                          key: deferredKey,
                          title: 'دليل المعركة',
                          description: 'تحقق من احترام الحواف الأفقية والشريط السفلي',
                        ),
                      ],
                      onFinished: () {},
                      onSkipped: () {},
                    ),
                    Positioned(
                      top: 60,
                      right: 40,
                      child: ElevatedButton(
                        onPressed: () => setState(() => attachTarget = true),
                        child: const Text('attach'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      // Frame 1 with unattached key must not crash
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Frame 2 attaches target key and verifies tooltip obeys left >= 30dp & right <= 330dp & bottom <= 752dp
      await tester.tap(find.text('attach'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);

      final titleRect = tester.getRect(find.text('دليل المعركة'));
      expect(titleRect.left, greaterThanOrEqualTo(30.0));
      expect(titleRect.right, lessThanOrEqualTo(330.0));
      expect(titleRect.bottom, lessThanOrEqualTo(752.0));

      // Verify tooltip shown BELOW a top target does not double-count the 48dp top inset
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 60,
                  left: 40,
                  child: Container(
                    key: deferredKey,
                    width: 48,
                    height: 48,
                    color: Colors.amber,
                  ),
                ),
                CoachMarkOverlay(
                  steps: [
                    CoachMarkStep(
                      key: deferredKey,
                      title: 'دليل الأعلى',
                      description: 'يجب ألا تتضاعف مسافة الشريط العلوي',
                    ),
                  ],
                  onFinished: () {},
                  onSkipped: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      final targetTopRect = tester.getRect(find.byKey(deferredKey));
      final belowTooltipTitleRect = tester.getRect(find.text('دليل الأعلى'));
      expect(belowTooltipTitleRect.left, greaterThanOrEqualTo(30.0));
      expect(belowTooltipTitleRect.right, lessThanOrEqualTo(330.0));
      expect(belowTooltipTitleRect.top - targetTopRect.bottom, lessThan(56.0));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
