import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/player_level_model.dart';
import '../../../data/models/arena_model.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../data/services/profile_service.dart';
import '../../../data/services/progression_service.dart';
import '../../widgets/avatar_selector.dart';
import '../../widgets/animated_avatar_frame.dart';
import '../../widgets/level_badge_widget.dart';
import 'online_game_screen.dart';

class VersusScreen extends StatefulWidget {
  final String matchId;
  final String opponentId;
  final int seed;
  final bool isBot;
  final bool isGhost;
  final List<String>? questionIds;
  final List<Map<String, dynamic>>? ghostTimeline;
  final Map<String, dynamic>? initialOpponentData;

  const VersusScreen({
    super.key,
    required this.matchId,
    required this.opponentId,
    required this.seed,
    this.isBot = false,
    this.isGhost = false,
    this.questionIds,
    this.ghostTimeline,
    this.initialOpponentData,
  });

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen> with TickerProviderStateMixin {
  late AnimationController _vsController;
  late Animation<double> _vsScale;
  
  Map<String, dynamic>? _opponentData;
  List<String>? _questionIds;
  bool _isLoading = true;
  bool _waitingForOpponent = false;
  bool _bothReady = false;
  
  int _countdown = 3;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  Timer? _safetyTimeoutTimer;
  StreamSubscription? _matchStateSubscription;

  @override
  void initState() {
    super.initState();
    _vsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _vsScale = CurvedAnimation(parent: _vsController, curve: Curves.elasticOut);
    
    _loadDataAndConfirmReady();
  }
  
  @override
  void dispose() {
     _vsController.dispose();
     _countdownTimer?.cancel();
     _pollTimer?.cancel();
     _safetyTimeoutTimer?.cancel();
     _matchStateSubscription?.cancel();
     super.dispose();
  }

  Future<void> _loadDataAndConfirmReady() async {
    // If ghost match with pre-fetched profile, launch countdown immediately
    if (widget.isGhost && widget.initialOpponentData != null) {
      if (!mounted) return;
      setState(() {
        _opponentData = widget.initialOpponentData;
        _questionIds = widget.questionIds;
        _isLoading = false;
        _bothReady = true;
      });
      _vsController.forward();
      SoundService().playGameStart();
      _startCountdown();
      return;
    }

    // 1. Fetch Opponent Data
    final opponentData = await MultiplayerService.instance.fetchOpponentData(widget.opponentId);
    if (!mounted) return;
    
    // 2. Fetch Match Data (if online) or use passed IDs (if bot)
    List<String> qIds = [];
    if (widget.isBot) {
       qIds = widget.questionIds ?? [];
    } else {
       final matchData = await MultiplayerService.instance.getMatchData(widget.matchId);
       if (matchData != null && matchData['question_ids'] != null) {
          qIds = List<String>.from(matchData['question_ids']);
       }
    }
    
    if (!mounted) return;
    
    setState(() {
      _opponentData = opponentData;
      _questionIds = qIds;
      _isLoading = false;
    });
    
    // 3. Animate VS
    await _vsController.forward();
    
    // 4. Confirm Ready Logic
    if (widget.isBot) {
       // Bot is always ready after a short delay
       await Future.delayed(const Duration(seconds: 1));
       if (mounted) {
         _onBothPlayersReady();
       }
    } else {
      // Online Match Logic: Dual-Trigger (Realtime Stream + Active Polling + 15s Safety Timeout)
      _matchStateSubscription = MultiplayerService.instance
          .listenToMatchState(widget.matchId)
          .listen((state) {
            if (!mounted) return;
            if ((state.status == 'ready' || state.status == 'playing') && !_bothReady) {
              _onBothPlayersReady();
            }
          });

      // Active fallback polling every 1.5s in case WebSocket packet is dropped
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
        if (!mounted || _bothReady) {
          timer.cancel();
          return;
        }
        final matchData = await MultiplayerService.instance.getMatchData(widget.matchId);
        if (!mounted || _bothReady) return;
        final status = matchData?['status'] as String?;
        if (status == 'ready' || status == 'playing') {
          if (_questionIds == null || _questionIds!.isEmpty) {
            if (matchData?['question_ids'] != null) {
              _questionIds = List<String>.from(matchData!['question_ids']);
            }
          }
          _onBothPlayersReady();
        }
      });

      // 15-second safety timeout so player NEVER hangs forever on VS screen if opponent left
      _safetyTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!mounted || _bothReady) return;
        _pollTimer?.cancel();
        _matchStateSubscription?.cancel();
        unawaited(MultiplayerService.instance.cancelMatch(widget.matchId));
        _showOpponentTimeoutDialog();
      });
      
      // 5. Confirm this player is ready
      setState(() => _waitingForOpponent = true);
      final bothReady = await MultiplayerService.instance.confirmReady(widget.matchId);
      
      if (bothReady && mounted) {
        _onBothPlayersReady();
      }
    }
  }

  void _onBothPlayersReady() {
    if (_bothReady || !mounted) return;
    _pollTimer?.cancel();
    _safetyTimeoutTimer?.cancel();
    setState(() {
      _bothReady = true;
      _waitingForOpponent = false;
    });
    _startCountdown();
  }

  void _showOpponentTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'الخصم غير متصل',
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'يبدو أن الخصم غادر الغرفة أو فقد الاتصال بالإنترنت.\nهل ترغب في بدء جولة فورية ضد الذكاء الاصطناعي؟',
          style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('العودة', style: TextStyle(color: Colors.white60, fontFamily: 'Cairo')),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final botResult = await MultiplayerService.instance.createBotMatch();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => VersusScreen(
                    matchId: botResult.matchId!,
                    opponentId: botResult.opponentId!,
                    seed: botResult.seed!,
                    isBot: true,
                    questionIds: botResult.questionIds,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.smart_toy_rounded),
            label: const Text('تحدي الذكاء الاصطناعي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  void _startCountdown() {
    if (_countdownTimer != null) return; // Already counting
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
       if (_countdown > 1) {
         if (mounted) setState(() => _countdown--);
         SoundService().playClick();
       } else {
         _countdownTimer?.cancel();
         _startGame();
       }
    });
  }

  void _startGame() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          matchId: widget.matchId,
          opponentId: widget.opponentId,
          seed: widget.seed,
          questionIds: _questionIds ?? [],
          opponentName: _opponentData?['display_name'] ?? 'الخصم',
          opponentAvatarIndex: (_opponentData?['avatar_index'] as num?)?.toInt() ?? 0,
          isBot: widget.isBot,
          isGhost: widget.isGhost,
          ghostTimeline: widget.ghostTimeline,
          ghostFrame: _opponentData?['equipped_frame'] as String?,
          ghostLevel: (_opponentData?['player_level'] as num?)?.toInt(),
          ghostTrophies: (_opponentData?['trophies'] as num?)?.toInt(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ProfileService.instance.activeProfile;
    final myLevelInfo = ProgressionService.instance.currentLevelInfo;
    final myArena = ProgressionService.instance.currentArena;

    final oppScore = (_opponentData?['score'] as num?)?.toInt() ?? 0;
    final oppTrophies = (_opponentData?['trophies'] as num?)?.toInt() ?? 1000;
    final oppLevelInfo = PlayerLevelInfo.fromTotalScore(oppScore);
    final oppArena = ArenaModel.fromTrophies(oppTrophies);
    final oppFrame =
        (_opponentData?['equipped_frame'] as String?) ?? oppLevelInfo.frameKey;
    final oppWinStreak = (_opponentData?['win_streak'] as num?)?.toInt() ?? 0;
    final oppTitle = _opponentData?['player_title'] as String?;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppCustomTheme.of(context).backgroundGradient,
        ),
        child: SafeArea(
           child: Stack(
             children: [
               Column(
                 children: [
                   // Top Half (Me)
                   Expanded(
                     child: Container(
                       width: double.infinity,
                       color: Colors.blue.withValues(alpha: 0.08),
                       child: Center(
                         child: SingleChildScrollView(
                           padding: const EdgeInsets.symmetric(vertical: 8),
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               AnimatedAvatarFrame(
                                 size: 88,
                                 frameKey:
                                     myProfile?.equippedFrame ??
                                     myLevelInfo.frameKey,
                                 winStreak: myProfile?.winStreak ?? 0,
                                 child: ProfileAvatar(
                                   avatarIndex: myProfile?.avatarIndex ?? 0,
                                   size: 76,
                                 ),
                               ),
                               const SizedBox(height: 8),
                               Padding(
                                 padding: const EdgeInsets.symmetric(
                                   horizontal: 24,
                                 ),
                                 child: Text(
                                   myProfile?.name ?? 'أنا',
                                   style: const TextStyle(
                                     color: Colors.white,
                                     fontSize: 20,
                                     fontWeight: FontWeight.bold,
                                     fontFamily: 'Cairo',
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                               const SizedBox(height: 4),
                               LevelBadgeWidget(
                                 levelInfo: myLevelInfo,
                                 customTitle: myProfile?.effectiveTitle,
                                 isCompact: true,
                               ),
                               const SizedBox(height: 4),
                               Text(
                                 'النقاط: ${myProfile?.totalScore ?? 0}  •  🏆 ${myProfile?.trophies ?? 1000} (${myArena.name})',
                                 style: const TextStyle(
                                   color: Colors.white70,
                                   fontSize: 12,
                                   fontFamily: 'Cairo',
                                 ),
                               ),
                               const SizedBox(height: 6),
                               // Ready indicator
                               Container(
                                 padding: const EdgeInsets.symmetric(
                                   horizontal: 12,
                                   vertical: 4,
                                 ),
                                 decoration: BoxDecoration(
                                   color: Colors.green.withValues(alpha: 0.3),
                                   borderRadius: BorderRadius.circular(12),
                                   border: Border.all(color: Colors.green),
                                 ),
                                 child: const Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Icon(
                                       Icons.check_circle,
                                       color: Colors.green,
                                       size: 16,
                                     ),
                                     SizedBox(width: 4),
                                     Text(
                                       'جاهز',
                                       style: TextStyle(
                                         color: Colors.green,
                                         fontFamily: 'Cairo',
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                     ),
                   ),

                   // Dedicated Central VS & Countdown Band (Zero Overlap!)
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                     decoration: BoxDecoration(
                       color: Colors.black.withValues(alpha: 0.25),
                       border: const Border.symmetric(
                         horizontal: BorderSide(color: Colors.white12, width: 1),
                       ),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         ScaleTransition(
                           scale: _vsScale,
                           child: Container(
                             padding: const EdgeInsets.all(14),
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               gradient: AppTheme.goldGradient,
                               boxShadow: [
                                 BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15)
                               ],
                             ),
                             child: const Text(
                               'VS',
                               style: TextStyle(
                                 color: AppTheme.primaryDark,
                                 fontSize: 28,
                                 fontWeight: FontWeight.w900,
                                 fontStyle: FontStyle.italic,
                               ),
                             ),
                           ),
                         ),
                         const SizedBox(width: 16),
                         if (_bothReady)
                           Text(
                             '$_countdown',
                             style: const TextStyle(
                               color: AppTheme.accentColor,
                               fontSize: 44,
                               fontWeight: FontWeight.bold,
                               shadows: [
                                 Shadow(color: Colors.black, blurRadius: 10),
                               ],
                             ),
                           )
                         else if (_waitingForOpponent)
                           const Flexible(
                             child: Text(
                               'في انتظار تأكيد الخصم...',
                               style: TextStyle(
                                 color: Colors.white70,
                                 fontSize: 16,
                                 fontFamily: 'Cairo',
                               ),
                             ),
                           ),
                       ],
                     ),
                   ),
                   
                   // Bottom Half (Opponent)
                   Expanded(
                     child: Container(
                       width: double.infinity,
                       color: Colors.red.withValues(alpha: 0.08),
                       child: Center(
                         child: _isLoading 
                           ? const CircularProgressIndicator(color: Colors.white)
                           : SingleChildScrollView(
                               padding: const EdgeInsets.symmetric(vertical: 8),
                               child: Column(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   AnimatedAvatarFrame(
                                     size: 88,
                                     frameKey: oppFrame,
                                     winStreak: oppWinStreak,
                                     child: ProfileAvatar(
                                       avatarIndex:
                                           (_opponentData?['avatar_index']
                                                   as num?)
                                               ?.toInt() ??
                                           0,
                                       size: 76,
                                     ),
                                   ),
                                   const SizedBox(height: 8),
                                   Padding(
                                     padding: const EdgeInsets.symmetric(
                                       horizontal: 24,
                                     ),
                                     child: Text(
                                       _opponentData?['display_name'] ?? 'الخصم',
                                       style: const TextStyle(
                                         color: Colors.white,
                                         fontSize: 20,
                                         fontWeight: FontWeight.bold,
                                         fontFamily: 'Cairo',
                                       ),
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                   ),
                                   const SizedBox(height: 4),
                                   LevelBadgeWidget(
                                     levelInfo: oppLevelInfo,
                                     isCompact: true,
                                     customTitle: oppTitle,
                                   ),
                                   const SizedBox(height: 4),
                                   Text(
                                     'النقاط: $oppScore  •  🏆 $oppTrophies (${oppArena.name})',
                                     style: const TextStyle(
                                       color: Colors.white70,
                                       fontSize: 12,
                                       fontFamily: 'Cairo',
                                     ),
                                   ),
                                   const SizedBox(height: 6),
                                   // Opponent ready indicator
                                   if (_waitingForOpponent && !_bothReady)
                                     Container(
                                       padding: const EdgeInsets.symmetric(
                                         horizontal: 12,
                                         vertical: 4,
                                       ),
                                       decoration: BoxDecoration(
                                         color: Colors.orange.withValues(
                                           alpha: 0.3,
                                         ),
                                         borderRadius: BorderRadius.circular(12),
                                         border: Border.all(
                                           color: Colors.orange,
                                         ),
                                       ),
                                       child: const Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           SizedBox(
                                             width: 14,
                                             height: 14,
                                             child: CircularProgressIndicator(
                                               strokeWidth: 2,
                                               color: Colors.orange,
                                             ),
                                           ),
                                           SizedBox(width: 6),
                                           Text(
                                             'في الانتظار...',
                                             style: TextStyle(
                                               color: Colors.orange,
                                               fontFamily: 'Cairo',
                                             ),
                                           ),
                                         ],
                                       ),
                                     )
                                   else if (_bothReady)
                                     Container(
                                       padding: const EdgeInsets.symmetric(
                                         horizontal: 12,
                                         vertical: 4,
                                       ),
                                       decoration: BoxDecoration(
                                         color: Colors.green.withValues(
                                           alpha: 0.3,
                                         ),
                                         borderRadius: BorderRadius.circular(12),
                                         border: Border.all(
                                           color: Colors.green,
                                         ),
                                       ),
                                       child: const Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           Icon(
                                             Icons.check_circle,
                                             color: Colors.green,
                                             size: 16,
                                           ),
                                           SizedBox(width: 4),
                                           Text(
                                             'جاهز',
                                             style: TextStyle(
                                               color: Colors.green,
                                               fontFamily: 'Cairo',
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                 ],
                               ),
                             ),
                       ),
                     ),
                   ),
                 ],
               ),

               // Top Bar Cancel Button (in case user wants to leave before match starts)
               if (!_bothReady)
                 Positioned(
                   top: 8,
                   left: 8,
                   child: TextButton.icon(
                     onPressed: () {
                       SoundService().playClick();
                       if (!widget.isBot) {
                         unawaited(MultiplayerService.instance.cancelMatch(widget.matchId));
                       }
                       if (mounted) Navigator.of(context).pop();
                     },
                     icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                     label: const Text('إلغاء', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
                   ),
                 ),
             ],
           ),
        ),
      ),
    );
  }
}
