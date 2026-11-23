/// Per-player dynamic moderation, ban, mute & tri-state Live Arena hosting permissions.
class PlayerPermissions {
  final bool isBanned;
  final DateTime? bannedUntil;
  final String banReason;
  final bool isDiwanMuted;
  final DateTime? diwanMutedUntil;
  final String diwanMuteReason;
  final bool canUseOnline;
  final bool canUseDiwan;
  final bool canUseGuilds;

  /// Tri-state override:
  /// - `null`: inherit global `live_arena_host_restricted` policy
  /// - `true`: authorized Teacher/Host override (always allowed when `guilds_arenas` is ON)
  /// - `false`: explicitly denied individually (even in open mode)
  final bool? canHostLiveArenas;
  final bool effectiveCanHostLiveArenas;
  final String notes;

  const PlayerPermissions({
    this.isBanned = false,
    this.bannedUntil,
    this.banReason = '',
    this.isDiwanMuted = false,
    this.diwanMutedUntil,
    this.diwanMuteReason = '',
    this.canUseOnline = true,
    this.canUseDiwan = true,
    this.canUseGuilds = true,
    this.canHostLiveArenas,
    this.effectiveCanHostLiveArenas = false,
    this.notes = '',
  });

  bool isEffectivelyBannedAt(DateTime nowUtc) {
    if (!isBanned) return false;
    if (bannedUntil == null) return true;
    return bannedUntil!.toUtc().isAfter(nowUtc.toUtc());
  }

  bool get isEffectivelyBannedNow => isEffectivelyBannedAt(DateTime.now().toUtc());

  bool isEffectivelyDiwanMutedAt(DateTime nowUtc) {
    if (!isDiwanMuted) return false;
    if (diwanMutedUntil == null) return true;
    return diwanMutedUntil!.toUtc().isAfter(nowUtc.toUtc());
  }

  bool get isEffectivelyDiwanMutedNow =>
      isEffectivelyDiwanMutedAt(DateTime.now().toUtc());

  factory PlayerPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const PlayerPermissions();
    final rawHost = json['can_host_live_arenas'];
    bool? parsedHost;
    if (rawHost is bool) {
      parsedHost = rawHost;
    } else if (rawHost is String) {
      final norm = rawHost.trim().toLowerCase();
      if (norm == 'true') parsedHost = true;
      if (norm == 'false') parsedHost = false;
    }
    return PlayerPermissions(
      isBanned: json['is_banned'] as bool? ?? false,
      bannedUntil: json['banned_until'] != null
          ? DateTime.tryParse(json['banned_until'].toString())
          : null,
      banReason: (json['ban_reason'] as String?) ?? '',
      isDiwanMuted: json['is_diwan_muted'] as bool? ?? false,
      diwanMutedUntil: json['diwan_muted_until'] != null
          ? DateTime.tryParse(json['diwan_muted_until'].toString())
          : null,
      diwanMuteReason: (json['diwan_mute_reason'] as String?) ?? '',
      canUseOnline: json['can_use_online'] as bool? ?? true,
      canUseDiwan: json['can_use_diwan'] as bool? ?? true,
      canUseGuilds: json['can_use_guilds'] as bool? ?? true,
      canHostLiveArenas: parsedHost,
      effectiveCanHostLiveArenas:
          json['effective_can_host_live_arenas'] as bool? ??
              (parsedHost ?? false),
      notes: (json['notes'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'is_banned': isBanned,
        'banned_until': bannedUntil?.toUtc().toIso8601String(),
        'ban_reason': banReason,
        'is_diwan_muted': isDiwanMuted,
        'diwan_muted_until': diwanMutedUntil?.toUtc().toIso8601String(),
        'diwan_mute_reason': diwanMuteReason,
        'can_use_online': canUseOnline,
        'can_use_diwan': canUseDiwan,
        'can_use_guilds': canUseGuilds,
        'can_host_live_arenas': canHostLiveArenas,
        'effective_can_host_live_arenas': effectiveCanHostLiveArenas,
        'notes': notes,
      };
}
