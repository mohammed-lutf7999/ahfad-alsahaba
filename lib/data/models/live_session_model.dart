class LiveSessionModel {
  final String id;
  final String pinCode;
  final String title;
  final String categoryId;
  final String hostId;
  final String status; // 'waiting' | 'active' | 'finished'
  final int currentQuestionIndex;
  final List<String> questionIds;
  final int participantsCount;

  const LiveSessionModel({
    required this.id,
    required this.pinCode,
    required this.title,
    this.categoryId = 'quran',
    required this.hostId,
    this.status = 'waiting',
    this.currentQuestionIndex = 0,
    this.questionIds = const [],
    this.participantsCount = 0,
  });

  factory LiveSessionModel.fromJson(Map<String, dynamic> json) {
    final qRaw = json['question_ids'];
    final qIds = qRaw is List
        ? qRaw.map((e) => e.toString()).toList()
        : const <String>[];
    return LiveSessionModel(
      id: (json['id'] ?? '').toString(),
      pinCode: (json['pin_code'] ?? '').toString(),
      title: (json['title'] ?? 'بطولة الفرسان الحية').toString(),
      categoryId: (json['category_id'] ?? 'quran').toString(),
      hostId: (json['host_id'] ?? '').toString(),
      status: (json['status'] ?? 'waiting').toString(),
      currentQuestionIndex:
          (json['current_question_index'] as num?)?.toInt() ?? 0,
      questionIds: qIds,
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class LiveParticipantModel {
  final String sessionId;
  final String userId;
  final String displayName;
  final int avatarIndex;
  final int score;
  final int correctCount;

  const LiveParticipantModel({
    required this.sessionId,
    required this.userId,
    required this.displayName,
    this.avatarIndex = 0,
    this.score = 0,
    this.correctCount = 0,
  });

  factory LiveParticipantModel.fromJson(Map<String, dynamic> json) {
    return LiveParticipantModel(
      sessionId: (json['session_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? 'متسابق').toString(),
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class LiveArenaBroadcastEvent {
  final String type; // 'question' | 'reveal' | 'finish' | 'score_update' | 'participant_joined'
  final int questionIndex;
  final List<LiveParticipantModel> leaderboard;
  final LiveParticipantModel? participant;

  const LiveArenaBroadcastEvent({
    required this.type,
    this.questionIndex = 0,
    this.leaderboard = const [],
    this.participant,
  });
}
