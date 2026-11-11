import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/services/multiplayer_service.dart';

enum RematchUIState {
  idle,
  waitingForOpponent,
  receivedOffer,
  launchingMatch,
  opponentLeft,
}

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
    Function(MatchmakingResult newMatch)? onRematchAccepted,
  }) {
    showDialog(
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
        onRematchAccepted: onRematchAccepted,
      ),
    );
  }
}

class _GameMatchResultDialogContent extends StatefulWidget {
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
  final Function(MatchmakingResult newMatch)? onRematchAccepted;

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
    this.onRematchAccepted,
  });

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
    if (widget.matchId == null || widget.isBot) return;

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
          _startCountdown(onTimeout: () {
            if (mounted && _rematchState == RematchUIState.receivedOffer) {
              setState(() => _rematchState = RematchUIState.opponentLeft);
            }
          });
        }
      } else if (type == 'accept') {
        _handleRematchLaunch();
      } else if (type == 'leave') {
        _countdownTimer?.cancel();
        setState(() {
          _rematchState = RematchUIState.opponentLeft;
        });
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

    if (widget.matchId == null) return;

    setState(() {
      _rematchState = RematchUIState.waitingForOpponent;
      _countdown = 10;
    });

    await MultiplayerService.instance.sendRematchOffer(widget.matchId!);

    _startCountdown(onTimeout: () {
      if (mounted && _rematchState == RematchUIState.waitingForOpponent) {
        setState(() => _rematchState = RematchUIState.opponentLeft);
      }
    });
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              widget.isDraw
                  ? Icons.handshake
                  : (widget.isWinner
                      ? Icons.emoji_events
                      : Icons.sentiment_dissatisfied),
              size: 56,
              color: widget.isDraw
                  ? Colors.blue
                  : (widget.isWinner ? AppTheme.accentColor : Colors.red),
            ),
            const SizedBox(height: 12),

            // Result Title
            Text(
              widget.isDraw
                  ? 'تعادل!'
                  : (widget.isWinner ? '🎉 أنت الفائز!' : 'حظاً أوفر..'),
              style: TextStyle(
                color: widget.isDraw
                    ? Colors.blue
                    : (widget.isWinner ? Colors.green : Colors.red),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),

            // Trophies and Coins badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: (widget.effectiveDelta >= 0
                            ? Colors.amber
                            : Colors.redAccent)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (widget.effectiveDelta >= 0
                              ? Colors.amber
                              : Colors.redAccent)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${widget.effectiveDelta >= 0 ? "+${widget.effectiveDelta}" : "${widget.effectiveDelta}"} كأساً 🏆${widget.totalTrophies != null ? " (${widget.totalTrophies})" : ""}',
                    style: TextStyle(
                      color: widget.effectiveDelta >= 0
                          ? Colors.amberAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                if (widget.coinsEarned > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '+${widget.coinsEarned} 🪙 دنانير الفتح',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
              ],
            ),

            if (widget.shieldConsumed || widget.xpBannerConsumed) ...[
              const SizedBox(height: 8),
              Text(
                widget.shieldConsumed
                    ? '🛡️ درع الحماية حمى كؤوسك وسلسلة انتصاراتك!'
                    : '🚩 راية المضاعفة ضاعفت خبرتك المكتسبة (2x)!',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),

            // Scores comparison card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'أنت',
                          style: TextStyle(
                              color: Colors.white70, fontFamily: 'Cairo'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.myScore}',
                          style: const TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 45,
                    color: Colors.white24,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.opponentName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '${widget.opponentScore}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Rematch Status Banner if received or opponent left
            if (_rematchState == RematchUIState.receivedOffer) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flash_on,
                        color: AppTheme.accentColor, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'الخصم يطلب إعادة النزال! (${_countdown}s)',
                        style: const TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_rematchState == RematchUIState.opponentLeft) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.door_back_door_outlined,
                        color: Colors.white60, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'غادر الخصم شاشة النزال أو انتهى الوقت',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        // Action Buttons according to Rematch State
        if (_rematchState == RematchUIState.receivedOffer) ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleRematchLaunch,
                    icon: const Icon(Icons.sports_kabaddi, size: 18),
                    label: const Text(
                      'قبول النزال ⚔️',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Cairo',
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleLeave,
                    child: const Text(
                      'انسحاب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else if (_rematchState == RematchUIState.launchingMatch) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: null,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'جاري تجهيز ساحة المعركة...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // Rematch Button
          if (_rematchState == RematchUIState.waitingForOpponent)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.8),
                  foregroundColor: AppTheme.primaryDark,
                  elevation: 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: null,
                icon: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryDark,
                  ),
                ),
                label: Text(
                  'بانتظار رد الخصم (${_countdown}s)...',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                    height: 1.2,
                  ),
                ),
              ),
            )
          else if (_rematchState != RematchUIState.opponentLeft)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: AppTheme.primaryDark,
                  elevation: 3,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _requestRematch,
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: const Text(
                  'طلب إعادة النزال ⚔️',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Cairo',
                    height: 1.2,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Return to Home button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleLeave,
              child: const Text(
                'العودة للرئيسية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Cairo',
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
