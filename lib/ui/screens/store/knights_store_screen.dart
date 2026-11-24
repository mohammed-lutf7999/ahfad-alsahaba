import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/models/store_item_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/profile_service.dart';
import '../../../data/services/progression_service.dart';
import '../../../data/services/store_service.dart';
import '../glory/glory_road_screen.dart';
import 'widgets/store_item_card.dart';
import 'widgets/store_wallet_and_closed.dart';

/// «سوق الفرسان» (Knight's Store Screen) — The Royal In-Game Economy Bazaar
class KnightsStoreScreen extends StatefulWidget {
  final int initialTabIndex;

  const KnightsStoreScreen({super.key, this.initialTabIndex = 0});

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
    if (mounted) setState(() {});
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
    final customTheme = Theme.of(context).extension<AppCustomTheme>() ??
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
                  MaterialPageRoute(builder: (_) => const GloryRoadScreen()),
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
        body: ValueListenableBuilder<AppFeatureFlags>(
          valueListenable: AppControlService.instance.featureFlagsNotifier,
          builder: (context, flags, _) {
            if (!flags.knightsStore) {
              return StoreClosedView(customTheme: customTheme);
            }
            return SafeArea(
              top: false,
              child: Column(
                children: [
                  StoreWalletHeader(
                    customTheme: customTheme,
                    levelInfo: levelInfo,
                    equippedFrame: equippedFrame,
                    customTitle: profile?.effectiveTitle,
                    coins: coins,
                    gems: gems,
                    winStreak: winStreak,
                  ),
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
            );
          },
        ),
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
        return StoreItemCard(
          item: item,
          customTheme: customTheme,
          playerLevel: playerLevel,
          onAction: () => _handleItemAction(item),
        );
      },
    );
  }
}
