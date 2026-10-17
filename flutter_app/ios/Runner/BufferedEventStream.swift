import Flutter

/// An event channel that holds events until Dart listens, so what happens
/// while the app is still starting (a call answered on the lock screen, an
/// approval allowed from a notification, a widget tap) still reaches it.
final class BufferedEventStream: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var pending: [Any] = []

  init(name: String, messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterEventChannel(name: name, binaryMessenger: messenger).setStreamHandler(self)
  }

  func send(_ event: Any) {
    if let sink {
      sink(event)
    } else {
      pending.append(event)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    let queued = pending
    pending.removeAll()
    queued.forEach { events($0) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
