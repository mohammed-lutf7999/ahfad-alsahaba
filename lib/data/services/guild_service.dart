import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/guild_model.dart';
import 'profile_service.dart';

typedef GuildsOverviewFetcher = Future<Map<String, dynamic>> Function({int limit});
typedef GuildActionHandler = Future<Map<String, dynamic>> Function(
  String rpcName,
  Map<String, dynamic> params,
);

/// Manages Clans / Guilds («الكتائب والرايات» + «معركة الجمعة الكبرى»).
class GuildService extends ChangeNotifier {
  static final GuildService instance = GuildService._();
  GuildService._();

  GuildsOverviewData _overview = const GuildsOverviewData();
  bool _isLoading = false;
  String? _lastError;

  @visibleForTesting
  GuildsOverviewFetcher? overviewFetcherOverride;

  @visibleForTesting
  GuildActionHandler? rpcOverride;

  @visibleForTesting
  bool? isAuthenticatedOverride;

  GuildsOverviewData get overview => _overview;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

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

  @visibleForTesting
  void resetForTesting() {
    overviewFetcherOverride = null;
    rpcOverride = null;
    isAuthenticatedOverride = null;
    _overview = const GuildsOverviewData();
    _isLoading = false;
    _lastError = null;
  }

  Future<GuildsOverviewData> fetchOverview({int limit = 25}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      Map<String, dynamic>? raw;
      if (overviewFetcherOverride != null) {
        raw = await overviewFetcherOverride!(limit: limit)
            .timeout(const Duration(seconds: 6));
      } else {
        final client = _safeClient();
        if (client != null) {
          final res = await client.rpc(
            'get_guilds_overview',
            params: {'p_limit': limit},
          ).timeout(const Duration(seconds: 6));
          if (res is Map) {
            raw = Map<String, dynamic>.from(res);
          }
        }
      }
      if (raw != null) {
        _overview = GuildsOverviewData.fromJson(raw);
      }
    } catch (e) {
      _lastError = 'تعذر تحميل بيانات الكتائب حالياً';
      debugPrint('GuildService overview notice: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _overview;
  }

  Future<String?> createGuild({
    required String name,
    String description = '',
    int bannerIcon = 0,
  }) async {
    if (!isAuthenticated) {
      return 'يلزم تسجيل الدخول بحساب Google لتأسيس كتيبة';
    }
    final cleanName = name.trim();
    if (cleanName.length < 3 || cleanName.length > 30) {
      return 'اسم الكتيبة يجب أن يكون بين 3 و 30 حرفاً';
    }
    final profile = ProfileService.instance.activeProfile;
    try {
      final params = {
        'p_name': cleanName,
        'p_description': description.trim(),
        'p_banner_icon': bannerIcon,
        'p_leader_name': profile?.name ?? 'قائد الكتيبة',
        'p_avatar_index': profile?.avatarIndex ?? 0,
      };
      if (rpcOverride != null) {
        await rpcOverride!('create_guild', params);
      } else {
        final client = _safeClient();
        if (client == null) return 'الاتصال غير متاح';
        await client.rpc('create_guild', params: params).timeout(const Duration(seconds: 6));
      }
      await fetchOverview();
      return null;
    } catch (e) {
      return _friendlyRpcError(e, fallback: 'تعذر تأسيس الكتيبة');
    }
  }

  Future<String?> joinGuild(String guildId) async {
    if (!isAuthenticated) {
      return 'يلزم تسجيل الدخول بحساب Google للانضمام للكتيبة';
    }
    final profile = ProfileService.instance.activeProfile;
    try {
      final params = {
        'p_guild_id': guildId,
        'p_display_name': profile?.name ?? 'فارس',
        'p_avatar_index': profile?.avatarIndex ?? 0,
      };
      if (rpcOverride != null) {
        await rpcOverride!('join_guild', params);
      } else {
        final client = _safeClient();
        if (client == null) return 'الاتصال غير متاح';
        await client.rpc('join_guild', params: params).timeout(const Duration(seconds: 6));
      }
      await fetchOverview();
      return null;
    } catch (e) {
      return _friendlyRpcError(e, fallback: 'تعذر الانضمام للكتيبة');
    }
  }

  Future<String?> leaveGuild() async {
    if (!isAuthenticated) return 'يلزم تسجيل الدخول';
    try {
      if (rpcOverride != null) {
        await rpcOverride!('leave_guild', {});
      } else {
        final client = _safeClient();
        if (client == null) return 'الاتصال غير متاح';
        await client.rpc('leave_guild').timeout(const Duration(seconds: 6));
      }
      await fetchOverview();
      return null;
    } catch (e) {
      return _friendlyRpcError(e, fallback: 'تعذر مغادرة الكتيبة');
    }
  }

  /// Safely adds earned quiz/match points to the player's Friday Grand Battle tally.
  Future<void> contributeScore(int points) async {
    if (points <= 0 || !isAuthenticated) return;
    try {
      if (rpcOverride != null) {
        await rpcOverride!('contribute_guild_score', {'p_points': points});
        return;
      }
      final client = _safeClient();
      if (client == null) return;
      await client
          .rpc('contribute_guild_score', params: {'p_points': points})
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('GuildService contribute notice: $e');
    }
  }

  String _friendlyRpcError(Object err, {required String fallback}) {
    final s = err.toString();
    if (s.contains('اكتمل')) return 'اكتمل عدد أعضاء الكتيبة (30 عضواً)';
    if (s.contains('أنت منضم') || s.contains('أنت عضو')) {
      return 'أنت عضو بالفعل في كتيبة؛ غادرها أولاً للانتقال';
    }
    if (s.contains('duplicate') || s.contains('23505')) {
      return 'اسم الكتيبة مستخدم بالفعل، اختر اسماً آخر';
    }
    return fallback;
  }
}
