import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/shared_prefs_service.dart';
import '../models/app_control_models.dart';
import '../models/player_profile_model.dart';
import 'app_control_service.dart';
import 'profile_service.dart';

typedef InboxFetcher = Future<List<Map<String, dynamic>>> Function({
  String? playerCode,
  int limit,
});

typedef InboxMarkAllReader = Future<int> Function({String? playerCode});

/// On-demand, offline-cached Royal Inbox service backed by `get_player_inbox`
/// and `mark_all_inbox_read` with zero background WebSocket overhead.
class RoyalInboxService extends ChangeNotifier {
  static final RoyalInboxService instance = RoyalInboxService._();
  RoyalInboxService._() {
    AppControlService.instance.pendingAnnouncementsNotifier.addListener(
      _recomputeUnreadCount,
    );
  }

  List<RoyalInboxMessage> _messages = [];
  bool _isLoading = false;
  bool _hasHydratedCache = false;
  String? _lastError;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  @visibleForTesting
  InboxFetcher? inboxFetcherOverride;

  @visibleForTesting
  InboxMarkAllReader? markAllReaderOverride;

  List<RoyalInboxMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  int get unreadCount => unreadCountNotifier.value;

  List<RoyalInboxMessage> get announcementMessages =>
      _messages.where((m) => !m.isRewardNotice).toList();

  List<RoyalInboxMessage> get rewardMessages =>
      _messages.where((m) => m.isRewardNotice).toList();

  @visibleForTesting
  void resetForTesting() {
    inboxFetcherOverride = null;
    markAllReaderOverride = null;
    _messages = [];
    _isLoading = false;
    _hasHydratedCache = false;
    _lastError = null;
    unreadCountNotifier.value = 0;
  }

  String? _resolvePlayerCode() {
    final code = ProfileService.instance.activeProfile?.playerCode;
    if (PlayerProfile.isValidPlayerCode(code)) {
      return code!.trim().toUpperCase();
    }
    return SharedPrefsService.getDevicePlayerCode();
  }

  /// Hydrates cached inbox messages instantaneously from SharedPreferences.
  Future<void> initFromCache() async {
    if (_hasHydratedCache) return;
    _hasHydratedCache = true;
    await SharedPrefsService.init();
    final raw = SharedPrefsService.getCachedInboxJson();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _messages = list
            .whereType<Map>()
            .map(
              (m) => RoyalInboxMessage.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList();
      } catch (e) {
        debugPrint('RoyalInboxService cache parse notice: $e');
      }
    }
    _recomputeUnreadCount();
  }

  /// Fetches fresh inbox history on-demand (when the player opens Inbox).
  Future<List<RoyalInboxMessage>> fetchInbox({int limit = 25}) async {
    await initFromCache();
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final code = _resolvePlayerCode();
      List<Map<String, dynamic>> rawRows = const [];
      if (inboxFetcherOverride != null) {
        rawRows = await inboxFetcherOverride!(
          playerCode: code,
          limit: limit,
        ).timeout(const Duration(seconds: 6));
      } else {
        final client = Supabase.instance.client;
        final res = await client.rpc(
          'get_player_inbox',
          params: {
            if (code != null) 'p_player_code': code,
            'p_limit': limit.clamp(1, 50),
          },
        ).timeout(const Duration(seconds: 6));
        if (res is List) {
          rawRows = res
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      final seenLocally = SharedPrefsService.getSeenAnnouncementIds();
      _messages = rawRows.map((row) {
        final item = RoyalInboxMessage.fromJson(row);
        if (!item.isRead && seenLocally.contains(item.announcement.id)) {
          return item.copyWith(isRead: true);
        }
        return item;
      }).toList();

      await _persistCache();
      _recomputeUnreadCount();
      return messages;
    } catch (e) {
      _lastError = 'تعذر تحديث صندوق الرسائل حالياً (يعرض المحفوظ محلياً)';
      debugPrint('RoyalInboxService fetch notice: $e');
      _recomputeUnreadCount();
      return messages;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marks a single message read locally (0ms) and sends receipt via AppControlService.
  Future<void> markMessageRead(RoyalInboxMessage item) async {
    if (!item.isRead) {
      _messages = _messages
          .map(
            (m) => m.announcement.id == item.announcement.id
                ? m.copyWith(isRead: true)
                : m,
          )
          .toList();
      await _persistCache();
    }
    await AppControlService.instance.markAnnouncementSeen(
      item.announcement,
      playerCode: _resolvePlayerCode(),
    );
    _recomputeUnreadCount();
    notifyListeners();
  }

  /// Marks all active inbox messages read locally and on Supabase in one batch.
  Future<void> markAllRead() async {
    if (_messages.isEmpty &&
        AppControlService.instance.pendingAnnouncementsNotifier.value.isEmpty) {
      return;
    }

    for (final msg in _messages) {
      if (!msg.isRead) {
        await SharedPrefsService.markAnnouncementSeen(msg.announcement.id);
      }
    }
    for (final pending
        in AppControlService.instance.pendingAnnouncementsNotifier.value) {
      await SharedPrefsService.markAnnouncementSeen(pending.id);
    }

    _messages = _messages.map((m) => m.copyWith(isRead: true)).toList();
    await _persistCache();
    _recomputeUnreadCount();
    notifyListeners();

    try {
      final code = _resolvePlayerCode();
      if (markAllReaderOverride != null) {
        await markAllReaderOverride!(playerCode: code)
            .timeout(const Duration(seconds: 6));
      } else {
        await Supabase.instance.client.rpc(
          'mark_all_inbox_read',
          params: {
            if (code != null) 'p_player_code': code,
          },
        ).timeout(const Duration(seconds: 6));
      }
      await AppControlService.instance.syncControlState(force: true);
    } catch (e) {
      debugPrint('RoyalInboxService markAllRead cloud notice: $e');
    }
  }

  void _recomputeUnreadCount() {
    final seenLocally = SharedPrefsService.getSeenAnnouncementIds();
    final unreadIds = <String>{};

    for (final pending
        in AppControlService.instance.pendingAnnouncementsNotifier.value) {
      if (pending.id.isNotEmpty && !seenLocally.contains(pending.id)) {
        unreadIds.add(pending.id);
      }
    }
    for (final m in _messages) {
      if (!m.isRead &&
          m.announcement.id.isNotEmpty &&
          !seenLocally.contains(m.announcement.id)) {
        unreadIds.add(m.announcement.id);
      }
    }
    unreadCountNotifier.value = unreadIds.length;
  }

  Future<void> _persistCache() async {
    try {
      final encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await SharedPrefsService.setCachedInboxJson(encoded);
    } catch (e) {
      debugPrint('RoyalInboxService cache write notice: $e');
    }
  }
}
