import Flutter
import WidgetKit

/// `neoagent/home_widgets` on iOS: the app publishes what the mascot shows,
/// and the sign-in the widgets refresh with while it is closed.
enum HomeWidgetsBridge {
  static func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "neoagent/home_widgets", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "publish", let args = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented)
          return
        }
        HomeWidgetStore.saveSession(
          backendUrl: args["backendUrl"] as? String ?? "",
          cookie: args["sessionCookie"] as? String ?? "",
          agentId: args["agentId"] as? String ?? ""
        )
        let callStartedAtMs = (args["callStartedAtMs"] as? NSNumber)?.doubleValue
        HomeWidgetStore.publish(
          mood: .of(args["mood"] as? String),
          detail: args["detail"] as? String ?? "",
          live: args["live"] as? Bool == true,
          callStartedAt: callStartedAtMs.map { Date(timeIntervalSince1970: $0 / 1000) }
        )
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      }
  }
}
