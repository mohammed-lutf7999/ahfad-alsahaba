import 'package:flutter/material.dart';

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
  });

  /// Master catalog of items in «سوق الفرسان».
  static const List<StoreItemModel> defaultCatalog = [
    // 1. Themes (خزانة الثيمات الملكية)
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

    // 2. Avatar Frames (الأطر الملكية المتوهجة)
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
      id: 'item_frame_silver',
      title: 'الإطار الفضي الدمشقي',
      description: 'بريق الفضة المشغولة لفرسان المعرفة',
      category: StoreItemCategory.frame,
      priceCoins: 1200,
      minLevel: 10,
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
      minLevel: 20,
      assetKey: 'frame_gold',
      previewColor: Color(0xFFF3C644),
      icon: Icons.hdr_strong_rounded,
    ),
    StoreItemModel(
      id: 'item_frame_emerald',
      title: 'الإطار الزمردي الملكي',
      description: 'نبض زمردي فاخر لحكماء السيرة النبوية',
      category: StoreItemCategory.frame,
      priceCoins: 4000,
      minLevel: 30,
      assetKey: 'frame_emerald',
      previewColor: Color(0xFF10B981),
      icon: Icons.hexagon_outlined,
    ),
    StoreItemModel(
      id: 'item_frame_diamond',
      title: 'الإطار الماسي الأندلسي',
      description: 'شيدر ضوئي مشع خاص بنخبة الأحفاد',
      category: StoreItemCategory.frame,
      priceCoins: 8000,
      priceGems: 50,
      minLevel: 50,
      assetKey: 'frame_diamond',
      previewColor: Color(0xFF38BDF8),
      icon: Icons.diamond_rounded,
    ),

    // 3. Honor Titles (أوسمة وألقاب الفرسان)
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

    // 4. Smart Power-ups (وسائل المساعدة الذكية)
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

  factory StoreItemModel.fromJson(Map<String, dynamic> json) {
    final catStr = json['category'] as String? ?? 'theme';
    final category = StoreItemCategory.values.firstWhere(
      (c) => c.name == catStr,
      orElse: () => StoreItemCategory.theme,
    );

    return StoreItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: category,
      priceCoins: (json['price_coins'] as num?)?.toInt() ?? 0,
      priceGems: (json['price_gems'] as num?)?.toInt() ?? 0,
      minLevel: (json['min_level'] as num?)?.toInt() ?? 1,
      assetKey: json['asset_key'] as String? ?? '',
      previewColor: const Color(0xFFF3C644),
      icon: Icons.stars_rounded,
      isDefaultFree: ((json['price_coins'] as num?)?.toInt() ?? 0) == 0 &&
          ((json['price_gems'] as num?)?.toInt() ?? 0) == 0,
    );
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
    };
  }
}
