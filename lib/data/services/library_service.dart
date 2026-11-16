import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/cms_icon_registry.dart';
import '../models/cms_models.dart';
import '../models/library_model.dart';
import 'cms_cache_service.dart';

/// Loads built-in offline Library content and merges dynamic cloud section/article
/// additions, edits, and visibility toggles cached in [CmsCacheService].
class LibraryService {
  static const Map<String, ({String title, IconData icon, int sortOrder})>
      _defaultSections = {
    'stories': (
      title: 'قصص وعبر',
      icon: Icons.auto_stories_rounded,
      sortOrder: 10,
    ),
    'azkar': (
      title: 'الأذكار',
      icon: Icons.nights_stay_rounded,
      sortOrder: 20,
    ),
    'duas': (
      title: 'أدعية مستجابة',
      icon: Icons.volunteer_activism_rounded,
      sortOrder: 30,
    ),
    'hadith': (
      title: 'الحديث الشريف',
      icon: Icons.format_quote_rounded,
      sortOrder: 40,
    ),
    'wisdom': (
      title: 'حكم وأقوال',
      icon: Icons.lightbulb_rounded,
      sortOrder: 50,
    ),
    'jokes': (
      title: 'طرائف عربية',
      icon: Icons.emoji_emotions_rounded,
      sortOrder: 60,
    ),
    'quran': (
      title: 'القرآن الكريم',
      icon: Icons.menu_book_rounded,
      sortOrder: 70,
    ),
  };

  static Future<List<LibrarySection>> loadLibraryContent({
    String? rawAssetJsonOverride,
  }) async {
    try {
      final String jsonString = rawAssetJsonOverride ??
          await rootBundle.loadString('assets/data/library/content.json');
      final Map<String, dynamic> data =
          json.decode(jsonString) as Map<String, dynamic>;

      final cms = CmsCacheService.instance.snapshot;
      final cloudItemsBySection = <String, List<DynamicLibraryItemData>>{};
      for (final item in cms.libraryItems.values) {
        cloudItemsBySection.putIfAbsent(item.sectionId, () => []).add(item);
      }

      // Collect all candidate section IDs (built-in + cloud additions)
      final allSectionIds = <String>{
        ..._defaultSections.keys,
        ...data.keys,
        ...cms.librarySections.keys,
      };

      final List<LibrarySection> sections = [];
      for (final sectionId in allSectionIds) {
        final cloudSec = cms.librarySections[sectionId];
        final defMeta = _defaultSections[sectionId];
        if (cloudSec == null && defMeta == null) continue;

        final isVisible = cloudSec?.isVisible ?? true;
        if (!isVisible) continue;

        final rawItems = data[sectionId];
        final mergedItemsMap = <String, LibraryItem>{};
        var baseIdx = 0;
        if (rawItems is List) {
          for (final entry in rawItems) {
            if (entry is Map) {
              final parsed =
                  LibraryItem.fromJson(Map<String, dynamic>.from(entry));
              final key = parsed.id.isNotEmpty
                  ? parsed.id
                  : '${sectionId}_base_$baseIdx';
              mergedItemsMap[key] = LibraryItem(
                id: key,
                title: parsed.title,
                subtitle: parsed.subtitle,
                content: parsed.content,
                sourceRef: parsed.sourceRef,
                sortOrder: 100 + baseIdx,
                isVisible: true,
              );
              baseIdx++;
            }
          }
        }

        for (final cloudItem
            in (cloudItemsBySection[sectionId] ?? const <DynamicLibraryItemData>[])) {
          mergedItemsMap[cloudItem.id] = LibraryItem(
            id: cloudItem.id,
            title: cloudItem.title,
            subtitle: cloudItem.subtitle,
            content: cloudItem.content,
            sourceRef: cloudItem.sourceRef,
            sortOrder: cloudItem.sortOrder,
            isVisible: cloudItem.isVisible,
          );
        }

        final visibleItems = mergedItemsMap.values
            .where((item) => item.isVisible)
            .toList()
          ..sort((a, b) {
            final cmpSort = a.sortOrder.compareTo(b.sortOrder);
            return cmpSort != 0 ? cmpSort : a.id.compareTo(b.id);
          });

        final icon = cloudSec != null
            ? CmsIconRegistry.resolveIcon(
                cloudSec.iconName,
                fallback: defMeta?.icon ?? Icons.auto_stories_rounded,
              )
            : (defMeta?.icon ?? Icons.auto_stories_rounded);

        sections.add(
          LibrarySection(
            id: sectionId,
            title: cloudSec?.title.isNotEmpty == true
                ? cloudSec!.title
                : (defMeta?.title ?? sectionId),
            icon: icon,
            items: visibleItems,
            accentColor: cloudSec != null
                ? CmsIconRegistry.parseHexColor(cloudSec.colorHex)
                : null,
            sortOrder: cloudSec?.sortOrder ?? defMeta?.sortOrder ?? 100,
            isVisible: isVisible,
          ),
        );
      }

      sections.sort((a, b) {
        final cmpSort = a.sortOrder.compareTo(b.sortOrder);
        return cmpSort != 0 ? cmpSort : a.id.compareTo(b.id);
      });

      return sections;
    } catch (e) {
      debugPrint('LibraryService loadLibraryContent error: $e');
      return [];
    }
  }
}
