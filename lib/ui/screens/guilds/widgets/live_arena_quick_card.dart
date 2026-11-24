import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/services/app_control_service.dart';
import '../../live_arena/host_control_screen.dart';
import '../../live_arena/student_participant_screen.dart';

class LiveArenaQuickCard extends StatelessWidget {
  final ValueChanged<String> onHostDenied;

  const LiveArenaQuickCard({super.key, required this.onHostDenied});

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = customTheme.sovereignAccent;
    final control = AppControlService.instance;
    final canHost = control.canHostLiveArena();
    final hostDeniedReason =
        control.playerPermissionsNotifier.value.canHostLiveArenas == false
            ? 'تم منعك فردياً من إنشاء البطولات الحية من الإدارة 🔒'
            : 'إنشاء البطولات الحية محصور حالياً بالمعلمين والمشرفين المعتمدين 🎓';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.cast_for_education_rounded, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'غرف البطولات الجماعية الحية (حتى 100 متسابق) 🎓',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (!canHost) ...[
            const SizedBox(height: 6),
            Text(
              hostDeniedReason,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.amberAccent,
                fontSize: 11.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    key: const Key('arena_host_entry_btn'),
                    onPressed: () {
                      SoundService().playClick();
                      if (!canHost) {
                        onHostDenied(hostDeniedReason);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HostControlScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canHost
                          ? const Color(0xFF38BDF8)
                          : Colors.blueGrey.shade700,
                      foregroundColor:
                          canHost ? AppTheme.primaryDark : Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        canHost ? 'إنشاء بطولة (معلم)' : 'للمعلمين فقط 🔒',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    key: const Key('arena_student_entry_btn'),
                    onPressed: () {
                      SoundService().playClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentParticipantScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      side: BorderSide(color: accent.withValues(alpha: 0.65)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'دخول برمز PIN',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
