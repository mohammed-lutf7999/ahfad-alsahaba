import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_10y.dart' as tz_data;
import '../../core/app_routes.dart';
import '../local/shared_prefs_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static Future<void>? _initFuture;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static String? _pendingRoute;

  static const Set<String> _allowedTapRoutes = {
    AppRoutes.royalInbox,
    AppRoutes.challenge,
    AppRoutes.guilds,
    AppRoutes.liveArena,
    AppRoutes.knightsStore,
    AppRoutes.gloryRoad,
    AppRoutes.home,
  };

  // معرف القناة (محدث)
  static const String _channelId = 'quiz_notifications_v3';
  static const String _channelName = 'تحديثات المسابقة';
  static const String _channelDescription = 'إشعارات وتنبيهات المسابقة الإسلامية';

  static final List<Map<String, String>> _notificationMessages = [
    {
      'title': '🏆 حان وقت المسابقة!',
      'body': 'هل أنت مستعد لتحدي جديد؟ افتح التطبيق الآن!',
    },
    {
      'title': '📚 وقت التعلم!',
      'body': 'اختبر معلوماتك الإسلامية اليوم',
    },
    {
      'title': '⭐ تحدي اليوم',
      'body': 'أسئلة جديدة بانتظارك، هيا نبدأ!',
    },
    {
      'title': '🎯 لا تفوت الفرصة',
      'body': 'المسابقة الإسلامية تنتظرك',
    },
  ];

  static Future<void> init() {
    if (_isInitialized) return Future<void>.value();
    _initFuture ??= _initInternal().whenComplete(() {
      _initFuture = null;
    });
    return _initFuture!;
  }

  static Future<void> _initInternal() async {
    try {
      tz_data.initializeTimeZones();
      const String timeZoneName = 'Asia/Riyadh';

      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint('TimeZone setting error: $e');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // إعدادات التهيئة
      const androidSettings = AndroidInitializationSettings('launcher_icon');

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      final launchDetails =
          await _notifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final launchPayload = launchDetails?.notificationResponse?.payload;
        handleNotificationPayload(launchPayload);
      }

      // إنشاء القناة بشكل صريح
      await _createNotificationChannel();

      // طلب الأذونات
      await _requestPermissions();

      // جدولة الإشعارات فقط إذا لم تكن مجدولة مسبقاً لتجنب تكرار مكالمات النظام
      await scheduleDailyNotifications();

      _isInitialized = true;
      debugPrint('NotificationService Initialized Successfully ✅');
    } catch (e) {
      debugPrint('CRITICAL: NotificationService init failed: $e');
    }
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _requestPermissions() async {
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Permission error: $e');
    }
  }

  static void configureNavigation(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    flushPendingNavigation();
  }

  @visibleForTesting
  static String? get pendingRouteForTesting => _pendingRoute;

  @visibleForTesting
  static void resetNavigationForTesting() {
    _navigatorKey = null;
    _pendingRoute = null;
  }

  /// Parses an incoming notification payload (`/inbox`, `route:/inbox`, or JSON `{"route":"/inbox"}`)
  /// and accepts only safe in-app routes.
  static String? parseRouteFromPayload(String? rawPayload) {
    final trimmed = rawPayload?.trim() ?? '';
    if (trimmed.isEmpty) return AppRoutes.royalInbox;

    String candidate = trimmed;
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map && decoded['route'] != null) {
          candidate = decoded['route'].toString().trim();
        }
      } catch (_) {
        return null;
      }
    } else if (trimmed.toLowerCase().startsWith('route:')) {
      candidate = trimmed.substring(6).trim();
    }

    if (!candidate.startsWith('/')) return null;
    return _allowedTapRoutes.contains(candidate) ? candidate : null;
  }

  static void handleNotificationPayload(String? payload) {
    final route = parseRouteFromPayload(payload);
    if (route == null) return;
    _pendingRoute = route;
    flushPendingNavigation();
  }

  static void flushPendingNavigation() {
    final route = _pendingRoute;
    final nav = _navigatorKey?.currentState;
    if (route == null || nav == null) return;
    _pendingRoute = null;
    nav.pushNamed(route);
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('User tapped notification: ${response.payload}');
    handleNotificationPayload(response.payload);
  }

  static Future<void> showInboxAlertNotification({
    required String title,
    required String body,
    String payload = AppRoutes.royalInbox,
  }) async {
    try {
      await _notifications.show(
        777,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: 'launcher_icon',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService showInboxAlert error: $e');
    }
  }

  static Future<void> scheduleDailyNotifications({bool force = false}) async {
    if (!force && SharedPrefsService.areDailyNotificationsScheduled()) {
      return;
    }

    await _notifications.cancelAll();

    // جدولة 3 إشعارات يومية
    await _scheduleNotificationAt(hour: 14, minute: 0, id: 101);
    await _scheduleNotificationAt(hour: 17, minute: 0, id: 102);
    await _scheduleNotificationAt(hour: 21, minute: 0, id: 103);

    await SharedPrefsService.setDailyNotificationsScheduled(true);
    debugPrint('Daily notifications scheduled ✅');
  }

  static Future<void> _scheduleNotificationAt({
    required int hour,
    required int minute,
    required int id,
  }) async {
    try {
      final random = Random();
      final message = _notificationMessages[random.nextInt(_notificationMessages.length)];
      final scheduledTime = _nextInstanceOfTime(hour, minute);

      await _notifications.zonedSchedule(
        id,
        message['title'],
        message['body'],
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: 'launcher_icon',
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Schedule error: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    await SharedPrefsService.setDailyNotificationsScheduled(false);
  }

  static Future<void> showTestNotification() async {
    try {
      debugPrint('Sending test notification...');
      await _notifications.show(
        999, 
        'اختبار الإشعارات',
        'نظام الإشعارات يعمل بنجاح! ✅',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: 'launcher_icon',
            fullScreenIntent: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Test notification failed: $e');
    }
  }
}
