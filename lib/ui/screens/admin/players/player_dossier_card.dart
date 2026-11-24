import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../widgets/admin_ui_kit.dart';

class PlayerDossierCard extends StatelessWidget {
  final AdminPlayerDetail detail;

  const PlayerDossierCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final email =
        (detail.directory?['email'] ?? detail.leaderboard?['email'])?.toString();
    final appVer = detail.directory?['app_version']?.toString();
    final verCode = detail.directory?['version_code']?.toString();

    return AdminSectionCard(
      title: 'ملف اللاعب: ${detail.displayName}',
      icon: Icons.badge_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((detail.playerCode != null && detail.playerCode!.isNotEmpty) ||
              (email != null && email.isNotEmpty) ||
              appVer != null) ...[
            Text(
              [
                if (detail.playerCode != null && detail.playerCode!.isNotEmpty)
                  'الكود: ${detail.playerCode}',
                if (email != null && email.isNotEmpty) email,
                if (appVer != null)
                  'النسخة: $appVer${verCode != null ? " (b$verCode)" : ""}',
              ].join(' • '),
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white70,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStatChip(label: 'المستوى', value: 'م${detail.playerLevel}'),
              _MiniStatChip(label: 'الكؤوس', value: '🏆 ${detail.trophies}'),
              _MiniStatChip(label: 'النقاط XP', value: '${detail.totalScore}'),
              _MiniStatChip(label: 'الدنانير', value: '🪙 ${detail.coins}'),
              _MiniStatChip(label: 'الياقوت', value: '💎 ${detail.gems}'),
              _MiniStatChip(label: 'السلسلة', value: '🔥 ${detail.winStreak}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'المقتنيات (${detail.inventory.length}):',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: customTheme.sovereignAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (detail.inventory.isEmpty)
            const Text(
              'لا توجد عناصر متجر مملوكة.',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white60),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in detail.inventory)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.title}${item.isVisible ? "" : " (مخفي)"}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
              ],
            ),
          if (detail.recentMatches.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'آخر النزالات (${detail.recentMatches.length}):',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: customTheme.sovereignAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final m in detail.recentMatches.take(5))
              Text(
                '• ${m.isGhostMatch ? "👻" : "⚔️"} ${m.myScore} نقطة (${m.status})',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white70,
                  fontSize: 11.5,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white60,
              fontSize: 10.5,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
