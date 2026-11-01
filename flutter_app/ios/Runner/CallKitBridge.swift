import AVFoundation
import CallKit
import Flutter
import UIKit

/// Native side of agent calls, behind the same channels as on Android:
/// `neoagent/call` rings and dismisses a call and switches the speaker, and
/// `neoagent/telecom` holds a system call while a voice session runs, so it
/// gets the call's audio route and survives in the background.
///
/// CallKit shows the call over the lock screen and plays the ringtone, so
/// there is nothing to present and no permission to ask for. Answer, decline
/// and hang-up on CallKit's screen reach Dart on `neoagent/call/events` as
/// the actions the call notification sends on Android.
final class CallKitBridge: NSObject, CXProviderDelegate {
  static let shared = CallKitBridge()

  private static let handle = CXHandle(type: .generic, value: "NeoAgent")

  private let provider: CXProvider
  private let callController = CXCallController()
  private var events: BufferedEventStream?

  /// The one call CallKit knows about, ringing or connected.
  private var call: (id: UUID, answered: Bool)?
  private var expiry: Timer?
  private var speakerOn = false

  override private init() {
    let configuration = CXProviderConfiguration()
    configuration.supportsVideo = false
    configuration.maximumCallGroups = 1
    configuration.maximumCallsPerCallGroup = 1
    configuration.supportedHandleTypes = [.generic]
    configuration.includesCallsInRecents = false
    provider = CXProvider(configuration: configuration)
    super.init()
    provider.setDelegate(self, queue: nil)
  }

  func register(with messenger: FlutterBinaryMessenger) {
    events = BufferedEventStream(name: "neoagent/call/events", messenger: messenger)
    FlutterMethodChannel(name: "neoagent/call", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handleCall(call, result) }
    FlutterMethodChannel(name: "neoagent/telecom", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handleTelecom(call, result) }
  }

  /// Rings [id] until it is answered or [expiresAt] passes. The VoIP push
  /// and the socket both announce a call; the second report is a no-op.
  func reportIncoming(id: UUID, callerName: String, expiresAt: Date, completion: (() -> Void)? = nil) {
    if call?.id == id {
      completion?()
      return
    }
    if let current = call {
      end(current.id, reason: .remoteEnded)
    }
    let update = CXCallUpdate()
    update.remoteHandle = Self.handle
    update.localizedCallerName = callerName
    update.hasVideo = false
    update.supportsHolding = false
    update.supportsGrouping = false
    update.supportsUngrouping = false
    update.supportsDTMF = false
    call = (id, false)
    provider.reportNewIncomingCall(with: id, update: update) { [weak self] error in
      if error != nil {
        if self?.call?.id == id { self?.call = nil }
      } else {
        self?.ringUntil(expiresAt, id: id)
      }
      completion?()
    }
  }

  private func handleCall(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "startRinging":
      guard let callId = args?["callId"] as? String, let id = UUID(uuidString: callId) else {
        result(nil)
        return
      }
      let expiresAtMs = (args?["expiresAtMs"] as? NSNumber)?.doubleValue ?? 0
      reportIncoming(
        id: id,
        callerName: args?["callerName"] as? String ?? "NeoAgent",
        expiresAt: Date(timeIntervalSince1970: expiresAtMs / 1000)
      )
      result(nil)
    case "stopRinging":
      // The ring stops when the call is answered in the app; CallKit then
      // has to answer it too, or it would keep ringing over the call.
      if let current = self.call, !current.answered {
        request(CXAnswerCallAction(call: current.id))
      }
      result(nil)
    case "dismiss":
      if let current = self.call { end(current.id, reason: .remoteEnded) }
      result(nil)
    case "setSpeakerphone":
      setSpeaker(args?["on"] as? Bool == true)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleTelecom(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "startCallRouting":
      // An answered agent call is already the system call.
      if self.call != nil {
        result(true)
        return
      }
      let id = UUID()
      self.call = (id, true)
      request(CXStartCallAction(call: id, handle: Self.handle)) { error in
        if let error {
          if self.call?.id == id { self.call = nil }
          result(FlutterError(code: "CALL_NOT_PERMITTED", message: error.localizedDescription, details: nil))
        } else {
          result(true)
        }
      }
    case "stopCallRouting":
      if let current = self.call { end(current.id, reason: .remoteEnded) }
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func ringUntil(_ expiresAt: Date, id: UUID) {
    expiry?.invalidate()
    expiry = Timer.scheduledTimer(withTimeInterval: max(expiresAt.timeIntervalSinceNow, 0), repeats: false) {
      [weak self] _ in
      guard let self, let current = self.call, current.id == id, !current.answered else { return }
      self.end(id, reason: .unanswered)
    }
  }

  /// Ends a call the app or the server ended. Reported, not requested, so it
  /// does not come back to Dart as the user's hang-up.
  private func end(_ id: UUID, reason: CXCallEndedReason) {
    provider.reportCall(with: id, endedAt: nil, reason: reason)
    if call?.id == id { cleanUp() }
  }

  private func cleanUp() {
    call = nil
    expiry?.invalidate()
    expiry = nil
    speakerOn = false
    UIDevice.current.isProximityMonitoringEnabled = false
  }

  private func request(_ action: CXCallAction, completion: ((Error?) -> Void)? = nil) {
    callController.request(CXTransaction(action: action)) { error in
      DispatchQueue.main.async { completion?(error) }
    }
  }

  private func send(_ action: String, for id: UUID) {
    events?.send(["callId": id.uuidString.lowercased(), "action": action])
  }

  // The earpiece unless the speaker is chosen, with the screen dark at the
  // ear, as in the phone's own calls.
  private func setSpeaker(_ on: Bool) {
    speakerOn = on
    try? AVAudioSession.sharedInstance().overrideOutputAudioPort(on ? .speaker : .none)
    UIDevice.current.isProximityMonitoringEnabled = call != nil && !on
  }

  // MARK: CXProviderDelegate

  func providerDidReset(_ provider: CXProvider) {
    cleanUp()
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard call?.id == action.callUUID else {
      action.fail()
      return
    }
    call?.answered = true
    expiry?.invalidate()
    send("call_answer", for: action.callUUID)
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    let answered = call?.answered ?? false
    if call?.id == action.callUUID { cleanUp() }
    send(answered ? "call_end" : "call_decline", for: action.callUUID)
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    action.fulfill()
    provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
  }

  // The live model hears the microphone throughout; there is no mute to map.
  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    action.fail()
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    setSpeaker(speakerOn)
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    UIDevice.current.isProximityMonitoringEnabled = false
  }
}
