import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';

class ResourceGlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const ResourceGlassCard({super.key, required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ??
              customTheme.sovereignAccent.withValues(alpha: 0.42),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}

class ResourceSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const ResourceSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: accent,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class ResourceStorageCard extends StatelessWidget {
  final AdminResourceHealth? health;

  const ResourceStorageCard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final pct = (health?.dbUsagePercent ?? 0).clamp(0.0, 100.0);
    final statusColor = pct >= 80
        ? Colors.redAccent
        : (pct >= 60 ? Colors.amberAccent : const Color(0xFF10B981));
    final usedMb = (health?.dbSizeMb ?? 0).toStringAsFixed(1);
    final limitMb = (health?.dbLimitMb ?? 500).toStringAsFixed(0);

    return ResourceGlassCard(
      borderColor: statusColor.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.storage_rounded, color: statusColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'سعة قاعدة البيانات (Free Plan)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: statusColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$usedMb MB مستخدم من أصل $limitMb MB المتاحة في الخطة المجانية',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ResourceActivityCard extends StatelessWidget {
  final AdminResourceHealth? health;

  const ResourceActivityCard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return ResourceGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ResourceSectionHeader(
            title: 'النشاط الحي في قاعدة البيانات',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  'تحديات الآن',
                  '${health?.activeMatchesNow ?? 0}',
                  const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  'نشطون (5د)',
                  '${health?.activePlayers5m ?? 0}',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniMetric(
                  'نشطون (24س)',
                  '${health?.activePlayers24h ?? 0}',
                  accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ملاحظة: عداد اتصالات WebSocket اللحظية (حد 200) وEgress يُتابعان من لوحة Supabase Studio مباشرة.',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class ResourceTablesCard extends StatelessWidget {
  final AdminResourceHealth? health;

  const ResourceTablesCard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    final tables = health?.tables ?? const [];
    return ResourceGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ResourceSectionHeader(
            title: 'أكبر الجداول استهلاكاً للمساحة',
            icon: Icons.table_chart_rounded,
          ),
          const SizedBox(height: 10),
          if (tables.isEmpty)
            const Text(
              'لا توجد بيانات جداول بعد.',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white60),
            )
          else
            for (final t in tables)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.tableName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${t.rowEstimate} صف',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${t.sizeMb.toStringAsFixed(2)} MB',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
