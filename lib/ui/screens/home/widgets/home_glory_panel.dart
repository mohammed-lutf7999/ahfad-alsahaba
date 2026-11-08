import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/sound_service.dart';
import '../../../../data/models/player_profile_model.dart';
import '../../../../data/services/progression_service.dart';
import '../../../widgets/glory_progress_bar.dart';
import '../../glory/glory_road_screen.dart';
import '../../store/knights_store_screen.dart';

/// لوحة المجد وسوق الفرسان بالشاشة الرئيسية
/// تعرض الميدان التنافسي الحالي ورصيد الكؤوس وشريط خبرة المستويات وزري الوصول المباشر
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Arena & Trophies + Progress Bar clickable to Glory Road
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              SoundService().playClick();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GloryRoadScreen()),
              );
              onRefresh();
            },
            child: Column(
              children: [
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
                GloryProgressBar(
                  levelInfo: levelInfo,
                  height: 8,
                  showLabels: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Bottom Row: Direct Prominent Buttons for Glory Road & Knight's Store
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      SoundService().playClick();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GloryRoadScreen(),
                        ),
                      );
                      onRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.military_tech_rounded, size: 18),
                    label: const Text(
                      'طريق المجد 🏆',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      SoundService().playClick();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KnightsStoreScreen(),
                        ),
                      );
                      onRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.amberAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      side: BorderSide(
                        color: Colors.amber.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: Text(
                      'سوق الفرسان (${profile.coins} 🪙)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
