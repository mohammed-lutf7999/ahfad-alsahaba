import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/profanity_filter.dart';
import '../models/chat_message_model.dart';
import 'admin_service.dart';
import 'app_control_service.dart';
import 'multiplayer_service.dart';
import 'profile_service.dart';

typedef DiwanFetcher = Future<List<Map<String, dynamic>>> Function({
  required String channel,
  int limit,
});

typedef DiwanSender = Future<Map<String, dynamic>> Function({
  required String content,
  required String channel,
  required String displayName,
  required int avatarIndex,
  required String userRank,
  String? playerCode,
  required String messageKind,
  String? inviteRoomCode,
});

typedef DiwanChallengeCreator = Future<PrivateRoomResult> Function();

/// On-demand Realtime chat service for «ديوان الأحفاد».
/// Opens its Supabase Realtime channel ONLY while `GlobalChatBottomSheet` is mounted
/// and removes it strictly in `closeChannel()` (`0` idle WebSocket connections).
class ChatService extends ChangeNotifier {
  static final ChatService instance = ChatService._();
  ChatService._();

  final List<ChatMessageModel> _messages = [];
  RealtimeChannel? _channel;
  String? _activeChannelName;
  bool _isLoading = false;
  bool _isSending = false;
  String? _lastError;
  DateTime? _lastSentAt;

  @visibleForTesting
  DiwanFetcher? messagesFetcherOverride;

  @visibleForTesting
  DiwanSender? messageSenderOverride;

  @visibleForTesting
  DiwanChallengeCreator? challengeCreatorOverride;

  @visibleForTesting
  bool? isAuthenticatedOverride;

  @visibleForTesting
  DateTime Function()? nowProvider;

  @visibleForTesting
  bool allowRealtimeInTests = false;

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get lastError => _lastError;
  bool get hasActiveChannel => _channel != null;

  DateTime _now() => nowProvider?.call() ?? DateTime.now().toUtc();

  SupabaseClient? _safeClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isCurrentUserAuthenticated {
    if (isAuthenticatedOverride != null) return isAuthenticatedOverride!;
    return _safeClient()?.auth.currentUser != null;
  }

  String? get currentUserId => _safeClient()?.auth.currentUser?.id;

  bool _isRunningUnderFlutterTest() {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    messagesFetcherOverride = null;
    messageSenderOverride = null;
    challengeCreatorOverride = null;
    isAuthenticatedOverride = null;
    nowProvider = null;
    allowRealtimeInTests = false;
    _messages.clear();
    _channel = null;
    _activeChannelName = null;
    _isLoading = false;
    _isSending = false;
    _lastError = null;
    _lastSentAt = null;
  }

  /// Opens the on-demand Realtime channel and loads recent 24h messages.
  Future<void> openChannel([String channelName = 'global']) async {
    final normalized =
        channelName.trim().isEmpty ? 'global' : channelName.trim().toLowerCase();
    if (_activeChannelName != normalized) {
      await closeChannel();
    }
    _activeChannelName = normalized;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      List<Map<String, dynamic>> rawList = const [];
      if (messagesFetcherOverride != null) {
        rawList = await messagesFetcherOverride!(
          channel: normalized,
          limit: 40,
        ).timeout(const Duration(seconds: 6));
      } else {
        final client = _safeClient();
        if (client != null) {
          final res = await client.rpc(
            'get_diwan_messages',
            params: {'p_channel': normalized, 'p_limit': 40},
          ).timeout(const Duration(seconds: 6));
          if (res is List) {
            rawList = res
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      }

      if (_activeChannelName != normalized) return;
      _messages
        ..clear()
        ..addAll(rawList.map(ChatMessageModel.fromJson));
      _subscribeRealtime(normalized);
    } catch (e) {
      _lastError = 'تعذر تحميل رسائل الديوان حالياً';
      debugPrint('ChatService openChannel notice: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeRealtime(String channelName) {
    if (messagesFetcherOverride != null) return;
    if (!allowRealtimeInTests && _isRunningUnderFlutterTest()) return;
    if (!AppControlService.instance.featureFlagsNotifier.value.diwanChat) {
      return;
    }
    final client = _safeClient();
    if (client == null || _channel != null) return;

    try {
      final ch = client.channel('diwan_$channelName');
      ch
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'channel',
              value: channelName,
            ),
            callback: (payload) {
              final record = payload.newRecord;
              if (record.isEmpty) return;
              final msg = ChatMessageModel.fromJson(
                Map<String, dynamic>.from(record),
              );
              _upsertMessage(msg);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'chat_messages',
            callback: (payload) {
              final deletedId = payload.oldRecord['id']?.toString();
              if (deletedId != null && deletedId.isNotEmpty) {
                _messages.removeWhere((m) => m.id == deletedId);
                notifyListeners();
              }
            },
          )
          .subscribe();
      _channel = ch;
    } catch (e) {
      debugPrint('ChatService Realtime subscribe notice: $e');
    }
  }

  void _upsertMessage(ChatMessageModel msg) {
    if (msg.id.isEmpty) return;
    final idx = _messages.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      _messages[idx] = msg;
    } else {
      _messages.add(msg);
      if (_messages.length > 80) {
        _messages.removeRange(0, _messages.length - 80);
      }
    }
    notifyListeners();
  }

  /// Detaches the Realtime WebSocket channel immediately when leaving chat.
  Future<void> closeChannel() async {
    final ch = _channel;
    _channel = null;
    _activeChannelName = null;
    if (ch == null) return;
    try {
      await _safeClient()?.removeChannel(ch);
    } catch (e) {
      debugPrint('ChatService closeChannel notice: $e');
    }
  }

  String _resolveSenderRank() {
    final profile = ProfileService.instance.activeProfile;
    if (profile == null) return 'فارس';
    return profile.effectiveTitle;
  }

  String? _guardDiwanParticipation() {
    final control = AppControlService.instance;
    final isAdmin = control.isAdminNotifier.value;
    if (!isAdmin && !control.featureFlagsNotifier.value.diwanChat) {
      return 'ديوان الأحفاد متوقف مؤقتاً من الإدارة';
    }
    if (!isCurrentUserAuthenticated) {
      return 'يلزم تسجيل الدخول بحساب Google للمشاركة في الديوان';
    }
    final perms = control.playerPermissionsNotifier.value;
    if (!isAdmin && perms.isEffectivelyBannedNow) {
      return perms.banReason.trim().isNotEmpty
          ? 'تم حظر حسابك من الإدارة: ${perms.banReason.trim()}'
          : 'تم حظر حسابك مؤقتاً أو دائماً من الإدارة';
    }
    if (!isAdmin && !perms.canUseDiwan) {
      return 'تم منعك من المشاركة في ديوان الأحفاد من الإدارة';
    }
    if (!isAdmin && perms.isEffectivelyDiwanMutedNow) {
      return 'تم كتم مشاركتك في الديوان مؤقتاً بسبب مخالفة الآداب';
    }
    return null;
  }

  /// Sends a text or challenge_invite message via `send_diwan_message` with
  /// client + server profanity guard and 3-second cooldown.
  Future<String?> sendMessage(
    String rawContent, {
    String channel = 'global',
    String messageKind = 'text',
    String? inviteRoomCode,
  }) async {
    final guardErr = _guardDiwanParticipation();
    if (guardErr != null) {
      return guardErr;
    }

    final validationError = ProfanityFilter.validateMessage(rawContent);
    if (validationError != null) {
      return validationError;
    }

    final now = _now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(seconds: 3)) {
      return 'انتظر 3 ثوانٍ قبل إرسال رسالة جديدة';
    }

    final profile = ProfileService.instance.activeProfile;
    final displayName = (profile?.name ?? 'فارس').trim().isEmpty
        ? 'فارس'
        : profile!.name.trim();
    final avatarIndex = profile?.avatarIndex ?? 0;
    final userRank = _resolveSenderRank();
    final playerCode = profile?.playerCode;

    _isSending = true;
    notifyListeners();

    try {
      Map<String, dynamic>? row;
      if (messageSenderOverride != null) {
        row = await messageSenderOverride!(
          content: rawContent.trim(),
          channel: channel,
          displayName: displayName,
          avatarIndex: avatarIndex,
          userRank: userRank,
          playerCode: playerCode,
          messageKind: messageKind,
          inviteRoomCode: inviteRoomCode,
        ).timeout(const Duration(seconds: 6));
      } else {
        final client = _safeClient();
        if (client == null) return 'الاتصال غير متاح حالياً';
        final res = await client.rpc(
          'send_diwan_message',
          params: {
            'p_content': rawContent.trim(),
            'p_channel': channel,
            'p_display_name': displayName,
            'p_avatar_index': avatarIndex,
            'p_user_rank': userRank,
            if (playerCode != null) 'p_player_code': playerCode,
            'p_message_kind': messageKind,
            if (inviteRoomCode != null) 'p_invite_room_code': inviteRoomCode,
          },
        ).timeout(const Duration(seconds: 6));
        if (res is Map) {
          row = Map<String, dynamic>.from(res);
        }
      }

      _lastSentAt = now;
      if (row != null) {
        _upsertMessage(ChatMessageModel.fromJson(row));
      }
      return null;
    } catch (e) {
      final msg = e is PostgrestException ? e.message.trim() : e.toString().trim();
      if (msg.contains('انتظر')) return 'انتظر 3 ثوانٍ قبل إرسال رسالة جديدة';
      if (msg.contains('الآداب')) {
        return 'يرجى الالتزام بالآداب الإسلامية وتجنب الألفاظ أو الروابط المخالفة';
      }
      if (msg.contains('حظر') ||
          msg.contains('منع') ||
          msg.contains('كتم') ||
          msg.contains('متوقف')) {
        return msg;
      }
      debugPrint('ChatService sendMessage notice: $e');
      return 'تعذر إرسال الرسالة، حاول مجدداً';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Creates a private room and broadcasts an interactive challenge card in the chat.
  Future<PrivateRoomResult> sendChallengeInvite({String channel = 'global'}) async {
    if (!isCurrentUserAuthenticated) {
      return PrivateRoomResult(
        error: 'يلزم تسجيل الدخول بحساب Google لإنشاء تحدٍ من الديوان',
      );
    }
    final diwanGuard = _guardDiwanParticipation();
    if (diwanGuard != null) {
      return PrivateRoomResult(error: diwanGuard);
    }

    final room = challengeCreatorOverride != null
        ? await challengeCreatorOverride!()
        : await MultiplayerService.instance.createPrivateRoom();

    if (!room.success || room.roomCode == null) {
      return PrivateRoomResult(
        error: room.error ?? 'تعذر إنشاء غرفة التحدي الخاصة',
      );
    }

    final err = await sendMessage(
      'أدعوكم لنزال معرفي شريف! انضموا عبر الرمز #${room.roomCode}',
      channel: channel,
      messageKind: 'challenge_invite',
      inviteRoomCode: room.roomCode,
    );
    if (err != null) {
      return PrivateRoomResult(error: err);
    }
    return room;
  }

  Future<bool> reportMessage(
    String messageId, {
    String reason = 'مخالفة آداب الديوان',
  }) async {
    final client = _safeClient();
    if (client == null || !isCurrentUserAuthenticated) return false;
    try {
      await client.rpc(
        'report_diwan_message',
        params: {
          'p_message_id': messageId,
          'p_reason': reason.trim().isEmpty ? 'مخالفة آداب الديوان' : reason.trim(),
        },
      ).timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('ChatService report notice: $e');
      return false;
    }
  }

  Future<bool> adminModerate({
    required String action,
    String? messageId,
    String? targetUserId,
    int muteHours = 24,
    String reason = '',
  }) async {
    final client = _safeClient();
    if (client == null) return false;
    try {
      final res = await client.rpc(
        'admin_moderate_diwan',
        params: {
          'p_action': action,
          if (messageId != null) 'p_message_id': messageId,
          if (targetUserId != null) 'p_target_user_id': targetUserId,
          'p_mute_hours': muteHours.clamp(1, 720),
          'p_reason': reason,
        },
      ).timeout(const Duration(seconds: 6));
      if (action == 'delete_message' && messageId != null) {
        _messages.removeWhere((m) => m.id == messageId);
        notifyListeners();
      }
      if ((action == 'mute_user' || action == 'unmute_user') &&
          targetUserId != null) {
        final playerCode = res is Map ? res['player_code']?.toString() : null;
        unawaited(
          AdminService().broadcastControlPing(
            targetCode: (playerCode != null && playerCode.trim().isNotEmpty)
                ? playerCode.trim()
                : 'SINGLE',
            targetUserId: targetUserId,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('ChatService adminModerate notice: $e');
      return false;
    }
  }
}
