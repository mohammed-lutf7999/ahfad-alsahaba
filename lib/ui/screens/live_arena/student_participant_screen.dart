import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/live_session_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/live_tournament_service.dart';
import '../../../data/services/question_service.dart';
import 'widgets/arena_lobby_view.dart';
import 'widgets/arena_podium_view.dart';

/// شاشة مشاركة الطالب/المتسابق في البطولات الجماعية الحية عبر PIN.
class StudentParticipantScreen extends StatefulWidget {
  const StudentParticipantScreen({super.key});

  @override
  State<StudentParticipantScreen> createState() =>
      _StudentParticipantScreenState();
}

class _StudentParticipantScreenState extends State<StudentParticipantScreen> {
  final LiveTournamentService _arena = LiveTournamentService.instance;
  final TextEditingController _pinCtrl = TextEditingController();
  StreamSubscription<LiveArenaBroadcastEvent>? _sub;
  List<Question> _questions = [];
  List<LiveParticipantModel> _revealBoard = const [];
  bool _showMidRoundReveal = false;
  int? _answeredIndex;
  int? _selectedOption;
  String? _error;

  @override
  void initState() {
    super.initState();
    _arena.addListener(_onUpdated);
    _sub = _arena.eventsStream.listen(_onBroadcastEvent);
  }

  void _onUpdated() {
    if (mounted) setState(() {});
  }

  void _onBroadcastEvent(LiveArenaBroadcastEvent event) {
    if (!mounted) return;
    if (event.type == 'question') {
      setState(() {
        _showMidRoundReveal = false;
        _answeredIndex = null;
        _selectedOption = null;
      });
    } else if (event.type == 'reveal') {
      setState(() {
        _showMidRoundReveal = true;
        _revealBoard = event.leaderboard.isNotEmpty
            ? event.leaderboard
            : List<LiveParticipantModel>.from(_arena.participants);
      });
    } else if (event.type == 'finish') {
      setState(() => _showMidRoundReveal = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _arena.removeListener(_onUpdated);
    _pinCtrl.dispose();
    unawaited(_arena.leaveSession());
    super.dispose();
  }

  Future<void> _join() async {
    SoundService().playClick();
    setState(() => _error = null);
    try {
      final session = await _arena.joinByPin(_pinCtrl.text);
      final loaded = await QuestionService().loadQuestionsBySpecs(
        session.questionIds,
        seed: session.pinCode.hashCode,
        fallbackCategoryId: session.categoryId,
      );
      if (mounted) setState(() => _questions = loaded);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _answer(int qIdx, int optionIdx, Question q) async {
    if (_answeredIndex == qIdx) return;
    SoundService().playClick();
    final isCorrect = optionIdx == q.correctAnswerIndex;
    setState(() {
      _answeredIndex = qIdx;
      _selectedOption = optionIdx;
    });
    await _arena.submitAnswer(
      pointsDelta: isCorrect ? 100 : 0,
      isCorrect: isCorrect,
    );
  }

  Widget _buildSessionView(LiveSessionModel session) {
    if (session.status == 'waiting') {
      return ArenaWaitingLobbyCard(title: session.title);
    }
    if (session.status == 'finished' ||
        _questions.isEmpty ||
        session.currentQuestionIndex < 0 ||
        session.currentQuestionIndex >= _questions.length) {
      return ArenaPodiumView(
        isFinished: session.status == 'finished',
        board: _arena.participants,
      );
    }
    if (_showMidRoundReveal) {
      return ArenaMidRoundRevealCard(
        board: _revealBoard.isNotEmpty ? _revealBoard : _arena.participants,
        myUserId: _arena.currentUserId,
      );
    }
    final idx = session.currentQuestionIndex;
    final q = _questions[idx];
    return ArenaLiveQuestionView(
      questionIndex: idx,
      question: q,
      answered: _answeredIndex == idx,
      selectedOption: _selectedOption,
      onAnswerOption: (optIdx) => _answer(idx, optIdx, q),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final control = AppControlService.instance;
    final isAdmin = control.isAdminNotifier.value;
    final flags = control.featureFlagsNotifier.value;
    final perms = control.playerPermissionsNotifier.value;
    final arenaEnabled = (isAdmin || flags.guildsArenas) &&
        (isAdmin || !perms.isEffectivelyBannedNow);
    final session = _arena.activeSession;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: customTheme.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'ميدان البطولة الجماعية الحية ⚔️',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: accent,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!arenaEnabled && session == null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          !flags.guildsArenas
                              ? 'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً للصيانة.'
                              : 'تم حظر هذا الحساب من الإدارة ولا يمكنه دخول البطولات الحية.',
                          key: const Key('student_arena_blocked_msg'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white70,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: session == null
                          ? ArenaPinEntryCard(
                              pinController: _pinCtrl,
                              isBusy: _arena.isBusy,
                              error: _error,
                              onJoin: _join,
                            )
                          : _buildSessionView(session),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
