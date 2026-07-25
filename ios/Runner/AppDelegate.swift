import UIKit
import Flutter
import flutter_local_notifications // 通知プラグインをインポート

@main // @UIApplicationMain から最新の @main に変更
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool { // ← ここに "-> Bool" を追加しました
    
    // 通知プラグインの登録（バックグラウンド動作を安定させるため）
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}