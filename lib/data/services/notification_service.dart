import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

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

  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      tz_data.initializeTimeZones();
      final String timeZoneName = 'Asia/Riyadh';
      
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

      // إنشاء القناة بشكل صريح
      await _createNotificationChannel();

      // طلب الأذونات
      await _requestPermissions();

      // جدولة الإشعارات
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

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('User tapped notification: ${response.payload}');
  }

  static Future<void> scheduleDailyNotifications() async {
    await cancelAllNotifications();
    
    // جدولة 3 إشعارات يومية
    await _scheduleNotificationAt(hour: 14, minute: 0, id: 101); 
    await _scheduleNotificationAt(hour: 17, minute: 0, id: 102); 
    await _scheduleNotificationAt(hour: 21, minute: 0, id: 103); 
    
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
