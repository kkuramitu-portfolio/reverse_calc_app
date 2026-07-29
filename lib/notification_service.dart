import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Webでのエラーを避けるため dynamic で保持
  dynamic _plugin;

  Future<void> init() async {
    if (kIsWeb) return;

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

      await _plugin.initialize(initializationSettings);
    } catch (e) {
      debugPrint("Notification init error: $e");
    }
  }

  // 全ての通知をキャンセル
  Future<void> cancelAll() async {
    if (kIsWeb || _plugin == null) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint("Cancel error: $e");
    }
  }

  // 💡 ここが重要！特定のIDの通知だけをキャンセルする本物の処理
  Future<void> cancelNotification(int id) async {
    if (kIsWeb || _plugin == null) return;
    try {
      await _plugin.cancel(id); // プラグインに対して「このIDを消して」と命令
      debugPrint("通知 ID: $id をキャンセルしました");
    } catch (e) {
      debugPrint("Cancel single error: $e");
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb || _plugin == null) return;

    try {
      await _plugin.zonedSchedule(
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
