import 'package:flutter/material.dart';
import '../../../core/cms_icon_registry.dart';
import '../../../data/models/player_level_model.dart';
import '../../../data/models/store_item_model.dart';
import '../../../data/services/cms_cache_service.dart';

/// Visual specification for each of the 10 Royal Avatar Frames (`frame_wood` .. `frame_diamond`).
class RoyalFrameStyle {
  final String frameKey;
  final String name;
  final int tierIndex; // 1..10
  final Color primaryColor;
  final Color secondaryColor;
  final Color highlightColor;
  final bool hasOctagonalStar;
  final bool hasCornerGems;
  final bool hasCrownCrest;
  final double strokeRatio;

  const RoyalFrameStyle({
    required this.frameKey,
    required this.name,
    required this.tierIndex,
    required this.primaryColor,
    required this.secondaryColor,
    required this.highlightColor,
    this.hasOctagonalStar = false,
    this.hasCornerGems = false,
    this.hasCrownCrest = false,
    this.strokeRatio = 0.085,
  });

  static const Map<String, RoyalFrameStyle> styles = {
    'frame_wood': RoyalFrameStyle(
      frameKey: 'frame_wood',
      name: 'الإطار الخشبي العتيق',
      tierIndex: 1,
      primaryColor: Color(0xFF78350F),
      secondaryColor: Color(0xFFB45309),
      highlightColor: Color(0xFFFDE68A),
      strokeRatio: 0.075,
    ),
    'frame_copper': RoyalFrameStyle(
      frameKey: 'frame_copper',
      name: 'الإطار النحاسي المنقوش',
      tierIndex: 2,
      primaryColor: Color(0xFF9A3412),
      secondaryColor: Color(0xFFD97706),
      highlightColor: Color(0xFFFED7AA),
      hasCornerGems: true,
      strokeRatio: 0.08,
    ),
    'frame_bronze': RoyalFrameStyle(
      frameKey: 'frame_bronze',
      name: 'الإطار البرونزي المذهب',
      tierIndex: 3,
      primaryColor: Color(0xFF92400E),
      secondaryColor: Color(0xFFF59E0B),
      highlightColor: Color(0xFFFEF3C7),
      hasOctagonalStar: true,
      strokeRatio: 0.085,
    ),
    'frame_silver': RoyalFrameStyle(
      frameKey: 'frame_silver',
      name: 'الإطار الفضي الدمشقي',
      tierIndex: 4,
      primaryColor: Color(0xFF475569),
      secondaryColor: Color(0xFFCBD5E1),
      highlightColor: Color(0xFFFFFFFF),
      hasOctagonalStar: true,
      hasCornerGems: true,
      strokeRatio: 0.088,
    ),
    'frame_gold': RoyalFrameStyle(
      frameKey: 'frame_gold',
      name: 'الإطار الذهبي الموحد',
      tierIndex: 5,
      primaryColor: Color(0xFFB45309),
      secondaryColor: Color(0xFFF3C644),
      highlightColor: Color(0xFFFFFBEB),
      hasOctagonalStar: true,
      hasCornerGems: true,
      strokeRatio: 0.092,
    ),
    'frame_emerald': RoyalFrameStyle(
      frameKey: 'frame_emerald',
      name: 'الإطار الزمردي الملكي',
      tierIndex: 6,
      primaryColor: Color(0xFF065F46),
      secondaryColor: Color(0xFF10B981),
      highlightColor: Color(0xFFA7F3D0),
      hasOctagonalStar: true,
      hasCornerGems: true,
      strokeRatio: 0.095,
    ),
    'frame_ruby': RoyalFrameStyle(
      frameKey: 'frame_ruby',
      name: 'الإطار الياقوتي المشرق',
      tierIndex: 7,
      primaryColor: Color(0xFF9F1239),
      secondaryColor: Color(0xFFF43F5E),
      highlightColor: Color(0xFFFECDD3),
      hasOctagonalStar: true,
      hasCornerGems: true,
      hasCrownCrest: true,
      strokeRatio: 0.098,
    ),
    'frame_sapphire': RoyalFrameStyle(
      frameKey: 'frame_sapphire',
      name: 'الإطار اللازوردي السلطاني',
      tierIndex: 8,
      primaryColor: Color(0xFF1E40AF),
      secondaryColor: Color(0xFF38BDF8),
      highlightColor: Color(0xFFE0F2FE),
      hasOctagonalStar: true,
      hasCornerGems: true,
      hasCrownCrest: true,
      strokeRatio: 0.10,
    ),
    'frame_platinum': RoyalFrameStyle(
      frameKey: 'frame_platinum',
      name: 'الإطار البلاتيني المتوهج',
      tierIndex: 9,
      primaryColor: Color(0xFF5B21B6),
      secondaryColor: Color(0xFFC084FC),
      highlightColor: Color(0xFFFAF5FF),
      hasOctagonalStar: true,
      hasCornerGems: true,
      hasCrownCrest: true,
      strokeRatio: 0.105,
    ),
    'frame_diamond': RoyalFrameStyle(
      frameKey: 'frame_diamond',
      name: 'الإطار الماسي الأندلسي المشع',
      tierIndex: 10,
      primaryColor: Color(0xFF0284C7),
      secondaryColor: Color(0xFF38BDF8),
      highlightColor: Color(0xFFFFFFFF),
      hasOctagonalStar: true,
      hasCornerGems: true,
      hasCrownCrest: true,
      strokeRatio: 0.11,
    ),
  };

  factory RoyalFrameStyle.fromStoreItem(StoreItemModel item) {
    final meta = item.metadata;
    final secondary = CmsIconRegistry.tryParseColor(
          meta['secondaryColor'] ??
              meta['secondary_color'] ??
              meta['previewColor'],
        ) ??
        item.previewColor;
    final primary = CmsIconRegistry.tryParseColor(
          meta['primaryColor'] ?? meta['primary_color'],
        ) ??
        Color.lerp(secondary, Colors.black, 0.45) ??
        secondary;
    final highlight = CmsIconRegistry.tryParseColor(
          meta['highlightColor'] ??
              meta['glow_color'] ??
              meta['highlight_color'],
        ) ??
        Color.lerp(secondary, Colors.white, 0.65) ??
        Colors.white;
    final rawStroke =
        ((meta['strokeRatio'] ?? meta['stroke_ratio']) as num?)?.toDouble() ??
            0.095;
    final tierFromLevel = ((item.minLevel / 10).ceil()).clamp(2, 10);

    return RoyalFrameStyle(
      frameKey: item.assetKey.isNotEmpty ? item.assetKey : item.id,
      name: item.title,
      tierIndex:
          ((meta['tierIndex'] ?? meta['tier_index']) as num?)?.toInt() ??
              tierFromLevel,
      primaryColor: primary,
      secondaryColor: secondary,
      highlightColor: highlight,
      hasOctagonalStar: (meta['hasOctagonalStar'] ??
              meta['has_octagonal_star']) as bool? ??
          true,
      hasCornerGems: (meta['hasCornerGems'] ??
              meta['show_gems'] ??
              meta['has_corner_gems']) as bool? ??
          true,
      hasCrownCrest: (meta['hasCrownCrest'] ??
              meta['has_crown_crest']) as bool? ??
          (item.minLevel >= 60),
      strokeRatio: rawStroke.clamp(0.06, 0.14),
    );
  }

  static RoyalFrameStyle resolve({String? frameKey, int? level}) {
    if (frameKey != null && styles.containsKey(frameKey)) {
      return styles[frameKey]!;
    }
    if (frameKey != null && frameKey.isNotEmpty) {
      final cloudFrame = CmsCacheService.instance.findStoreItemByAssetKey(
        frameKey,
        category: StoreItemCategory.frame,
      );
      if (cloudFrame != null) {
        return RoyalFrameStyle.fromStoreItem(cloudFrame);
      }
    }
    if (level != null) {
      final tier = PlayerLevelInfo.resolveTier(level);
      if (styles.containsKey(tier.frameKey)) {
        return styles[tier.frameKey]!;
      }
    }
    return styles['frame_wood']!;
  }
}
