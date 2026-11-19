import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/live_session_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/services/live_tournament_service.dart';
import '../../../data/services/question_service.dart';

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
        _answeredIndex = null;
        _selectedOption = null;
      });
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
      if (mounted) {
        setState(() => _questions = loaded);
      }
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

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: session == null
                        ? _buildPinEntry(customTheme, accent)
                        : _buildSessionView(customTheme, accent, session),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry(AppCustomTheme customTheme, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'أدخل رمز البطولة المكون من 5 أرقام',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('student_arena_pin_input'),
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
            decoration: const InputDecoration(
              hintText: '12345',
              hintStyle: TextStyle(color: Colors.white24),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.amberAccent,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('student_join_arena_btn'),
              onPressed: _arena.isBusy ? null : _join,
              icon: const Icon(Icons.login_rounded),
              label: const Text(
                'انضمام فوري للبطولة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionView(
    AppCustomTheme customTheme,
    Color accent,
    LiveSessionModel session,
  ) {
    if (session.status == 'waiting') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: customTheme.surfaceCard.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Icon(Icons.hourglass_top_rounded, color: accent, size: 42),
            const SizedBox(height: 12),
            Text(
              session.title,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أنت جاهز! في انتظار ضغط المعلم على «ابدأ البطولة»...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white70,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      );
    }

    if (session.status == 'finished' ||
        session.currentQuestionIndex >= _questions.length) {
      final board = _arena.participants;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'انتهت البطولة — الترتيب النهائي 🏆',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: accent,
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < board.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: customTheme.surfaceCard.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Text(
                    '#${i + 1}',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      board[i].displayName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${board[i].score} ⭐',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final idx = session.currentQuestionIndex;
    final q = _questions[idx];
    final answered = _answeredIndex == idx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Text(
            'السؤال ${idx + 1}: ${q.questionText}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: answered ? null : () => _answer(idx, i, q),
                style: ElevatedButton.styleFrom(
                  backgroundColor: answered && _selectedOption == i
                      ? (i == q.correctAnswerIndex
                          ? const Color(0xFF10B981)
                          : Colors.redAccent)
                      : customTheme.surfaceCard,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  side: BorderSide(color: accent.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    q.options[i],
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
