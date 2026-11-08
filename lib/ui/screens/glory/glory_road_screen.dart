import 'package:flutter/material.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/player_level_model.dart';
import '../../../data/services/profile_service.dart';
import '../../../data/services/progression_service.dart';
import '../../widgets/animated_avatar_frame.dart';
import '../../widgets/glory_progress_bar.dart';
import '../../widgets/level_badge_widget.dart';
import 'widgets/glory_arenas_road_tab.dart';
import 'widgets/glory_level_step_card.dart';

/// Interactive «طريق المجد والميادين» (Glory Road Screen) displaying:
/// - Tab 1: The full 100-Level Mastery Ladder (`1..100`) with `ListView.builder`,
///   auto-scroll to current level, `GloryProgressBar`, coin grants (`L * 50`),
///   and 1-tap equipping of unlocked Royal Frames.
/// - Tab 2: The 6 Historic Competitive Arenas (`800` to `1850+` trophies),
///   coin multipliers (`1.0x` to `2.5x`), and the 800-trophy protection shield.
class GloryRoadScreen extends StatefulWidget {
  final int initialTabIndex;

  const GloryRoadScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<GloryRoadScreen> createState() => _GloryRoadScreenState();
}

class _GloryRoadScreenState extends State<GloryRoadScreen>
    with SingleTickerProviderStateMixin {
  static const double _estimatedItemScrollStep = 116.0;

  late final TabController _tabController;
  late final ScrollController _levelsScrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _levelsScrollController = ScrollController();

    ProgressionService.instance.addListener(_onProgressionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentLevel(animate: false);
    });
  }

  void _onProgressionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToCurrentLevel({bool animate = true}) {
    if (!_levelsScrollController.hasClients) return;
    final currentLevel = ProgressionService.instance.currentLevelInfo.level;
    final targetIndex = (currentLevel - 1).clamp(0, PlayerLevelInfo.maxLevel - 1);
    final rawOffset = (targetIndex * _estimatedItemScrollStep) - 80.0;
    final maxScroll = _levelsScrollController.position.maxScrollExtent;
    final clampedOffset = rawOffset.clamp(0.0, maxScroll > 0 ? maxScroll : 0.0);

    if (animate) {
      _levelsScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _levelsScrollController.jumpTo(clampedOffset);
    }
  }

  @override
  void dispose() {
    ProgressionService.instance.removeListener(_onProgressionChanged);
    _levelsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleEquipFrame(String frameKey, String frameName) async {
    await ProgressionService.instance.equipFrame(frameKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تفعيل «$frameName» بنجاح! ✨',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFF047857),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customTheme =
        Theme.of(context).extension<AppCustomTheme>() ??
        AppCustomTheme.andalusianGold;
    final profile = ProfileService.instance.activeProfile;
    final levelInfo = ProgressionService.instance.currentLevelInfo;
    final arenaInfo = ProgressionService.instance.currentArena;
    final equippedFrame = profile?.equippedFrame ?? levelInfo.frameKey;
    final coins = profile?.coins ?? 100;
    final trophies = profile?.trophies ?? 1000;
    final winStreak = profile?.winStreak ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: customTheme.deepBackground,
        appBar: AppBar(
          backgroundColor: customTheme.surfaceCard.withValues(alpha: 0.95),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'طريق المجد والميادين 👑',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'الانتقال إلى مستواي الحالي',
              onPressed: () {
                if (_tabController.index != 0) {
                  _tabController.animateTo(0);
                }
                _scrollToCurrentLevel(animate: true);
              },
              icon: Icon(
                Icons.my_location_rounded,
                color: customTheme.sovereignAccent,
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: customTheme.sovereignAccent,
            indicatorWeight: 3,
            labelColor: customTheme.sovereignAccent,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.auto_graph_rounded, size: 18),
                text: 'سُلّم الـ 100 مستوى',
              ),
              Tab(
                icon: Icon(Icons.emoji_events_rounded, size: 18),
                text: 'الميادين الستة (6)',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: 100-Level Mastery Ladder
            _buildLevelsRoadTab(
              customTheme: customTheme,
              levelInfo: levelInfo,
              equippedFrame: equippedFrame,
              customTitle: profile?.effectiveTitle,
              coins: coins,
              winStreak: winStreak,
              playerName: profile?.name ?? 'فارس المعرفة',
            ),

            // TAB 2: 6 Historic Competitive Arenas
            GloryArenasRoadTab(
              customTheme: customTheme,
              currentArena: arenaInfo,
              trophies: trophies,
              winStreak: winStreak,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelsRoadTab({
    required AppCustomTheme customTheme,
    required PlayerLevelInfo levelInfo,
    required String equippedFrame,
    String? customTitle,
    required int coins,
    required int winStreak,
    required String playerName,
  }) {
    return Column(
      children: [
        // Top Player Mastery Summary Card
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: customTheme.sovereignAccent.withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedAvatarFrame(
                    frameKey: equippedFrame,
                    level: levelInfo.level,
                    winStreak: winStreak,
                    size: 62,
                    child: Container(
                      color: customTheme.deepBackground,
                      child: Icon(
                        levelInfo.tierIcon,
                        color: customTheme.sovereignAccent,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LevelBadgeWidget(
                          levelInfo: levelInfo,
                          customTitle: customTitle,
                          isCompact: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF3C644).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$coins 🪙',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFFF3C644),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          '${levelInfo.totalScore} XP',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GloryProgressBar(
                levelInfo: levelInfo,
                height: 11,
              ),
            ],
          ),
        ),

        // 100-Level Mastery ListView.builder (60/120fps)
        Expanded(
          child: ListView.builder(
            key: const Key('glory_road_levels_list'),
            controller: _levelsScrollController,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
            itemCount: PlayerLevelInfo.maxLevel,
            itemBuilder: (context, index) {
              final lvl = index + 1;
              return GloryLevelStepCard(
                level: lvl,
                currentLevelInfo: levelInfo,
                equippedFrame: equippedFrame,
                customTheme: customTheme,
                onEquipFrame: _handleEquipFrame,
              );
            },
          ),
        ),
      ],
    );
  }

}
