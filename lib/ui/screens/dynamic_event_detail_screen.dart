import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../core/sound_service.dart';
import '../../core/theme/app_custom_theme.dart';
import '../../data/models/app_control_models.dart';
import '../../data/services/app_control_service.dart';
import '../screens/chat/global_chat_bottom_sheet.dart';
import '../widgets/top_notification.dart';

/// Shared visual and navigation helpers for Dynamic Events & Admin Announcements.
class AppControlVisuals {
  AppControlVisuals._();

  static const Set<String> _safeNamedRoutes = {
    AppRoutes.home,
    AppRoutes.categories,
    AppRoutes.settings,
    AppRoutes.profileSelector,
    AppRoutes.achievements,
    AppRoutes.challenge,
    AppRoutes.privateRoomHub,
    AppRoutes.gloryRoad,
    AppRoutes.knightsStore,
    AppRoutes.royalInbox,
    AppRoutes.guilds,
    AppRoutes.liveArena,
    AppRoutes.library,
    AppRoutes.profileSetup,
  };

  /// Parses `#D4AF37` or `0xFFD4AF37` strings cleanly with fallback accent color.
  static Color parseHexColor(String? rawHex, Color fallback) {
    if (rawHex == null) return fallback;
    var cleaned = rawHex.trim().replaceFirst('#', '');
    if (cleaned.startsWith('0x') || cleaned.startsWith('0X')) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    if (cleaned.length != 8) return fallback;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  /// Resolves an icon string configured from Admin Dashboard / Web into a Material icon.
  static IconData iconForName(String? rawName) {
    switch (rawName?.trim().toLowerCase()) {
      case 'stars':
      case 'star':
        return Icons.stars_rounded;
      case 'celebration':
      case 'party':
        return Icons.celebration_rounded;
      case 'military_tech':
      case 'medal':
        return Icons.military_tech_rounded;
      case 'emoji_events':
      case 'trophy':
        return Icons.emoji_events_rounded;
      case 'campaign':
      case 'announcement':
        return Icons.campaign_rounded;
      case 'bolt':
      case 'flash':
        return Icons.bolt_rounded;
      case 'castle':
        return Icons.castle_rounded;
      case 'menu_book':
      case 'book':
        return Icons.menu_book_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'mosque':
        return Icons.mosque_rounded;
      case 'auto_awesome':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  /// Executes either an internal route (`/knights-store`, `/challenge`, etc.)
  /// or an external `http(s)://` link safely without throwing on bad input.
  static Future<void> handleRouteOrUrl(
    BuildContext context,
    String? rawTarget,
  ) async {
    final target = rawTarget?.trim() ?? '';
    if (target.isEmpty) return;

    final lower = target.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(target);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('AppControlVisuals URL launch failed: $e');
        }
      }
      return;
    }

    if (!context.mounted) return;
    final flags = AppControlService.instance.featureFlagsNotifier.value;
    final normalizedRoute = target.startsWith('/') ? target : '/$target';

    if (normalizedRoute == '/diwan') {
      if (!flags.diwanChat) {
        TopNotification.showWarning(
          context,
          'ديوان الأحفاد متوقف مؤقتاً للصيانة والتحديث 🛡️',
        );
        return;
      }
      await GlobalChatBottomSheet.show(context);
      return;
    }

    if ((normalizedRoute == AppRoutes.guilds ||
            normalizedRoute == AppRoutes.liveArena) &&
        !flags.guildsArenas) {
      TopNotification.showWarning(
        context,
        'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً للصيانة 🛡️',
      );
      return;
    }

    if (normalizedRoute == AppRoutes.knightsStore && !flags.knightsStore) {
      TopNotification.showWarning(
        context,
        'سوق الفرسان متوقف مؤقتاً للتحديث والجرد',
      );
      return;
    }
    if (normalizedRoute == AppRoutes.privateRoomHub && !flags.privateRooms) {
      TopNotification.showWarning(
        context,
        'غرف التحدي الخاصة متوقفة مؤقتاً للصيانة',
      );
      return;
    }

    if (_safeNamedRoutes.contains(normalizedRoute)) {
      await Navigator.of(context).pushNamed(normalizedRoute);
      return;
    }

    // Safe fallback if route requires missing arguments (e.g. /levels without id)
    if (normalizedRoute == AppRoutes.levels || normalizedRoute == AppRoutes.quiz) {
      await Navigator.of(context).pushNamed(AppRoutes.categories);
    }
  }

  /// Executes a [AppDynamicEvent] CTA action cleanly.
  static Future<void> executeEventAction(
    BuildContext context,
    AppDynamicEvent event, {
    bool alreadyOnDetailScreen = false,
  }) async {
    SoundService().playClick();
    switch (event.actionType) {
      case DynamicEventActionType.openEventScreen:
        if (alreadyOnDetailScreen) {
          if (event.actionTarget.trim().isNotEmpty) {
            await handleRouteOrUrl(context, event.actionTarget);
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        } else if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DynamicEventDetailScreen(event: event),
            ),
          );
        }
        return;
      case DynamicEventActionType.navigateRoute:
      case DynamicEventActionType.openUrl:
        if (event.actionTarget.trim().isNotEmpty) {
          await handleRouteOrUrl(context, event.actionTarget);
        } else if (!alreadyOnDetailScreen && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DynamicEventDetailScreen(event: event),
            ),
          );
        }
        return;
      case DynamicEventActionType.none:
        return;
    }
  }
}

/// Full-screen cloud-controlled Dynamic Event view launched from [HomeDynamicEventBanner]
/// or via route [AppRoutes.dynamicEvent].
class DynamicEventDetailScreen extends StatelessWidget {
  final AppDynamicEvent event;

  const DynamicEventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final customTheme = AppCustomTheme.of(context);
    final accent = AppControlVisuals.parseHexColor(
      event.themeColorHex,
      customTheme.sovereignAccent,
    );
    final iconData = AppControlVisuals.iconForName(event.iconName);
    final hasFollowupAction =
        event.actionType != DynamicEventActionType.none &&
            (event.actionType != DynamicEventActionType.openEventScreen ||
                event.actionTarget.trim().isNotEmpty);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: customTheme.backgroundGradient),
        child: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          SoundService().playClick();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: accent,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              event.badgeText,
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accent.withValues(alpha: 0.35),
                                  accent.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.65),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(iconData, color: accent, size: 42),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          event.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            height: 1.35,
                          ),
                        ),
                        if (event.subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            event.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Text(
                            event.body.trim().isNotEmpty
                                ? event.body
                                : event.subtitle.trim().isNotEmpty
                                    ? event.subtitle
                                    : 'فعالية خاصة مفعلة من إدارة معركة أحفاد الصحابة.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 14.5,
                              fontFamily: 'Cairo',
                              height: 1.75,
                            ),
                          ),
                        ),
                        if (event.endsAt != null) ...[
                          const SizedBox(height: 14),
                          _EventExpiryChip(
                            endsAtUtc: event.endsAt!.toUtc(),
                            accent: accent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom Action
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (hasFollowupAction) {
                          unawaited(
                            AppControlVisuals.executeEventAction(
                              context,
                              event,
                              alreadyOnDetailScreen: true,
                            ),
                          );
                        } else {
                          SoundService().playClick();
                          Navigator.of(context).pop();
                        }
                      },
                      icon: Icon(
                        hasFollowupAction
                            ? Icons.rocket_launch_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 20,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          hasFollowupAction ? event.ctaLabel : 'حسناً',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventExpiryChip extends StatelessWidget {
  final DateTime endsAtUtc;
  final Color accent;

  const _EventExpiryChip({required this.endsAtUtc, required this.accent});

  @override
  Widget build(BuildContext context) {
    final nowUtc = DateTime.now().toUtc();
    final diff = endsAtUtc.difference(nowUtc);
    final String label;
    if (diff.isNegative) {
      label = 'انتهت مدة الفعالية';
    } else if (diff.inDays >= 1) {
      label = 'متبقي ${diff.inDays} يوم';
    } else if (diff.inHours >= 1) {
      label = 'متبقي ${diff.inHours} ساعة';
    } else {
      label = 'ينتهي خلال ${diff.inMinutes.clamp(1, 59)} دقيقة';
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, color: accent, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

