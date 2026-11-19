import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/question_model.dart';
import '../../../data/services/live_tournament_service.dart';
import '../../../data/services/question_service.dart';

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
  List<Question> _questions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _arena.addListener(_onUpdated);
  }

  void _onUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _arena.removeListener(_onUpdated);
    _titleCtrl.dispose();
    unawaited(_arena.leaveSession());
    super.dispose();
  }

  Future<void> _createSession() async {
    SoundService().playClick();
    setState(() => _error = null);
    try {
      final levelQuestions = await QuestionService().loadQuestions(
        categoryId: _categoryId,
        levelNumber: 1,
      );
      final slots = List<int>.generate(levelQuestions.length, (i) => i)
        ..shuffle();
      final qSpecs = slots.take(8).map((slot) => '$_categoryId:1:$slot').toList();
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
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
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
    final session = _arena.activeSession;
    final participants = _arena.participants;

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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    child: session == null
                        ? _buildSetupForm(customTheme, accent)
                        : _buildLiveConsole(
                            customTheme,
                            accent,
                            session,
                            participants,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupForm(AppCustomTheme customTheme, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'أنشئ بطولة حية لفصلك أو مسجدك (حتى 100 مشارك برمز PIN فوري)',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('host_arena_title_input'),
            controller: _titleCtrl,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'عنوان البطولة',
              labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoryId,
            dropdownColor: AppTheme.primaryDark,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'مجال الأسئلة',
              labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
            ),
            items: const [
              DropdownMenuItem(value: AppConstants.quranCategory, child: Text('القرآن الكريم')),
              DropdownMenuItem(value: AppConstants.hadithCategory, child: Text('الحديث الشريف')),
              DropdownMenuItem(value: AppConstants.seerahCategory, child: Text('السيرة النبوية')),
              DropdownMenuItem(value: AppConstants.fiqhCategory, child: Text('الفقه')),
              DropdownMenuItem(value: AppConstants.historyCategory, child: Text('التاريخ الإسلامي')),
              DropdownMenuItem(value: AppConstants.aqeedahCategory, child: Text('العقيدة')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _categoryId = v);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.amberAccent,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('host_create_arena_btn'),
              onPressed: _arena.isBusy ? null : _createSession,
              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: const Text(
                'إطلاق غرفة البطولة وإصدار PIN',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
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

  Widget _buildLiveConsole(
    AppCustomTheme customTheme,
    Color accent,
    dynamic session,
    List<dynamic> participants,
  ) {
    final idx = session.currentQuestionIndex as int;
    final currentQ =
        idx < _questions.length ? _questions[idx] : null;
    final status = session.status as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent, width: 1.4),
          ),
          child: Column(
            children: [
              Text(
                'رمز الانضمام المباشر (PIN)',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    session.pinCode,
                    key: const Key('host_arena_pin_text'),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: accent,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: session.pinCode));
                    },
                    icon: Icon(Icons.copy_rounded, color: accent),
                  ),
                ],
              ),
              Text(
                'المتصلون الآن: ${participants.length} / 100  •  الحالة: $status',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF10B981),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (currentQ != null && status == 'active')
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: customTheme.surfaceCard.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'السؤال ${idx + 1}: ${currentQ.questionText}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (status == 'waiting')
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('host_start_arena_btn'),
              onPressed: () => _advanceQuestion(0),
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text(
                'ابدأ البطولة الآن (طرح السؤال الأول)',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          )
        else if (status == 'active')
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => _arena.hostRevealLeaderboard(idx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      side: BorderSide(color: accent),
                    ),
                    child: Text(
                      'كشف الترتيب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    key: const Key('host_next_question_btn'),
                    onPressed: () => _advanceQuestion(idx + 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      idx + 1 >= _questions.length
                          ? 'إنهاء وإعلان الفائزين'
                          : 'السؤال التالي ⏭️',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Text(
          'لوحة المتصدرين الحية 🏆',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: accent,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (participants.isEmpty)
          const Text(
            'في انتظار انضمام المتسابقين بالرمز...',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white60),
          )
        else
          for (var i = 0; i < participants.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: customTheme.surfaceCard.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
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
                      participants[i].displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${participants[i].score} نقطة',
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
}
