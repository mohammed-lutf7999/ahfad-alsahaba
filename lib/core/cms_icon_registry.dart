import 'package:flutter/material.dart';

/// Shared icon and hex-color registry for CMS-driven Store items, Library
/// sections, Quiz categories, and Dynamic Events.
class CmsIconRegistry {
  CmsIconRegistry._();

  static const Map<String, IconData> _icons = {
    // Store & Themes
    'palette_rounded': Icons.palette_rounded,
    'park_rounded': Icons.park_rounded,
    'nights_stay_rounded': Icons.nights_stay_rounded,
    'local_fire_department_rounded': Icons.local_fire_department_rounded,
    'crop_square_rounded': Icons.crop_square_rounded,
    'filter_frames_rounded': Icons.filter_frames_rounded,
    'shield_moon_outlined': Icons.shield_moon_outlined,
    'shield_outlined': Icons.shield_outlined,
    'hdr_strong_rounded': Icons.hdr_strong_rounded,
    'hexagon_outlined': Icons.hexagon_outlined,
    'flare_rounded': Icons.flare_rounded,
    'auto_awesome_motion_rounded': Icons.auto_awesome_motion_rounded,
    'stars_rounded': Icons.stars_rounded,
    'diamond_rounded': Icons.diamond_rounded,
    'workspace_premium_rounded': Icons.workspace_premium_rounded,
    'security_rounded': Icons.security_rounded,
    'auto_awesome_rounded': Icons.auto_awesome_rounded,
    'auto_awesome': Icons.auto_awesome,
    'health_and_safety_rounded': Icons.health_and_safety_rounded,
    'lightbulb_rounded': Icons.lightbulb_rounded,
    'bolt_rounded': Icons.bolt_rounded,
    'bolt': Icons.bolt,
    'military_tech_rounded': Icons.military_tech_rounded,
    'military_tech': Icons.military_tech,
    'emoji_events_rounded': Icons.emoji_events_rounded,
    'emoji_events': Icons.emoji_events,
    // Library & Categories
    'auto_stories_rounded': Icons.auto_stories_rounded,
    'book': Icons.auto_stories_rounded,
    'volunteer_activism_rounded': Icons.volunteer_activism_rounded,
    'format_quote_rounded': Icons.format_quote_rounded,
    'emoji_emotions_rounded': Icons.emoji_emotions_rounded,
    'menu_book_rounded': Icons.menu_book_rounded,
    'menu_book': Icons.menu_book_rounded,
    'balance_rounded': Icons.balance_rounded,
    'mosque_rounded': Icons.mosque_rounded,
    'mosque': Icons.mosque_rounded,
    'account_balance_rounded': Icons.account_balance_rounded,
    'history_edu_rounded': Icons.history_edu_rounded,
    'castle_rounded': Icons.castle_rounded,
    'castle': Icons.castle_rounded,
    'quiz_rounded': Icons.quiz_rounded,
    'quiz': Icons.quiz_rounded,
    'shield_rounded': Icons.shield_rounded,
    'shield': Icons.shield_rounded,
    'celebration_rounded': Icons.celebration_rounded,
    'celebration': Icons.celebration_rounded,
    'campaign_rounded': Icons.campaign_rounded,
    'campaign': Icons.campaign_rounded,
    'stars': Icons.stars_rounded,
  };

  /// Resolves an [IconData] from an icon key name with [fallback].
  static IconData resolveIcon(
    String? iconName, {
    IconData fallback = Icons.auto_awesome_rounded,
  }) {
    if (iconName == null) return fallback;
    final key = iconName.trim();
    if (key.isEmpty) return fallback;
    return _icons[key] ?? _icons['${key}_rounded'] ?? fallback;
  }

  /// Parses `#RRGGBB` / `#AARRGGBB` hex strings safely with a [fallback] color.
  static Color parseHexColor(
    String? hex, {
    Color fallback = const Color(0xFFD4AF37),
  }) {
    if (hex == null) return fallback;
    final cleaned = hex.trim().replaceFirst('#', '').toUpperCase();
    if (cleaned.length == 6) {
      final parsed = int.tryParse('FF$cleaned', radix: 16);
      if (parsed != null) return Color(parsed);
    } else if (cleaned.length == 8) {
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }

  /// Parses numeric color values (int or `#RRGGBB` string) from metadata maps.
  static Color? tryParseColor(dynamic raw) {
    if (raw is int) return Color(raw);
    if (raw is String) {
      final parsed = parseHexColor(raw, fallback: const Color(0x00000000));
      if (parsed.toARGB32() != 0) return parsed;
    }
    return null;
  }
}

/// Lightweight indirection avoiding circular imports between `PlayerProfile`
/// and `CmsCacheService` when resolving per-category dynamic max levels.
class CmsCategoryBounds {
  CmsCategoryBounds._();

  static int Function(String categoryId)? totalLevelsResolver;

  /// Resolves dynamic max levels for [categoryId], defaulting safely to 10.
  static int maxLevelsFor(String categoryId, {int defaultMax = 10}) {
    final resolver = totalLevelsResolver;
    if (resolver == null) return defaultMax;
    final resolved = resolver(categoryId);
    return resolved > 0 ? resolved.clamp(1, 100) : defaultMax;
  }
}
