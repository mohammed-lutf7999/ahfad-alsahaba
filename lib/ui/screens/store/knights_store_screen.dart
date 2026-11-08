import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/store_item_model.dart';
import '../../../data/services/profile_service.dart';
import '../../../data/services/progression_service.dart';
import '../../../data/services/store_service.dart';
import '../../widgets/animated_avatar_frame.dart';
import '../../widgets/level_badge_widget.dart';
import '../glory/glory_road_screen.dart';

/// «سوق الفرسان» (Knight's Store Screen) — The Royal In-Game Economy Bazaar
/// featuring 4 tabs:
/// 1. خزانة الثيمات الملكية (4 Legendary Themes with live 300ms theme morphing)
/// 2. الأطر الملكية المتوهجة (10 Procedural Shader Frames)
/// 3. أوسمة وألقاب الفرسان (Honor Titles)
/// 4. وسائل المساعدة الذكية (Smart Tactical Power-ups)
class KnightsStoreScreen extends StatefulWidget {
  final int initialTabIndex;

  const KnightsStoreScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<KnightsStoreScreen> createState() => _KnightsStoreScreenState();
}

class _KnightsStoreScreenState extends State<KnightsStoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    ProgressionService.instance.addListener(_onStateChanged);
    StoreService.instance.addListener(_onStateChanged);
    unawaited(StoreService.instance.syncCatalogFromCloud());
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ProgressionService.instance.removeListener(_onStateChanged);
    StoreService.instance.removeListener(_onStateChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleItemAction(StoreItemModel item) async {
    final result = await StoreService.instance.purchaseOrEquip(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: result.success
            ? const Color(0xFF047857)
            : const Color(0xFFBE123C),
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
    final coins = profile?.coins ?? 100;
    final gems = profile?.gems ?? 10;
    final equippedFrame = profile?.equippedFrame ?? levelInfo.frameKey;
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
            'سوق الفرسان الملكي 🪙',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'طريق المجد والميادين',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GloryRoadScreen(),
                  ),
                );
              },
              icon: Icon(
                Icons.emoji_events_rounded,
                color: customTheme.sovereignAccent,
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: customTheme.sovereignAccent,
            indicatorWeight: 3,
            labelColor: customTheme.sovereignAccent,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.palette_rounded, size: 18),
                text: 'الثيمات الملكية (4)',
              ),
              Tab(
                icon: Icon(Icons.filter_frames_rounded, size: 18),
                text: 'الأطر المتوهجة (10)',
              ),
              Tab(
                icon: Icon(Icons.workspace_premium_rounded, size: 18),
                text: 'أوسمة الفرسان',
              ),
              Tab(
                icon: Icon(Icons.shield_rounded, size: 18),
                text: 'وسائل المساعدة',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // 1. Royal Wallet & Active Customization Header
            _buildWalletHeader(
              customTheme: customTheme,
              levelInfo: levelInfo,
              equippedFrame: equippedFrame,
              customTitle: profile?.effectiveTitle,
              coins: coins,
              gems: gems,
              winStreak: winStreak,
            ),

            // 2. 4 Category Tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCatalogList(
                    key: const Key('store_tab_themes'),
                    category: StoreItemCategory.theme,
                    customTheme: customTheme,
                    playerLevel: levelInfo.level,
                  ),
                  _buildCatalogList(
                    key: const Key('store_tab_frames'),
                    category: StoreItemCategory.frame,
                    customTheme: customTheme,
                    playerLevel: levelInfo.level,
                  ),
                  _buildCatalogList(
                    key: const Key('store_tab_titles'),
                    category: StoreItemCategory.title,
                    customTheme: customTheme,
                    playerLevel: levelInfo.level,
                  ),
                  _buildCatalogList(
                    key: const Key('store_tab_powerups'),
                    category: StoreItemCategory.powerup,
                    customTheme: customTheme,
                    playerLevel: levelInfo.level,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletHeader({
    required AppCustomTheme customTheme,
    required dynamic levelInfo,
    required String equippedFrame,
    String? customTitle,
    required int coins,
    required int gems,
    required int winStreak,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: customTheme.sovereignAccent.withValues(alpha: 0.6),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedAvatarFrame(
            frameKey: equippedFrame,
            level: levelInfo.level,
            winStreak: winStreak,
            size: 54,
            child: Container(
              color: customTheme.deepBackground,
              child: Icon(
                Icons.person_rounded,
                color: customTheme.sovereignAccent,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الثيم النشط: ${customTheme.themeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
          // Coins & Gems Wallet Badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                key: const Key('wallet_coins_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFF3C644).withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  '$coins 🪙',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFFF3C644),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                key: const Key('wallet_gems_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  '$gems 💎',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogList({
    required Key key,
    required StoreItemCategory category,
    required AppCustomTheme customTheme,
    required int playerLevel,
  }) {
    final items = StoreService.instance.itemsByCategory(category);

    return ListView.builder(
      key: key,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildStoreItemCard(
          item: item,
          customTheme: customTheme,
          playerLevel: playerLevel,
        );
      },
    );
  }

  Widget _buildStoreItemCard({
    required StoreItemModel item,
    required AppCustomTheme customTheme,
    required int playerLevel,
  }) {
    final isOwned = StoreService.instance.isItemOwned(item);
    final isEquipped = StoreService.instance.isItemEquipped(item);
    final isLevelLocked = !isOwned && playerLevel < item.minLevel;

    String buttonText;
    if (isEquipped) {
      buttonText = item.category == StoreItemCategory.powerup
          ? 'مفعّل في خزانتك ⚡'
          : 'مُفعّل حالياً ✓';
    } else if (isOwned) {
      buttonText = 'تفعيل مجاناً';
    } else if (item.priceGems > 0) {
      buttonText = '${item.priceCoins} 🪙 + ${item.priceGems} 💎';
    } else {
      buttonText = 'اقتناء بـ ${item.priceCoins} 🪙';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEquipped
            ? customTheme.surfaceCard
            : customTheme.surfaceCard.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEquipped
              ? customTheme.sovereignAccent
              : item.previewColor.withValues(alpha: 0.45),
          width: isEquipped ? 2.0 : 1.1,
        ),
        boxShadow: isEquipped
            ? [
                BoxShadow(
                  color: customTheme.sovereignAccent.withValues(alpha: 0.24),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Visual Preview Leading Widget
          _buildItemLeadingPreview(item, customTheme),
          const SizedBox(width: 12),

          // Title, Description & Level Requirement
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isLevelLocked
                            ? const Color(0xFFBE123C).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'يتطلب المستوى ${item.minLevel}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: isLevelLocked
                              ? const Color(0xFFFDA4AF)
                              : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (isOwned && !isEquipped) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'مملوك ✓',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Color(0xFF6EE7B7),
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Action Button (Rule 6: vertical padding 8)
          SizedBox(
            height: 44,
            child: ElevatedButton(
              key: Key('store_action_${item.id}'),
              onPressed: isEquipped ? null : () => _handleItemAction(item),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOwned
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF3C644),
                foregroundColor: isOwned
                    ? Colors.white
                    : const Color(0xFF140B29),
                disabledBackgroundColor: Colors.black.withValues(alpha: 0.35),
                disabledForegroundColor: const Color(0xFF6EE7B7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemLeadingPreview(
    StoreItemModel item,
    AppCustomTheme customTheme,
  ) {
    if (item.category == StoreItemCategory.frame) {
      return AnimatedAvatarFrame(
        frameKey: item.assetKey,
        size: 56,
        showStreakBadge: false,
        child: Container(
          color: customTheme.deepBackground,
          child: Icon(
            item.icon,
            color: item.previewColor,
            size: 24,
          ),
        ),
      );
    }

    if (item.category == StoreItemCategory.theme) {
      final themeSpec = AppCustomTheme.fromId(item.assetKey);
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [themeSpec.deepBackground, themeSpec.surfaceCard],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: themeSpec.sovereignAccent,
            width: 2.0,
          ),
        ),
        child: Center(
          child: Icon(
            item.icon,
            color: themeSpec.sovereignAccent,
            size: 26,
          ),
        ),
      );
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: item.previewColor.withValues(alpha: 0.18),
        border: Border.all(
          color: item.previewColor.withValues(alpha: 0.75),
          width: 1.5,
        ),
      ),
      child: Icon(
        item.icon,
        color: item.previewColor,
        size: 26,
      ),
    );
  }
}

