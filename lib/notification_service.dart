import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _plugin;
  bool _isInitialized = false;

  Future<void> init() async {
    if (kIsWeb) return; // Webなら即終了

    try {
      _plugin = FlutterLocalNotificationsPlugin();
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      await _plugin?.initialize(initializationSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint("Notification init error: $e");
    }
  }

  Future<void> cancelAll() async {
    // Web環境、または初期化されていない場合は何もしない
    if (kIsWeb || !_isInitialized || _plugin == null) return;
    try {
      await _plugin?.cancelAll();
    } catch (e) {
      debugPrint("Cancel error: $e");
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Web環境、または初期化されていない場合は何もしない
    if (kIsWeb || !_isInitialized || _plugin == null) return;

    try {
      await _plugin?.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reverse_calc_channel',
            '予定逆算通知',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint("Schedule error: $e");
    }
  }
}
