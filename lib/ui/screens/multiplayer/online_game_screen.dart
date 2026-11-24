import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../data/services/profile_service.dart';
import '../../../data/services/progression_service.dart';
import '../../../logic/online_match_controller.dart';
import '../../dialogs/app_dialogs.dart';
import 'versus_screen.dart';
import 'widgets/game_match_result_dialog.dart';
import 'widgets/online_question_board.dart';
import 'widgets/online_reactions_overlay.dart';
import 'widgets/online_scoreboard_header.dart';

class OnlineGameScreen extends StatefulWidget {
  final String matchId;
  final String opponentId;
  final int seed;
  final List<String> questionIds;
  final String opponentName;
  final int opponentAvatarIndex;
  final bool isBot;
  final bool isGhost;
  final bool isFriendly;
  final List<Map<String, dynamic>>? ghostTimeline;
  final String? ghostFrame;
  final int? ghostLevel;
  final int? ghostTrophies;

  const OnlineGameScreen({
    super.key,
    required this.matchId,
    required this.opponentId,
    required this.seed,
    required this.questionIds,
    required this.opponentName,
    required this.opponentAvatarIndex,
    this.isBot = false,
    this.isGhost = false,
    this.isFriendly = false,
    this.ghostTimeline,
    this.ghostFrame,
    this.ghostLevel,
    this.ghostTrophies,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with TickerProviderStateMixin {
  late final OnlineMatchController _controller;
  late final AnimationController _progressController;
  late final AnimationController _reactionController;
  late final Animation<Offset> _emojiSlideAnim;
  late final Animation<double> _emojiFadeAnim;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _reactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _emojiSlideAnim = Tween<Offset>(
      begin: const Offset(0, 2),
      end: const Offset(0, -1.5),
    ).animate(
      CurvedAnimation(parent: _reactionController, curve: Curves.easeOutQuad),
    );
    _emojiFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _reactionController,
        curve: const Interval(0.7, 1.0),
      ),
    );

    _controller = OnlineMatchController(
      matchId: widget.matchId,
      opponentId: widget.opponentId,
      seed: widget.seed,
      questionIds: widget.questionIds,
      isBot: widget.isBot,
      isGhost: widget.isGhost,
      isFriendly: widget.isFriendly,
      ghostTimeline: widget.ghostTimeline,
      onQuestionStarted: () {
        if (mounted) _progressController.forward(from: 0);
      },
      onIncomingReaction: (_) {
        if (mounted) _reactionController.forward(from: 0);
      },
      onLoadError: (msg) {
        if (mounted) _showErrorDialog(msg);
      },
      onMatchFinished: _handleMatchFinished,
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  Future<void> _handleMatchFinished(OnlineMatchFinishSummary summary) async {
    if (!mounted) return;
    if (summary.preSnapshot != null) {
      await ProgressionService.instance.checkAndTriggerCelebrations(
        context,
        before: summary.preSnapshot!,
      );
    }
    if (!mounted) return;

    final effectiveDelta = summary.trophiesDelta ??
        (summary.isDraw ? 5 : (summary.isWinner ? 25 : -12));

    GameMatchResultDialog.show(
      context,
      isWinner: summary.isWinner,
      isDraw: summary.isDraw,
      effectiveDelta: effectiveDelta,
      totalTrophies: summary.totalTrophies,
      coinsEarned: summary.coinsEarned,
      shieldConsumed: summary.shieldConsumed,
      xpBannerConsumed: summary.xpBannerConsumed,
      myScore: summary.myScore,
      opponentScore: summary.opponentScore,
      opponentName: widget.opponentName,
      matchId: widget.matchId,
      opponentId: widget.opponentId,
      isBot: widget.isBot,
      isGhost: widget.isGhost,
      isFriendly: widget.isFriendly,
      onRematchAccepted: _onRematchAccepted,
      onGhostRematchAccepted: _onGhostRematchAccepted,
      onDismiss: () => Navigator.of(context).popUntil((route) => route.isFirst),
    );
  }

  void _onRematchAccepted(MatchmakingResult newMatch) {
    if (!mounted) return;
    final resolvedIsBot =
        widget.isBot || (newMatch.matchId?.startsWith('bot_') ?? false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          matchId: newMatch.matchId!,
          opponentId: newMatch.opponentId ?? widget.opponentId,
          seed: newMatch.seed ?? widget.seed,
          questionIds: newMatch.questionIds ?? [],
          opponentName: resolvedIsBot ? 'المتحدي الذكي' : widget.opponentName,
          opponentAvatarIndex: widget.opponentAvatarIndex,
          isBot: resolvedIsBot,
          isFriendly: newMatch.isFriendly,
        ),
      ),
    );
  }

  void _onGhostRematchAccepted(GhostMatchResult ghost) {
    if (!mounted || ghost.matchId == null) return;
    if (ghost.isHumanMatch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VersusScreen(
            matchId: ghost.matchId!,
            opponentId: ghost.ghostUserId ?? '',
            seed: ghost.seed ?? 1000,
            isBot: false,
            isGhost: false,
            isFriendly: ghost.isFriendly,
            questionIds: ghost.questionIds,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          matchId: ghost.matchId!,
          opponentId: ghost.ghostUserId ??
              'ghost_${DateTime.now().millisecondsSinceEpoch}',
          seed: ghost.seed ?? widget.seed,
          questionIds: ghost.questionIds ?? [],
          opponentName: ghost.ghostName ?? 'فارس الأندلس',
          opponentAvatarIndex: ghost.ghostAvatarIndex ?? 0,
          isBot: false,
          isGhost: true,
          isFriendly: ghost.isFriendly,
          ghostTimeline: ghost.timeline,
          ghostFrame: ghost.ghostFrame,
          ghostLevel: ghost.ghostLevel ?? 5,
          ghostTrophies: ghost.ghostTrophies,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.primaryDark,
        title: const Text('خطأ', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('عودة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return _buildPlaceholderScaffold(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'جاري تحميل الأسئلة...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        final question = _controller.currentQuestion;
        if (question == null) {
          return _buildPlaceholderScaffold(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد أسئلة',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('عودة'),
                ),
              ],
            ),
          );
        }

        final myProfile = ProfileService.instance.activeProfile;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            AppDialogs.showExitConfirmationDialog(
              context,
              title: 'الانسحاب من المباراة؟',
              message:
                  'الخروج أثناء المباراة المباشرة سيؤدي إلى خسارتك النقاط والكؤوس. هل تريد الخروج حقاً؟',
              confirmLabel: 'تأكيد الانسحاب',
              cancelLabel: 'متابعة القتال',
              onConfirm: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            );
          },
          child: Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: AppCustomTheme.of(context).backgroundGradient,
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        OnlineScoreboardHeader(
                          myName: myProfile?.name ?? 'أنا',
                          myAvatarIndex: myProfile?.avatarIndex ?? 0,
                          myEquippedFrame:
                              myProfile?.equippedFrame ?? 'frame_wood',
                          myWinStreak: myProfile?.winStreak ?? 0,
                          myScore: _controller.myScore,
                          opponentName: widget.opponentName,
                          opponentAvatarIndex: widget.opponentAvatarIndex,
                          opponentScore: _controller.opponentScore,
                          opponentQuestionIndex:
                              _controller.opponentQuestionIndex,
                          currentQuestionIndex:
                              _controller.currentQuestionIndex,
                          totalQuestions: _controller.questions.length,
                          timeLeft: _controller.timeLeft,
                          progressAnimation: _progressController,
                        ),
                        Expanded(
                          child: OnlineQuestionBoard(
                            question: question,
                            isBot: widget.isBot,
                            isAnswered: _controller.isAnswered,
                            selectedAnswer: _controller.selectedAnswer,
                            hiddenOptionIndices:
                                _controller.hiddenOptionIndices,
                            showQuickPhrases: _controller.showQuickPhrases,
                            random: _controller.random,
                            onInsightUsed: _controller.applyHiddenOptions,
                            onReactionSelected: _controller.sendReaction,
                            onToggleQuickPhrases: _controller.toggleQuickPhrases,
                            onQuickPhraseSelected: _controller.sendQuickPhrase,
                            onOptionSelected: _controller.submitAnswer,
                          ),
                        ),
                      ],
                    ),
                    OnlineReactionsOverlay(
                      incomingQuickPhrase: _controller.incomingQuickPhrase,
                      incomingReactionEmoji: _controller.incomingReactionEmoji,
                      emojiSlideAnim: _emojiSlideAnim,
                      emojiFadeAnim: _emojiFadeAnim,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderScaffold(Widget child) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(child: Center(child: child)),
      ),
    );
  }
}
