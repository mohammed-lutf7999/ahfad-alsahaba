import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../data/services/profile_service.dart';
import '../../widgets/avatar_selector.dart';
import 'online_game_screen.dart';

class VersusScreen extends StatefulWidget {
  final String matchId;
  final String opponentId;
  final int seed;
  final bool isBot;
  final List<String>? questionIds;

  const VersusScreen({
    super.key,
    required this.matchId,
    required this.opponentId,
    required this.seed,
    this.isBot = false,
    this.questionIds,
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
         setState(() {
           _bothReady = true;
           _waitingForOpponent = false;
         });
         _startCountdown();
       }
    } else {
      // Online Match Logic
      _matchStateSubscription = MultiplayerService.instance
          .listenToMatchState(widget.matchId)
          .listen((state) {
            if (!mounted) return;
            
            if (state.status == 'ready' && !_bothReady) {
              setState(() {
                _bothReady = true;
                _waitingForOpponent = false;
              });
              _startCountdown();
            }
          });
      
      // 5. Confirm this player is ready
      setState(() => _waitingForOpponent = true);
      final bothReady = await MultiplayerService.instance.confirmReady(widget.matchId);
      
      if (bothReady && mounted) {
        setState(() {
          _bothReady = true;
          _waitingForOpponent = false;
        });
        _startCountdown();
      }
    }
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ProfileService.instance.activeProfile;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
           child: Stack(
             children: [
               Column(
                 children: [
                   // Top Half (Me)
                   Expanded(
                     child: Container(
                       color: Colors.blue.withOpacity(0.1),
                       child: Center(
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             ProfileAvatar(
                               avatarIndex: myProfile?.avatarIndex ?? 0, 
                               size: 100,
                             ),
                             const SizedBox(height: 16),
                             Text(
                               myProfile?.name ?? 'أنا',
                               style: const TextStyle(
                                 color: Colors.white,
                                 fontSize: 24,
                                 fontWeight: FontWeight.bold,
                                 fontFamily: 'Cairo',
                               ),
                             ),
                             Text(
                               'النقاط: ${myProfile?.totalScore ?? 0}',
                               style: const TextStyle(color: Colors.white70),
                             ),
                             const SizedBox(height: 10),
                             // Ready indicator
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                               decoration: BoxDecoration(
                                 color: Colors.green.withOpacity(0.3),
                                 borderRadius: BorderRadius.circular(12),
                                 border: Border.all(color: Colors.green),
                               ),
                               child: const Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Icon(Icons.check_circle, color: Colors.green, size: 16),
                                   SizedBox(width: 4),
                                   Text('جاهز', style: TextStyle(color: Colors.green)),
                                 ],
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
                   
                   // Bottom Half (Opponent)
                   Expanded(
                     child: Container(
                       color: Colors.red.withOpacity(0.1),
                       child: Center(
                         child: _isLoading 
                           ? const CircularProgressIndicator(color: Colors.white)
                           : Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 ProfileAvatar(
                                   avatarIndex: (_opponentData?['avatar_index'] as num?)?.toInt() ?? 0, 
                                   size: 100,
                                 ),
                                 const SizedBox(height: 16),
                                 Text(
                                   _opponentData?['display_name'] ?? 'الخصم',
                                   style: const TextStyle(
                                     color: Colors.white,
                                     fontSize: 24,
                                     fontWeight: FontWeight.bold,
                                     fontFamily: 'Cairo',
                                   ),
                                 ),
                                 Text(
                                   'النقاط: ${_opponentData?['score'] ?? 0}',
                                   style: const TextStyle(color: Colors.white70),
                                 ),
                                 const SizedBox(height: 10),
                                 // Opponent ready indicator
                                 if (_waitingForOpponent && !_bothReady)
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                     decoration: BoxDecoration(
                                       color: Colors.orange.withOpacity(0.3),
                                       borderRadius: BorderRadius.circular(12),
                                       border: Border.all(color: Colors.orange),
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
                                         Text('في الانتظار...', style: TextStyle(color: Colors.orange)),
                                       ],
                                     ),
                                   )
                                 else if (_bothReady)
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                     decoration: BoxDecoration(
                                       color: Colors.green.withOpacity(0.3),
                                       borderRadius: BorderRadius.circular(12),
                                       border: Border.all(color: Colors.green),
                                     ),
                                     child: const Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         Icon(Icons.check_circle, color: Colors.green, size: 16),
                                         SizedBox(width: 4),
                                         Text('جاهز', style: TextStyle(color: Colors.green)),
                                       ],
                                     ),
                                   ),
                               ],
                             ),
                       ),
                     ),
                   ),
                 ],
               ),
               
               // VS Badge & Countdown (Center)
               Center(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     ScaleTransition(
                       scale: _vsScale,
                       child: Container(
                         padding: const EdgeInsets.all(20),
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           gradient: AppTheme.goldGradient,
                           boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)
                           ],
                         ),
                         child: const Text(
                           'VS',
                           style: TextStyle(
                             color: AppTheme.primaryDark,
                             fontSize: 40,
                             fontWeight: FontWeight.w900,
                             fontStyle: FontStyle.italic,
                           ),
                         ),
                       ),
                     ),
                     const SizedBox(height: 20),
                     if (_bothReady)
                       Text(
                         '$_countdown',
                         style: const TextStyle(
                           color: Colors.white,
                           fontSize: 60,
                           fontWeight: FontWeight.bold,
                           shadows: [
                             Shadow(color: Colors.black, blurRadius: 10),
                           ],
                         ),
                       )
                     else if (_waitingForOpponent)
                       const Text(
                         'في انتظار الخصم...',
                         style: TextStyle(
                           color: Colors.white70,
                           fontSize: 18,
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
    );
  }
}
