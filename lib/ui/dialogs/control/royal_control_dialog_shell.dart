import 'package:flutter/material.dart';

import '../../../core/theme/app_custom_theme.dart';

/// Shared Edge-to-Edge & 360dp-safe royal modal shell for App Control dialogs.
class RoyalControlDialogShell extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String badgeText;
  final String title;
  final String body;
  final String? statusNote;
  final List<Widget> actions;

  const RoyalControlDialogShell({
    super.key,
    required this.icon,
    required this.accent,
    required this.badgeText,
    required this.title,
    required this.body,
    this.statusNote,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return SafeArea(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: (constraints.maxHeight - 32).clamp(260.0, 680.0),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: customTheme.deepBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withValues(alpha: 0.18),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Icon(icon, color: accent, size: 30),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  badgeText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 13.5,
                                fontFamily: 'Cairo',
                                height: 1.65,
                              ),
                            ),
                            if (statusNote != null &&
                                statusNote!.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  statusNote!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            ...actions,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
