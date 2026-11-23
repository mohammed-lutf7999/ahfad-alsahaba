import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ahfad_alsahaba/core/cms_icon_registry.dart';
import 'package:ahfad_alsahaba/core/date_formatters.dart';
import 'package:ahfad_alsahaba/data/models/achievement_model.dart';
import 'package:ahfad_alsahaba/data/models/app_control_models.dart';
import 'package:ahfad_alsahaba/data/models/cms_models.dart';
import 'package:ahfad_alsahaba/data/models/player_profile_model.dart';
import 'package:ahfad_alsahaba/data/services/admin_service.dart';
import 'package:ahfad_alsahaba/data/services/control/app_control_snapshot_differ.dart';
import 'package:ahfad_alsahaba/data/services/profile/profile_merger.dart';
import 'package:ahfad_alsahaba/data/services/question/question_cms_merger.dart';
import 'package:ahfad_alsahaba/ui/screens/admin/widgets/admin_ui_kit.dart';
import 'package:ahfad_alsahaba/ui/widgets/app_snackbar.dart';

void main() {
  group('Plan 21 Wave 1 — Clean Architecture & Modular Services', () {
    test('DateFormatters formats dates, times, and countdowns deterministically', () {
      final dt = DateTime(2026, 11, 5, 9, 7);
      expect(DateFormatters.formatShortDate(dt), '5/11/2026');
      expect(DateFormatters.formatHourMinute(dt), '09:07');
      expect(DateFormatters.formatDayMonthTime(dt), '05/11 • 09:07');
      expect(DateFormatters.formatDayMonthTime(null), '');
      expect(DateFormatters.formatAdminTimestamp(dt), '2026-11-05 09:07');
      expect(DateFormatters.formatAdminTimestamp(null), '—');
      expect(DateFormatters.formatCountdown(95), '01:35');
      expect(DateFormatters.formatCountdown(-5), '00:00');
    });

    test('CmsIconRegistry resolves guild banner icons safely with index clamping', () {
      expect(CmsIconRegistry.guildBannerIcons.length, 6);
      expect(
        CmsIconRegistry.guildBannerIconFor(-10),
        CmsIconRegistry.guildBannerIcons.first,
      );
      expect(
        CmsIconRegistry.guildBannerIconFor(999),
        CmsIconRegistry.guildBannerIcons.last,
      );
    });

    test('ProfileMerger enforces AGENTS.md Rule #3 GREATEST merge guarantee', () {
      final local = PlayerProfile.create(
        name: 'فارس اليرموك',
        avatarIndex: 2,
        playerCode: 'SAH-7788',
      )
        ..totalScore = 4500
        ..highScore = 900
        ..coins = 1200
        ..gems = 45
        ..trophies = 1350
        ..winStreak = 6
        ..equippedTheme = 'constantinople_night'
        ..equippedFrame = 'frame_gold'
        ..equippedTitle = 'سيف الله'
        ..unlockedItemIds.addAll(['theme_1', 'frame_gold'])
        ..categoryProgress['seerah'] = 7
        ..levelStars['seerah_1'] = 3
        ..levelScores['seerah_1'] = 250
        ..achievementProgress['ach_1'] = AchievementProgress(
          achievementId: 'ach_1',
          currentValue: 10,
          isUnlocked: true,
        );

      final cloud = PlayerProfile.create(
        name: 'لاعب',
        avatarIndex: 0,
        playerCode: 'SAH-1122',
      )
        ..totalScore = 1200
        ..highScore = 300
        ..coins = 400
        ..gems = 10
        ..trophies = 1100
        ..winStreak = 2
        ..categoryProgress['seerah'] = 3
        ..categoryProgress['quran'] = 5
        ..levelStars['seerah_1'] = 1
        ..levelScores['seerah_1'] = 100;

      ProfileMerger.mergeLocalIntoCloud(local, cloud);

      expect(cloud.playerCode, 'SAH-7788');
      expect(cloud.name, 'فارس اليرموك');
      expect(cloud.totalScore, 4500);
      expect(cloud.highScore, 900);
      expect(cloud.coins, 1200);
      expect(cloud.gems, 45);
      expect(cloud.trophies, 1350);
      expect(cloud.winStreak, 6);
      expect(cloud.equippedTheme, 'constantinople_night');
      expect(cloud.equippedFrame, 'frame_gold');
      expect(cloud.equippedTitle, 'سيف الله');
      expect(cloud.unlockedItemIds, containsAll(['theme_1', 'frame_gold']));
      expect(cloud.categoryProgress['seerah'], 7);
      expect(cloud.categoryProgress['quran'], 5);
      expect(cloud.levelStars['seerah_1'], 3);
      expect(cloud.levelScores['seerah_1'], 250);
      expect(cloud.achievementProgress['ach_1']?.isUnlocked, isTrue);
    });

    test('AppControlSnapshotDiffer filters expired/seen announcements and compares snapshots', () {
      final now = DateTime.utc(2026, 11, 22, 12);
      final activeAnn = AppAnnouncement(
        id: 'ann-1',
        title: 'بطولة الجمعة',
        body: 'انطلقوا',
        messageType: AnnouncementType.admin,
        targetScope: 'all',
        isDismissible: true,
        isActive: true,
        expiresAt: now.add(const Duration(hours: 4)),
      );
      final seenAnn = AppAnnouncement(
        id: 'ann-seen',
        title: 'قديم',
        body: 'مقروء',
        messageType: AnnouncementType.normal,
        targetScope: 'all',
        isDismissible: true,
        isActive: true,
      );

      final raw = AppControlSnapshot(
        configVersion: 10,
        cmsVersion: 4,
        isAdmin: false,
        playerPermissions: const PlayerPermissions(),
        releaseConfig: const AppReleaseConfig(),
        announcements: [activeAnn, seenAnn],
        syncedAt: now,
      );

      final sanitized = AppControlSnapshotDiffer.sanitizeForNow(
        raw: raw,
        nowUtc: now,
        seenAnnouncementIds: {'ann-seen'},
        buildCode: 21,
      );

      expect(sanitized.announcements.length, 1);
      expect(sanitized.announcements.first.id, 'ann-1');
      expect(
        AppControlSnapshotDiffer.sameReleaseConfig(
          const AppReleaseConfig(),
          const AppReleaseConfig(),
        ),
        isTrue,
      );
      expect(
        AppControlSnapshotDiffer.samePlayerPermissions(
          const PlayerPermissions(),
          const PlayerPermissions(),
        ),
        isTrue,
      );
    });

    test('QuestionCmsMerger maps base and dynamic questions while preserving correct answer after shuffle', () {
      final q = QuestionCmsMerger.mapQuestionEntry(
        {
          'id': 's1_1',
          'question': 'في أي عام ولد النبي ﷺ؟',
          'options': ['عام الجوع', 'عام الفيل', 'عام الحزن', 'عام الفتح'],
          'correct': 1,
          'explanation': 'ولد في عام الفيل',
        },
        categoryId: 'seerah',
        levelNumber: 1,
        optionRandom: Random(42),
      );
      expect(q.options[q.correctAnswerIndex], 'عام الفيل');

      final dyn = QuestionCmsMerger.mapDynamicQuestion(
        const DynamicQuizQuestionData(
          id: 'cms_q1',
          categoryId: 'fiqh',
          levelNumber: 2,
          questionText: 'كم عدد أركان الإسلام؟',
          options: ['3', '4', '5', '6'],
          correctIndex: 2,
          explanation: 'خمسة أركان',
          isVisible: true,
          sortOrder: 10,
          syncScope: 'solo_only',
        ),
        optionRandom: Random(99),
      );
      expect(dyn.options[dyn.correctAnswerIndex], '5');
    });

    test('Decomposed AdminService mixins wire and reset all domain overrides cleanly', () async {
      final admin = AdminService();
      admin.resetForTesting();

      admin.overviewFetcherOverride = () async => const AdminOverview(
            totalAccounts: 100,
            directoryPlayers: 120,
            guestPlayers: 20,
            active24h: 35,
            activeEvents: 1,
            activeAnnouncements: 2,
          );

      final ov = await admin.getOverview();
      expect(ov?.totalAccounts, 100);

      admin.resetForTesting();
      expect(admin.overviewFetcherOverride, isNull);
    });

    testWidgets('Admin shared components and AppSnackBar render cleanly on 360x800dp', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                child: Column(
                  children: [
                    const AdminStatusBanner(
                      message: 'تم تحديث الصلاحيات بنجاح',
                    ),
                    const AdminEmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'لا توجد بلاغات حالياً',
                      subtitle: 'الديوان نظيف تماماً',
                    ),
                    const AdminAccessDeniedView(),
                    ElevatedButton(
                      onPressed: () =>
                          AppSnackBar.success(context, 'تم الحفظ بنجاح'),
                      child: const Text('اختبار تنبيه'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('تم تحديث الصلاحيات بنجاح'), findsOneWidget);
      expect(find.text('لا توجد بلاغات حالياً'), findsOneWidget);
      expect(find.byType(AdminAccessDeniedView), findsOneWidget);

      await tester.tap(find.text('اختبار تنبيه'));
      await tester.pump();
      expect(find.text('تم الحفظ بنجاح'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
