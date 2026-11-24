import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';
import '../../../../data/models/app_control_models.dart';
import '../../dynamic_event_detail_screen.dart';

class AdminEventListItem extends StatelessWidget {
  final AppDynamicEvent event;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AdminEventListItem({
    super.key,
    required this.event,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ev = event;
    final accent = AppControlVisuals.parseHexColor(
      ev.themeColorHex,
      AppCustomTheme.of(context).sovereignAccent,
    );
    final isLive = ev.isCurrentlyActiveAt(DateTime.now().toUtc());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: ev.isActive ? 0.52 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppControlVisuals.iconForName(ev.iconName), color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${isLive ? 'مباشر الآن 🟢' : (ev.isActive ? 'مجدول ⏳' : 'متوقف ⏸️')} • أولوية ${ev.priority}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: Key('toggle_event_${ev.id}'),
                value: ev.isActive,
                activeColor: accent,
                onChanged: onToggleActive,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: Key('edit_event_${ev.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text(
                  'تعديل',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                key: Key('delete_event_${ev.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text(
                  'حذف',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> showConfirmDeleteEventDialog(
  BuildContext context,
  AppDynamicEvent ev,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppCustomTheme.of(ctx).surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'حذف الحدث نهائياً؟',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم حذف «${ev.title}» من قاعدة البيانات.',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'حذف',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return confirmed == true;
}
