import 'dart:convert';

/// إعدادات التحدي التنافسي
class ChallengeConfig {
  final String challengeId;
  final String hostName;
  final String hostAvatarIndex;
  final ChallengeType type;
  final String? categoryId;     // null = random (brute force)
  final int questionCount;
  final bool speedMode;         // نقاط السرعة
  final int maxPlayers;
  final DateTime createdAt;

  ChallengeConfig({
    required this.challengeId,
    required this.hostName,
    required this.hostAvatarIndex,
    required this.type,
    this.categoryId,
    this.questionCount = 10,
    this.speedMode = true,
    this.maxPlayers = 4,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// إنشاء معرّف فريد للتحدي
  static String generateId() {
    return 'CH_${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> toJson() => {
    'challengeId': challengeId,
    'hostName': hostName,
    'hostAvatarIndex': hostAvatarIndex,
    'type': type.index,
    'categoryId': categoryId,
    'questionCount': questionCount,
    'speedMode': speedMode,
    'maxPlayers': maxPlayers,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChallengeConfig.fromJson(Map<String, dynamic> json) {
    return ChallengeConfig(
      challengeId: json['challengeId'],
      hostName: json['hostName'],
      hostAvatarIndex: json['hostAvatarIndex'],
      type: ChallengeType.values[json['type']],
      categoryId: json['categoryId'],
      questionCount: json['questionCount'] ?? 10,
      speedMode: json['speedMode'] ?? true,
      maxPlayers: json['maxPlayers'] ?? 4,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  String encode() => jsonEncode(toJson());
  
  static ChallengeConfig decode(String data) => 
      ChallengeConfig.fromJson(jsonDecode(data));
}

/// أنواع التحديات
enum ChallengeType {
  category,     // قسم محدد
  bruteForce,   // القوة الغاشمة (عشوائي من الكل)
}

/// حالة التحدي
enum ChallengeState {
  waiting,      // انتظار اللاعبين
  starting,     // بدء العد التنازلي
  inProgress,   // جاري التحدي
  finished,     // انتهى
}
