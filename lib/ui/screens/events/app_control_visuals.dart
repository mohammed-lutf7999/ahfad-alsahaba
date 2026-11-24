import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_routes.dart';
import '../../../core/sound_service.dart';
import '../../../data/models/app_control_models.dart';
import '../../../data/services/app_control_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/top_notification.dart';
import '../chat/global_chat_bottom_sheet.dart';
import '../dynamic_event_detail_screen.dart';

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
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
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
    final perms = AppControlService.instance.playerPermissionsNotifier.value;
    final isAdmin = AppControlService.instance.isAdminNotifier.value;
    final isLoggedIn = AuthService().isLoggedIn;
    final normalizedRoute = target.startsWith('/') ? target : '/$target';

    if (normalizedRoute == AppRoutes.royalInbox &&
        !isAdmin &&
        !flags.royalInbox) {
      TopNotification.showWarning(
        context,
        'صندوق البريد الملكي متوقف مؤقتاً للصيانة 🛡️',
      );
      return;
    }

    if (normalizedRoute == '/diwan') {
      final diwanRestricted = isLoggedIn && !perms.canUseDiwan;
      if (!isAdmin && (!flags.diwanChat || diwanRestricted)) {
        TopNotification.showWarning(
          context,
          !flags.diwanChat
              ? 'ديوان الأحفاد متوقف مؤقتاً للصيانة والتحديث 🛡️'
              : 'تم تقييد المشاركة في ديوان الأحفاد من الإدارة 🔒',
        );
        return;
      }
      await GlobalChatBottomSheet.show(context);
      return;
    }

    if ((normalizedRoute == AppRoutes.guilds ||
            normalizedRoute == AppRoutes.liveArena) &&
        !isAdmin &&
        (!flags.guildsArenas ||
            (normalizedRoute == AppRoutes.guilds &&
                isLoggedIn &&
                !perms.canUseGuilds))) {
      TopNotification.showWarning(
        context,
        !flags.guildsArenas
            ? 'نظام الكتائب والبطولات الجماعية متوقف مؤقتاً للصيانة 🛡️'
            : 'تم تقييد استخدام نظام الكتائب من الإدارة 🔒',
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

    if (normalizedRoute == AppRoutes.levels ||
        normalizedRoute == AppRoutes.quiz) {
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
