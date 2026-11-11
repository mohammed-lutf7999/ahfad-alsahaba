import 'package:flutter/material.dart';
import '../../../../core/sound_service.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/player_profile_model.dart';
import '../../../../data/services/progression_service.dart';
import '../../../widgets/glory_progress_bar.dart';
import '../../glory/glory_road_screen.dart';

/// لوحة الميدان والخبرة بالشاشة الرئيسية
/// تعرض الميدان التنافسي الحالي ورصيد الكؤوس وشريط خبرة المستويات بنقاء معماري
class HomeGloryPanel extends StatelessWidget {
  final PlayerProfile profile;
  final VoidCallback onRefresh;

  const HomeGloryPanel({
    super.key,
    required this.profile,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final levelInfo = profile.levelInfo;
    final arena = ProgressionService.instance.currentArena;
    final customTheme = AppCustomTheme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        SoundService().playClick();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GloryRoadScreen()),
        );
        onRefresh();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: customTheme.sovereignAccent.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Arena & Trophies
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        arena.icon,
                        color: arena.accentColor,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          arena.name,
                          style: TextStyle(
                            color: arena.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '🏆 ${profile.trophies} كأس',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Progress Bar (Glory & XP)
            GloryProgressBar(
              levelInfo: levelInfo,
              height: 7,
              showLabels: true,
            ),
          ],
        ),
      ),
    );
  }
}
