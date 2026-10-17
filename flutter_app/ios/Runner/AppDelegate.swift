import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var appLaunchEvents: BufferedEventStream?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // flutter_local_notifications answers through the app delegate.
    UNUserNotificationCenter.current().delegate = self
    let messenger = registrar(forPlugin: "NeoAgent")!.messenger()
    CallKitBridge.shared.register(with: messenger)
    HealthKitBridge.shared.register(with: messenger)
    HomeWidgetsBridge.register(with: messenger)
    appLaunchEvents = BufferedEventStream(name: "neoagent/app_launch/events", messenger: messenger)
    HealthKitBridge.shared.startObserving()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// The call widget opens `neoagent://call`, which starts a voice call like
  /// Android's START_CALL intent.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "neoagent", url.host == "call" {
      appLaunchEvents?.send(["action": "start_call"])
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
