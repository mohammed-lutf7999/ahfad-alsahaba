import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_theme.dart';
import '../../../core/sound_service.dart';
import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/question_model.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/cms_cache_service.dart';
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
  int _selectedLevel = 1; // 0 = mixed across levels
  int _questionCount = 8;
  List<Question> _questions = [];
  String? _error;

  static const List<({String id, String name, int totalLevels})> _builtInCategories = [
    (id: AppConstants.quranCategory, name: 'القرآن الكريم', totalLevels: 10),
    (id: AppConstants.hadithCategory, name: 'الحديث الشريف', totalLevels: 10),
    (id: AppConstants.seerahCategory, name: 'السيرة النبوية', totalLevels: 10),
    (id: AppConstants.fiqhCategory, name: 'الفقه', totalLevels: 10),
    (id: AppConstants.historyCategory, name: 'التاريخ الإسلامي', totalLevels: 10),
    (id: AppConstants.aqeedahCategory, name: 'العقيدة', totalLevels: 10),
  ];

  List<({String id, String name, int totalLevels})> _availableCategories() {
    final map = <String, ({String id, String name, int totalLevels})>{
      for (final c in _builtInCategories) c.id: c,
    };
    final cmsCats = CmsCacheService.instance.snapshot.quizCategories.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final cat in cmsCats) {
      if (!cat.isVisible) {
        map.remove(cat.id);
        continue;
      }
      map[cat.id] = (
        id: cat.id,
        name: cat.name.trim().isEmpty ? cat.id : cat.name.trim(),
        totalLevels: cat.totalLevels.clamp(1, 50),
      );
    }
    return map.values.toList();
  }

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

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppTheme.primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'إنهاء البطولة والخروج؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          content: const Text(
            'ما تزال غرفة البطولة نشطة للمشاركين. هل تريد إنهاء البطولة للجميع قبل المغادرة؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'البقاء في الغرفة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white60),
              ),
            ),
            ElevatedButton(
              key: const Key('host_confirm_finish_exit_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'إنهاء البطولة للجميع والخروج',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldEnd == true) {
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
      ),
    );
  }

  Widget _buildSetupForm(AppCustomTheme customTheme, Color accent) {
    final categories = _availableCategories();
    final safeCategoryId = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : (categories.isNotEmpty ? categories.first.id : AppConstants.quranCategory);
    final selectedCat = categories.firstWhere(
      (c) => c.id == safeCategoryId,
      orElse: () => (id: safeCategoryId, name: safeCategoryId, totalLevels: 10),
    );
    final maxLevels = selectedCat.totalLevels.clamp(1, 50);
    final safeLevel = _selectedLevel > maxLevels ? 0 : _selectedLevel;

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
            key: const Key('host_category_dropdown'),
            value: safeCategoryId,
            isExpanded: true,
            dropdownColor: AppTheme.primaryDark,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'مجال الأسئلة (يشمل أقسام السحابة)',
              labelStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
            ),
            items: [
              for (final cat in categories)
                DropdownMenuItem(
                  value: cat.id,
                  child: Text(cat.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _categoryId = v;
                  _selectedLevel = 1;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  key: const Key('host_level_dropdown'),
                  value: safeLevel,
                  isExpanded: true,
                  dropdownColor: AppTheme.primaryDark,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المستوى',
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text(
                        'مختلط (كل المستويات)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (var lv = 1; lv <= maxLevels; lv++)
                      DropdownMenuItem(
                        value: lv,
                        child: Text(
                          'المستوى $lv',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedLevel = v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  key: const Key('host_count_dropdown'),
                  value: _questionCount,
                  isExpanded: true,
                  dropdownColor: AppTheme.primaryDark,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'عدد الأسئلة',
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 5,
                      child: Text('5 أسئلة', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 8,
                      child: Text('8 أسئلة', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 10,
                      child: Text('10 أسئلة', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _questionCount = v);
                  },
                ),
              ),
            ],
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        session.pinCode,
                        key: const Key('host_arena_pin_text'),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: accent,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'نسخ الرمز',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: session.pinCode));
                    },
                    icon: Icon(Icons.copy_rounded, color: accent),
                  ),
                  IconButton(
                    key: const Key('host_share_pin_btn'),
                    tooltip: 'مشاركة رمز البطولة',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      SoundService().playClick();
                      unawaited(
                        SharePlus.instance.share(
                          ShareParams(
                            text:
                                'انضم الآن إلى بطولة "${session.title}" في معركة أحفاد الصحابة ⚔️\nرمز الانضمام (PIN): ${session.pinCode}',
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.share_rounded, color: accent),
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
