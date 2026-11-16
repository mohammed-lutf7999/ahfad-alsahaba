import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/app_control_models.dart';
import '../../data/services/app_control_service.dart';
import '../screens/dynamic_event_detail_screen.dart';

/// Compact, zero-cost HomeScreen dynamic event banner.
///
/// Renders `SizedBox.shrink()` (`0px`) whenever no active event is live right now
/// or when `feature_flags.show_event_banner == false`, preserving normal home layout.
class HomeDynamicEventBanner extends StatelessWidget {
  final AppDynamicEvent? eventOverride;
  final AppFeatureFlags? flagsOverride;

  const HomeDynamicEventBanner({
    super.key,
    this.eventOverride,
    this.flagsOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (eventOverride != null || flagsOverride != null) {
      final event = eventOverride ?? AppControlService.instance.activeEventNotifier.value;
      final flags = flagsOverride ?? AppControlService.instance.featureFlagsNotifier.value;
      return _buildBannerIfActive(context, event, flags);
    }

    final service = AppControlService.instance;
    return ValueListenableBuilder<AppFeatureFlags>(
      valueListenable: service.featureFlagsNotifier,
      builder: (context, flags, _) {
        return ValueListenableBuilder<AppDynamicEvent?>(
          valueListenable: service.activeEventNotifier,
          builder: (context, event, _) {
            return _buildBannerIfActive(context, event, flags);
          },
        );
      },
    );
  }

  Widget _buildBannerIfActive(
    BuildContext context,
    AppDynamicEvent? event,
    AppFeatureFlags flags,
  ) {
    if (!flags.showEventBanner || event == null) {
      return const SizedBox.shrink();
    }
    if (!event.isCurrentlyActiveAt(DateTime.now().toUtc())) {
      return const SizedBox.shrink();
    }

    final customTheme = AppCustomTheme.of(context);
    final accent = AppControlVisuals.parseHexColor(
      event.themeColorHex,
      customTheme.sovereignAccent,
    );
    final iconData = AppControlVisuals.iconForName(event.iconName);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => unawaited(
            AppControlVisuals.executeEventAction(context, event),
          ),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.24),
                  Colors.black.withValues(alpha: 0.36),
                ],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.52), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Icon(iconData, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.badgeText.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.badgeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              height: 1.2,
                            ),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          height: 1.25,
                        ),
                      ),
                      if (event.subtitle.trim().isNotEmpty)
                        Text(
                          event.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11,
                            fontFamily: 'Cairo',
                            height: 1.25,
                          ),
                        ),
                    ],
                  ),
                ),
                if (event.actionType != DynamicEventActionType.none) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 104,
                      minHeight: 40,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: AppTheme.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => unawaited(
                        AppControlVisuals.executeEventAction(context, event),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          event.ctaLabel,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

