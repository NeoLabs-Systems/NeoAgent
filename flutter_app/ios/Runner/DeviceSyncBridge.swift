import BackgroundTasks
import Contacts
import CryptoKit
import EventKit
import Flutter
import UIKit

/// `neoagent/device_sync` on iOS, answering the same calls as Android. iOS has
/// no periodic worker, so the phone syncs when its calendars or contacts change
/// while the app runs, and when iOS grants a background refresh.
final class DeviceSyncBridge {
  static let shared = DeviceSyncBridge()
  static let refreshTaskId = "com.neoagent.device-sync"

  private enum Key {
    static let enabled = "device_sync.enabled"
    static let backendUrl = "device_sync.backend_url"
    static let cookie = "device_sync.session_cookie"
    static let agentId = "device_sync.agent_id"
    static let deviceId = "device_sync.device_id"
    static let kinds = "device_sync.kinds"
    static let calendarHash = "device_sync.calendar_hash"
    static let contactsHash = "device_sync.contacts_hash"
    static let executed = "device_sync.executed_commands"
    static let lastSuccessAt = "device_sync.last_success_at"
    static let lastError = "device_sync.last_error"
  }

  private static let syncPath = "/api/mobile/device-sync/sync"
  private static let maxRounds = 3
  private static let keptResults = 50

  private let defaults = UserDefaults.standard
  private let gateway = DeviceDataGateway()
  private var syncing = false
  private var pendingChange: Task<Void, Never>?

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "neoagent/device_sync", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else { return }
        Task { @MainActor in await self.handle(call, result) }
      }
    for name in [Notification.Name.EKEventStoreChanged, .CNContactStoreDidChange] {
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.syncSoon()
      }
    }
  }

  /// Must run before launch finishes, as BGTaskScheduler requires.
  func registerBackgroundRefresh() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskId, using: nil) { [weak self] task in
      guard let self else { return task.setTaskCompleted(success: false) }
      self.scheduleRefresh()
      let work = Task { @MainActor in
        await self.run()
        task.setTaskCompleted(success: self.defaults.string(forKey: Key.lastError) == nil)
      }
      task.expirationHandler = { work.cancel() }
    }
  }

  private func scheduleRefresh() {
    guard defaults.bool(forKey: Key.enabled) else { return }
    let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
  }

  /// A burst of edits makes one sync, shortly after the last of them.
  private func syncSoon() {
    guard defaults.bool(forKey: Key.enabled) else { return }
    pendingChange?.cancel()
    pendingChange = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 20_000_000_000)
      guard !Task.isCancelled else { return }
      await run()
    }
  }

  @MainActor
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) async {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "deviceName":
      result(UIDevice.current.name)
    case "grantedKinds":
      result(DeviceDataGateway.grantedKinds())
    case "requestPermissions":
      await gateway.requestAccess(args["kinds"] as? [String] ?? [])
      result(DeviceDataGateway.grantedKinds())
    case "openSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        await UIApplication.shared.open(url)
      }
      result(nil)
    case "configure":
      configure(args)
      result(nil)
    case "syncNow":
      await run()
      result(status())
    case "status":
      result(status())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configure(_ args: [String: Any]) {
    let enabled = args["enabled"] as? Bool == true
    defaults.set(enabled, forKey: Key.enabled)
    // Turning sharing on, off or changing what is shared uploads everything again.
    defaults.removeObject(forKey: Key.calendarHash)
    defaults.removeObject(forKey: Key.contactsHash)
    guard enabled else {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskId)
      return
    }
    for (key, name) in [(Key.backendUrl, "backendUrl"), (Key.cookie, "sessionCookie"), (Key.agentId, "agentId"), (Key.deviceId, "deviceId")] {
      defaults.set((args[name] as? String ?? "").trimmingCharacters(in: .whitespaces), forKey: key)
    }
    defaults.set(args["kinds"] as? [String] ?? [], forKey: Key.kinds)
    scheduleRefresh()
  }

  private func status() -> [String: Any?] {
    [
      "enabled": defaults.bool(forKey: Key.enabled),
      "kinds": kinds(),
      "lastSuccessAt": defaults.string(forKey: Key.lastSuccessAt),
      "lastError": defaults.string(forKey: Key.lastError),
    ]
  }

  /// The shared kinds this app may still read; access turned off in Settings drops out.
  private func kinds() -> [String] {
    let granted = Set(DeviceDataGateway.grantedKinds())
    return (defaults.stringArray(forKey: Key.kinds) ?? []).filter(granted.contains)
  }

  /// Android's `DeviceSyncRunner.run`: upload what changed, make the changes
  /// the server queued for this phone, and report them back.
  @MainActor
  private func run() async {
    guard defaults.bool(forKey: Key.enabled), !syncing else { return }
    syncing = true
    defer { syncing = false }
    do {
      var results: [[String: Any]] = []
      for _ in 0..<Self.maxRounds {
        guard let commands = try await upload(results) else { return }
        if commands.isEmpty { break }
        results = commands.map(execute)
      }
      defaults.set(ISO8601DateFormatter().string(from: Date()), forKey: Key.lastSuccessAt)
      defaults.removeObject(forKey: Key.lastError)
    } catch {
      defaults.set(error.localizedDescription, forKey: Key.lastError)
    }
  }

  /// Sends what changed since the last upload; nil once the server forgot this phone.
  private func upload(_ results: [[String: Any]]) async throws -> [[String: Any]]? {
    var body: [String: Any] = [
      "deviceId": defaults.string(forKey: Key.deviceId) ?? "",
      "agentId": defaults.string(forKey: Key.agentId) ?? "",
      "results": results,
    ]
    var hashes: [String: String] = [:]
    let shared = kinds()
    if shared.contains("calendar") {
      let now = Date()
      let calendars = gateway.calendars()
      let events = gateway.events(from: now.addingTimeInterval(-30 * 86400), to: now.addingTimeInterval(90 * 86400))
      if let hash = changedHash(Key.calendarHash, [calendars, events]) {
        hashes[Key.calendarHash] = hash
        body["calendars"] = calendars
        body["events"] = events
      }
    }
    if shared.contains("contacts") {
      let contacts = try gateway.contacts()
      if let hash = changedHash(Key.contactsHash, contacts) {
        hashes[Key.contactsHash] = hash
        body["contacts"] = contacts
      }
    }

    let response = try await BackendHttp.request(
      "POST",
      baseUrl: defaults.string(forKey: Key.backendUrl) ?? "",
      path: Self.syncPath,
      cookie: defaults.string(forKey: Key.cookie),
      json: try JSONSerialization.data(withJSONObject: body)
    )
    if response.code == 401 {
      throw DeviceSyncError(message: "NeoAgent signed this phone out. Open the app and sign in.")
    }
    guard (200..<300).contains(response.code) else {
      throw DeviceSyncError(message: "NeoAgent rejected the sync (\(response.code)).")
    }
    let reply = try JSONSerialization.jsonObject(with: response.body) as? [String: Any] ?? [:]
    guard reply["connected"] as? Bool == true else {
      configure(["enabled": false])
      return nil
    }
    for (key, hash) in hashes { defaults.set(hash, forKey: key) }
    return reply["commands"] as? [[String: Any]] ?? []
  }

  private func changedHash(_ key: String, _ content: Any) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: content, options: [.sortedKeys]) else { return nil }
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    return hash == defaults.string(forKey: key) ? nil : hash
  }

  /// A change already made is reported again, never made twice.
  private func execute(_ command: [String: Any]) -> [String: Any] {
    let id = "\(command["id"] ?? "")"
    var executed = defaults.dictionary(forKey: Key.executed) ?? [:]
    if let done = executed[id] as? [String: Any] { return done }
    var result: [String: Any] = ["id": id]
    do {
      result["result"] = try gateway.apply(command["action"] as? String ?? "", command["payload"] as? [String: Any] ?? [:])
      result["ok"] = true
    } catch {
      result["ok"] = false
      result["error"] = error.localizedDescription
    }
    executed[id] = result
    let kept = executed.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }.suffix(Self.keptResults)
    defaults.set(executed.filter { kept.contains($0.key) }, forKey: Key.executed)
    return result
  }
}
