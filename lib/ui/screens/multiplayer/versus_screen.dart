import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/arena_model.dart';
import '../../../data/models/player_level_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../data/services/profile_service.dart';
import '../../../data/services/progression_service.dart';
import 'online_game_screen.dart';
import 'widgets/versus_countdown_badge.dart';
import 'widgets/versus_player_card.dart';
import 'widgets/versus_timeout_dialog.dart';

class VersusScreen extends StatefulWidget {
  final String matchId;
  final String opponentId;
  final int seed;
  final bool isBot;
  final bool isGhost;
  final bool isFriendly;
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
    this.isFriendly = false,
    this.questionIds,
    this.ghostTimeline,
    this.initialOpponentData,
  });

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen>
    with TickerProviderStateMixin {
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
  Timer? _botReadyTimer;
  Timer? _phraseTimer;
  Timer? _phraseEchoTimer;
  StreamSubscription<MatchState>? _matchStateSubscription;
  StreamSubscription<String>? _reactionKeepaliveSub;
  StreamSubscription<String>? _phraseSubscription;
  String? _activeQuickPhrase;
  bool _phraseIsMine = false;

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
    _botReadyTimer?.cancel();
    _phraseTimer?.cancel();
    _phraseEchoTimer?.cancel();
    _matchStateSubscription?.cancel();
    _reactionKeepaliveSub?.cancel();
    _phraseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDataAndConfirmReady() async {
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

    final opponentData =
        await MultiplayerService.instance.fetchOpponentData(widget.opponentId);
    if (!mounted) return;

    List<String> qIds = [];
    if (widget.isBot) {
      qIds = widget.questionIds ?? [];
    } else {
      final matchData =
          await MultiplayerService.instance.getMatchData(widget.matchId);
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

    await _vsController.forward();

    if (widget.isBot) {
      _botReadyTimer?.cancel();
      _botReadyTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) _onBothPlayersReady();
      });
      return;
    }

    _reactionKeepaliveSub = MultiplayerService.instance
        .listenToReactions(widget.matchId)
        .listen((_) {});
    _phraseSubscription = MultiplayerService.instance.quickPhrasesStream
        .listen((phrase) => _showQuickPhraseBanner(phrase, isMine: false));
    _matchStateSubscription = MultiplayerService.instance
        .listenToMatchState(widget.matchId)
        .listen((state) {
      if (!mounted) return;
      if ((state.status == 'ready' || state.status == 'playing') &&
          !_bothReady) {
        _onBothPlayersReady();
      }
    });

    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!mounted || _bothReady) {
        timer.cancel();
        return;
      }
      final matchData =
          await MultiplayerService.instance.getMatchData(widget.matchId);
      if (!mounted || _bothReady) return;
      final status = matchData?['status'] as String?;
      if (status == 'ready' || status == 'playing') {
        if ((_questionIds == null || _questionIds!.isEmpty) &&
            matchData?['question_ids'] != null) {
          _questionIds = List<String>.from(matchData!['question_ids']);
        }
        _onBothPlayersReady();
      }
    });

    _safetyTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _bothReady) return;
      _pollTimer?.cancel();
      _matchStateSubscription?.cancel();
      unawaited(MultiplayerService.instance.cancelMatch(widget.matchId));
      showVersusOpponentTimeoutDialog(context);
    });

    setState(() => _waitingForOpponent = true);
    final bothReady =
        await MultiplayerService.instance.confirmReady(widget.matchId);
    if (bothReady && mounted) _onBothPlayersReady();
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

  void _showQuickPhraseBanner(String phrase, {required bool isMine}) {
    if (!mounted ||
        !AppControlService.instance.featureFlagsNotifier.value.quickPhrases) {
      return;
    }
    _phraseTimer?.cancel();
    setState(() {
      _activeQuickPhrase = phrase;
      _phraseIsMine = isMine;
    });
    _phraseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _activeQuickPhrase = null);
    });
  }

  void _sendQuickPhrase(String phrase) {
    SoundService().playClick();
    _showQuickPhraseBanner(phrase, isMine: true);
    if (!widget.isBot && !widget.isGhost) {
      unawaited(
        MultiplayerService.instance.sendQuickPhrase(widget.matchId, phrase),
      );
    } else {
      _phraseEchoTimer?.cancel();
      _phraseEchoTimer = Timer(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        _showQuickPhraseBanner(
          'وعليكم السلام ورحمة الله، حياك الله ⚔️',
          isMine: false,
        );
      });
    }
  }

  void _startCountdown() {
    if (_countdownTimer != null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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
          opponentAvatarIndex:
              (_opponentData?['avatar_index'] as num?)?.toInt() ?? 0,
          isBot: widget.isBot,
          isGhost: widget.isGhost,
          isFriendly: widget.isFriendly,
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
    final oppLevelNum = (_opponentData?['player_level'] as num?)?.toInt();
    final oppTrophies = (_opponentData?['trophies'] as num?)?.toInt() ?? 1000;
    final oppLevelInfo = oppLevelNum != null && oppLevelNum > 0
        ? PlayerLevelInfo.forMilestoneLevel(oppLevelNum)
        : PlayerLevelInfo.fromTotalScore(oppScore);
    final oppArena = ArenaModel.fromTrophies(oppTrophies);
    final oppName = _opponentData?['display_name'] as String? ?? 'الخصم';

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
                  Expanded(
                    child: VersusPlayerCard(
                      tintColor: Colors.blue,
                      name: myProfile?.name ?? 'أنا',
                      avatarIndex: myProfile?.avatarIndex ?? 0,
                      frameKey:
                          myProfile?.equippedFrame ?? myLevelInfo.frameKey,
                      winStreak: myProfile?.winStreak ?? 0,
                      levelInfo: myLevelInfo,
                      arena: myArena,
                      score: myProfile?.totalScore ?? 0,
                      trophies: myProfile?.trophies ?? 1000,
                      customTitle: myProfile?.effectiveTitle,
                      isReady: true,
                    ),
                  ),
                  VersusCountdownBadge(
                    vsScale: _vsScale,
                    bothReady: _bothReady,
                    waitingForOpponent: _waitingForOpponent,
                    countdown: _countdown,
                    isFriendly: widget.isFriendly,
                    opponentName: oppName,
                    activeQuickPhrase: _activeQuickPhrase,
                    phraseIsMine: _phraseIsMine,
                    onQuickPhraseSelected: _sendQuickPhrase,
                  ),
                  Expanded(
                    child: VersusPlayerCard(
                      tintColor: Colors.red,
                      name: oppName,
                      avatarIndex:
                          (_opponentData?['avatar_index'] as num?)?.toInt() ??
                              0,
                      frameKey: (_opponentData?['equipped_frame'] as String?) ??
                          oppLevelInfo.frameKey,
                      winStreak:
                          (_opponentData?['win_streak'] as num?)?.toInt() ?? 0,
                      levelInfo: oppLevelInfo,
                      arena: oppArena,
                      score: oppScore,
                      trophies: oppTrophies,
                      customTitle: _opponentData?['player_title'] as String?,
                      isLoading: _isLoading,
                      isReady: _bothReady,
                      isWaiting: _waitingForOpponent,
                    ),
                  ),
                ],
              ),
              if (!_bothReady)
                Positioned(
                  top: 8,
                  left: 8,
                  child: TextButton.icon(
                    onPressed: () {
                      SoundService().playClick();
                      if (!widget.isBot) {
                        unawaited(
                          MultiplayerService.instance.cancelMatch(widget.matchId),
                        );
                      }
                      if (mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    label: const Text(
                      'إلغاء',
                      style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
