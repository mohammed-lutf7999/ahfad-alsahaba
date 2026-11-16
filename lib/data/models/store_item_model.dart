import 'package:flutter/material.dart';
import '../../core/cms_icon_registry.dart';

/// Categories of items available in «سوق الفرسان» (Knight's Store).
enum StoreItemCategory {
  theme,
  frame,
  title,
  powerup,
}

/// Represents a purchasable or unlockable item in «سوق الفرسان».
class StoreItemModel {
  final String id;
  final String title;
  final String description;
  final StoreItemCategory category;
  final int priceCoins;
  final int priceGems;
  final int minLevel;
  final String assetKey;
  final Color previewColor;
  final IconData icon;
  final bool isDefaultFree;
  final bool isVisible;
  final int sortOrder;
  final Map<String, dynamic> metadata;
  final int cmsRevision;

  const StoreItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.priceCoins = 0,
    this.priceGems = 0,
    this.minLevel = 1,
    required this.assetKey,
    required this.previewColor,
    required this.icon,
    this.isDefaultFree = false,
    this.isVisible = true,
    this.sortOrder = 100,
    this.metadata = const {},
    this.cmsRevision = 1,
  });

  /// Master catalog of items in «سوق الفرسان» (4 Themes, 10 Frames, Titles, Powerups).
  static const List<StoreItemModel> defaultCatalog = [
    // =========================================================================
    // 1. Themes (خزانة الثيمات الملكية الأربعة)
    // =========================================================================
    StoreItemModel(
      id: 'theme_andalusian_gold',
      title: 'ثيم الدرع الأندلسي',
      description: 'فخامة القصور والذهب الإمبراطوري الأصيل',
      category: StoreItemCategory.theme,
      priceCoins: 0,
      minLevel: 1,
      assetKey: 'andalusian_gold',
      previewColor: Color(0xFFF3C644),
      icon: Icons.palette_rounded,
      isDefaultFree: true,
    ),
    StoreItemModel(
      id: 'theme_emerald_banner',
      title: 'ثيم راية الفتح الزمردي',
      description: 'سكينة الواحات وعزة الرايات الإسلامية الخضراء',
      category: StoreItemCategory.theme,
      priceCoins: 2500,
      minLevel: 5,
      assetKey: 'emerald_banner',
      previewColor: Color(0xFF52B788),
      icon: Icons.park_rounded,
    ),
    StoreItemModel(
      id: 'theme_badr_meteors',
      title: 'ثيم شهب ليلة بدر',
      description: 'وقار الليل الملوكي وبريق السيوف الفضية',
      category: StoreItemCategory.theme,
      priceCoins: 3000,
      minLevel: 10,
      assetKey: 'badr_meteors',
      previewColor: Color(0xFF38BDF8),
      icon: Icons.nights_stay_rounded,
    ),
    StoreItemModel(
      id: 'theme_yarmouk_carnelian',
      title: 'ثيم عقيق اليرموك',
      description: 'حماسة النزال المباشر وعزم الأبطال في الميادين',
      category: StoreItemCategory.theme,
      priceCoins: 3500,
      minLevel: 15,
      assetKey: 'yarmouk_carnelian',
      previewColor: Color(0xFFF43F5E),
      icon: Icons.local_fire_department_rounded,
    ),

    // =========================================================================
    // 2. Avatar Frames (الأطر الملكية العشرة)
    // =========================================================================
    StoreItemModel(
      id: 'item_frame_wood',
      title: 'الإطار الخشبي العتيق',
      description: 'إطار البدايات لطالب العلم المجد',
      category: StoreItemCategory.frame,
      priceCoins: 0,
      minLevel: 1,
      assetKey: 'frame_wood',
      previewColor: Color(0xFFA16207),
      icon: Icons.crop_square_rounded,
      isDefaultFree: true,
    ),
    StoreItemModel(
      id: 'item_frame_copper',
      title: 'الإطار النحاسي المنقوش',
      description: 'نقوش أندلسية نحاسية لرواة الأثر',
      category: StoreItemCategory.frame,
      priceCoins: 500,
      minLevel: 10,
      assetKey: 'frame_copper',
      previewColor: Color(0xFFD97706),
      icon: Icons.filter_frames_rounded,
    ),
    StoreItemModel(
      id: 'item_frame_bronze',
      title: 'الإطار البرونزي المذهب',
      description: 'درع برونزي متين لمحدثي الميدان',
      category: StoreItemCategory.frame,
      priceCoins: 900,
      minLevel: 20,
      assetKey: 'frame_bronze',
      previewColor: Color(0xFFB45309),
      icon: Icons.shield_moon_outlined,
    ),
    StoreItemModel(
      id: 'item_frame_silver',
      title: 'الإطار الفضي الدمشقي',
      description: 'بريق الفضة المشغولة لفرسان المعرفة',
      category: StoreItemCategory.frame,
      priceCoins: 1500,
      minLevel: 30,
      assetKey: 'frame_silver',
      previewColor: Color(0xFFE2E8F0),
      icon: Icons.shield_outlined,
    ),
    StoreItemModel(
      id: 'item_frame_gold',
      title: 'الإطار الذهبي الموحد',
      description: 'هالة ذهبية متوهجة تليق بقادة الكتائب',
      category: StoreItemCategory.frame,
      priceCoins: 2500,
      minLevel: 40,
      assetKey: 'frame_gold',
      previewColor: Color(0xFFF3C644),
      icon: Icons.hdr_strong_rounded,
    ),
    StoreItemModel(
      id: 'item_frame_emerald',
      title: 'الإطار الزمردي الملكي',
      description: 'نبض زمردي فاخر لحكماء السيرة النبوية',
      category: StoreItemCategory.frame,
      priceCoins: 3500,
      minLevel: 50,
      assetKey: 'frame_emerald',
      previewColor: Color(0xFF10B981),
      icon: Icons.hexagon_outlined,
    ),
    StoreItemModel(
      id: 'item_frame_ruby',
      title: 'الإطار الياقوتي المشرق',
      description: 'وهج الياقوت الأحمر لوزراء الديوان',
      category: StoreItemCategory.frame,
      priceCoins: 4500,
      minLevel: 60,
      assetKey: 'frame_ruby',
      previewColor: Color(0xFFE11D48),
      icon: Icons.flare_rounded,
    ),
    StoreItemModel(
      id: 'item_frame_sapphire',
      title: 'الإطار اللازوردي السلطاني',
      description: 'فخامة اللازورد الأزرق لأمراء الفتح',
      category: StoreItemCategory.frame,
      priceCoins: 6000,
      minLevel: 70,
      assetKey: 'frame_sapphire',
      previewColor: Color(0xFF2563EB),
      icon: Icons.auto_awesome_motion_rounded,
    ),
    StoreItemModel(
      id: 'item_frame_platinum',
      title: 'الإطار البلاتيني المتوهج',
      description: 'شعاع بلاتيني مهيب لأسود الملاحم',
      category: StoreItemCategory.frame,
      priceCoins: 7500,
      priceGems: 25,
      minLevel: 80,
      assetKey: 'frame_platinum',
      previewColor: Color(0xFF8B5CF6),
      icon: Icons.stars_rounded,
    ),
    StoreItemModel(
      id: 'item_frame_diamond',
      title: 'الإطار الماسي الأندلسي المشع',
      description: 'شيدر ضوئي مشع خاص بنخبة الأحفاد',
      category: StoreItemCategory.frame,
      priceCoins: 10000,
      priceGems: 50,
      minLevel: 90,
      assetKey: 'frame_diamond',
      previewColor: Color(0xFF38BDF8),
      icon: Icons.diamond_rounded,
    ),

    // =========================================================================
    // 3. Honor Titles (أوسمة وألقاب الفرسان)
    // =========================================================================
    StoreItemModel(
      id: 'title_saqr_quraish',
      title: 'لقب «صقر الأندلس»',
      description: 'وسام شرفي يظهر تحت اسمك في غرف التحدي',
      category: StoreItemCategory.title,
      priceCoins: 1500,
      minLevel: 10,
      assetKey: 'صقر الأندلس',
      previewColor: Color(0xFFF59E0B),
      icon: Icons.workspace_premium_rounded,
    ),
    StoreItemModel(
      id: 'title_dira_qadisiyah',
      title: 'لقب «درع القادسية»',
      description: 'وسام الصمود والانتصار في الميادين الكبرى',
      category: StoreItemCategory.title,
      priceCoins: 2200,
      minLevel: 20,
      assetKey: 'درع القادسية',
      previewColor: Color(0xFF10B981),
      icon: Icons.security_rounded,
    ),
    StoreItemModel(
      id: 'title_hakiim_zaman',
      title: 'لقب «علامة الزمان»',
      description: 'وسام التفوق الموسوعي في علوم السيرة والتاريخ',
      category: StoreItemCategory.title,
      priceCoins: 4500,
      minLevel: 40,
      assetKey: 'علامة الزمان',
      previewColor: Color(0xFF38BDF8),
      icon: Icons.auto_awesome_rounded,
    ),

    // =========================================================================
    // 4. Smart Power-ups (وسائل المساعدة الذكية)
    // =========================================================================
    StoreItemModel(
      id: 'powerup_shield',
      title: 'درع الحماية التنافسي',
      description: 'يحمي سلسلة انتصاراتك وكؤوسك من النقصان لمرة واحدة',
      category: StoreItemCategory.powerup,
      priceCoins: 500,
      minLevel: 1,
      assetKey: 'powerup_shield',
      previewColor: Color(0xFF38BDF8),
      icon: Icons.health_and_safety_rounded,
    ),
    StoreItemModel(
      id: 'powerup_insight',
      title: 'بصيرة القائد',
      description: 'تحذف خيارين خاطئين في المراحل الفردية الصعبة',
      category: StoreItemCategory.powerup,
      priceCoins: 300,
      minLevel: 1,
      assetKey: 'powerup_insight',
      previewColor: Color(0xFFF3C644),
      icon: Icons.lightbulb_rounded,
    ),
    StoreItemModel(
      id: 'powerup_xp_banner',
      title: 'راية المضاعفة',
      description: 'تضاعف نقاط الخبرة المكتسبة في الجولة القادمة',
      category: StoreItemCategory.powerup,
      priceCoins: 600,
      minLevel: 5,
      assetKey: 'powerup_xp_banner',
      previewColor: Color(0xFFA855F7),
      icon: Icons.bolt_rounded,
    ),
  ];

  static IconData defaultIconForCategory(StoreItemCategory category) {
    switch (category) {
      case StoreItemCategory.theme:
        return Icons.palette_rounded;
      case StoreItemCategory.frame:
        return Icons.filter_frames_rounded;
      case StoreItemCategory.title:
        return Icons.workspace_premium_rounded;
      case StoreItemCategory.powerup:
        return Icons.bolt_rounded;
    }
  }

  static Map<String, dynamic> _parseMeta(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  factory StoreItemModel.fromJson(Map<String, dynamic> json) =>
      StoreItemModel.fromCloudJson(json);

  factory StoreItemModel.fromCloudJson(
    Map<String, dynamic> json, {
    StoreItemModel? fallback,
  }) {
    final catStr = json['category']?.toString() ?? fallback?.category.name ?? 'theme';
    final category = StoreItemCategory.values.firstWhere(
      (c) => c.name == catStr,
      orElse: () => fallback?.category ?? StoreItemCategory.theme,
    );
    final meta = _parseMeta(json['metadata']);
    final resolvedColor = CmsIconRegistry.tryParseColor(meta['previewColor']) ??
        CmsIconRegistry.tryParseColor(meta['sovereignAccent']) ??
        CmsIconRegistry.tryParseColor(meta['secondaryColor']) ??
        fallback?.previewColor ??
        const Color(0xFFF3C644);
    final resolvedIcon = CmsIconRegistry.resolveIcon(
      meta['iconName']?.toString(),
      fallback: fallback?.icon ?? defaultIconForCategory(category),
    );
    final coins = (json['price_coins'] as num?)?.toInt() ?? fallback?.priceCoins ?? 0;
    final gems = (json['price_gems'] as num?)?.toInt() ?? fallback?.priceGems ?? 0;

    return StoreItemModel(
      id: (json['id'] ?? fallback?.id ?? '').toString(),
      title: (json['title'] ?? fallback?.title ?? '').toString(),
      description: (json['description'] ?? fallback?.description ?? '').toString(),
      category: category,
      priceCoins: coins,
      priceGems: gems,
      minLevel: (json['min_level'] as num?)?.toInt() ?? fallback?.minLevel ?? 1,
      assetKey: (json['asset_key'] ?? fallback?.assetKey ?? '').toString(),
      previewColor: resolvedColor,
      icon: resolvedIcon,
      isDefaultFree: fallback?.isDefaultFree ?? (coins == 0 && gems == 0),
      isVisible: (json['is_visible'] as bool?) ?? fallback?.isVisible ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? fallback?.sortOrder ?? 100,
      metadata: meta.isNotEmpty ? meta : (fallback?.metadata ?? const {}),
      cmsRevision:
          (json['cms_revision'] as num?)?.toInt() ?? fallback?.cmsRevision ?? 1,
    );
  }

  StoreItemModel withFallback(StoreItemModel? fallback) {
    if (fallback == null) return this;
    final hasMeta = metadata.isNotEmpty;
    return StoreItemModel(
      id: id,
      title: title.isNotEmpty ? title : fallback.title,
      description: description.isNotEmpty ? description : fallback.description,
      category: category,
      priceCoins: priceCoins,
      priceGems: priceGems,
      minLevel: minLevel,
      assetKey: assetKey.isNotEmpty ? assetKey : fallback.assetKey,
      previewColor:
          hasMeta ? previewColor : fallback.previewColor,
      icon: metaIconOr(fallback.icon),
      isDefaultFree: fallback.isDefaultFree,
      isVisible: isVisible,
      sortOrder: sortOrder,
      metadata: hasMeta ? metadata : fallback.metadata,
      cmsRevision: cmsRevision,
    );
  }

  IconData metaIconOr(IconData fallbackIcon) {
    final rawName = metadata['iconName']?.toString();
    if (rawName != null && rawName.trim().isNotEmpty) {
      return CmsIconRegistry.resolveIcon(rawName, fallback: fallbackIcon);
    }
    return fallbackIcon;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'price_coins': priceCoins,
      'price_gems': priceGems,
      'min_level': minLevel,
      'asset_key': assetKey,
      'is_visible': isVisible,
      'sort_order': sortOrder,
      'metadata': metadata,
      'cms_revision': cmsRevision,
    };
  }

  Map<String, dynamic> toCloudJson() => toJson();
}
