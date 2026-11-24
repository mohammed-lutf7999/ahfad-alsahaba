import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/services/app_control_service.dart';
import '../../../../data/services/multiplayer_service.dart';
import '../../../../data/services/profile_service.dart';
import 'match_rewards_summary.dart';
import 'rematch_action_bar.dart';

export 'rematch_action_bar.dart' show RematchUIState;

/// نافذة نتيجة المباراة النهائية في المنافسات المباشرة مع نظام إعادة النزال الفوري
class GameMatchResultDialog {
  static void show(
    BuildContext context, {
    required bool isWinner,
    required bool isDraw,
    required int effectiveDelta,
    int? totalTrophies,
    int coinsEarned = 0,
    bool shieldConsumed = false,
    bool xpBannerConsumed = false,
    required int myScore,
    required int opponentScore,
    required String opponentName,
    required VoidCallback onDismiss,
    String? matchId,
    String? opponentId,
    bool isBot = false,
    bool isGhost = false,
    bool isFriendly = false,
    Function(MatchmakingResult newMatch)? onRematchAccepted,
    Function(GhostMatchResult newGhostMatch)? onGhostRematchAccepted,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameMatchResultDialogContent(
        isWinner: isWinner,
        isDraw: isDraw,
        effectiveDelta: effectiveDelta,
        totalTrophies: totalTrophies,
        coinsEarned: coinsEarned,
        shieldConsumed: shieldConsumed,
        xpBannerConsumed: xpBannerConsumed,
        myScore: myScore,
        opponentScore: opponentScore,
        opponentName: opponentName,
        onDismiss: onDismiss,
        matchId: matchId,
        opponentId: opponentId,
        isBot: isBot,
        isGhost: isGhost,
        isFriendly: isFriendly,
        onRematchAccepted: onRematchAccepted,
        onGhostRematchAccepted: onGhostRematchAccepted,
      ),
    );
  }
}

class _GameMatchResultDialogContent extends StatefulWidget {
  const _GameMatchResultDialogContent({
    required this.isWinner,
    required this.isDraw,
    required this.effectiveDelta,
    this.totalTrophies,
    this.coinsEarned = 0,
    this.shieldConsumed = false,
    this.xpBannerConsumed = false,
    required this.myScore,
    required this.opponentScore,
    required this.opponentName,
    required this.onDismiss,
    this.matchId,
    this.opponentId,
    this.isBot = false,
    this.isGhost = false,
    this.isFriendly = false,
    this.onRematchAccepted,
    this.onGhostRematchAccepted,
  });

  final bool isWinner;
  final bool isDraw;
  final int effectiveDelta;
  final int? totalTrophies;
  final int coinsEarned;
  final bool shieldConsumed;
  final bool xpBannerConsumed;
  final int myScore;
  final int opponentScore;
  final String opponentName;
  final VoidCallback onDismiss;
  final String? matchId;
  final String? opponentId;
  final bool isBot;
  final bool isGhost;
  final bool isFriendly;
  final Function(MatchmakingResult newMatch)? onRematchAccepted;
  final Function(GhostMatchResult newGhostMatch)? onGhostRematchAccepted;

  @override
  State<_GameMatchResultDialogContent> createState() =>
      _GameMatchResultDialogContentState();
}

class _GameMatchResultDialogContentState
    extends State<_GameMatchResultDialogContent> {
  RematchUIState _rematchState = RematchUIState.idle;
  int _countdown = 10;
  Timer? _countdownTimer;
  StreamSubscription<Map<String, dynamic>>? _rematchSubscription;

  @override
  void initState() {
    super.initState();
    _initRematchListener();
  }

  void _initRematchListener() {
    if (widget.matchId == null || widget.isBot || widget.isGhost) return;

    _rematchSubscription = MultiplayerService.instance
        .listenToRematchEvents(widget.matchId!)
        .listen((event) {
      if (!mounted) return;
      final type = event['event'] as String?;

      if (type == 'offer') {
        if (_rematchState == RematchUIState.idle) {
          SoundService().playCorrect();
          setState(() {
            _rematchState = RematchUIState.receivedOffer;
            _countdown = 10;
          });
          _startCountdown(
            onTimeout: () {
              if (mounted && _rematchState == RematchUIState.receivedOffer) {
                setState(() => _rematchState = RematchUIState.opponentLeft);
              }
            },
          );
        }
      } else if (type == 'accept') {
        _handleRematchLaunch();
      } else if (type == 'leave') {
        _countdownTimer?.cancel();
        setState(() => _rematchState = RematchUIState.opponentLeft);
      }
    });
  }

  void _startCountdown({required VoidCallback onTimeout}) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          timer.cancel();
          onTimeout();
        }
      });
    });
  }

  Future<void> _requestRematch() async {
    SoundService().playClick();
    if (widget.isBot) {
      setState(() => _rematchState = RematchUIState.launchingMatch);
      final newMatch = await MultiplayerService.instance.createBotMatch();
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRematchAccepted?.call(newMatch);
      return;
    }

    if (widget.isGhost) {
      setState(() => _rematchState = RematchUIState.launchingMatch);
      if (AppControlService.instance.featureFlagsNotifier.value.ghostMatches) {
        try {
          final trophies =
              ProfileService.instance.activeProfile?.trophies ?? 1000;
          final ghostResult = await MultiplayerService.instance
              .findOrCreateGhostMatch(trophies: trophies);
          if (!mounted) return;
          if (ghostResult.success && ghostResult.matchId != null) {
            Navigator.of(context).pop();
            widget.onGhostRematchAccepted?.call(ghostResult);
            return;
          }
        } catch (e) {
          debugPrint('Ghost rematch fallback to bot: $e');
        }
      }
      final fallbackBot = await MultiplayerService.instance.createBotMatch();
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRematchAccepted?.call(fallbackBot);
      return;
    }

    if (widget.matchId == null) return;
    setState(() {
      _rematchState = RematchUIState.waitingForOpponent;
      _countdown = 10;
    });

    await MultiplayerService.instance.sendRematchOffer(widget.matchId!);
    _startCountdown(
      onTimeout: () {
        if (mounted && _rematchState == RematchUIState.waitingForOpponent) {
          setState(() => _rematchState = RematchUIState.opponentLeft);
        }
      },
    );
  }

  Future<void> _handleRematchLaunch() async {
    _countdownTimer?.cancel();
    setState(() => _rematchState = RematchUIState.launchingMatch);

    final result = await MultiplayerService.instance.createInstantRematch(
      parentMatchId: widget.matchId!,
    );
    if (!mounted) return;

    if (result.success && result.matchId != null) {
      unawaited(SoundService().playGameStart());
      Navigator.of(context).pop();
      widget.onRematchAccepted?.call(result);
    } else {
      setState(() => _rematchState = RematchUIState.opponentLeft);
    }
  }

  void _handleLeave() {
    SoundService().playClick();
    _countdownTimer?.cancel();
    if (!widget.isBot && widget.matchId != null) {
      unawaited(MultiplayerService.instance.sendRematchLeave(widget.matchId!));
      MultiplayerService.instance.closeRematchChannel();
    }
    Navigator.of(context).pop();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _rematchSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.primaryDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'انتهت المباراة!',
        style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: MatchRewardsSummary(
          isWinner: widget.isWinner,
          isDraw: widget.isDraw,
          effectiveDelta: widget.effectiveDelta,
          totalTrophies: widget.totalTrophies,
          coinsEarned: widget.coinsEarned,
          shieldConsumed: widget.shieldConsumed,
          xpBannerConsumed: widget.xpBannerConsumed,
          isFriendly: widget.isFriendly,
          myScore: widget.myScore,
          opponentScore: widget.opponentScore,
          opponentName: widget.opponentName,
          rematchState: _rematchState,
          countdown: _countdown,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        RematchActionBar(
          rematchState: _rematchState,
          countdown: _countdown,
          isGhost: widget.isGhost,
          onAcceptRematch: _handleRematchLaunch,
          onRequestRematch: _requestRematch,
          onLeave: _handleLeave,
        ),
      ],
    );
  }
}
