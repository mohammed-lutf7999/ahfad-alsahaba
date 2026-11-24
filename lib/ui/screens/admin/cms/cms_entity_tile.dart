import 'package:flutter/material.dart';

import '../../../../core/theme/app_custom_theme.dart';

/// Opens a managed modal bottom sheet whose [TextEditingController] instances
/// are disposed only AFTER the sheet exit animation unmounts.
Future<bool?> showManagedCmsEditor({
  required BuildContext context,
  required Map<String, String> initialTexts,
  required Widget Function(
    BuildContext sheetCtx,
    Map<String, TextEditingController> ctrls,
  ) builder,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppCustomTheme.of(context).deepBackground,
    builder: (_) => ManagedEditorSheet(
      initialTexts: initialTexts,
      builder: builder,
    ),
  );
}

/// Owns modal [TextEditingController] instances so they are only disposed AFTER
/// the bottom-sheet exit transition unmounts from the widget tree.
class ManagedEditorSheet extends StatefulWidget {
  final Map<String, String> initialTexts;
  final Widget Function(
    BuildContext context,
    Map<String, TextEditingController> ctrls,
  ) builder;

  const ManagedEditorSheet({
    super.key,
    required this.initialTexts,
    required this.builder,
  });

  @override
  State<ManagedEditorSheet> createState() => _ManagedEditorSheetState();
}

class _ManagedEditorSheetState extends State<ManagedEditorSheet> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final entry in widget.initialTexts.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: widget.builder(context, _ctrls),
        ),
      ),
    );
  }
}

/// Reusable list tile for CMS items (store items, library sections/items, quiz categories/questions).
class CmsEntityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final bool isVisible;
  final ValueChanged<bool> onToggleVisibility;
  final VoidCallback onEdit;

  const CmsEntityTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.isVisible,
    required this.onToggleVisibility,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final statusColor =
        isVisible ? const Color(0xFF10B981) : const Color(0xFFFB7185);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isVisible ? customTheme.sovereignAccent : statusColor)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'تعديل',
            icon: Icon(
              Icons.edit_rounded,
              color: customTheme.sovereignAccent,
              size: 19,
            ),
          ),
          Switch(
            value: isVisible,
            onChanged: onToggleVisibility,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}
