import 'package:flutter/material.dart';

import '../../../../core/sound_service.dart';
import '../../../../core/theme/app_custom_theme.dart';

export 'admin_shared_components.dart';
export 'admin_ui_helpers.dart';

/// Shared scaffold shell providing royal custom theme gradient, SafeArea,
/// 360dp-safe responsive header, and consistent RTL layout for Admin screens.
class AdminScaffoldShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final Widget body;
  final List<Widget>? headerExtras;

  const AdminScaffoldShell({
    super.key,
    required this.title,
    this.subtitle,
    this.isLoading = false,
    this.onRefresh,
    required this.body,
    this.headerExtras,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: customTheme.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      _AdminHeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        tooltip: 'رجوع',
                        onTap: () {
                          SoundService().playClick();
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (headerExtras != null) ...headerExtras!,
                      if (onRefresh != null) ...[
                        const SizedBox(width: 8),
                        _AdminHeaderIconButton(
                          icon: Icons.refresh_rounded,
                          color: customTheme.sovereignAccent,
                          tooltip: 'تحديث',
                          onTap: isLoading
                              ? null
                              : () {
                                  SoundService().playClick();
                                  onRefresh!();
                                },
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _AdminHeaderIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

/// Sculpted section container for admin forms and listings.
class AdminSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;
  final Widget child;
  final Widget? trailing;

  const AdminSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = accentColor ?? customTheme.sovereignAccent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customTheme.surfaceCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.42), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Styled RTL text input field used across Admin forms.
class AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const AdminTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.suffixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppCustomTheme.of(context).sovereignAccent;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'Cairo',
        color: Colors.white,
        fontSize: 13.5,
        height: 1.4,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          color: accent.withValues(alpha: 0.9),
          fontSize: 12.5,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 12,
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.26),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.5,
          color: Color(0xFFFCA5A5),
        ),
      ),
    );
  }
}

/// Primary CTA button obeying AGENTS.md Rule 6 (`height >= 48dp` + `vertical: 8`).
class AdminPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AdminPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final bg = backgroundColor ?? customTheme.sovereignAccent;
    final fg = foregroundColor ?? customTheme.deepBackground;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Icon(icon, size: 20),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}
