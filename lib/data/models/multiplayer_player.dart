/// لاعب في التحدي التنافسي
class MultiplayerPlayer {
  final String id;              // معرّف فريد (endpoint ID)
  final String name;
  final int avatarIndex;
  final bool isHost;
  int score;
  int correctAnswers;
  int totalTimeMs;
  int currentQuestionIndex; // تتبع السؤال الحالي لكل لاعب
  bool hasFinished;         // هل أنهى جميع الأسئلة
  bool isReady;
  bool isConnected;

  MultiplayerPlayer({
    required this.id,
    required this.name,
    required this.avatarIndex,
    this.isHost = false,
    this.score = 0,
    this.correctAnswers = 0,
    this.totalTimeMs = 0,
    this.currentQuestionIndex = 0,
    this.hasFinished = false,
    this.isReady = false,
    this.isConnected = true,
  });

  /// حساب معدل السرعة
  double get averageTimeSeconds => 
      correctAnswers > 0 ? (totalTimeMs / correctAnswers) / 1000 : 0;

  /// إضافة نقاط مع حساب السرعة
  void addScore(int basePoints, int timeMs, bool speedMode) {
    if (speedMode) {
      // نقاط أكثر للإجابة الأسرع (max 2x bonus)
      final speedBonus = (1 + (10000 - timeMs.clamp(0, 10000)) / 10000);
      score += (basePoints * speedBonus).round();
    } else {
      score += basePoints;
    }
    correctAnswers++;
    totalTimeMs += timeMs;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarIndex': avatarIndex,
    'isHost': isHost,
    'score': score,
    'correctAnswers': correctAnswers,
    'totalTimeMs': totalTimeMs,
    'currentQuestionIndex': currentQuestionIndex,
    'hasFinished': hasFinished,
    'isReady': isReady,
    'isConnected': isConnected,
  };

  factory MultiplayerPlayer.fromJson(Map<String, dynamic> json) {
    return MultiplayerPlayer(
      id: json['id'],
      name: json['name'],
      avatarIndex: json['avatarIndex'],
      isHost: json['isHost'] ?? false,
      score: json['score'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      totalTimeMs: json['totalTimeMs'] ?? 0,
      isReady: json['isReady'] ?? false,
      isConnected: json['isConnected'] ?? true,
    )
      ..currentQuestionIndex = json['currentQuestionIndex'] ?? 0
      ..hasFinished = json['hasFinished'] ?? false;
  }

  MultiplayerPlayer copyWith({
    String? id,
    String? name,
    int? avatarIndex,
    bool? isHost,
    int? score,
    int? correctAnswers,
    int? totalTimeMs,
    int? currentQuestionIndex,
    bool? hasFinished,
    bool? isReady,
    bool? isConnected,
  }) {
    return MultiplayerPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      isHost: isHost ?? this.isHost,
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalTimeMs: totalTimeMs ?? this.totalTimeMs,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      hasFinished: hasFinished ?? this.hasFinished,
      isReady: isReady ?? this.isReady,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

/// نتيجة التحدي
class ChallengeResult {
  final List<MultiplayerPlayer> players;
  final String winnerId;
  final int totalQuestions;
  final Duration duration;

  ChallengeResult({
    required this.players,
    required this.winnerId,
    required this.totalQuestions,
    required this.duration,
  });

  MultiplayerPlayer get winner => 
      players.firstWhere((p) => p.id == winnerId);
  
  List<MultiplayerPlayer> get rankedPlayers {
    final sorted = List<MultiplayerPlayer>.from(players);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }
}
