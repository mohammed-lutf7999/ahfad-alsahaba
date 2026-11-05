import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../data/models/achievement_model.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/profile_service.dart';

/// شاشة عرض جميع الإنجازات
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final List<_CategoryTab> _tabs = [
    _CategoryTab('الكل', null, Icons.grid_view_rounded),
    _CategoryTab('تعلم', AchievementCategory.learning, Icons.school_rounded),
    _CategoryTab('إتقان', AchievementCategory.mastery, Icons.star_rounded),
    _CategoryTab('فئات', AchievementCategory.categories, Icons.category_rounded),
    _CategoryTab('كمال', AchievementCategory.perfection, Icons.check_circle_rounded),
    _CategoryTab('سرعة', AchievementCategory.speed, Icons.flash_on_rounded),
    _CategoryTab('مثابرة', AchievementCategory.dedication, Icons.local_fire_department_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    AchievementService.instance.reconcileAchievements();
    AchievementService.instance.addListener(_onServiceChanged);
    ProfileService.instance.addListener(_onServiceChanged);
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
        decoration: const BoxDecoration(
          gradient: AppTheme.imperialGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(unlocked, total, progress),
              
              // Tabs
              _buildTabs(),
              
              // Achievement List
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) => _buildAchievementList(tab.category)).toList(),
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
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title and Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppTheme.accentColor.withAlpha(80), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: AppTheme.primaryDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppTheme.accentLight, AppTheme.accentColor],
                        ).createShader(bounds),
                        child: const Text(
                          'الإنجازات',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '$unlocked / $total',
                        style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(180)),
                      ),
                    ],
                  ),
                ],
              ),
              // Back button
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
                    border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.accentColor, size: 20),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress bar
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.3),
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
                          color: AppTheme.accentColor.withOpacity(0.5),
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
              color: Colors.white.withOpacity(0.6),
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
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(25),
        ),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: _tabs.map((tab) => Tab(
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
        )).toList(),
      ),
    );
  }

  Widget _buildAchievementList(AchievementCategory? category) {
    List<AchievementWithProgress> achievements;
    
    if (category == null) {
      achievements = AchievementService.instance.getAllAchievementsWithProgress();
    } else {
      achievements = AchievementService.instance.getByCategory(category);
    }
    
    // Sort: unlocked first, then by rarity
    achievements.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) {
        return a.isUnlocked ? -1 : 1;
      }
      return b.achievement.rarity.index.compareTo(a.achievement.rarity.index);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        return _AchievementCard(
          achievementWithProgress: achievements[index],
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementWithProgress achievementWithProgress;

  const _AchievementCard({
    required this.achievementWithProgress,
  });

  Color get _rarityColor {
    switch (achievementWithProgress.achievement.rarity) {
      case AchievementRarity.common:
        return const Color(0xFFCD7F32); // Bronze
      case AchievementRarity.rare:
        return const Color(0xFFC0C0C0); // Silver
      case AchievementRarity.epic:
        return AppTheme.accentColor; // Gold
      case AchievementRarity.legendary:
        return const Color(0xFFB9F2FF); // Diamond
    }
  }

  String get _rarityName {
    switch (achievementWithProgress.achievement.rarity) {
      case AchievementRarity.common:
        return 'شائع';
      case AchievementRarity.rare:
        return 'نادر';
      case AchievementRarity.epic:
        return 'ملحمي';
      case AchievementRarity.legendary:
        return 'أسطوري';
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievement = achievementWithProgress.achievement;
    final isUnlocked = achievementWithProgress.isUnlocked;
    final progress = achievementWithProgress.progressPercent;
    final currentValue = achievementWithProgress.progress.currentValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isUnlocked
              ? [
                  _rarityColor.withOpacity(0.2),
                  _rarityColor.withOpacity(0.05),
                ]
              : [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? _rarityColor.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: _rarityColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Content (on the right for RTL)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  textDirection: TextDirection.rtl,
                  children: [
                    Flexible(
                      child: Text(
                        achievement.isSecret && !isUnlocked ? '???' : achievement.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? Colors.white : Colors.white.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _rarityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _rarityName,
                          style: TextStyle(
                            color: _rarityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Description
                Text(
                  achievement.isSecret && !isUnlocked
                      ? 'إنجاز سري'
                      : achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(isUnlocked ? 0.7 : 0.4),
                  ),
                  textAlign: TextAlign.right,
                ),
                
                const SizedBox(height: 8),
                
                // Progress bar
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Text(
                      '${achievement.targetValue}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerRight,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _rarityColor.withOpacity(0.5),
                                  _rarityColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currentValue',
                      style: TextStyle(
                        fontSize: 11,
                        color: isUnlocked ? _rarityColor : Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                // Unlocked date
                if (isUnlocked && achievementWithProgress.progress.unlockedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'تم الفتح: ${_formatDate(achievementWithProgress.progress.unlockedAt!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _rarityColor.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 14),
          
          // Icon (on the left for RTL)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? _rarityColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: isUnlocked
                    ? _rarityColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
              ),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: _rarityColor.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isUnlocked || !achievement.isSecret
                  ? Text(
                      achievement.icon,
                      style: TextStyle(
                        fontSize: 28,
                        color: isUnlocked ? null : Colors.grey,
                      ),
                    )
                  : Icon(
                      Icons.lock_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _CategoryTab {
  final String name;
  final AchievementCategory? category;
  final IconData icon;

  _CategoryTab(this.name, this.category, this.icon);
}
