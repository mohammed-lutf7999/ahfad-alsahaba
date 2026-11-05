import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../data/services/multiplayer_service.dart';
import 'versus_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  String _statusText = 'جاري البحث عن خصم...';
  bool _isSearching = true;
  bool _showBotButton = false;
  bool _hasError = false;
  
  StreamSubscription? _matchSubscription;
  Timer? _lobbyTimer;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _startMatchmaking();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _matchSubscription?.cancel();
    _lobbyTimer?.cancel();
    MultiplayerService.instance.stopHeartbeat();
    
    // Cancel matchmaking if leaving screen without match
    if (_isSearching) {
      unawaited(MultiplayerService.instance.cancelMatchmaking());
    }
    super.dispose();
  }

  String _formatErrorMessage(String rawError) {
    if (rawError.contains('SocketException') || 
        rawError.contains('Failed host lookup') || 
        rawError.contains('errno = 7') ||
        rawError.contains('ClientException')) {
      return 'تعذر الاتصال بالخادم السحابي.\nيرجى التحقق من اتصال الإنترنت.';
    }
    if (rawError.contains('timedOut') || rawError.contains('Timeout') || rawError.contains('RealtimeSubscribeException')) {
      return 'انتهت مهلة انتظار الخادم بسبب بطء الشبكة.\nيمكنك المحاولة مجدداً أو اللعب ضد الذكاء الاصطناعي.';
    }
    if (rawError.contains('User not logged in')) {
      return 'يجب تسجيل الدخول أولاً لتحدي اللاعبين.';
    }
    return 'تعذر الاتصال المباشر حالياً.\nيمكنك التحدي ضد الذكاء الاصطناعي.';
  }

  Future<void> _startMatchmaking() async {
    // Show Bot Button after 15 seconds
    _lobbyTimer?.cancel();
    MultiplayerService.instance.stopHeartbeat();
    _lobbyTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isSearching) {
        setState(() => _showBotButton = true);
        SoundService().playNotification(); // Subtle notification
      }
    });

    // Get actual app version from package info
    final appVersion = AppConstants.appVersion; 
    
    final result = await MultiplayerService.instance.findMatch(appVersion: appVersion);
    
    if (!mounted) return;

    if (result.error != null) {
      if (!mounted) return;
      setState(() {
        _statusText = _formatErrorMessage(result.error!);
        _isSearching = false;
        _hasError = true;
      });
      _radarController.stop();
      return;
    }

    if (result.matchId != null && !result.isWaiting) {
      // Match found immediately!
      _goToVersusScreen(result.matchId!, result.opponentId!, result.seed!, questionIds: result.questionIds);
    } else if (result.isWaiting) {
      // Waiting in queue... listen for match
      setState(() => _statusText = 'في انتظار خصم...');
      
      _matchSubscription = MultiplayerService.instance.listenForMatchFound().listen(
        (matchData) {
          if (!mounted) return;
          
          // Safe null checks before proceeding
          final matchId = matchData['id'];
          final seedValue = matchData['seed'];
          
          if (matchId == null || seedValue == null) {
            debugPrint('Incomplete match data received, waiting...');
            return;
          }
          
          final seed = (seedValue is num) ? seedValue.toInt() : int.tryParse(seedValue.toString()) ?? 0;
          
          // Determine opponent using auth ID
          final myId = MultiplayerService.instance.currentUserId;
          final p1 = matchData['player1_id'];
          final p2 = matchData['player2_id'];
          
          if (myId == null || p1 == null || p2 == null) {
            debugPrint('Missing player IDs, waiting...');
            return;
          }
          
          final opponentId = (p1 == myId) ? p2 : p1;
          
          _goToVersusScreen(matchId, opponentId, seed, questionIds: matchData['question_ids'] != null ? List<String>.from(matchData['question_ids']) : null);
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _statusText = _formatErrorMessage(error.toString());
              _isSearching = false;
              _hasError = true;
            });
            _radarController.stop();
          }
        },
      );
    }
  }

  Future<void> _startBotMatch() async {
    SoundService().playClick();
    _lobbyTimer?.cancel();
    MultiplayerService.instance.stopHeartbeat();
    _matchSubscription?.cancel();
    setState(() => _isSearching = false);
    
    // Fire-and-forget online queue cleanup so offline/slow network NEVER blocks or throws!
    unawaited(MultiplayerService.instance.cancelMatchmaking());
    
    // Start local bot match immediately (0ms delay)
    final result = await MultiplayerService.instance.createBotMatch();
    if (!mounted) return;
    _goToVersusScreen(
      result.matchId!, 
      result.opponentId!, 
      result.seed!, 
      isBot: true, 
      questionIds: result.questionIds,
    );
  }

  void _goToVersusScreen(String matchId, String opponentId, int seed, {bool isBot = false, List<String>? questionIds}) {
    // Cancel subscription and stop search
    _matchSubscription?.cancel();
    _lobbyTimer?.cancel();
    MultiplayerService.instance.stopHeartbeat();
    
    setState(() => _isSearching = false);
    _radarController.stop();
    SoundService().playPlayerJoin();
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VersusScreen(
          matchId: matchId,
          opponentId: opponentId,
          seed: seed,
          isBot: isBot,
          questionIds: questionIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              const Text(
                'تحدي مباشر',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 50),
              
              // Radar Visual
              SizedBox(
                height: 300,
                width: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ripples
                    ...List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _radarController,
                        builder: (context, child) {
                          final progress = (_radarController.value + (index * 0.33)) % 1.0;
                          return Opacity(
                            opacity: 1.0 - progress,
                            child: Container(
                              width: 300 * progress,
                              height: 300 * progress,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.accentColor.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    
                    // Center Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentColor,
                        boxShadow: [
                          BoxShadow(color: AppTheme.accentColor.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)
                        ],
                      ),
                      child: const Icon(Icons.search, size: 50, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // Status Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Cairo',
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Action buttons when error occurs
              if (_hasError) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            SoundService().playClick();
                            setState(() {
                              _statusText = 'جاري البحث عن خصم...';
                              _isSearching = true;
                              _hasError = false;
                              _showBotButton = false;
                            });
                            _radarController.repeat();
                            _startMatchmaking();
                          },
                          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryDark),
                          label: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDark,
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              height: 1.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _startBotMatch,
                          icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
                          label: const Text(
                            'تحدي الذكاء الاصطناعي 🤖',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              height: 1.2,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            side: const BorderSide(color: AppTheme.accentColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          SoundService().playClick();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                        label: const Text('العودة للرئيسية', style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                ),
              ] else if (_showBotButton && _isSearching) ...[
                AnimatedOpacity(
                  opacity: _showBotButton ? 1.0 : 0.0,
                  duration: const Duration(seconds: 1),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _startBotMatch,
                      icon: const Icon(Icons.smart_toy_rounded, color: AppTheme.primaryDark),
                      label: const Text(
                        'تحدي الذكاء الاصطناعي 🤖',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Cancel Button
              if (_isSearching)
                TextButton.icon(
                  onPressed: () {
                    SoundService().playClick();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text('إلغاء', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
