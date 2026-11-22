enum DynamicEventActionType {
  openEventScreen('open_event_screen'),
  navigateRoute('navigate_route'),
  openUrl('open_url'),
  none('none');

  final String wireName;
  const DynamicEventActionType(this.wireName);

  static DynamicEventActionType fromWire(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? 'open_event_screen';
    return DynamicEventActionType.values.firstWhere(
      (e) => e.wireName == normalized,
      orElse: () => DynamicEventActionType.openEventScreen,
    );
  }
}

/// Cloud-controlled event displayed as a banner on HomeScreen and opened in-app.
class AppDynamicEvent {
  final String id;
  final String badgeText;
  final String title;
  final String subtitle;
  final String body;
  final String ctaLabel;
  final DynamicEventActionType actionType;
  final String actionTarget;
  final String themeColorHex;
  final String iconName;
  final int priority;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? updatedAt;

  const AppDynamicEvent({
    required this.id,
    this.badgeText = 'حدث نشط',
    required this.title,
    this.subtitle = '',
    this.body = '',
    this.ctaLabel = 'اكتشف الآن',
    this.actionType = DynamicEventActionType.openEventScreen,
    this.actionTarget = '',
    this.themeColorHex = '#D4AF37',
    this.iconName = 'auto_awesome',
    this.priority = 100,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    this.updatedAt,
  });

  bool isCurrentlyActiveAt(DateTime nowUtc) {
    if (!isActive) return false;
    if (startsAt != null && nowUtc.isBefore(startsAt!.toUtc())) return false;
    if (endsAt != null && !nowUtc.isBefore(endsAt!.toUtc())) return false;
    return true;
  }

  factory AppDynamicEvent.fromJson(Map<String, dynamic> json) {
    return AppDynamicEvent(
      id: json['id']?.toString() ?? '',
      badgeText: (json['badge_text'] as String?) ?? 'حدث نشط',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      ctaLabel: (json['cta_label'] as String?) ?? 'اكتشف الآن',
      actionType:
          DynamicEventActionType.fromWire(json['action_type'] as String?),
      actionTarget: (json['action_target'] as String?) ?? '',
      themeColorHex: (json['theme_color_hex'] as String?) ?? '#D4AF37',
      iconName: (json['icon_name'] as String?) ?? 'auto_awesome',
      priority: (json['priority'] as num?)?.toInt() ?? 100,
      isActive: json['is_active'] as bool? ?? true,
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'badge_text': badgeText,
        'title': title,
        'subtitle': subtitle,
        'body': body,
        'cta_label': ctaLabel,
        'action_type': actionType.wireName,
        'action_target': actionTarget,
        'theme_color_hex': themeColorHex,
        'icon_name': iconName,
        'priority': priority,
        'is_active': isActive,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

enum AnnouncementType {
  normal('normal'),
  mandatory('mandatory'),
  admin('admin'),
  motivational('motivational');

  final String wireName;
  const AnnouncementType(this.wireName);

  static AnnouncementType fromWire(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? 'normal';
    return AnnouncementType.values.firstWhere(
      (t) => t.wireName == normalized,
      orElse: () => AnnouncementType.normal,
    );
  }
}

/// Admin announcement or direct targeted player message.
class AppAnnouncement {
  final String id;
  final String title;
  final String body;
  final AnnouncementType messageType;
  final String targetScope;
  final String? targetUserId;
  final String? targetPlayerCode;
  final String? ctaLabel;
  final String? ctaRoute;
  final bool isDismissible;
  final bool isActive;
  final int? minVersionCode;
  final int? maxVersionCode;
  final int receiptCount;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    this.messageType = AnnouncementType.normal,
    this.targetScope = 'all',
    this.targetUserId,
    this.targetPlayerCode,
    this.ctaLabel,
    this.ctaRoute,
    this.isDismissible = true,
    this.isActive = true,
    this.minVersionCode,
    this.maxVersionCode,
    this.receiptCount = 0,
    this.expiresAt,
    this.createdAt,
  });

  bool get requiresBlockingGate =>
      messageType == AnnouncementType.mandatory || !isDismissible;

  bool isExpiredAt(DateTime nowUtc) =>
      expiresAt != null && !nowUtc.isBefore(expiresAt!.toUtc());

  bool matchesVersion(int versionCode) {
    if (versionCode <= 0) return true;
    if (minVersionCode != null && versionCode < minVersionCode!) return false;
    if (maxVersionCode != null && versionCode > maxVersionCode!) return false;
    return true;
  }

  AppAnnouncement copyWith({
    String? id,
    String? title,
    String? body,
    AnnouncementType? messageType,
    String? targetScope,
    String? targetUserId,
    String? targetPlayerCode,
    String? ctaLabel,
    String? ctaRoute,
    bool? isDismissible,
    bool? isActive,
    int? minVersionCode,
    int? maxVersionCode,
    int? receiptCount,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return AppAnnouncement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      messageType: messageType ?? this.messageType,
      targetScope: targetScope ?? this.targetScope,
      targetUserId: targetUserId ?? this.targetUserId,
      targetPlayerCode: targetPlayerCode ?? this.targetPlayerCode,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      ctaRoute: ctaRoute ?? this.ctaRoute,
      isDismissible: isDismissible ?? this.isDismissible,
      isActive: isActive ?? this.isActive,
      minVersionCode: minVersionCode ?? this.minVersionCode,
      maxVersionCode: maxVersionCode ?? this.maxVersionCode,
      receiptCount: receiptCount ?? this.receiptCount,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppAnnouncement.fromJson(Map<String, dynamic> json) {
    return AppAnnouncement(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      messageType:
          AnnouncementType.fromWire(json['message_type'] as String?),
      targetScope: (json['target_scope'] as String?) ?? 'all',
      targetUserId: json['target_user_id']?.toString(),
      targetPlayerCode: json['target_player_code'] as String?,
      ctaLabel: json['cta_label'] as String?,
      ctaRoute: json['cta_route'] as String?,
      isDismissible: json['is_dismissible'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      minVersionCode: (json['min_version_code'] as num?)?.toInt(),
      maxVersionCode: (json['max_version_code'] as num?)?.toInt(),
      receiptCount: (json['receipt_count'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'message_type': messageType.wireName,
        'target_scope': targetScope,
        'target_user_id': targetUserId,
        'target_player_code': targetPlayerCode,
        'cta_label': ctaLabel,
        'cta_route': ctaRoute,
        'is_dismissible': isDismissible,
        'is_active': isActive,
        'min_version_code': minVersionCode,
        'max_version_code': maxVersionCode,
        'receipt_count': receiptCount,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}
