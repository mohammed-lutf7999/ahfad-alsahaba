class MatchmakingResult {
  final bool success;
  final String? matchId;
  final String? opponentId;
  final int? seed;
  final List<String>? questionIds;
  final bool isWaiting;
  final String? error;
  final bool isFriendly;

  MatchmakingResult({
    this.success = false,
    this.matchId,
    this.opponentId,
    this.seed,
    this.questionIds,
    this.isWaiting = false,
    this.error,
    this.isFriendly = false,
  });
}

class PrivateRoomResult {
  final bool success;
  final String? matchId;
  final String? roomCode;
  final DateTime? expiresAt;
  final String? opponentId;
  final int? seed;
  final List<String>? questionIds;
  final String? error;

  PrivateRoomResult({
    this.success = false,
    this.matchId,
    this.roomCode,
    this.expiresAt,
    this.opponentId,
    this.seed,
    this.questionIds,
    this.error,
  });
}

class MatchState {
  final String status;
  final int currentQuestion;
  final List<String> questionIds;
  final DateTime? startedAt;
  final bool bothReady;

  MatchState({
    required this.status,
    this.currentQuestion = 0,
    this.questionIds = const [],
    this.startedAt,
    this.bothReady = false,
  });

  factory MatchState.fromJson(Map<String, dynamic> json) {
    return MatchState(
      status: json['status'] ?? 'unknown',
      currentQuestion: json['current_question'] ?? 0,
      questionIds: json['question_ids'] != null
          ? List<String>.from(json['question_ids'])
          : [],
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
    );
  }
}

class GhostMatchResult {
  final bool success;
  final String? matchId;
  final String? ghostUserId;
  final String? ghostName;
  final int? ghostAvatarIndex;
  final String? ghostFrame;
  final int? ghostLevel;
  final int? ghostTrophies;
  final int? seed;
  final List<String>? questionIds;
  final List<Map<String, dynamic>>? timeline;
  final bool isFriendly;
  final int dailyGhostCount;
  final bool isHumanMatch;
  final String? error;

  GhostMatchResult({
    this.success = false,
    this.matchId,
    this.ghostUserId,
    this.ghostName,
    this.ghostAvatarIndex,
    this.ghostFrame,
    this.ghostLevel,
    this.ghostTrophies,
    this.seed,
    this.questionIds,
    this.timeline,
    this.isFriendly = false,
    this.dailyGhostCount = 0,
    this.isHumanMatch = false,
    this.error,
  });
}
