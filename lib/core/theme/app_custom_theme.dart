import 'package:flutter/material.dart';
import '../cms_icon_registry.dart';
import '../../data/models/store_item_model.dart';
import '../../data/services/cms_cache_service.dart';

/// Custom ThemeExtension implementing the 4 Legendary Historical Themes
/// plus dynamic cloud-configured themes from «سوق الفرسان».
class AppCustomTheme extends ThemeExtension<AppCustomTheme> {
  final String themeId;
  final String themeName;
  final String themeSubtitle;
  final Color deepBackground;
  final Color surfaceCard;
  final Color sovereignAccent;
  final Color secondaryAccent;
  final Color textLight;
  final Color textMuted;
  final bool isFreeDefault;
  final int priceCoins;

  const AppCustomTheme({
    required this.themeId,
    required this.themeName,
    required this.themeSubtitle,
    required this.deepBackground,
    required this.surfaceCard,
    required this.sovereignAccent,
    required this.secondaryAccent,
    this.textLight = const Color(0xFFFFFFFF),
    this.textMuted = const Color(0xFFCBD5E1),
    this.isFreeDefault = false,
    this.priceCoins = 0,
  });

  /// 1. الدرع الأندلسي (Free Default Master Theme)
  static const AppCustomTheme andalusianGold = AppCustomTheme(
    themeId: 'andalusian_gold',
    themeName: 'الدرع الأندلسي',
    themeSubtitle: 'فخامة القصور والذهب الإمبراطوري',
    deepBackground: Color(0xFF0D061A),
    surfaceCard: Color(0xFF24143D),
    sovereignAccent: Color(0xFFF3C644),
    secondaryAccent: Color(0xFFD4AF37),
    isFreeDefault: true,
    priceCoins: 0,
  );

  /// 2. راية الفتح الزمردي (Knight's Store Theme)
  static const AppCustomTheme emeraldBanner = AppCustomTheme(
    themeId: 'emerald_banner',
    themeName: 'راية الفتح الزمردي',
    themeSubtitle: 'سكينة الواحات وعزة الفتوحات',
    deepBackground: Color(0xFF05140E),
    surfaceCard: Color(0xFF14382A),
    sovereignAccent: Color(0xFFE9B872),
    secondaryAccent: Color(0xFF52B788),
    isFreeDefault: false,
    priceCoins: 2500,
  );

  /// 3. شهب ليلة بدر (Knight's Store Theme)
  static const AppCustomTheme badrMeteors = AppCustomTheme(
    themeId: 'badr_meteors',
    themeName: 'شهب ليلة بدر',
    themeSubtitle: 'وقار الليل وبريق السيوف الفضية',
    deepBackground: Color(0xFF060B19),
    surfaceCard: Color(0xFF12234D),
    sovereignAccent: Color(0xFF38BDF8),
    secondaryAccent: Color(0xFF93C5FD),
    isFreeDefault: false,
    priceCoins: 3000,
  );

  /// 4. عقيق اليرموك (Knight's Store Theme)
  static const AppCustomTheme yarmoukCarnelian = AppCustomTheme(
    themeId: 'yarmouk_carnelian',
    themeName: 'عقيق اليرموك',
    themeSubtitle: 'حماسة النزال المباشر وعزم الأبطال',
    deepBackground: Color(0xFF120409),
    surfaceCard: Color(0xFF340E1E),
    sovereignAccent: Color(0xFFF59E0B),
    secondaryAccent: Color(0xFFF43F5E),
    isFreeDefault: false,
    priceCoins: 3500,
  );

  /// All 4 Legendary Themes.
  static const List<AppCustomTheme> allThemes = [
    andalusianGold,
    emeraldBanner,
    badrMeteors,
    yarmoukCarnelian,
  ];

  /// Builds a dynamic [AppCustomTheme] from a cloud-configured Store item.
  factory AppCustomTheme.fromStoreItem(StoreItemModel item) {
    final meta = item.metadata;
    final accent = CmsIconRegistry.tryParseColor(meta['sovereignAccent']) ??
        item.previewColor;
    final secondary = CmsIconRegistry.tryParseColor(meta['secondaryAccent']) ??
        accent;
    final deepBg = CmsIconRegistry.tryParseColor(meta['deepBackground']) ??
        andalusianGold.deepBackground;
    final surface = CmsIconRegistry.tryParseColor(meta['surfaceCard']) ??
        andalusianGold.surfaceCard;
    final textLightColor =
        CmsIconRegistry.tryParseColor(meta['textLight']) ?? Colors.white;
    final textMutedColor = CmsIconRegistry.tryParseColor(meta['textMuted']) ??
        const Color(0xFFCBD5E1);

    return AppCustomTheme(
      themeId: item.assetKey.isNotEmpty ? item.assetKey : item.id,
      themeName: item.title,
      themeSubtitle: item.description,
      deepBackground: deepBg,
      surfaceCard: surface,
      sovereignAccent: accent,
      secondaryAccent: secondary,
      textLight: textLightColor,
      textMuted: textMutedColor,
      isFreeDefault: item.isDefaultFree,
      priceCoins: item.priceCoins,
    );
  }

  /// Resolves a theme by its [id] (built-in first, then dynamic CMS store items),
  /// defaulting to [andalusianGold].
  static AppCustomTheme fromId(String? id) {
    if (id == null || id.isEmpty) return andalusianGold;
    for (final t in allThemes) {
      if (t.themeId == id) return t;
    }
    final cloudItem = CmsCacheService.instance.findStoreItemByAssetKey(
      id,
      category: StoreItemCategory.theme,
    );
    if (cloudItem != null) {
      return AppCustomTheme.fromStoreItem(cloudItem);
    }
    return andalusianGold;
  }

  /// Convenient lookup from [BuildContext].
  static AppCustomTheme of(BuildContext context) {
    return Theme.of(context).extension<AppCustomTheme>() ?? andalusianGold;
  }

  /// Dynamic background gradient for full-screen scaffolds.
  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          deepBackground,
          surfaceCard,
          deepBackground,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  /// Dynamic sovereign accent gradient for buttons, badges, and highlights.
  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          secondaryAccent,
          sovereignAccent,
          secondaryAccent,
        ],
      );

  /// Sculpted glassmorphic card decoration (85% opacity, 1.5px glowing border).
  BoxDecoration get sculptedGlassCardDecoration => BoxDecoration(
        color: surfaceCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: sovereignAccent.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: sovereignAccent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      );

  @override
  AppCustomTheme copyWith({
    String? themeId,
    String? themeName,
    String? themeSubtitle,
    Color? deepBackground,
    Color? surfaceCard,
    Color? sovereignAccent,
    Color? secondaryAccent,
    Color? textLight,
    Color? textMuted,
    bool? isFreeDefault,
    int? priceCoins,
  }) {
    return AppCustomTheme(
      themeId: themeId ?? this.themeId,
      themeName: themeName ?? this.themeName,
      themeSubtitle: themeSubtitle ?? this.themeSubtitle,
      deepBackground: deepBackground ?? this.deepBackground,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      sovereignAccent: sovereignAccent ?? this.sovereignAccent,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      textLight: textLight ?? this.textLight,
      textMuted: textMuted ?? this.textMuted,
      isFreeDefault: isFreeDefault ?? this.isFreeDefault,
      priceCoins: priceCoins ?? this.priceCoins,
    );
  }

  @override
  AppCustomTheme lerp(ThemeExtension<AppCustomTheme>? other, double t) {
    if (other is! AppCustomTheme) return this;
    return AppCustomTheme(
      themeId: t < 0.5 ? themeId : other.themeId,
      themeName: t < 0.5 ? themeName : other.themeName,
      themeSubtitle: t < 0.5 ? themeSubtitle : other.themeSubtitle,
      deepBackground: Color.lerp(deepBackground, other.deepBackground, t) ?? deepBackground,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t) ?? surfaceCard,
      sovereignAccent: Color.lerp(sovereignAccent, other.sovereignAccent, t) ?? sovereignAccent,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t) ?? secondaryAccent,
      textLight: Color.lerp(textLight, other.textLight, t) ?? textLight,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      isFreeDefault: t < 0.5 ? isFreeDefault : other.isFreeDefault,
      priceCoins: t < 0.5 ? priceCoins : other.priceCoins,
    );
  }
}

