import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/arena_model.dart';
import '../../data/models/leaderboard_model.dart';
import '../../data/services/leaderboard_service.dart';
import '../../data/services/profile_service.dart';
import 'ranking/rank_card.dart';

class GlobalRankingScreen extends StatefulWidget {
  const GlobalRankingScreen({super.key});

  @override
  State<GlobalRankingScreen> createState() => _GlobalRankingScreenState();
}

class _GlobalRankingScreenState extends State<GlobalRankingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Stream<List<RankEntry>> _leaderboardStream;
  bool _isLoading = true;
  bool _isOffline = false;
  List<RankEntry> _globalRanks = [];

  List<RankEntry> get _localRanks {
    final profiles = List.of(ProfileService.instance.profiles);
    if (profiles.isEmpty) {
      return const [
        RankEntry(name: 'أنت (المستخدم)', score: 2500, rank: 1, isMe: true),
        RankEntry(name: 'ضيف 1', score: 1200, rank: 2),
        RankEntry(name: 'ضيف 2', score: 800, rank: 3),
      ];
    }
    profiles.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final activeId = ProfileService.instance.activeProfile?.id;
    return List.generate(profiles.length, (i) {
      final p = profiles[i];
      final lvl = p.levelInfo;
      final arena = ArenaModel.fromTrophies(p.trophies);
      return RankEntry(
        name: p.name,
        score: p.totalScore,
        trophies: p.trophies,
        rank: i + 1,
        isMe: p.id == activeId,
        playerLevel: lvl.level,
        playerTitle: p.effectiveTitle,
        arenaId: arena.id,
        arenaName: arena.name,
        equippedFrame: p.equippedFrame,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _leaderboardStream = LeaderboardService().getLeaderboardStream(limit: 50);
    _loadGlobalRanks();
  }

  Future<void> _loadGlobalRanks({bool refreshStream = false}) async {
    setState(() {
      _isLoading = true;
      if (refreshStream) {
        _leaderboardStream =
            LeaderboardService().getLeaderboardStream(limit: 50);
      }
    });

    final hasConnection = await _checkConnectivity();
    if (!hasConnection) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
          _globalRanks = _getMockData();
        });
        _fadeController.forward();
      }
      return;
    }

    try {
      final ranks =
          await LeaderboardService().fetchGlobalLeaderboard(limit: 50);
      if (mounted) {
        setState(() {
          _globalRanks = ranks;
          _isLoading = false;
          _isOffline = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('GlobalRankingScreen fetch failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
          _globalRanks = _getMockData();
        });
        _fadeController.forward();
      }
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  List<RankEntry> _getMockData() {
    return const [
      RankEntry(name: 'عبدالله المكي', score: 15300, rank: 1, countryCode: 'SA'),
      RankEntry(name: 'عمر الفاروق', score: 14250, rank: 2, countryCode: 'EG'),
      RankEntry(name: 'سارة أحمد', score: 13900, rank: 3, countryCode: 'AE'),
      RankEntry(name: 'أبو بكر', score: 12500, rank: 4, countryCode: 'YE'),
      RankEntry(name: 'خالد بن وليد', score: 11200, rank: 5, countryCode: 'MA'),
      RankEntry(
        name: 'فاطمة الزهراء',
        score: 10800,
        rank: 6,
        countryCode: 'QA',
      ),
      RankEntry(name: 'يوسف الصديق', score: 9500, rank: 7, countryCode: 'JO'),
      RankEntry(name: 'مريم البتول', score: 8700, rank: 8, countryCode: 'DZ'),
      RankEntry(name: 'علي الكرار', score: 8200, rank: 9, countryCode: 'KW'),
      RankEntry(
        name: 'أسماء ذات النطاقين',
        score: 7500,
        rank: 10,
        countryCode: 'OM',
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF001020),
        appBar: AppBar(
          backgroundColor: const Color(0xFF001020),
          title: const Text(
            'التصنيف العالمي',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFD700),
            ),
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFFFD700),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFFD700),
            labelColor: const Color(0xFFFFD700),
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(text: 'التصنيف المحلي'),
              Tab(text: 'التصنيف العالمي'),
            ],
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: RankingStarfieldBackground()),
            Positioned.fill(
              child: SafeArea(
                top: false,
                child: Stack(
                  children: [
                    if (_isOffline) _buildOfflineBanner(),
                    Padding(
                      padding: EdgeInsets.only(top: _isOffline ? 40 : 0),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(_localRanks),
                          _buildGlobalStreamTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'لا يوجد اتصال بالإنترنت - يتم عرض بيانات مؤقتة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalStreamTab() {
    return StreamBuilder<List<RankEntry>>(
      stream: _leaderboardStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          final isNetworkError = error.contains('SocketException') ||
              error.contains('RealtimeSubscribeException') ||
              error.contains('Failed host lookup');

          if (isNetworkError || _isOffline) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '  انت غير متصل بالانترنت يا بطل',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يرجى التحقق من الاتصال لعرض التصنيف العالمي',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _loadGlobalRanks(refreshStream: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }

          return const Center(
            child: Text(
              'حدث خطأ غير متوقع',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
          if (_globalRanks.isNotEmpty) return _buildList(_globalRanks);
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700)),
          );
        }

        final ranks = snapshot.data ?? [];
        if (ranks.isEmpty) return _buildEmptyState();
        return _buildList(ranks);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد لاعبين بعد!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ' كن الأول أو لا تكن كن أول من يسجل نقاطه',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<RankEntry> data) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final entry = data[index];
        return FadeTransition(
          opacity: _fadeController,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.2 + (index * 0.05).clamp(0, 0.5)),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _fadeController,
                curve: Curves.easeOutBack,
              ),
            ),
            child: GlobalRankCard(entry: entry, index: index),
          ),
        );
      },
    );
  }
}
