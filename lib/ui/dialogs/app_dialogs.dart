import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';

/// نوافذ الحوار والتأكيد المركزية للتطبيق
class AppDialogs {
  /// نافذة تأكيد الخروج أو الانسحاب الموحدة بالهوية الملكية الأندلسية
  /// تُستخدم في: QuizScreen, OnlineGameScreen, VersusScreen
  static Future<bool?> showExitConfirmationDialog(
    BuildContext context, {
    String title = 'هل تود الانسحاب؟',
    String message = 'خروجك الآن يعني فقدان تقدمك في هذه الجولة. هل أنت متأكد من قرارك؟',
    String confirmLabel = 'تأكيد الخروج',
    String cancelLabel = 'تراجع ومتابعة',
    IconData icon = Icons.shield_outlined,
    VoidCallback? onConfirm,
  }) {
    final customTheme = AppCustomTheme.of(context);

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ExitDialog',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim.value),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.86,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              decoration: BoxDecoration(
                color: customTheme.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: customTheme.sovereignAccent.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: customTheme.sovereignAccent.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Royal Chivalric Emblem Badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: customTheme.sovereignAccent.withValues(alpha: 0.12),
                      border: Border.all(
                        color: customTheme.sovereignAccent.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: customTheme.sovereignAccent.withValues(alpha: 0.2),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 36,
                        color: customTheme.sovereignAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Message
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: customTheme.textMuted,
                      height: 1.55,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons (Balanced Hierarchy & Zero Cairo Clipping)
                  Row(
                    children: [
                      // Subdued Exit Button (Secondary)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              SoundService().playClick();
                              Navigator.of(context).pop(true);
                              if (onConfirm != null) {
                                onConfirm();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              side: BorderSide(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              confirmLabel,
                              style: const TextStyle(
                                color: Color(0xFFFDA4AF),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Cairo',
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Heroic Golden Continue Button (Primary Action)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              SoundService().playClick();
                              Navigator.of(context).pop(false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: customTheme.sovereignAccent,
                              foregroundColor: AppTheme.primaryDark,
                              elevation: 5,
                              shadowColor: customTheme.sovereignAccent.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              cancelLabel,
                              style: const TextStyle(
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                fontFamily: 'Cairo',
                                height: 1.2,
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
            ),
          ),
        );
      },
    );
  }
}
