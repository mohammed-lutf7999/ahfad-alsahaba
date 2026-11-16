import 'package:flutter/material.dart';

class LibraryItem {
  final String id;
  final String title;
  final String subtitle;
  final String content;
  final String sourceRef;
  final int sortOrder;
  final bool isVisible;

  LibraryItem({
    required this.id,
    required this.title,
    required this.content,
    this.subtitle = '',
    this.sourceRef = '',
    this.sortOrder = 100,
    this.isVisible = true,
  });

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      sourceRef: (json['source_ref'] ?? json['sourceRef'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      isVisible: (json['is_visible'] as bool?) ?? true,
    );
  }
}

class LibrarySection {
  final String id;
  final String title;
  final dynamic icon; // IconData or String asset path
  final List<LibraryItem> items;
  final Color? accentColor;
  final int sortOrder;
  final bool isVisible;

  LibrarySection({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
    this.accentColor,
    this.sortOrder = 100,
    this.isVisible = true,
  });
}
