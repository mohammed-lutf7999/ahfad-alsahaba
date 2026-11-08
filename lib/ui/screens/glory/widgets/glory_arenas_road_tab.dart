import 'package:flutter/material.dart';
import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/arena_model.dart';

/// تبويب ميادين المجد التنافسية الستة
/// يعرض الميدان الحالي، بطاقة درع الأمان عند 800 كأس، وقائمة الميادين الستة مع مضاعفاتها وشريط التقدم
class GloryArenasRoadTab extends StatelessWidget {
  final AppCustomTheme customTheme;
  final ArenaModel currentArena;
  final int trophies;
  final int winStreak;

  const GloryArenasRoadTab({
    super.key,
    required this.customTheme,
    required this.currentArena,
    required this.trophies,
    this.winStreak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final safeTrophies = ArenaModel.clampTrophies(trophies);

    return Column(
      children: [
        // 1. Competitive Arena & 800-Trophy Shield Banner
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: customTheme.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: currentArena.accentColor.withValues(alpha: 0.75),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          currentArena.accentColor,
                          currentArena.secondaryColor,
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFF3C644),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      currentArena.icon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentArena.name,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          currentArena.subtitle,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentArena.accentColor.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$safeTrophies 🏆',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFFF3C644),
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          'المضاعف ${currentArena.coinMultiplier}x',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: currentArena.accentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 800-Trophy Floor Protection Shield Notice
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.55),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF6EE7B7),
                      size: 17,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'درع الأمان التنافسي: محمي عند سقف 800 كأس (لا هبوط تحت ميدان يثرب)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Color(0xFF6EE7B7),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. List of All 6 Historic Competitive Arenas
        Expanded(
          child: ListView.builder(
            key: const Key('glory_road_arenas_list'),
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
            itemCount: ArenaModel.allArenas.length,
            itemBuilder: (context, index) {
              final arena = ArenaModel.allArenas[index];
              final isCurrent = arena.id == currentArena.id;
              final isUnlocked = safeTrophies >= arena.minTrophies;
              final rangeText = arena.maxTrophies != null
                  ? '${arena.minTrophies} - ${arena.maxTrophies} 🏆'
                  : '${arena.minTrophies}+ 🏆';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? customTheme.surfaceCard
                      : isUnlocked
                          ? customTheme.surfaceCard.withValues(alpha: 0.65)
                          : Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isCurrent
                        ? arena.accentColor
                        : isUnlocked
                            ? arena.accentColor.withValues(alpha: 0.45)
                            : Colors.white12,
                    width: isCurrent ? 2.0 : 1.0,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: arena.accentColor.withValues(alpha: 0.28),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isUnlocked
                                ? RadialGradient(
                                    colors: [
                                      arena.accentColor,
                                      arena.secondaryColor,
                                    ],
                                  )
                                : null,
                            color: isUnlocked ? null : Colors.white10,
                            border: Border.all(
                              color: isUnlocked
                                  ? const Color(0xFFF3C644)
                                  : Colors.white24,
                            ),
                          ),
                          child: Icon(
                            isUnlocked ? arena.icon : Icons.lock_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'الميدان ${arena.id}: ${arena.name}',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: arena.accentColor
                                            .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'ميدانك الحالي ⚔️',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: arena.accentColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${arena.subtitle} • $rangeText',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3C644).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF3C644).withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            '${arena.coinMultiplier}x 🪙',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Color(0xFFF3C644),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isCurrent && arena.nextArena != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: arena.progressInArena(safeTrophies),
                          minHeight: 8,
                          backgroundColor: Colors.black38,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            arena.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'باقي ${arena.trophiesToNextArena(safeTrophies)} كأساً للصعود إلى «${arena.nextArena!.name}» (${arena.nextArena!.coinMultiplier}x 🪙)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
