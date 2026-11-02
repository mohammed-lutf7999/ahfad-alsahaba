import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/library_model.dart';
import 'package:flutter/material.dart';

class LibraryService {
  static Future<List<LibrarySection>> loadLibraryContent() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/library/content.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      
      List<LibrarySection> sections = [];

      // Define sections based on JSON keys and hardcoded metadata (Icon, Title)
      final sectionMetadata = {
        'stories': {'title': 'قصص وعبر', 'icon': Icons.auto_stories_rounded},
        'azkar': {'title': 'الأذكار', 'icon': Icons.nights_stay_rounded},
        'duas': {'title': 'أدعية مستجابة', 'icon': Icons.volunteer_activism_rounded},
        'hadith': {'title': 'الحديث الشريف', 'icon': Icons.format_quote_rounded},
        'wisdom': {'title': 'حكم وأقوال', 'icon': Icons.lightbulb_rounded},
        'jokes': {'title': 'طرائف عربية', 'icon': Icons.emoji_emotions_rounded},
        'quran': {'title': 'القرآن الكريم', 'icon': Icons.menu_book_rounded},
      };

      data.forEach((key, value) {
        if (sectionMetadata.containsKey(key)) {
          final items = (value as List).map((item) => LibraryItem.fromJson(item)).toList();
          sections.add(LibrarySection(
            id: key,
            title: sectionMetadata[key]!['title'] as String,
            icon: sectionMetadata[key]!['icon'] as IconData,
            items: items,
          ));
        }
      });

      return sections;
    } catch (e) {
      print('Error loading library content: $e');
      return [];
    }
  }
}
