import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Unified, `mounted`-safe royal SnackBar utility avoiding duplicated
/// `ScaffoldMessenger.of(context).showSnackBar(...)` boilerplate.
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          backgroundColor: backgroundColor ?? AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, backgroundColor: AppTheme.successColor);

  static void error(BuildContext context, String message) =>
      show(context, message, backgroundColor: AppTheme.errorColor);

  static void info(BuildContext context, String message) =>
      show(context, message, backgroundColor: AppTheme.primaryDark);
}
