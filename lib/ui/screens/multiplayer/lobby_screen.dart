import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/app_theme.dart';
import '../../../core/network_error_formatter.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/player_level_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../data/services/profile_service.dart';
import 'versus_screen.dart';

class LobbyScreen extends StatefulWidget {
  @visibleForTesting
  final Future<MatchmakingResult> Function({
    required String appVersion,
    int? trophies,
    String? lastOpponentId,
  })? findMatchOverride;

  @visibleForTesting
  final Stream<Map<String, dynamic>>? matchFoundStreamOverride;

  const LobbyScreen({
    super.key,
    this.findMatchOverride,
    this.matchFoundStreamOverride,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  String _statusText = 'جاري البحث عن خصم في فئتك...';
  bool _isSearching = true;
  bool _hasError = false;
  bool _isTransitioning = false;
  int _elapsedSearchSeconds = 0;

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
    return NetworkErrorFormatter.format(rawError);
  }

  Future<void> _startMatchmaking() async {
    _lobbyTimer?.cancel();
    MultiplayerService.instance.stopHeartbeat();
    _elapsedSearchSeconds = 0;
    _isTransitioning = false;
    _hasError = false;

    // Auto-Ghost Backfill at 15s (zero bot button clutter during online search)
    _lobbyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isSearching || _isTransitioning) {
        timer.cancel();
        return;
      }
      _elapsedSearchSeconds++;
      if (_elapsedSearchSeconds == 6) {
        setState(() => _statusText = 'جاري توسيع نطاق الكؤوس للمطابقة...');
      } else if (_elapsedSearchSeconds == 12) {
        setState(() => _statusText = 'جاري العثور على منافس مناسب لك الآن...');
      } else if (_elapsedSearchSeconds >= 15) {
        timer.cancel();
        _launchGhostMatchOrBotFallback(playClick: false);
      }
    });

    // Get actual app version and player trophies
    final appVersion = AppConstants.appVersion;
    final profile = ProfileService.instance.activeProfile;
    final trophies = profile?.trophies ?? 1000;

    final result = await (widget.findMatchOverride != null
        ? widget.findMatchOverride!(
            appVersion: appVersion,
            trophies: trophies,
          )
        : MultiplayerService.instance.findMatch(
            appVersion: appVersion,
            trophies: trophies,
          ));

    if (!mounted || _isTransitioning) return;

    if (result.error != null) {
      _lobbyTimer?.cancel();
      setState(() {
        _statusText = _formatErrorMessage(result.error!);
        _isSearching = false;
        _hasError = true;
      });
      _radarController.stop();
      return;
    }

    if (result.matchId != null && !result.isWaiting) {
      _goToVersusScreen(
        result.matchId!,
        result.opponentId!,
        result.seed!,
        questionIds: result.questionIds,
        isFriendly: result.isFriendly,
      );
    } else if (result.isWaiting) {
      setState(() => _statusText = 'جاري البحث عن خصم في فئتك...');

      final matchStream = widget.matchFoundStreamOverride ??
          MultiplayerService.instance.listenForMatchFound();
      _matchSubscription = matchStream.listen(
        (matchData) {
          if (!mounted || _isTransitioning) return;

          final matchId = matchData['id'];
          final seedValue = matchData['seed'];

          if (matchId == null || seedValue == null) {
            debugPrint('Incomplete match data received, waiting...');
            return;
          }

          final seed = (seedValue is num)
              ? seedValue.toInt()
              : int.tryParse(seedValue.toString()) ?? 0;

          final myId = MultiplayerService.instance.currentUserId;
          final p1 = matchData['player1_id'];
          final p2 = matchData['player2_id'];

          if (myId == null || p1 == null || p2 == null) {
            debugPrint('Missing player IDs, waiting...');
            return;
          }

          final opponentId = (p1 == myId) ? p2 : p1;

          _goToVersusScreen(
            matchId,
            opponentId,
            seed,
            isFriendly: matchData['is_friendly'] == true,
            questionIds: matchData['question_ids'] != null
                ? List<String>.from(matchData['question_ids'])
                : null,
          );
        },
        onError: (error) {
          if (mounted && !_isTransitioning) {
            _lobbyTimer?.cancel();
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

  /// Launches an authoritative Ghost match after 15s (or offline bot at 0ms when [offlineFallbackOnly]),
  /// honoring the server's last-millisecond human match race guard (`isHumanMatch`).
  Future<void> _launchGhostMatchOrBotFallback({
    bool playClick = true,
    bool offlineFallbackOnly = false,
  }) async {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;

    if (playClick) SoundService().playClick();
    _lobbyTimer?.cancel();
    MultiplayerService.instance.stopHeartbeat();
    _matchSubscription?.cancel();
    setState(() {
      _isSearching = false;
      _statusText = 'تم العثور على منافس! جاري التجهيز...';
    });

    if (!offlineFallbackOnly &&
        AppControlService.instance.featureFlagsNotifier.value.ghostMatches) {
      try {
        final profile = ProfileService.instance.activeProfile;
        final ghostResult = await MultiplayerService.instance
            .findOrCreateGhostMatch(trophies: profile?.trophies ?? 1000)
            .timeout(const Duration(seconds: 5));

        if (ghostResult.success && ghostResult.matchId != null && mounted) {
          if (ghostResult.isHumanMatch) {
            _navigateToVersus(
              ghostResult.matchId!,
              ghostResult.ghostUserId ?? '',
              ghostResult.seed ?? 1000,
              isBot: false,
              isGhost: false,
              isFriendly: ghostResult.isFriendly,
              questionIds: ghostResult.questionIds,
            );
            return;
          }

          final ghostLevel = ghostResult.ghostLevel ?? 5;
          final ghostData = {
            'display_name': ghostResult.ghostName ?? 'فارس الأندلس',
            'avatar_index': ghostResult.ghostAvatarIndex ?? 0,
            'equipped_frame': ghostResult.ghostFrame ?? 'frame_wood',
            'player_level': ghostLevel,
            'trophies': ghostResult.ghostTrophies ?? 1000,
            'score': PlayerLevelInfo.cumulativeXpForLevel(ghostLevel),
          };

          _navigateToVersus(
            ghostResult.matchId!,
            ghostResult.ghostUserId ??
                'ghost_${DateTime.now().millisecondsSinceEpoch}',
            ghostResult.seed ?? 1000,
            isBot: false,
            isGhost: true,
            isFriendly: ghostResult.isFriendly,
            ghostTimeline: ghostResult.timeline,
            initialOpponentData: ghostData,
            questionIds: ghostResult.questionIds,
          );
          return;
        }
      } catch (e) {
        debugPrint('Ghost match fallback to offline bot: $e');
      }
    }

    unawaited(MultiplayerService.instance.cancelMatchmaking());
    final result = await MultiplayerService.instance.createBotMatch();
    if (!mounted) return;
    _navigateToVersus(
      result.matchId!,
      result.opponentId!,
      result.seed!,
      isBot: true,
      questionIds: result.questionIds,
    );
  }

  void _goToVersusScreen(
    String matchId,
    String opponentId,
    int seed, {
    bool isBot = false,
    bool isGhost = false,
    bool isFriendly = false,
    List<Map<String, dynamic>>? ghostTimeline,
    Map<String, dynamic>? initialOpponentData,
    List<String>? questionIds,
  }) {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;
    _navigateToVersus(
      matchId,
      opponentId,
      seed,
      isBot: isBot,
      isGhost: isGhost,
      isFriendly: isFriendly,
      ghostTimeline: ghostTimeline,
      initialOpponentData: initialOpponentData,
      questionIds: questionIds,
    );
  }

  void _navigateToVersus(
    String matchId,
    String opponentId,
    int seed, {
    bool isBot = false,
    bool isGhost = false,
    bool isFriendly = false,
    List<Map<String, dynamic>>? ghostTimeline,
    Map<String, dynamic>? initialOpponentData,
    List<String>? questionIds,
  }) {
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
          isGhost: isGhost,
          isFriendly: isFriendly,
          ghostTimeline: ghostTimeline,
          initialOpponentData: initialOpponentData,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompactHeight = constraints.maxHeight < 680;
              final radarSize = isCompactHeight ? 220.0 : 300.0;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 32).clamp(0.0, double.infinity),
                  ),
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
                      SizedBox(height: isCompactHeight ? 24 : 40),
                      
                      // Radar Visual
                      SizedBox(
                        height: radarSize,
                        width: radarSize,
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
                                      width: radarSize * progress,
                                      height: radarSize * progress,
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
              
              SizedBox(height: isCompactHeight ? 24 : 40),
              
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
                              _statusText = 'جاري البحث عن خصم في فئتك...';
                              _isSearching = true;
                              _hasError = false;
                              _isTransitioning = false;
                              _elapsedSearchSeconds = 0;
                            });
                            _radarController.repeat();
                            _startMatchmaking();
                          },
                          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryDark),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'إعادة المحاولة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDark,
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                height: 1.2,
                              ),
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
                          onPressed: () =>
                              _launchGhostMatchOrBotFallback(offlineFallbackOnly: true),
                          icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'تحدي الذكاء الاصطناعي 🤖',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                height: 1.2,
                              ),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
