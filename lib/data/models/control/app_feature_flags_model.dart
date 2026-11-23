/// Feature toggles controlled remotely via `app_release_config.feature_flags`.
class AppFeatureFlags {
  final bool onlineMultiplayer;
  final bool ghostMatches;
  final bool privateRooms;
  final bool knightsStore;
  final bool showEventBanner;
  final bool dailyChallenges;
  final bool royalInbox;
  final bool liveAnnouncementPing;
  final bool wiseTeacherMode;
  final bool diwanChat;
  final bool guildsArenas;
  final bool quickPhrases;
  final bool liveArenaHostRestricted;
  final Map<String, bool> rawFlags;

  const AppFeatureFlags({
    this.onlineMultiplayer = true,
    this.ghostMatches = true,
    this.privateRooms = true,
    this.knightsStore = true,
    this.showEventBanner = true,
    this.dailyChallenges = true,
    this.royalInbox = true,
    this.liveAnnouncementPing = true,
    this.wiseTeacherMode = true,
    this.diwanChat = true,
    this.guildsArenas = true,
    this.quickPhrases = true,
    this.liveArenaHostRestricted = true,
    this.rawFlags = const {
      'online_multiplayer': true,
      'ghost_matches': true,
      'private_rooms': true,
      'knights_store': true,
      'show_event_banner': true,
      'daily_challenges': true,
      'royal_inbox': true,
      'live_announcement_ping': true,
      'wise_teacher_mode': true,
      'diwan_chat': true,
      'guilds_arenas': true,
      'quick_phrases': true,
      'live_arena_host_restricted': true,
    },
  });

  factory AppFeatureFlags.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const AppFeatureFlags();
    final map = <String, bool>{};
    for (final entry in json.entries) {
      final v = entry.value;
      if (v is bool) {
        map[entry.key] = v;
      } else if (v is String) {
        map[entry.key] = v.toLowerCase() == 'true';
      }
    }
    return AppFeatureFlags(
      onlineMultiplayer: map['online_multiplayer'] ?? true,
      ghostMatches: map['ghost_matches'] ?? true,
      privateRooms: map['private_rooms'] ?? true,
      knightsStore: map['knights_store'] ?? true,
      showEventBanner: map['show_event_banner'] ?? true,
      dailyChallenges: map['daily_challenges'] ?? true,
      royalInbox: map['royal_inbox'] ?? true,
      liveAnnouncementPing: map['live_announcement_ping'] ?? true,
      wiseTeacherMode: map['wise_teacher_mode'] ?? true,
      diwanChat: map['diwan_chat'] ?? true,
      guildsArenas: map['guilds_arenas'] ?? true,
      quickPhrases: map['quick_phrases'] ?? true,
      liveArenaHostRestricted: map['live_arena_host_restricted'] ?? true,
      rawFlags: map.isEmpty ? const AppFeatureFlags().rawFlags : map,
    );
  }

  bool isEnabled(String key, {bool defaultValue = true}) =>
      rawFlags[key] ?? defaultValue;

  Map<String, dynamic> toJson() => {
        ...rawFlags,
        'online_multiplayer': onlineMultiplayer,
        'ghost_matches': ghostMatches,
        'private_rooms': privateRooms,
        'knights_store': knightsStore,
        'show_event_banner': showEventBanner,
        'daily_challenges': dailyChallenges,
        'royal_inbox': royalInbox,
        'live_announcement_ping': liveAnnouncementPing,
        'wise_teacher_mode': wiseTeacherMode,
        'diwan_chat': diwanChat,
        'guilds_arenas': guildsArenas,
        'quick_phrases': quickPhrases,
        'live_arena_host_restricted': liveArenaHostRestricted,
      };
}
