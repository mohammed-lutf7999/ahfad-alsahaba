import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/live_session_model.dart';
import 'profile_service.dart';

typedef LiveRpcHandler = Future<Map<String, dynamic>> Function(
  String rpcName,
  Map<String, dynamic> params,
);

/// Realtime Broadcast service for up to 100-participant live classroom/mosque arenas.
/// Opens ONLY `live_arena_<sessionId>` while active and detaches cleanly in `leaveSession()`.
class LiveTournamentService extends ChangeNotifier {
  static final LiveTournamentService instance = LiveTournamentService._();
  LiveTournamentService._();

  LiveSessionModel? _activeSession;
  final List<LiveParticipantModel> _participants = [];
  RealtimeChannel? _channel;
  StreamController<LiveArenaBroadcastEvent>? _eventController;
  bool _isBusy = false;

  @visibleForTesting
  LiveRpcHandler? rpcOverride;

  @visibleForTesting
  bool? isAuthenticatedOverride;

  @visibleForTesting
  bool allowRealtimeInTests = false;

  LiveSessionModel? get activeSession => _activeSession;
  List<LiveParticipantModel> get participants {
    final sorted = List<LiveParticipantModel>.from(_participants)
      ..sort((a, b) => b.score.compareTo(a.score));
    return List.unmodifiable(sorted);
  }

  bool get isBusy => _isBusy;
  bool get hasActiveChannel => _channel != null;

  Stream<LiveArenaBroadcastEvent> get eventsStream {
    _eventController ??= StreamController<LiveArenaBroadcastEvent>.broadcast();
    return _eventController!.stream;
  }

  SupabaseClient? _safeClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated {
    if (isAuthenticatedOverride != null) return isAuthenticatedOverride!;
    return _safeClient()?.auth.currentUser != null;
  }

  bool _isRunningUnderFlutterTest() {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    rpcOverride = null;
    isAuthenticatedOverride = null;
    allowRealtimeInTests = false;
    _activeSession = null;
    _participants.clear();
    _channel = null;
    _isBusy = false;
    _eventController?.close();
    _eventController = null;
  }

  Future<Map<String, dynamic>?> createSession({
    required String title,
    required String categoryId,
    required List<String> questionIds,
  }) async {
    if (!isAuthenticated) {
      throw Exception('يلزم تسجيل الدخول بحساب Google لإنشاء بطولة حية');
    }
    _isBusy = true;
    notifyListeners();
    try {
      final params = {
        'p_title': title.trim().isEmpty ? 'بطولة الفرسان الحية' : title.trim(),
        'p_category_id': categoryId,
        'p_question_ids': questionIds,
      };
      Map<String, dynamic> raw;
      if (rpcOverride != null) {
        raw = await rpcOverride!('create_live_quiz_session', params);
      } else {
        final client = _safeClient();
        if (client == null) throw Exception('الاتصال غير متاح');
        final res = await client
            .rpc('create_live_quiz_session', params: params)
            .timeout(const Duration(seconds: 6));
        raw = Map<String, dynamic>.from(res as Map);
      }
      _activeSession = LiveSessionModel.fromJson(raw);
      _participants.clear();
      _openBroadcastChannel(_activeSession!.id);
      notifyListeners();
      return raw;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<LiveSessionModel> joinByPin(String pinCode) async {
    if (!isAuthenticated) {
      throw Exception('يلزم تسجيل الدخول بحساب Google للانضمام للبطولة');
    }
    final cleanPin = pinCode.trim();
    if (cleanPin.length < 5) {
      throw Exception('أدخل رمز الغرفة المكون من 5 أرقام');
    }
    _isBusy = true;
    notifyListeners();
    try {
      final profile = ProfileService.instance.activeProfile;
      final params = {
        'p_pin_code': cleanPin,
        'p_display_name': profile?.name ?? 'متسابق',
        'p_avatar_index': profile?.avatarIndex ?? 0,
      };
      Map<String, dynamic> raw;
      if (rpcOverride != null) {
        raw = await rpcOverride!('join_live_quiz_session', params);
      } else {
        final client = _safeClient();
        if (client == null) throw Exception('الاتصال غير متاح');
        final res = await client
            .rpc('join_live_quiz_session', params: params)
            .timeout(const Duration(seconds: 6));
        raw = Map<String, dynamic>.from(res as Map);
      }
      final session = LiveSessionModel.fromJson(
        Map<String, dynamic>.from(raw['session'] as Map),
      );
      final pList = ((raw['participants'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => LiveParticipantModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _activeSession = session;
      _participants
        ..clear()
        ..addAll(pList);
      _openBroadcastChannel(session.id);

      // Announce arrival cleanly over broadcast so Host UI updates in <50ms
      final myUid = _safeClient()?.auth.currentUser?.id ?? 'me';
      unawaited(
        _sendBroadcast('participant_joined', {
          'user_id': myUid,
          'display_name': profile?.name ?? 'متسابق',
          'avatar_index': profile?.avatarIndex ?? 0,
        }),
      );
      notifyListeners();
      return session;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> hostPushState({
    required String status,
    required int questionIndex,
  }) async {
    final session = _activeSession;
    if (session == null) return;
    final params = {
      'p_session_id': session.id,
      'p_status': status,
      'p_question_index': questionIndex,
    };
    Map<String, dynamic> raw;
    if (rpcOverride != null) {
      raw = await rpcOverride!('update_live_quiz_session_state', params);
    } else {
      final client = _safeClient();
      if (client == null) return;
      final res = await client
          .rpc('update_live_quiz_session_state', params: params)
          .timeout(const Duration(seconds: 5));
      raw = Map<String, dynamic>.from(res as Map);
    }
    _activeSession = LiveSessionModel.fromJson(raw);
    final eventType = status == 'finished' ? 'finish' : 'question';
    await _sendBroadcast(eventType, {
      'question_index': questionIndex,
      'leaderboard': _participants
          .map(
            (p) => {
              'session_id': p.sessionId,
              'user_id': p.userId,
              'display_name': p.displayName,
              'avatar_index': p.avatarIndex,
              'score': p.score,
              'correct_count': p.correctCount,
            },
          )
          .toList(),
    });
    notifyListeners();
  }

  Future<void> hostRevealLeaderboard(int questionIndex) async {
    await _sendBroadcast('reveal', {
      'question_index': questionIndex,
      'leaderboard': _participants
          .map(
            (p) => {
              'session_id': p.sessionId,
              'user_id': p.userId,
              'display_name': p.displayName,
              'avatar_index': p.avatarIndex,
              'score': p.score,
              'correct_count': p.correctCount,
            },
          )
          .toList(),
    });
  }

  Future<void> submitAnswer({
    required int pointsDelta,
    required bool isCorrect,
  }) async {
    final session = _activeSession;
    if (session == null) return;
    final params = {
      'p_session_id': session.id,
      'p_points_delta': pointsDelta.clamp(0, 150),
      'p_is_correct': isCorrect,
    };
    Map<String, dynamic>? updated;
    if (rpcOverride != null) {
      updated = await rpcOverride!('submit_live_quiz_answer', params);
    } else {
      final client = _safeClient();
      if (client == null) return;
      final res = await client
          .rpc('submit_live_quiz_answer', params: params)
          .timeout(const Duration(seconds: 5));
      if (res is Map) updated = Map<String, dynamic>.from(res);
    }
    if (updated != null) {
      final p = LiveParticipantModel.fromJson(updated);
      _upsertParticipant(p);
      unawaited(
        _sendBroadcast('score_update', {
          'user_id': p.userId,
          'display_name': p.displayName,
          'avatar_index': p.avatarIndex,
          'score': p.score,
          'correct_count': p.correctCount,
        }),
      );
      notifyListeners();
    }
  }

  void _openBroadcastChannel(String sessionId) {
    if (rpcOverride != null) return;
    if (!allowRealtimeInTests && _isRunningUnderFlutterTest()) return;
    final client = _safeClient();
    if (client == null) return;

    if (_channel != null) {
      unawaited(client.removeChannel(_channel!));
      _channel = null;
    }

    final ch = client.channel('live_arena_$sessionId');
    ch
        .onBroadcast(
          event: 'arena_event',
          callback: (payload) => _handleIncomingPayload(payload),
        )
        .subscribe();
    _channel = ch;
  }

  void _handleIncomingPayload(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? '').toString();
    final qIdx = (payload['question_index'] as num?)?.toInt() ?? 0;

    if (type == 'participant_joined' || type == 'score_update') {
      final p = LiveParticipantModel(
        sessionId: _activeSession?.id ?? '',
        userId: (payload['user_id'] ?? '').toString(),
        displayName: (payload['display_name'] ?? 'متسابق').toString(),
        avatarIndex: (payload['avatar_index'] as num?)?.toInt() ?? 0,
        score: (payload['score'] as num?)?.toInt() ?? 0,
        correctCount: (payload['correct_count'] as num?)?.toInt() ?? 0,
      );
      if (p.userId.isNotEmpty) {
        _upsertParticipant(p);
        notifyListeners();
      }
    }

    final boardRaw = payload['leaderboard'];
    final board = boardRaw is List
        ? boardRaw
            .whereType<Map>()
            .map((e) => LiveParticipantModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : participants;

    if (type == 'question' && _activeSession != null) {
      _activeSession = LiveSessionModel(
        id: _activeSession!.id,
        pinCode: _activeSession!.pinCode,
        title: _activeSession!.title,
        categoryId: _activeSession!.categoryId,
        hostId: _activeSession!.hostId,
        status: 'active',
        currentQuestionIndex: qIdx,
        questionIds: _activeSession!.questionIds,
        participantsCount: _participants.length,
      );
    } else if (type == 'finish' && _activeSession != null) {
      _activeSession = LiveSessionModel(
        id: _activeSession!.id,
        pinCode: _activeSession!.pinCode,
        title: _activeSession!.title,
        categoryId: _activeSession!.categoryId,
        hostId: _activeSession!.hostId,
        status: 'finished',
        currentQuestionIndex: qIdx,
        questionIds: _activeSession!.questionIds,
        participantsCount: _participants.length,
      );
    }

    final ec = _eventController;
    if (ec != null && !ec.isClosed) {
      ec.add(
        LiveArenaBroadcastEvent(
          type: type,
          questionIndex: qIdx,
          leaderboard: board,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> _sendBroadcast(String type, Map<String, dynamic> data) async {
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch
          .sendBroadcastMessage(
            event: 'arena_event',
            payload: {'type': type, ...data},
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('LiveTournamentService broadcast notice: $e');
    }
  }

  void _upsertParticipant(LiveParticipantModel p) {
    final idx = _participants.indexWhere((x) => x.userId == p.userId);
    if (idx >= 0) {
      _participants[idx] = p;
    } else {
      _participants.add(p);
    }
  }

  /// Strictly detaches Broadcast channel when leaving Host or Participant screen.
  Future<void> leaveSession() async {
    final ch = _channel;
    _channel = null;
    _activeSession = null;
    _participants.clear();
    if (ch != null) {
      try {
        await _safeClient()?.removeChannel(ch);
      } catch (e) {
        debugPrint('LiveTournamentService leave notice: $e');
      }
    }
    notifyListeners();
  }
}
