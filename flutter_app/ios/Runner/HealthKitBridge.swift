import Flutter
import HealthKit
import UserNotifications

/// `neoagent/health` on iOS: the same calls Android's Health Connect bridge
/// answers, and the background sync that uploads new samples while the app
/// is closed. HealthKit wakes the app when it has new data (at most hourly,
/// and only while the phone is unlocked) instead of a periodic worker.
final class HealthKitBridge {
  static let shared = HealthKitBridge()

  private static let enabledKey = "health_sync.enabled"
  private static let backendUrlKey = "health_sync.backend_url"
  private static let cookieKey = "health_sync.session_cookie"
  private static let failuresKey = "health_sync.consecutive_failures"

  private let defaults = UserDefaults.standard
  private let gateway = HealthKitGateway()
  private var observing = false
  private var syncing = false

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "neoagent/health", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else { return }
        Task { @MainActor in await self.handle(call, result) }
      }
  }

  /// Observers have to be in place at launch: HealthKit wakes the app for
  /// new data and delivers it to the queries started here.
  func startObserving() {
    guard defaults.bool(forKey: Self.enabledKey), HealthKitGateway.isAvailable, !observing else { return }
    observing = true
    for type in HealthKitGateway.sampleTypes {
      let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
        guard error == nil, let self else {
          completion()
          return
        }
        Task { @MainActor in
          await self.syncInBackground()
          completion()
        }
      }
      HealthKitGateway.store.execute(query)
      HealthKitGateway.store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
    }
  }

  @MainActor
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "status":
      result(await status())
    case "requestPermissions":
      guard HealthKitGateway.isAvailable else {
        result(FlutterError(code: "health_unavailable", message: "Apple Health is unavailable on this device.", details: nil))
        return
      }
      do {
        try await HealthKitGateway.requestAuthorization()
        result(await status())
      } catch {
        result(FlutterError(code: "health_permissions", message: error.localizedDescription, details: nil))
      }
    case "collectBatch":
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      guard let start = (args?["windowStart"] as? String).flatMap(formatter.date(from:)),
            let end = (args?["windowEnd"] as? String).flatMap(formatter.date(from:))
      else {
        result(FlutterError(code: "health_sync_window", message: "windowStart and windowEnd must be ISO-8601 timestamps.", details: nil))
        return
      }
      do {
        let batch = try await gateway.collectBatch(windowStart: start, windowEnd: end)
        let json = try JSONSerialization.data(withJSONObject: batch)
        result(String(data: json, encoding: .utf8))
      } catch {
        result(FlutterError(code: "health_sync_failed", message: error.localizedDescription, details: nil))
      }
    case "configureBackgroundSync":
      configure(
        enabled: args?["enabled"] as? Bool == true,
        backendUrl: args?["backendUrl"] as? String ?? "",
        cookie: args?["sessionCookie"] as? String ?? ""
      )
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func status() async -> [String: Any] {
    let names = HealthKitGateway.sampleTypes.map(\.identifier)
    guard HealthKitGateway.isAvailable else {
      return ["available": false, "permissionsGranted": false, "message": "Apple Health is unavailable on this device."]
    }
    let asked = await HealthKitGateway.hasAsked()
    return [
      "available": true,
      "permissionsGranted": asked,
      "grantedPermissions": asked ? names : [],
      "requiredPermissions": names,
    ]
  }

  private func configure(enabled: Bool, backendUrl: String, cookie: String) {
    defaults.set(enabled, forKey: Self.enabledKey)
    defaults.set(backendUrl.trimmingCharacters(in: .whitespaces), forKey: Self.backendUrlKey)
    defaults.set(cookie.trimmingCharacters(in: .whitespaces), forKey: Self.cookieKey)
    if enabled {
      startObserving()
    } else if observing {
      // The observers stay registered until the app next launches, but no
      // longer wake it.
      HealthKitGateway.store.disableAllBackgroundDelivery { _, _ in }
    }
  }

  /// Android's `HealthSyncWorker`: from where the server's last sync ended
  /// (or the last day), collect and upload.
  @MainActor
  private func syncInBackground() async {
    let backendUrl = defaults.string(forKey: Self.backendUrlKey) ?? ""
    let cookie = defaults.string(forKey: Self.cookieKey) ?? ""
    guard defaults.bool(forKey: Self.enabledKey), !backendUrl.isEmpty, !cookie.isEmpty, !syncing else { return }
    syncing = true
    defer { syncing = false }
    do {
      let status = try await BackendHttp.request("GET", baseUrl: backendUrl, path: "/api/mobile/health/status", cookie: cookie)
      guard (200..<300).contains(status.code) else {
        return failed("NeoAgent server rejected health status check (\(status.code)).")
      }
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      let lastRun = (try? JSONSerialization.jsonObject(with: status.body) as? [String: Any])?["lastRun"] as? [String: Any]
      let windowEnd = Date()
      let windowStart = (lastRun?["sync_window_end"] as? String).flatMap(formatter.date(from:))?
        .addingTimeInterval(-300) ?? windowEnd.addingTimeInterval(-24 * 60 * 60)
      let batch = try await gateway.collectBatch(windowStart: windowStart, windowEnd: windowEnd)
      let upload = try await BackendHttp.request(
        "POST", baseUrl: backendUrl, path: "/api/mobile/health/sync", cookie: cookie,
        json: try JSONSerialization.data(withJSONObject: batch)
      )
      guard (200..<300).contains(upload.code) else {
        return failed("NeoAgent server rejected health upload (\(upload.code)).")
      }
      defaults.set(0, forKey: Self.failuresKey)
    } catch {
      failed(error.localizedDescription)
    }
  }

  /// Like Android, a failure is shown once it repeats.
  private func failed(_ message: String) {
    let failures = defaults.integer(forKey: Self.failuresKey) + 1
    defaults.set(failures, forKey: Self.failuresKey)
    guard failures >= 2 else { return }
    let content = UNMutableNotificationContent()
    content.title = "Health sync needs attention"
    content.body = message
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: "neoagent.health_sync_failure", content: content, trigger: nil)
    )
  }
}
