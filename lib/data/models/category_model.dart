import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int totalLevels;
  final int questionsPerLevel;
  final String levelDrawMode;
  final int unlockedLevels;
  final bool isLocked;
  final Color color;
  final int sortOrder;
  final bool isVisible;
  final String availabilityStatus;
  final String comingSoonMessage;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.totalLevels,
    this.questionsPerLevel = 10,
    this.levelDrawMode = 'fixed',
    this.unlockedLevels = 1,
    this.isLocked = false,
    this.color = const Color(0xFF1B5E20),
    this.sortOrder = 100,
    this.isVisible = true,
    this.availabilityStatus = 'open',
    this.comingSoonMessage = '',
  });

  bool get isComingSoon => availabilityStatus == 'coming_soon';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconCodePoint': icon.codePoint,
      'totalLevels': totalLevels,
      'questionsPerLevel': questionsPerLevel,
      'levelDrawMode': levelDrawMode,
      'unlockedLevels': unlockedLevels,
      'isLocked': isLocked,
      'colorValue': color.toARGB32(),
      'sortOrder': sortOrder,
      'isVisible': isVisible,
      'availabilityStatus': availabilityStatus,
      'comingSoonMessage': comingSoonMessage,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
      totalLevels: json['totalLevels'],
      questionsPerLevel: ((json['questionsPerLevel'] as num?)?.toInt() ?? 10)
          .clamp(1, 100),
      levelDrawMode:
          (json['levelDrawMode']?.toString() == 'rotating_pool')
              ? 'rotating_pool'
              : 'fixed',
      unlockedLevels: json['unlockedLevels'] ?? 1,
      isLocked: json['isLocked'] ?? false,
      color: Color(json['colorValue'] ?? 0xFF1B5E20),
      sortOrder: json['sortOrder'] ?? 100,
      isVisible: json['isVisible'] ?? true,
      availabilityStatus: (json['availabilityStatus'] ?? 'open').toString(),
      comingSoonMessage: (json['comingSoonMessage'] ?? '').toString(),
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    int? totalLevels,
    int? questionsPerLevel,
    String? levelDrawMode,
    int? unlockedLevels,
    bool? isLocked,
    Color? color,
    int? sortOrder,
    bool? isVisible,
    String? availabilityStatus,
    String? comingSoonMessage,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      totalLevels: totalLevels ?? this.totalLevels,
      questionsPerLevel: questionsPerLevel ?? this.questionsPerLevel,
      levelDrawMode: levelDrawMode ?? this.levelDrawMode,
      unlockedLevels: unlockedLevels ?? this.unlockedLevels,
      isLocked: isLocked ?? this.isLocked,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isVisible: isVisible ?? this.isVisible,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      comingSoonMessage: comingSoonMessage ?? this.comingSoonMessage,
    );
  }

  double get progressPercentage =>
      totalLevels > 0 ? (unlockedLevels / totalLevels).clamp(0.0, 1.0) : 0.0;
}
