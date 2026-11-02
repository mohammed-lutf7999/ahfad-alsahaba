import 'dart:async';
import 'package:flutter/material.dart';
import '../models/challenge_config.dart';
import '../models/challenge_message.dart';
import '../models/multiplayer_player.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';
import 'nearby_service.dart';
import 'profile_service.dart';
import '../../core/sound_service.dart';

/// خدمة إدارة لعبة التحدي
class ChallengeGameService extends ChangeNotifier {
  static ChallengeGameService? _instance;
  static ChallengeGameService get instance {
    _instance ??= ChallengeGameService._();
    return _instance!;
  }
  ChallengeGameService._();

  final NearbyService _nearbyService = NearbyService.instance;
  
  // حالة اللعبة
  ChallengeState _state = ChallengeState.waiting;
  ChallengeState get state => _state;
  
  // إعدادات التحدي
  ChallengeConfig? _config;
  ChallengeConfig? get config => _config;
  
  // اللاعبون
  final List<MultiplayerPlayer> _players = [];
  List<MultiplayerPlayer> get players => List.unmodifiable(_players);
  
  // اللاعب المحلي
  MultiplayerPlayer? _localPlayer;
  MultiplayerPlayer? get localPlayer => _localPlayer;
  
  // الأسئلة
  List<Question> _questions = [];
  List<Question> get questions => _questions;
  
  // السؤال الحالي
  int _currentQuestionIndex = 0;
  int get currentQuestionIndex => _currentQuestionIndex;
  Question? get currentQuestion => 
      _currentQuestionIndex < _questions.length ? _questions[_currentQuestionIndex] : null;
  
  // وقت بدء السؤال الحالي
  DateTime? _questionStartTime;
  
  // هل أجاب اللاعب المحلي
  bool _hasAnswered = false;
  bool get hasAnswered => _hasAnswered;
  
  // النتيجة النهائية
  ChallengeResult? _result;
  ChallengeResult? get result => _result;
  
  // هل المضيف
  bool _isHost = false;
  bool get isHost => _isHost;

  /// تهيئة كمضيف
  Future<bool> initAsHost(ChallengeConfig config) async {
    _isHost = true;
    _config = config;
    _state = ChallengeState.waiting;
    _players.clear();
    
    // إضافة اللاعب المحلي (المضيف)
    final profile = ProfileService.instance.activeProfile;
    if (profile != null) {
      _localPlayer = MultiplayerPlayer(
        id: config.challengeId,
        name: profile.name,
        avatarIndex: profile.avatarIndex,
        isHost: true,
        isReady: true,
      );
      _players.add(_localPlayer!);
    }
    
    // إعداد callbacks
    _setupCallbacks();
    
    // بدء الإعلان
    final result = await _nearbyService.startAdvertising(
      playerName: _localPlayer?.name ?? 'Host',
      config: config,
    );
    
    notifyListeners();
    return result;
  }

  /// تهيئة كعميل
  Future<void> initAsClient() async {
    _isHost = false;
    _state = ChallengeState.waiting;
    _players.clear();
    
    final profile = ProfileService.instance.activeProfile;
    if (profile != null) {
      _localPlayer = MultiplayerPlayer(
        id: 'LOCAL_${DateTime.now().millisecondsSinceEpoch}',
        name: profile.name,
        avatarIndex: profile.avatarIndex,
        isHost: false,
      );
    }
    
    // إعداد callbacks
    _setupCallbacks();
    
    // بدء البحث
    await _nearbyService.startDiscovery(
      playerName: _localPlayer?.name ?? 'Player',
    );
    
    notifyListeners();
  }

  /// إعداد callbacks للاستماع للرسائل
  void _setupCallbacks() {
    _nearbyService.onMessageReceived = _handleMessage;
    _nearbyService.onPlayerConnected = _handlePlayerConnected;
    _nearbyService.onPlayerDisconnected = _handlePlayerDisconnected;
  }

  /// معالجة الرسائل الواردة
  void _handleMessage(ChallengeMessage message) {
    debugPrint('📩 Received message: ${message.type} from ${message.senderId}');
    
    switch (message.type) {
      case MessageType.challengeConfig:
        _handleChallengeConfig(message);
        break;
      case MessageType.playerReady:
        _handlePlayerReady(message);
        break;
      case MessageType.playerJoined:
        _handlePlayerJoined(message);
        break;
      case MessageType.playersSync:
        _handlePlayersSync(message);
        break;
      case MessageType.gameStart:
        _handleGameStart(message);
        break;
      case MessageType.questionStart:
        _handleQuestionStart(message);
        break;
      case MessageType.answerSubmitted:
        _handleAnswerSubmitted(message);
        break;
      case MessageType.answerResult:
        _handleAnswerResult(message);
        break;
      case MessageType.syncScores:
        _handleSyncScores(message);
        break;
      case MessageType.gameEnd:
        _handleGameEnd(message);
        break;
      case MessageType.disconnect:
        _handleDisconnect(message);
        break;
      default:
        debugPrint('⚠️ Unknown message type: ${message.type}');
        break;
    }
    notifyListeners();
  }

  void _handleChallengeConfig(ChallengeMessage message) {
    debugPrint('📦 Received challenge config from host');
    _config = ChallengeConfig.fromJson(message.data);
    
    // العميل يرسل معلوماته للمضيف ويضيف نفسه للقائمة
    if (!_isHost && _localPlayer != null) {
      debugPrint('📤 Sending playerJoined message to host');
      
      // إضافة اللاعب المحلي للقائمة
      if (!_players.any((p) => p.id == _localPlayer!.id)) {
        _players.add(_localPlayer!);
      }
      
      // إرسال معلومات اللاعب للمضيف
      _nearbyService.broadcastMessage(
        ChallengeMessage.playerJoined(
          _localPlayer!.id,
          _localPlayer!.name,
          _localPlayer!.avatarIndex,
        ),
      );
    }
  }

  void _handlePlayerReady(ChallengeMessage message) {
    final existingPlayer = _players.where((p) => p.id == message.senderId).firstOrNull;
    if (existingPlayer != null) {
      existingPlayer.isReady = true;
    }
  }

  void _handlePlayerJoined(ChallengeMessage message) {
    debugPrint('👤 Player joined: ${message.data['playerName']}');
    
    final player = MultiplayerPlayer(
      id: message.senderId,
      name: message.data['playerName'] ?? 'Unknown',
      avatarIndex: message.data['avatarIndex'] ?? 0,
      isReady: false,
      isConnected: true,
    );
    
    if (!_players.any((p) => p.id == player.id)) {
      _players.add(player);
      SoundService().playPlayerJoin(); // Sound Effect
      debugPrint('✅ Added player to list. Total players: ${_players.length}');
      
      // المضيف يبث قائمة اللاعبين المحدثة للجميع
      if (_isHost) {
        _broadcastPlayersList();
      }
    }
  }
  
  /// معالجة مزامنة قائمة اللاعبين
  void _handlePlayersSync(ChallengeMessage message) {
    debugPrint('🔄 Syncing players list');
    
    final playersData = message.data['players'] as List;
    bool newPlayerAdded = false;
    
    for (final playerJson in playersData) {
      final playerData = Map<String, dynamic>.from(playerJson);
      final playerId = playerData['id'] as String;
      
      // لا تضف اللاعب المحلي مرة أخرى
      if (playerId == _localPlayer?.id) continue;
      
      if (!_players.any((p) => p.id == playerId)) {
        _players.add(MultiplayerPlayer.fromJson(playerData));
        newPlayerAdded = true;
      }
    }

    if (newPlayerAdded) SoundService().playPlayerJoin(); // Sound on sync too
    
    debugPrint('✅ Players synced. Total: ${_players.length}');
  }

  void _handleGameStart(ChallengeMessage message) {
    debugPrint('🎮 Game starting! Received questions from host');
    SoundService().playGameStart(); // Sound Effect
    
    final questionsData = message.data['questions'] as List;
    _questions = questionsData.map((q) => Question.fromJson(q)).toList();
    _currentQuestionIndex = 0;
    _hasAnswered = false;
    _questionStartTime = DateTime.now();
    _state = ChallengeState.inProgress;
    
    debugPrint('✅ Game started with ${_questions.length} questions. State: $_state');
  }

  void _handleQuestionStart(ChallengeMessage message) {
    _currentQuestionIndex = message.data['questionIndex'];
    _questionStartTime = DateTime.now();
    _hasAnswered = false;
  }

  void _handleAnswerSubmitted(ChallengeMessage message) {
    if (!_isHost) return;
    
    final playerId = message.senderId;
    final answerIndex = message.data['answerIndex'];
    final timeMs = message.data['timeMs'];
    final questionIndex = message.data['questionIndex'];
    
    final player = _players.where((p) => p.id == playerId).firstOrNull;
    if (player != null && questionIndex < _questions.length) {
      // تحديث تقدم اللاعب
      player.currentQuestionIndex = questionIndex;
      
      final question = _questions[questionIndex];
      final correct = question.correctAnswerIndex == answerIndex;
      
      if (correct) {
        player.addScore(100, timeMs, _config?.speedMode ?? true);
      }
      
      // التحقق مما إذا كان اللاعب قد أنهى
      if (questionIndex >= _questions.length - 1) {
        player.hasFinished = true;
        _checkAllFinished();
      }
    }
    
    // إرسال تحديث النقاط
    _broadcastScores();
  }

  void _handleAnswerResult(ChallengeMessage message) {
    final scores = Map<String, int>.from(message.data['playerScores']);
    for (final player in _players) {
      if (scores.containsKey(player.id)) {
        player.score = scores[player.id]!;
      }
    }
  }

  void _handleSyncScores(ChallengeMessage message) {
    final scores = Map<String, int>.from(message.data['scores']);
    for (final player in _players) {
      if (scores.containsKey(player.id)) {
        player.score = scores[player.id]!;
      }
    }
  }

  void _handleGameEnd(ChallengeMessage message) {
    _state = ChallengeState.finished;
    final finalScores = Map<String, int>.from(message.data['finalScores']);
    final winnerId = message.data['winnerId'];
    
    for (final player in _players) {
      if (finalScores.containsKey(player.id)) {
        player.score = finalScores[player.id]!;
      }
    }
    
    _result = ChallengeResult(
      players: _players,
      winnerId: winnerId,
      totalQuestions: _questions.length,
      duration: Duration.zero,
    );
  }

  void _handleDisconnect(ChallengeMessage message) {
    _players.removeWhere((p) => p.id == message.senderId);
  }

  void _handlePlayerConnected(String endpointId, String endpointName) {
    debugPrint('✨ Player connected: $endpointName (ID: $endpointId)');
    
    if (_isHost && _config != null) {
      debugPrint('📤 Host sending challenge config to new player');
      
      // إرسال إعدادات التحدي للعميل الجديد
      _nearbyService.sendMessage(
        endpointId,
        ChallengeMessage.challengeConfig(_localPlayer!.id, _config!.toJson()),
      );
    }
  }

  void _handlePlayerDisconnected(String endpointId) {
    debugPrint('👋 Player disconnected: $endpointId');
    _players.removeWhere((p) => p.id == endpointId);
    
    // إعلام باقي اللاعبين بالقائمة المحدثة
    if (_isHost) {
      if (_players.length > 1) {
        _broadcastPlayersList();
      }
      // التحقق مما إذا انتهى الباقون (أو بقيت وحدي)
      _checkAllFinished();
    }
    
    notifyListeners();
  }
  
  /// بث قائمة اللاعبين لجميع المتصلين
  void _broadcastPlayersList() {
    if (!_isHost || _localPlayer == null) return;
    
    final playersList = _players.map((p) => p.toJson()).toList();
    debugPrint('📡 Broadcasting players list: ${playersList.length} players');
    
    _nearbyService.broadcastMessage(
      ChallengeMessage.playersSync(_localPlayer!.id, playersList),
    );
  }

  /// بث النقاط لجميع اللاعبين
  void _broadcastScores() {
    final scores = <String, int>{};
    for (final player in _players) {
      scores[player.id] = player.score;
    }
    _nearbyService.broadcastMessage(
      ChallengeMessage.syncScores(_localPlayer!.id, scores),
    );
  }

  /// إرسال إجابة (للاعب المحلي)
  Future<void> submitAnswer(int answerIndex) async {
    if (_hasAnswered || _questionStartTime == null) return;
    
    _hasAnswered = true;
    final timeMs = DateTime.now().difference(_questionStartTime!).inMilliseconds;
    
    // حساب النقاط محلياً
    final correct = currentQuestion?.correctAnswerIndex == answerIndex;
    if (correct && _localPlayer != null) {
      _localPlayer!.addScore(100, timeMs, _config?.speedMode ?? true);
    }
    
    if (_isHost) {
      // المضيف يحسب مباشرة
      _broadcastScores();
    } else {
      // العميل يرسل للمضيف
      await _nearbyService.broadcastMessage(
        ChallengeMessage.answerSubmitted(
          _localPlayer!.id,
          _currentQuestionIndex,
          answerIndex,
          timeMs,
        ),
      );
    }
    
    notifyListeners();
  }

  /// بدء اللعبة (للمضيف فقط)
  Future<void> startGame() async {
    if (!_isHost || _config == null) return;
    
    debugPrint('🎮 Host starting game...');
    
    // تحميل الأسئلة
    await _loadQuestions();
    
    if (_questions.isEmpty) {
      debugPrint('❌ No questions loaded!');
      return;
    }
    
    debugPrint('✅ Loaded ${_questions.length} questions');
    
    _state = ChallengeState.starting;
    notifyListeners();
    
    // إرسال الأسئلة لجميع اللاعبين
    debugPrint('📡 Broadcasting gameStart to all players');
    await _nearbyService.broadcastMessage(
      ChallengeMessage.gameStart(
        _localPlayer!.id,
        _questions.map((q) => q.toJson()).toList(),
      ),
    );
    
    // تقليل وقت الانتظار لتحسين الاستجابة (1 ثانية كافية بعد إصلاح الشبكة)
    await Future.delayed(const Duration(seconds: 1));
    
    _state = ChallengeState.inProgress;
    _questionStartTime = DateTime.now();
    _hasAnswered = false;
    _startNextQuestionLocal();
    
    debugPrint('✅ Game in progress!');
  }

  /// تحميل الأسئلة حسب إعدادات التحدي
  Future<void> _loadQuestions() async {
    if (_config == null) return;
    
    if (_config!.type == ChallengeType.bruteForce) {
      // أسئلة عشوائية من جميع الأقسام
      _questions = await _loadRandomQuestions(_config!.questionCount);
    } else if (_config!.categoryId != null) {
      // أسئلة من قسم محدد - تحميل من جميع المستويات
      _questions = await QuestionService().loadAllQuestionsForCategory(
        _config!.categoryId!,
      );
      
      // أخذ العدد المطلوب فقط بعد الخلط
      if (_questions.length > _config!.questionCount) {
        _questions = _questions.take(_config!.questionCount).toList();
      }
    }
  }

  /// تحميل أسئلة عشوائية من جميع الأقسام
  Future<List<Question>> _loadRandomQuestions(int count) async {
    final allCategories = ['quraan', 'hadith', 'fiqh', 'serah', 'tarikh', 'tawheed'];
    final allQuestions = <Question>[];
    
    for (final category in allCategories) {
      try {
        final questions = await QuestionService().loadQuestions(
          categoryId: category,
          levelNumber: 1,
        );
        allQuestions.addAll(questions);
      } catch (e) {
        // تجاهل الأخطاء
      }
    }
    
    allQuestions.shuffle();
    return allQuestions.take(count).toList();
  }

  /// بدء السؤال التالي محلياً
  void _startNextQuestionLocal() {
    _questionStartTime = DateTime.now();
    _hasAnswered = false;
    notifyListeners();
  }

  /// الانتقال للسؤال التالي
  void nextQuestion() {
    _currentQuestionIndex++;
    if (_localPlayer != null) {
      _localPlayer!.currentQuestionIndex = _currentQuestionIndex;
    }

    if (_currentQuestionIndex >= _questions.length) {
      // اللاعب المحلي انتهى
      if (_localPlayer != null) {
        _localPlayer!.hasFinished = true;
      }
      
      if (_isHost) {
        // المضيف يتحقق إذا انتهى الجميع
        _checkAllFinished();
      } else {
        // العميل ينتظر نهاية اللعبة من المضيف
        notifyListeners();
      }
      return;
    }
    
    _startNextQuestionLocal();
  }

  /// التحقق مما إذا انتهى الجميع
  void _checkAllFinished() {
    if (!_isHost) return;
    
    final allFinished = _players.every((p) => p.hasFinished);
    if (allFinished) {
      _endGame();
    }
  }

  /// إنهاء اللعبة
  void _endGame() {
    if (_state == ChallengeState.finished) return; // Prevent multiple calls
    _state = ChallengeState.finished;
    
    // تحديد الفائز
    final winner = _players.reduce((a, b) => a.score > b.score ? a : b);
    
    final scores = <String, int>{};
    for (final player in _players) {
      scores[player.id] = player.score;
    }
    
    _result = ChallengeResult(
      players: _players,
      winnerId: winner.id,
      totalQuestions: _questions.length,
      duration: Duration.zero,
    );
    
    _nearbyService.broadcastMessage(
      ChallengeMessage.gameEnd(_localPlayer!.id, scores, winner.id),
    );
    
    notifyListeners();
  }

  /// تنظيف وإعادة التعيين
  Future<void> reset() async {
    await _nearbyService.stopAll();
    _state = ChallengeState.waiting;
    _config = null;
    _players.clear();
    _questions.clear();
    _currentQuestionIndex = 0;
    _result = null;
    _isHost = false;
    _hasAnswered = false;
    notifyListeners();
  }
}
