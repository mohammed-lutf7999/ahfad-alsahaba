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
import 'widgets/lobby_radar_view.dart';

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

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
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

    if (_isSearching) {
      unawaited(MultiplayerService.instance.cancelMatchmaking());
    }
    super.dispose();
  }

  String _formatErrorMessage(String rawError) =>
      NetworkErrorFormatter.format(rawError);

  Future<void> _startMatchmaking() async {
    _lobbyTimer?.cancel();
    MultiplayerService.instance.stopHeartbeat();
    _elapsedSearchSeconds = 0;
    _isTransitioning = false;
    _hasError = false;

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
          child: LobbyRadarView(
            radarController: _radarController,
            statusText: _statusText,
            isSearching: _isSearching,
            hasError: _hasError,
            onRetry: () {
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
            onPlayOfflineBot: () =>
                _launchGhostMatchOrBotFallback(offlineFallbackOnly: true),
            onExit: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
