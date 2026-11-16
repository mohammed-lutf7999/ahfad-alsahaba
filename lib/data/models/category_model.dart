import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int totalLevels;
  final int unlockedLevels;
  final bool isLocked;
  final Color color;
  final int sortOrder;
  final bool isVisible;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.totalLevels,
    this.unlockedLevels = 1,
    this.isLocked = false,
    this.color = const Color(0xFF1B5E20),
    this.sortOrder = 100,
    this.isVisible = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconCodePoint': icon.codePoint,
      'totalLevels': totalLevels,
      'unlockedLevels': unlockedLevels,
      'isLocked': isLocked,
      'colorValue': color.toARGB32(),
      'sortOrder': sortOrder,
      'isVisible': isVisible,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
      totalLevels: json['totalLevels'],
      unlockedLevels: json['unlockedLevels'] ?? 1,
      isLocked: json['isLocked'] ?? false,
      color: Color(json['colorValue'] ?? 0xFF1B5E20),
      sortOrder: json['sortOrder'] ?? 100,
      isVisible: json['isVisible'] ?? true,
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    int? totalLevels,
    int? unlockedLevels,
    bool? isLocked,
    Color? color,
    int? sortOrder,
    bool? isVisible,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      totalLevels: totalLevels ?? this.totalLevels,
      unlockedLevels: unlockedLevels ?? this.unlockedLevels,
      isLocked: isLocked ?? this.isLocked,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  double get progressPercentage =>
      totalLevels > 0 ? (unlockedLevels / totalLevels).clamp(0.0, 1.0) : 0.0;
}
