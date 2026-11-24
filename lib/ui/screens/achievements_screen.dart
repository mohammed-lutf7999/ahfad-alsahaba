import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../data/models/achievement_model.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/profile_service.dart';
import 'achievements/achievement_card.dart';

/// شاشة عرض جميع الإنجازات
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_CategoryTab> _tabs = const [
    _CategoryTab('الكل', null, Icons.grid_view_rounded),
    _CategoryTab('تعلم', AchievementCategory.learning, Icons.school_rounded),
    _CategoryTab('إتقان', AchievementCategory.mastery, Icons.star_rounded),
    _CategoryTab('فئات', AchievementCategory.categories, Icons.category_rounded),
    _CategoryTab(
      'كمال',
      AchievementCategory.perfection,
      Icons.check_circle_rounded,
    ),
    _CategoryTab('سرعة', AchievementCategory.speed, Icons.flash_on_rounded),
    _CategoryTab(
      'مثابرة',
      AchievementCategory.dedication,
      Icons.local_fire_department_rounded,
    ),
    _CategoryTab('نقاط', AchievementCategory.points, Icons.stars_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    AchievementService.instance.addListener(_onServiceChanged);
    ProfileService.instance.addListener(_onServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reconcileAndMarkSeen());
    });
  }

  Future<void> _reconcileAndMarkSeen() async {
    await AchievementService.instance.reconcileAchievements();
    await AchievementService.instance.markAllUnlockedAsSeen();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AchievementService.instance.removeListener(_onServiceChanged);
    ProfileService.instance.removeListener(_onServiceChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = AchievementService.instance;
    final progress = service.overallProgress;
    final unlocked = service.unlockedCount;
    final total = AchievementDefinitions.all.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(unlocked, total, progress),
              _buildTabs(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs
                      .map((tab) => _buildAchievementList(tab.category))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int unlocked, int total, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor.withAlpha(80),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: AppTheme.primaryDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                AppTheme.accentLight,
                                AppTheme.accentColor,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'الإنجازات',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '$unlocked / $total',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  SoundService().playClick();
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentColor.withAlpha(80),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% مكتمل',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppTheme.primaryDark,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(25),
        ),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: _tabs
            .map(
              (tab) => Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 16),
                      const SizedBox(width: 6),
                      Text(tab.name),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAchievementList(AchievementCategory? category) {
    final achievements = category == null
        ? AchievementService.instance.getAllAchievementsWithProgress()
        : AchievementService.instance.getByCategory(category);

    achievements.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
      return b.achievement.rarity.index.compareTo(a.achievement.rarity.index);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievements.length,
      itemBuilder: (context, index) => AchievementCard(
        achievementWithProgress: achievements[index],
      ),
    );
  }
}

class _CategoryTab {
  final String name;
  final AchievementCategory? category;
  final IconData icon;

  const _CategoryTab(this.name, this.category, this.icon);
}
