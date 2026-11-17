import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ahfad_alsahaba/core/theme/app_custom_theme.dart';
import 'package:ahfad_alsahaba/data/local/shared_prefs_service.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/models/store_item_model.dart';
import 'package:ahfad_alsahaba/data/services/app_control_service.dart';
import 'package:ahfad_alsahaba/data/services/cms_cache_service.dart';
import 'package:ahfad_alsahaba/data/services/library_service.dart';
import 'package:ahfad_alsahaba/data/services/profile_service.dart';
import 'package:ahfad_alsahaba/data/services/progression_service.dart';
import 'package:ahfad_alsahaba/data/services/question_service.dart';
import 'package:ahfad_alsahaba/data/services/store_service.dart';
import 'package:ahfad_alsahaba/logic/game_controller.dart';
import 'package:ahfad_alsahaba/ui/screens/store/knights_store_screen.dart';
import 'package:ahfad_alsahaba/ui/widgets/animated_avatar_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.init(forceReload: true);
    AppControlService.instance.resetForTesting();
    CmsCacheService.instance.resetForTesting();
    StoreService.instance.resetForTesting();
    QuestionService().clearCache();

    final testProfile = PlayerProfile.create(
      name: 'فارس الاختبار',
      linkedUserId: 'uid_cms_test',
    )
      ..totalScore = 50000
      ..coins = 10000
      ..gems = 100;
    await SharedPrefsService.saveProfilesJson(
      PlayerProfile.profilesToJson([testProfile]),
    );
    await SharedPrefsService.setActiveProfileId(testProfile.id);
    await ProfileService.instance.init();
  });

  group('Phase 6: Hybrid Dynamic CMS, Safe Visibility & Store Hardening', () {
    test('CmsCacheService syncs once on version bump, passes owned IDs & hydrates at 0ms from cache', () async {
      final profile = ProfileService.instance.activeProfile!;
      profile.unlockedItemIds.add('theme_legacy_hidden');

      int fetchCalls = 0;
      List<String> capturedOwned = [];

      CmsCacheService.instance.bundleFetcherOverride = ({
        required int clientCmsVersion,
        required List<String> ownedItemIds,
      }) async {
        fetchCalls++;
        capturedOwned = List<String>.from(ownedItemIds);
        return {
          'changed': true,
          'incremental': clientCmsVersion > 0,
          'cms_version': 2,
          'store_items': [
            {
              'id': 'theme_legacy_hidden',
              'title': 'ثيم قديم مملوك',
              'description': 'ثيم موسمي سابق',
              'category': 'theme',
              'price_coins': 1200,
              'price_gems': 0,
              'min_level': 1,
              'asset_key': 'legacy_hidden',
              'is_visible': false,
              'sort_order': 15,
              'metadata': {
                'deepBackground': '#09111E',
                'surfaceCard': '#142842',
                'sovereignAccent': '#FBBF24',
                'secondaryAccent': '#60A5FA',
              },
              'cms_revision': 2,
            },
          ],
          'library_sections': [],
          'library_items': [],
          'quiz_categories': [],
          'quiz_questions': [],
        };
      };

      final applied = await CmsCacheService.instance.syncIfNeeded(
        serverCmsVersion: 2,
      );
      expect(applied, isTrue);
      expect(fetchCalls, 1);
      expect(capturedOwned, contains('theme_legacy_hidden'));

      // Second sync at same server version must skip network entirely (0 calls)
      final skipped = await CmsCacheService.instance.syncIfNeeded(
        serverCmsVersion: 2,
      );
      expect(skipped, isFalse);
      expect(fetchCalls, 1);

      // Simulate cold app restart hydrating 0ms from SharedPreferences
      CmsCacheService.instance.resetForTesting();
      expect(CmsCacheService.instance.cachedCmsVersion, 0);
      await CmsCacheService.instance.initFromCache();
      expect(CmsCacheService.instance.cachedCmsVersion, 2);
      expect(
        CmsCacheService.instance.snapshot.storeItems['theme_legacy_hidden']?.title,
        'ثيم قديم مملوك',
      );
    });

    test('Dynamic cloud themes, frames & titles resolve live, while hidden unowned items stay blocked and owned hidden items remain usable', () async {
      final profile = ProfileService.instance.activeProfile!;
      profile.unlockedItemIds.add('title_owned_secret');

      CmsCacheService.instance.bundleFetcherOverride = ({
        required int clientCmsVersion,
        required List<String> ownedItemIds,
      }) async {
        return {
          'changed': true,
          'incremental': false,
          'cms_version': 3,
          'store_items': [
            {
              'id': 'theme_ramadan_crescent',
              'title': 'ثيم هلال رمضان',
              'description': 'إطلالة رمضانية روحانية',
              'category': 'theme',
              'price_coins': 500,
              'price_gems': 0,
              'min_level': 1,
              'asset_key': 'ramadan_crescent',
              'is_visible': true,
              'sort_order': 5,
              'metadata': {
                'deepBackground': '#071318',
                'surfaceCard': '#11303B',
                'sovereignAccent': '#FDE047',
                'secondaryAccent': '#2DD4BF',
                'iconName': 'nights_stay_rounded',
              },
              'cms_revision': 3,
            },
            {
              'id': 'item_frame_andalus_azure',
              'title': 'إطار أندلسي لازوردي جديد',
              'description': 'إطار ديناميكي من السحابة',
              'category': 'frame',
              'price_coins': 400,
              'price_gems': 0,
              'min_level': 1,
              'asset_key': 'frame_andalus_azure',
              'is_visible': true,
              'sort_order': 5,
              'metadata': {
                'primaryColor': '#1D4ED8',
                'secondaryColor': '#38BDF8',
                'highlightColor': '#E0F2FE',
                'hasOctagonalStar': true,
                'hasCornerGems': true,
                'hasCrownCrest': true,
              },
              'cms_revision': 3,
            },
            {
              'id': 'title_unowned_hidden',
              'title': 'لقب مسودة مخفي',
              'description': 'لا يظهر لغير المالكين',
              'category': 'title',
              'price_coins': 200,
              'price_gems': 0,
              'min_level': 1,
              'asset_key': 'مسودة مخفية',
              'is_visible': false,
              'sort_order': 10,
              'metadata': {},
              'cms_revision': 3,
            },
            {
              'id': 'title_owned_secret',
              'title': 'لقب «فارس موسم سابق»',
              'description': 'يبقى مملوكاً ومفعّلاً حتى بعد الإخفاء',
              'category': 'title',
              'price_coins': 1000,
              'price_gems': 0,
              'min_level': 1,
              'asset_key': 'فارس موسم سابق',
              'is_visible': false,
              'sort_order': 11,
              'metadata': {'previewColor': '#38BDF8'},
              'cms_revision': 3,
            },
          ],
          'library_sections': [],
          'library_items': [],
          'quiz_categories': [],
          'quiz_questions': [],
        };
      };

      await CmsCacheService.instance.syncIfNeeded(serverCmsVersion: 3);

      // 1. Dynamic theme resolves colors smoothly
      final dynTheme = AppCustomTheme.fromId('ramadan_crescent');
      expect(dynTheme.themeName, 'ثيم هلال رمضان');
      expect(dynTheme.sovereignAccent, const Color(0xFFFDE047));

      // 2. Dynamic procedural frame resolves style cleanly
      final dynFrame = RoyalFrameStyle.resolve(frameKey: 'frame_andalus_azure');
      expect(dynFrame.frameKey, 'frame_andalus_azure');
      expect(dynFrame.secondaryColor, const Color(0xFF38BDF8));
      expect(dynFrame.hasCrownCrest, isTrue);

      // 3. Visibility filter: hides unowned hidden title, preserves owned hidden title
      final titles = StoreService.instance.itemsByCategory(StoreItemCategory.title);
      expect(titles.any((t) => t.id == 'title_unowned_hidden'), isFalse);
      expect(titles.any((t) => t.id == 'title_owned_secret'), isTrue);

      // Direct purchase attempt on hidden unowned item fails safely
      final hiddenItem = StoreService.instance.catalog
          .firstWhere((i) => i.id == 'title_unowned_hidden');
      final blockedRes = await StoreService.instance.purchaseOrEquip(hiddenItem);
      expect(blockedRes.success, isFalse);

      // Owner CAN equip their hidden owned title freely
      final ownedHidden =
          titles.firstWhere((i) => i.id == 'title_owned_secret');
      final equipRes = await StoreService.instance.purchaseOrEquip(ownedHidden);
      expect(equipRes.success, isTrue);
      expect(profile.effectiveTitle, 'فارس موسم سابق');

      // 4. Server purchase rejection aborts cleanly without deducting local coins
      final beforeCoins = profile.coins;
      StoreService.instance.purchaseRpcOverride = ({
        required String userId,
        required String itemId,
      }) async =>
          {'success': false, 'error': 'رفض من الخادم: رصيد غير مطابق'};
      final dynThemeItem = StoreService.instance.catalog
          .firstWhere((i) => i.id == 'theme_ramadan_crescent');
      final failRes = await StoreService.instance.purchaseOrEquip(dynThemeItem);
      expect(failRes.success, isFalse);
      expect(failRes.message, contains('رفض من الخادم'));
      expect(profile.coins, beforeCoins);

      // Server accepts -> succeeds and updates active theme
      StoreService.instance.purchaseRpcOverride = ({
        required String userId,
        required String itemId,
      }) async =>
          {'success': true};
      final buyOk = await StoreService.instance.purchaseOrEquip(dynThemeItem);
      expect(buyOk.success, isTrue);
      expect(ProgressionService.instance.activeTheme.themeId, 'ramadan_crescent');
    });

    testWidgets('KnightsStoreScreen shows hidden-owned badge cleanly on 360x800dp', (tester) async {
      final profile = ProfileService.instance.activeProfile!;
      profile.unlockedItemIds.add('title_owned_secret');

      CmsCacheService.instance.bundleFetcherOverride = ({
        required int clientCmsVersion,
        required List<String> ownedItemIds,
      }) async =>
          {
            'changed': true,
            'incremental': false,
            'cms_version': 2,
            'store_items': [
              {
                'id': 'title_owned_secret',
                'title': 'لقب «فارس موسم سابق»',
                'description': 'وسام نادر',
                'category': 'title',
                'price_coins': 900,
                'price_gems': 0,
                'min_level': 1,
                'asset_key': 'فارس موسم سابق',
                'is_visible': false,
                'sort_order': 1,
                'metadata': {'previewColor': '#38BDF8'},
                'cms_revision': 2,
              },
            ],
          };
      await CmsCacheService.instance.syncIfNeeded(serverCmsVersion: 2);

      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: KnightsStoreScreen(initialTabIndex: 2),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('لقب «فارس موسم سابق»'), findsOneWidget);
      expect(find.text('مقتنى خاص (مخفي)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Incremental delta sync and AppControlService cms_version trigger work seamlessly', () async {
      CmsCacheService.instance.bundleFetcherOverride = ({
        required int clientCmsVersion,
        required List<String> ownedItemIds,
      }) async {
        if (clientCmsVersion == 0) {
          return {
            'changed': true,
            'incremental': false,
            'cms_version': 2,
            'store_items': [],
            'library_sections': [],
            'library_items': [
              {
                'id': 'inc_lib_1',
                'section_id': 'stories',
                'title': 'قصة مضافة أولاً',
                'content': 'محتوى أول',
                'sort_order': 1,
                'is_visible': true,
                'cms_revision': 2,
              },
            ],
            'quiz_categories': [],
            'quiz_questions': [],
          };
        }
        return {
          'changed': true,
          'incremental': true,
          'cms_version': 5,
          'store_items': [],
          'library_sections': [],
          'library_items': [
            {
              'id': 'inc_lib_2',
              'section_id': 'stories',
              'title': 'قصة مضافة بالدلتا',
              'content': 'محتوى ثاني بالدلتا',
              'sort_order': 2,
              'is_visible': true,
              'cms_revision': 5,
            },
          ],
          'quiz_categories': [],
          'quiz_questions': [],
        };
      };

      await CmsCacheService.instance.syncIfNeeded(serverCmsVersion: 2);
      expect(CmsCacheService.instance.cachedCmsVersion, 2);

      AppControlService.instance.rpcStateFetcherOverride = ({
        required String platform,
        required int versionCode,
        required int clientConfigVersion,
        String? playerCode,
      }) async =>
          {
            'changed': false,
            'config_version': 1,
            'cms_version': 5,
            'is_admin': false,
          };

      await AppControlService.instance.syncControlState(force: true);
      // Let background unawaited CMS delta sync settle cleanly
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(CmsCacheService.instance.cachedCmsVersion, 5);
      expect(
        CmsCacheService.instance.snapshot.libraryItems.keys,
        containsAll(['inc_lib_1', 'inc_lib_2']),
      );
    });

    test('Dynamic Library & Dynamic Quiz support new sections, >10 levels, visibility toggles & isolate multiplayer bank', () async {
      CmsCacheService.instance.bundleFetcherOverride = ({
        required int clientCmsVersion,
        required List<String> ownedItemIds,
      }) async =>
          {
            'changed': true,
            'incremental': false,
            'cms_version': 4,
            'store_items': [],
            'library_sections': [
              {
                'id': 'tajweed_live',
                'title': 'أحكام التجويد',
                'icon_name': 'menu_book_rounded',
                'color_hex': '#10B981',
                'sort_order': 5,
                'is_visible': true,
                'cms_revision': 4,
              },
              {
                'id': 'jokes',
                'title': 'طرائف عربية',
                'icon_name': 'emoji_emotions_rounded',
                'color_hex': '#FB7185',
                'sort_order': 60,
                'is_visible': false,
                'cms_revision': 4,
              },
            ],
            'library_items': [
              {
                'id': 'lib_tajweed_1',
                'section_id': 'tajweed_live',
                'title': 'النون الساكنة والتنوين',
                'subtitle': 'أحكام التجويد الأساسية',
                'content': 'للنون الساكنة والتنوين أربعة أحكام: الإظهار، الإدغام، الإقلاب، والإخفاء.',
                'source_ref': 'تحفة الأطفال',
                'sort_order': 1,
                'is_visible': true,
                'cms_revision': 4,
              },
            ],
            'quiz_categories': [
              {
                'id': 'ghazawat',
                'name': 'غزوات وفتوحات',
                'description': 'سير المغازي والفتوحات الإسلامية',
                'icon_name': 'castle_rounded',
                'color_hex': '#B45309',
                'total_levels': 12,
                'sort_order': 5,
                'is_visible': true,
                'is_locked': false,
                'cms_revision': 4,
              },
            ],
            'quiz_questions': [
              {
                'id': 'gh_12_1',
                'category_id': 'ghazawat',
                'level_number': 12,
                'question_text': 'في أي سنة كانت غزوة بدر الكبرى؟',
                'options': ['2 هـ', '3 هـ', '5 هـ', '8 هـ'],
                'correct_index': 0,
                'explanation': 'وقعت غزوة بدر الكبرى في 17 رمضان سنة 2 هـ.',
                'sync_scope': 'solo_only',
                'sort_order': 1,
                'is_visible': true,
                'cms_revision': 4,
              },
              {
                'id': 'gh_12_hidden',
                'category_id': 'ghazawat',
                'level_number': 12,
                'question_text': 'سؤال مخفي للمراجعة',
                'options': ['أ', 'ب', 'ج', 'د'],
                'correct_index': 0,
                'explanation': '',
                'sync_scope': 'solo_only',
                'sort_order': 2,
                'is_visible': false,
                'cms_revision': 4,
              },
            ],
          };

      await CmsCacheService.instance.syncIfNeeded(serverCmsVersion: 4);

      // 1. Library includes new section + item, hides disabled section
      final libSections = await LibraryService.loadLibraryContent(
        rawAssetJsonOverride: jsonEncode({'jokes': []}),
      );
      expect(libSections.any((s) => s.id == 'tajweed_live'), isTrue);
      expect(libSections.any((s) => s.id == 'jokes'), isFalse);
      final tajweedSec = libSections.firstWhere((s) => s.id == 'tajweed_live');
      expect(tajweedSec.items.single.title, 'النون الساكنة والتنوين');

      // 2. Quiz initializes cloud category with 12 levels & loads visible level 12 question
      final gc = GameController();
      gc.initializeCategories();
      final ghCat = gc.categories.firstWhere((c) => c.id == 'ghazawat');
      expect(ghCat.totalLevels, 12);
      expect(gc.categories.first.id, 'ghazawat'); // sortOrder 5 < 10

      await gc.loadQuestionsForLevel('ghazawat', 12);
      expect(gc.currentQuestions.length, 1);
      expect(gc.currentQuestions.single.id, 'gh_12_1');

      // Completing level 11 unlocks level 12 cleanly (beyond old hardcoded 10 cap)
      final profile = ProfileService.instance.activeProfile!;
      profile.setCategoryUnlockedLevels('ghazawat', 12);
      expect(profile.getCategoryUnlockedLevels('ghazawat'), 12);
      expect(profile.isLevelUnlocked('ghazawat', 12), isTrue);

      // Meanwhile built-in default category without override still safely preserves 10 cap
      profile.setCategoryUnlockedLevels('quran', 11);
      expect(profile.getCategoryUnlockedLevels('quran'), 10);

      // Multiplayer question pool ignores solo_only cloud questions
      final mpQuestions = await QuestionService().getQuestionsForMultiplayer(42);
      expect(mpQuestions.length, 5);
      expect(mpQuestions.any((q) => q.id == 'gh_12_1'), isFalse);
    });

    test('Web Admin snake_case metadata resolves exact theme/frame colors & PostgrestException blocks local purchase', () async {
      final snakeThemeItem = StoreItemModel.fromCloudJson({
        'id': 'theme_snake_web',
        'title': 'ثيم ويب متوافق',
        'category': 'theme',
        'price_coins': 250,
        'asset_key': 'snake_web_theme',
        'is_visible': true,
        'metadata': {
          'bg_primary': '#062B22',
          'bg_secondary': '#0C4A3B',
          'surface_card': '#0B3A2E',
          'accent_gold': '#2DD4BF',
          'accent_secondary': '#F472B6',
        },
      });
      final resolvedTheme = AppCustomTheme.fromStoreItem(snakeThemeItem);
      expect(resolvedTheme.deepBackground, equals(const Color(0xFF062B22)));
      expect(resolvedTheme.surfaceCard, equals(const Color(0xFF0B3A2E)));
      expect(resolvedTheme.sovereignAccent, equals(const Color(0xFF2DD4BF)));
      expect(resolvedTheme.secondaryAccent, equals(const Color(0xFFF472B6)));
      expect(snakeThemeItem.previewColor, equals(const Color(0xFF2DD4BF)));

      final snakeFrameItem = StoreItemModel.fromCloudJson({
        'id': 'frame_snake_web',
        'title': 'إطار ويب متوافق',
        'category': 'frame',
        'price_coins': 300,
        'asset_key': 'snake_web_frame',
        'is_visible': true,
        'metadata': {
          'primary_color': '#1E293B',
          'secondary_color': '#38BDF8',
          'glow_color': '#E0F2FE',
          'show_gems': false,
        },
      });
      final resolvedFrame = RoyalFrameStyle.fromStoreItem(snakeFrameItem);
      expect(resolvedFrame.primaryColor, equals(const Color(0xFF1E293B)));
      expect(resolvedFrame.secondaryColor, equals(const Color(0xFF38BDF8)));
      expect(resolvedFrame.highlightColor, equals(const Color(0xFFE0F2FE)));
      expect(resolvedFrame.hasCornerGems, isFalse);

      // PostgrestException from server MUST NOT fall back to local purchase
      final profile = ProfileService.instance.activeProfile!;
      profile.coins = 5000;
      profile.linkedUserId = 'user_auth_1';
      StoreService.instance.purchaseRpcOverride = ({
        required String userId,
        required String itemId,
      }) async {
        throw const PostgrestException(message: 'RLS rejection test', code: '42501');
      };

      final blocked = await StoreService.instance.purchaseOrEquip(snakeThemeItem);
      expect(blocked.success, isFalse);
      expect(blocked.message, contains('RLS rejection test'));
      expect(profile.coins, equals(5000));
      expect(profile.unlockedItemIds.contains('theme_snake_web'), isFalse);
    });
  });
}
