import 'package:flutter/material.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/arena_model.dart';
import '../../../data/models/player_level_model.dart';
import '../../../data/services/profile_service.dart';
import '../../../data/services/progression_service.dart';
import '../../widgets/animated_avatar_frame.dart';
import '../../widgets/glory_progress_bar.dart';
import '../../widgets/level_badge_widget.dart';

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
            _buildArenasRoadTab(
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
              return _buildLevelStepCard(
                lvl: lvl,
                currentLevelInfo: levelInfo,
                equippedFrame: equippedFrame,
                customTheme: customTheme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLevelStepCard({
    required int lvl,
    required PlayerLevelInfo currentLevelInfo,
    required String equippedFrame,
    required AppCustomTheme customTheme,
  }) {
    final milestone = PlayerLevelInfo.forMilestoneLevel(lvl);
    final tier = PlayerLevelInfo.resolveTier(lvl);
    final isCompleted = lvl < currentLevelInfo.level;
    final isCurrent = lvl == currentLevelInfo.level;
    final isTierStart = lvl == tier.minLevel;
    final isFrameUnlocked = currentLevelInfo.level >= tier.minLevel;
    final isFrameEquipped = equippedFrame == tier.frameKey;

    final borderColor = isCurrent
        ? customTheme.sovereignAccent
        : isCompleted
            ? const Color(0xFFF3C644).withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.14);

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Major Historical Tier Header Banner (at Levels 1, 10, 20, ..., 90)
          if (isTierStart)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tier.primaryColor.withValues(alpha: 0.85),
                    tier.secondaryColor.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tier.secondaryColor.withValues(alpha: 0.9),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(tier.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مرتبة «${tier.title}» (المستويات ${tier.minLevel} - ${tier.maxLevel}) • ${tier.frameName}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (isFrameUnlocked)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: isFrameEquipped
                            ? null
                            : () => _handleEquipFrame(
                                  tier.frameKey,
                                  tier.frameName,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFrameEquipped
                              ? Colors.black26
                              : const Color(0xFFF3C644),
                          foregroundColor: const Color(0xFF140B29),
                          disabledBackgroundColor:
                              Colors.black.withValues(alpha: 0.35),
                          disabledForegroundColor: const Color(0xFF6EE7B7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          isFrameEquipped ? 'الإطار مُفعّل ✓' : 'تفعيل الإطار',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Individual Level Step Card (1..100)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? customTheme.surfaceCard
                  : isCompleted
                      ? customTheme.surfaceCard.withValues(alpha: 0.68)
                      : Colors.black.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: isCurrent ? 2.0 : 1.0,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: customTheme.sovereignAccent.withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Status Icon / Level Emblem
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isCompleted || isCurrent
                            ? LinearGradient(
                                colors: [tier.secondaryColor, tier.primaryColor],
                              )
                            : null,
                        color: isCompleted || isCurrent
                            ? null
                            : Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: isCompleted || isCurrent
                              ? const Color(0xFFF3C644)
                              : Colors.white24,
                          width: 1.3,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFFF3C644),
                                size: 22,
                              )
                            : isCurrent
                                ? Text(
                                    '$lvl',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      height: 1.1,
                                    ),
                                  )
                                : const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Colors.white54,
                                    size: 19,
                                  ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Level Title & XP Requirement
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'المستوى $lvl',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: isCompleted || isCurrent
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: customTheme.sovereignAccent
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'موقعك الحالي ⚔️',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: customTheme.sovereignAccent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'اللقب: ${milestone.title} • النقاط المطلوبة: ${milestone.currentLevelFloorXp} XP',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Coin Grant Badge (`L * 50`)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.16)
                            : const Color(0xFFF3C644).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : const Color(0xFFF3C644).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        isCompleted
                            ? '+${milestone.coinGrantForThisLevel} 🪙 ✓'
                            : '+${milestone.coinGrantForThisLevel} 🪙',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: isCompleted
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFF3C644),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),

                // Embedded Progress Bar on the Player's Current Level
                if (isCurrent) ...[
                  const SizedBox(height: 10),
                  GloryProgressBar(
                    levelInfo: currentLevelInfo,
                    height: 10,
                    showRemainingHint: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArenasRoadTab({
    required AppCustomTheme customTheme,
    required ArenaModel currentArena,
    required int trophies,
    required int winStreak,
  }) {
    final safeTrophies = ArenaModel.clampTrophies(trophies);

    return Column(
      children: [
        // 1. Competitive Arena & 800-Trophy Shield Banner
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: currentArena.accentColor.withValues(alpha: 0.75),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          currentArena.accentColor,
                          currentArena.secondaryColor,
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFF3C644),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      currentArena.icon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentArena.name,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          currentArena.subtitle,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentArena.accentColor.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$safeTrophies 🏆',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFFF3C644),
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          'المضاعف ${currentArena.coinMultiplier}x',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: currentArena.accentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 800-Trophy Floor Protection Shield Notice
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.55),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF6EE7B7),
                      size: 17,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'درع الأمان التنافسي: محمي عند سقف 800 كأس (لا هبوط تحت ميدان يثرب)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Color(0xFF6EE7B7),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. List of All 6 Historic Competitive Arenas
        Expanded(
          child: ListView.builder(
            key: const Key('glory_road_arenas_list'),
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
            itemCount: ArenaModel.allArenas.length,
            itemBuilder: (context, index) {
              final arena = ArenaModel.allArenas[index];
              final isCurrent = arena.id == currentArena.id;
              final isUnlocked = safeTrophies >= arena.minTrophies;
              final rangeText = arena.maxTrophies != null
                  ? '${arena.minTrophies} - ${arena.maxTrophies} 🏆'
                  : '${arena.minTrophies}+ 🏆';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? customTheme.surfaceCard
                      : isUnlocked
                          ? customTheme.surfaceCard.withValues(alpha: 0.65)
                          : Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isCurrent
                        ? arena.accentColor
                        : isUnlocked
                            ? arena.accentColor.withValues(alpha: 0.45)
                            : Colors.white12,
                    width: isCurrent ? 2.0 : 1.0,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: arena.accentColor.withValues(alpha: 0.28),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isUnlocked
                                ? RadialGradient(
                                    colors: [
                                      arena.accentColor,
                                      arena.secondaryColor,
                                    ],
                                  )
                                : null,
                            color: isUnlocked ? null : Colors.white10,
                            border: Border.all(
                              color: isUnlocked
                                  ? const Color(0xFFF3C644)
                                  : Colors.white24,
                            ),
                          ),
                          child: Icon(
                            isUnlocked ? arena.icon : Icons.lock_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'الميدان ${arena.id}: ${arena.name}',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: arena.accentColor
                                            .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'ميدانك الحالي ⚔️',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: arena.accentColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${arena.subtitle} • $rangeText',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3C644).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF3C644).withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            '${arena.coinMultiplier}x 🪙',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Color(0xFFF3C644),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isCurrent && arena.nextArena != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: arena.progressInArena(safeTrophies),
                          minHeight: 8,
                          backgroundColor: Colors.black38,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            arena.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'باقي ${arena.trophiesToNextArena(safeTrophies)} كأساً للصعود إلى «${arena.nextArena!.name}» (${arena.nextArena!.coinMultiplier}x 🪙)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
