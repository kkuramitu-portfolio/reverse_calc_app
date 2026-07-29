import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            // 💡 追加：アプリを開いている間も通知を表示する設定
            notificationCategories: [],
            defaultPresentAlert: true,
            defaultPresentBadge: true,
            defaultPresentSound: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      await _plugin.initialize(
        initializationSettings,
        // 💡 追加：通知をタップした時の処理（空でも定義しておくと安定します）
        onDidReceiveNotificationResponse: (details) {
          debugPrint("通知がタップされました: ${details.payload}");
        },
      );

      // 💡 iOSの権限を改めて要求
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      debugPrint("通知サービスが初期化されました（Asia/Tokyo）");
    } catch (e) {
      debugPrint("Notification init error: $e");
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
    debugPrint("全ての通知予約をクリアしました");
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
    debugPrint("通知 ID: $id をキャンセルしました");
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb) return;

    try {
      // 💡 予約時間をタイムゾーン付きに変換
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      // 💡 過去の時間は予約できないためチェック
      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint("警告: 過去の時刻（$tzDate）のため予約をスキップしました");
        return;
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reverse_calc_channel',
            '予定逆算通知',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true, // 💡 フォアグラウンドでも表示
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint("通知予約完了: ID=$id, 時刻=$tzDate, 内容=$body");
    } catch (e) {
      debugPrint("Schedule error: $e");
    }
  }
}
