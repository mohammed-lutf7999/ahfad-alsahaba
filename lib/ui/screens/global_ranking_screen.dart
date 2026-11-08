import 'package:flutter/material.dart';
import 'dart:io';
import '../../data/models/leaderboard_model.dart';
import '../../data/models/player_level_model.dart';
import '../../data/models/arena_model.dart';
import '../../data/services/leaderboard_service.dart';
import '../../data/services/profile_service.dart';
import '../widgets/animated_avatar_frame.dart';
import '../widgets/level_badge_widget.dart';
import 'dart:math' as math;

class GlobalRankingScreen extends StatefulWidget {
  const GlobalRankingScreen({super.key});

  @override
  State<GlobalRankingScreen> createState() => _GlobalRankingScreenState();
}

class _GlobalRankingScreenState extends State<GlobalRankingScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  bool _isLoading = true;
  
  bool _isOffline = false;
  List<RankEntry> _globalRanks = [];
  
  List<RankEntry> get _localRanks {
    final profiles = List.of(ProfileService.instance.profiles);
    if (profiles.isEmpty) {
      return const [
        RankEntry(name: "أنت (المستخدم)", score: 2500, rank: 1, isMe: true),
        RankEntry(name: "ضيف 1", score: 1200, rank: 2),
        RankEntry(name: "ضيف 2", score: 800, rank: 3),
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
    
    _loadGlobalRanks();
  }
  
  Future<void> _loadGlobalRanks() async {
    setState(() => _isLoading = true);
    
    // Check connectivity first
    bool hasConnection = await _checkConnectivity();
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
      final ranks = await LeaderboardService().fetchGlobalLeaderboard(limit: 50);
      if (mounted) {
        setState(() {
          _globalRanks = ranks;
          _isLoading = false;
          _isOffline = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
          // Show mock data if fetch fails
          _globalRanks = _getMockData();
        });
        _fadeController.forward();
      }
    }
  }
  
  /// Check internet connectivity
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
      RankEntry(name: "عبدالله المكي", score: 15300, rank: 1, countryCode: "SA"),
      RankEntry(name: "عمر الفاروق", score: 14250, rank: 2, countryCode: "EG"),
      RankEntry(name: "سارة أحمد", score: 13900, rank: 3, countryCode: "AE"),
      RankEntry(name: "أبو بكر", score: 12500, rank: 4, countryCode: "YE"),
      RankEntry(name: "خالد بن وليد", score: 11200, rank: 5, countryCode: "MA"),
      RankEntry(name: "فاطمة الزهراء", score: 10800, rank: 6, countryCode: "QA"),
      RankEntry(name: "يوسف الصديق", score: 9500, rank: 7, countryCode: "JO"),
      RankEntry(name: "مريم البتول", score: 8700, rank: 8, countryCode: "DZ"),
      RankEntry(name: "علي الكرار", score: 8200, rank: 9, countryCode: "KW"),
      RankEntry(name: "أسماء ذات النطاقين", score: 7500, rank: 10, countryCode: "OM"),
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
        backgroundColor: const Color(0xFF001020), // Deep Imperial Blue
         appBar: AppBar(
          backgroundColor: const Color(0xFF001020),
          title: const Text("التصنيف العالمي", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFD700)),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Refresh button removed - updates are real-time now
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFFD700),
            labelColor: const Color(0xFFFFD700),
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "التصنيف المحلي"),
              Tab(text: "التصنيف العالمي"),
            ],
          ),
        ),
        body: Stack(
          children: [
            // Background Effects
             const Positioned.fill(child: _StarfieldBackground()),
            
            // Offline Status Banner
            if (_isOffline)
              Positioned(
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'لا يوجد اتصال بالإنترنت - يتم عرض بيانات مؤقتة',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Login prompt if not logged in for global tab - REMOVED to allow viewing
            /* 
            if (!isLoggedIn)
              Positioned(...)
            */
            
            // Add top padding when offline banner is shown
            Padding(
              padding: EdgeInsets.only(top: _isOffline ? 40 : 0),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_localRanks, isGlobal: false),
                StreamBuilder<List<RankEntry>>(
                  stream: LeaderboardService().getLeaderboardStream(limit: 50),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      // Check for network errors
                      final error = snapshot.error.toString();
                      final isNetworkError = error.contains('SocketException') || 
                                           error.contains('RealtimeSubscribeException') ||
                                           error.contains('Failed host lookup');
                      
                      if (isNetworkError || _isOffline) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.3)),
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
                                style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Cairo'),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  _loadGlobalRanks(); // Retry logic
                                },
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
                      
                      return Center(child: Text('حدث خطأ غير متوقع', style: const TextStyle(color: Colors.white54)));
                    }
                    
                    if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
                      if (_globalRanks.isNotEmpty) {
                         // Show cached data while connecting
                         return _buildList(_globalRanks, isGlobal: true);
                      }
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                    }
                    
                    final ranks = snapshot.data ?? [];
                    if (ranks.isEmpty) {
                      return _buildEmptyState();
                    }
                    
                    return _buildList(ranks, isGlobal: true);
                  },
                ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'لا يوجد لاعبين بعد!',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 8),
          Text(
            ' كن الأول أو لا تكن كن أول من يسجل نقاطه',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<RankEntry> data, {required bool isGlobal}) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final entry = data[index];
        return FadeTransition(
          opacity: _fadeController,
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(0, 0.2 + (index * 0.05).clamp(0, 0.5)), end: Offset.zero).animate(
              CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
            ),
            child: _RankCard(entry: entry, index: index),
          ),
        );
      },
    );
  }
}

class _RankCard extends StatelessWidget {
  final RankEntry entry;
  final int index;
  const _RankCard({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    bool isTop3 = entry.rank <= 3;
    Color rankColor = _getRankColor(entry.rank);
    Color glowColor = entry.isMe ? Colors.green : rankColor;

    final levelInfo = PlayerLevelInfo.fromTotalScore(entry.score);
    final arena = ArenaModel.fromTrophies(entry.trophies);
    final String effectiveFrameKey =
        (entry.equippedFrame.isNotEmpty && entry.equippedFrame != 'frame_wood')
        ? entry.equippedFrame
        : (entry.rank == 1 && levelInfo.level < 31
              ? 'frame_gold'
              : levelInfo.frameKey);
    final String avatarLetter = entry.name.trim().isNotEmpty
        ? entry.name.trim()[0]
        : 'ف';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isMe ? const Color(0xFF1E3A1E) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isMe
              ? Colors.green.withValues(alpha: 0.5)
              : (isTop3 ? rankColor.withValues(alpha: 0.4) : Colors.white12),
          width: (entry.isMe || isTop3) ? 1.8 : 1,
        ),
        boxShadow: [
          if (isTop3 || entry.isMe)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3
                  ? rankColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              border: isTop3 ? Border.all(color: rankColor) : null,
            ),
            child: Center(
              child: isTop3
                  ? Icon(Icons.emoji_events_rounded, color: rankColor, size: 22)
                  : Text(
                      "${entry.rank}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // Royal Animated Avatar Frame
          AnimatedAvatarFrame(
            size: 48,
            frameKey: effectiveFrameKey,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF263238),
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name, Level Badge & Competitive Arena
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          color: entry.isMe ? Colors.greenAccent : Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!entry.isMe && entry.countryCode.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        entry.countryCode,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LevelBadgeWidget(
                      levelInfo: levelInfo,
                      isCompact: true,
                      customTitle: entry.playerTitle.isNotEmpty
                          ? entry.playerTitle
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: arena.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: arena.accentColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        '${arena.name} • 🏆 ${entry.trophies}',
                        style: TextStyle(
                          color: arena.accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFD700),
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  "${entry.score}",
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFFFD700); // Gold
      case 2: return const Color(0xFFC0C0C0); // Silver
      case 3: return const Color(0xFFCD7F32); // Bronze
      default: return Colors.white;
    }
  }
}

class _StarfieldBackground extends StatefulWidget {
  const _StarfieldBackground();

  @override
  State<_StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<_StarfieldBackground> with SingleTickerProviderStateMixin {
   late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 15), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter(_controller));
  }
}

class _StarPainter extends CustomPainter {
  final Animation<double> animation;
  _StarPainter(this.animation) : super(repaint: animation);

   final List<Offset> _stars = List.generate(40, (index) => Offset(math.Random(index).nextDouble(), math.Random(index).nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.2);
    for (int i = 0; i < _stars.length; i++) {
        var offset = _stars[i];
        double dy = (offset.dy + animation.value * 0.1) % 1.0;
        canvas.drawCircle(Offset(offset.dx * size.width, dy * size.height), 1.5, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
