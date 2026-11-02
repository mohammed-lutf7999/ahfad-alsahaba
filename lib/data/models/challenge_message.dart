import 'dart:convert';

/// بروتوكول الرسائل بين الأجهزة
class ChallengeMessage {
  final MessageType type;
  final String senderId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ChallengeMessage({
    required this.type,
    required this.senderId,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'senderId': senderId,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChallengeMessage.fromJson(Map<String, dynamic> json) {
    return ChallengeMessage(
      type: MessageType.values[json['type']],
      senderId: json['senderId'],
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  String encode() => jsonEncode(toJson());
  
  static ChallengeMessage decode(String data) => 
      ChallengeMessage.fromJson(jsonDecode(data));

  // Factory methods للرسائل الشائعة
  
  /// رسالة إعدادات التحدي (Host -> Client)
  factory ChallengeMessage.challengeConfig(String senderId, Map<String, dynamic> config) {
    return ChallengeMessage(
      type: MessageType.challengeConfig,
      senderId: senderId,
      data: config,
    );
  }

  /// رسالة جاهزية اللاعب (Client -> Host)
  factory ChallengeMessage.playerReady(String senderId, String playerName, int avatarIndex) {
    return ChallengeMessage(
      type: MessageType.playerReady,
      senderId: senderId,
      data: {
        'playerName': playerName,
        'avatarIndex': avatarIndex,
      },
    );
  }

  /// رسالة انضمام لاعب جديد (Client -> Host)
  factory ChallengeMessage.playerJoined(String senderId, String playerName, int avatarIndex) {
    return ChallengeMessage(
      type: MessageType.playerJoined,
      senderId: senderId,
      data: {
        'playerName': playerName,
        'avatarIndex': avatarIndex,
      },
    );
  }

  /// رسالة مزامنة قائمة اللاعبين (Host -> All)
  factory ChallengeMessage.playersSync(String senderId, List<Map<String, dynamic>> players) {
    return ChallengeMessage(
      type: MessageType.playersSync,
      senderId: senderId,
      data: {'players': players},
    );
  }

  /// رسالة بدء اللعبة (Host -> All)
  factory ChallengeMessage.gameStart(String senderId, List<Map<String, dynamic>> questions) {
    return ChallengeMessage(
      type: MessageType.gameStart,
      senderId: senderId,
      data: {'questions': questions},
    );
  }

  /// رسالة بدء السؤال (Host -> All)
  factory ChallengeMessage.questionStart(String senderId, int questionIndex) {
    return ChallengeMessage(
      type: MessageType.questionStart,
      senderId: senderId,
      data: {'questionIndex': questionIndex},
    );
  }

  /// رسالة إرسال الإجابة (Player -> Host)
  factory ChallengeMessage.answerSubmitted(String senderId, int questionIndex, int answerIndex, int timeMs) {
    return ChallengeMessage(
      type: MessageType.answerSubmitted,
      senderId: senderId,
      data: {
        'questionIndex': questionIndex,
        'answerIndex': answerIndex,
        'timeMs': timeMs,
      },
    );
  }

  /// رسالة نتيجة الإجابة (Host -> All)
  factory ChallengeMessage.answerResult(String senderId, int questionIndex, Map<String, int> playerScores) {
    return ChallengeMessage(
      type: MessageType.answerResult,
      senderId: senderId,
      data: {
        'questionIndex': questionIndex,
        'playerScores': playerScores,
      },
    );
  }

  /// رسالة مزامنة النقاط (Host -> All)
  factory ChallengeMessage.syncScores(String senderId, Map<String, int> scores) {
    return ChallengeMessage(
      type: MessageType.syncScores,
      senderId: senderId,
      data: {'scores': scores},
    );
  }

  /// رسالة انتهاء اللعبة (Host -> All)
  factory ChallengeMessage.gameEnd(String senderId, Map<String, int> finalScores, String winnerId) {
    return ChallengeMessage(
      type: MessageType.gameEnd,
      senderId: senderId,
      data: {
        'finalScores': finalScores,
        'winnerId': winnerId,
      },
    );
  }

  /// رسالة قطع الاتصال
  factory ChallengeMessage.disconnect(String senderId, String reason) {
    return ChallengeMessage(
      type: MessageType.disconnect,
      senderId: senderId,
      data: {'reason': reason},
    );
  }
}

/// أنواع الرسائل
enum MessageType {
  challengeConfig,    // 0x01 - إعدادات التحدي
  playerReady,        // 0x02 - اللاعب جاهز
  gameStart,          // 0x03 - بدء اللعبة
  questionStart,      // 0x04 - بدء السؤال
  answerSubmitted,    // 0x05 - إرسال الإجابة
  answerResult,       // 0x06 - نتيجة الإجابة
  syncScores,         // 0x07 - مزامنة النقاط
  gameEnd,            // 0x08 - انتهاء اللعبة
  disconnect,         // 0x09 - قطع الاتصال
  playerJoined,       // 0x0A - لاعب انضم
  playerLeft,         // 0x0B - لاعب غادر
  playersSync,        // 0x0C - مزامنة قائمة اللاعبين
}
