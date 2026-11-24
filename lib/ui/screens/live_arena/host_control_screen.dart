import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/question_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/cms_cache_service.dart';
import '../../../data/services/live_tournament_service.dart';
import '../../../data/services/question_service.dart';
import 'widgets/arena_host_console_view.dart';
import 'widgets/arena_host_setup_form.dart';

/// شاشة تحكم المشرف/المعلم لغرفة البطولة الجماعية الحية (حتى 100 مشارك).
class HostControlScreen extends StatefulWidget {
  const HostControlScreen({super.key});

  @override
  State<HostControlScreen> createState() => _HostControlScreenState();
}

class _HostControlScreenState extends State<HostControlScreen> {
  final LiveTournamentService _arena = LiveTournamentService.instance;
  final TextEditingController _titleCtrl = TextEditingController(
    text: 'بطولة الفرسان المعرفية',
  );
  String _categoryId = AppConstants.quranCategory;
  int _selectedLevel = 1; // 0 = mixed across levels
  int _questionCount = 8;
  List<Question> _questions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _arena.addListener(_onUpdated);
    CmsCacheService.instance.addListener(_onUpdated);
  }

  void _onUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _arena.removeListener(_onUpdated);
    CmsCacheService.instance.removeListener(_onUpdated);
    _titleCtrl.dispose();
    unawaited(_arena.leaveSession());
    super.dispose();
  }

  Future<void> _createSession() async {
    SoundService().playClick();
    setState(() => _error = null);
    try {
      final qSpecs = await QuestionService().buildLiveArenaQuestionSpecs(
        categoryId: _categoryId,
        levelNumber: _selectedLevel == 0 ? null : _selectedLevel,
        count: _questionCount,
      );
      if (qSpecs.isEmpty) {
        throw Exception('لا توجد أسئلة متاحة في هذا القسم والمستوى حالياً');
      }
      final sessionRaw = await _arena.createSession(
        title: _titleCtrl.text,
        categoryId: _categoryId,
        questionIds: qSpecs,
      );
      final pinSeed = (sessionRaw?['pin_code'] ?? '').hashCode;
      _questions = await QuestionService().loadQuestionsBySpecs(
        qSpecs,
        seed: pinSeed,
        fallbackCategoryId: _categoryId,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _confirmExitActiveSession() async {
    final session = _arena.activeSession;
    if (session == null ||
        (session.status != 'waiting' && session.status != 'active')) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final shouldEnd = await showConfirmExitArenaDialog(context);
    if (shouldEnd) {
      await _arena.hostPushState(
        status: 'finished',
        questionIndex: _questions.length,
      );
      await _arena.leaveSession();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _advanceQuestion(int nextIdx) async {
    SoundService().playClick();
    if (_questions.isNotEmpty && nextIdx >= _questions.length) {
      await _arena.hostPushState(status: 'finished', questionIndex: nextIdx);
    } else {
      await _arena.hostPushState(status: 'active', questionIndex: nextIdx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final control = AppControlService.instance;
    final flags = control.featureFlagsNotifier.value;
    final perms = control.playerPermissionsNotifier.value;
    final canHost = control.canHostLiveArena();
    final session = _arena.activeSession;
    final participants = _arena.participants;

    final blockedMessage = !flags.guildsArenas
        ? 'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً للصيانة من الإدارة.'
        : (perms.isEffectivelyBannedNow
            ? 'تم حظر هذا الحساب مؤقتاً أو دائماً من الإدارة.'
            : (perms.canHostLiveArenas == false
                ? 'تم منعك فردياً من إنشاء البطولات الحية من الإدارة 🔒'
                : 'إنشاء البطولات الحية محصور حالياً بالمعلمين والمشرفين المعتمدين 🎓'));

    final hasLiveSession = session != null &&
        (session.status == 'waiting' || session.status == 'active');

    return PopScope(
      canPop: !hasLiveSession,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && hasLiveSession) {
          unawaited(_confirmExitActiveSession());
        }
      },
      child: Directionality(
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
                          onPressed: () {
                            if (hasLiveSession) {
                              unawaited(_confirmExitActiveSession());
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'غرفة إدارة المعلم/المشرف 🎓',
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
                  if (!canHost && session == null)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_person_rounded,
                                color: accent,
                                size: 46,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                blockedMessage,
                                key: const Key('host_arena_blocked_msg'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white70,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        child: session == null
                            ? ArenaHostSetupForm(
                                titleController: _titleCtrl,
                                categoryId: _categoryId,
                                selectedLevel: _selectedLevel,
                                questionCount: _questionCount,
                                isBusy: _arena.isBusy,
                                error: _error,
                                onCategoryChanged: (v) => setState(() {
                                  _categoryId = v;
                                  _selectedLevel = 1;
                                }),
                                onLevelChanged: (v) =>
                                    setState(() => _selectedLevel = v),
                                onQuestionCountChanged: (v) =>
                                    setState(() => _questionCount = v),
                                onCreateSession: _createSession,
                              )
                            : ArenaHostConsoleView(
                                session: session,
                                questions: _questions,
                                participants: participants,
                                onAdvanceQuestion: _advanceQuestion,
                                onRevealLeaderboard: (idx) =>
                                    _arena.hostRevealLeaderboard(idx),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
