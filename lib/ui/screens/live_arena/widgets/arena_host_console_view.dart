import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/live_session_model.dart';
import '../../../../data/models/question_model.dart';

Future<bool> showConfirmExitArenaDialog(BuildContext context) async {
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
  return shouldEnd == true;
}

class ArenaHostConsoleView extends StatelessWidget {
  final LiveSessionModel session;
  final List<Question> questions;
  final List<LiveParticipantModel> participants;
  final ValueChanged<int> onAdvanceQuestion;
  final ValueChanged<int> onRevealLeaderboard;

  const ArenaHostConsoleView({
    super.key,
    required this.session,
    required this.questions,
    required this.participants,
    required this.onAdvanceQuestion,
    required this.onRevealLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final idx = session.currentQuestionIndex;
    final currentQ = idx < questions.length ? questions[idx] : null;
    final status = session.status;

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
              onPressed: () => onAdvanceQuestion(0),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    onPressed: () => onRevealLeaderboard(idx),
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
                    onPressed: () => onAdvanceQuestion(idx + 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      idx + 1 >= questions.length
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
