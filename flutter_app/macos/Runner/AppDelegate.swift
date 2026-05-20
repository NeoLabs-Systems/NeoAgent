import Cocoa
import FlutterMacOS
import ApplicationServices
import CoreGraphics

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

final class DesktopCompanionNativePlugin: NSObject {
  private static let channelName = "neoagent/desktop_companion_native"
  private static var channelAssociationKey: UInt8 = 0
  private static var instanceAssociationKey: UInt8 = 0

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )

    let instance = DesktopCompanionNativePlugin()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }

    objc_setAssociatedObject(
      controller,
      &channelAssociationKey,
      channel,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    objc_setAssociatedObject(
      controller,
      &instanceAssociationKey,
      instance,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      result(buildDesktopStatus())
    case "listDisplays":
      result(desktopDisplays())
    case "captureFrame":
      guard preflightScreenCapturePermission() else {
        result(
          FlutterError(
            code: "screen_capture_permission_denied",
            message: "Screen Recording permission is required.",
            details: nil
          )
        )
        return
      }
      let arguments = call.arguments as? [String: Any]
      let displayId = arguments?["displayId"] as? String
      do {
        result(try captureFrame(displayId: displayId))
      } catch {
        result(
          FlutterError(
            code: "capture_failed",
            message: "Desktop capture failed.",
            details: "\(error)"
          )
        )
      }
    case "click":
      guard isAccessibilityTrusted() else {
        result(
          FlutterError(
            code: "accessibility_permission_denied",
            message: "Accessibility permission is required for input control.",
            details: nil
          )
        )
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let x = arguments["x"] as? NSNumber,
            let y = arguments["y"] as? NSNumber else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing click coordinates.",
            details: nil
          )
        )
        return
      }
      let button = (arguments["button"] as? String) ?? "left"
      let displayId = arguments["displayId"] as? String
      performClick(
        x: x.doubleValue,
        y: y.doubleValue,
        button: button,
        displayId: displayId
      )
      result(nil)
    case "drag":
      guard isAccessibilityTrusted() else {
        result(
          FlutterError(
            code: "accessibility_permission_denied",
            message: "Accessibility permission is required for input control.",
            details: nil
          )
        )
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let x1 = arguments["x1"] as? NSNumber,
            let y1 = arguments["y1"] as? NSNumber,
            let x2 = arguments["x2"] as? NSNumber,
            let y2 = arguments["y2"] as? NSNumber else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing drag coordinates.",
            details: nil
          )
        )
        return
      }
      let durationMs = (arguments["durationMs"] as? NSNumber)?.intValue ?? 280
      let displayId = arguments["displayId"] as? String
      performDrag(
        x1: x1.doubleValue,
        y1: y1.doubleValue,
        x2: x2.doubleValue,
        y2: y2.doubleValue,
        durationMs: durationMs,
        displayId: displayId
      )
      result(nil)
    case "scroll":
      guard isAccessibilityTrusted() else {
        result(
          FlutterError(
            code: "accessibility_permission_denied",
            message: "Accessibility permission is required for input control.",
            details: nil
          )
        )
        return
      }
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing scroll payload.",
            details: nil
          )
        )
        return
      }
      let deltaX = (arguments["deltaX"] as? NSNumber)?.int32Value ?? 0
      let deltaY = (arguments["deltaY"] as? NSNumber)?.int32Value ?? 0
      let displayId = arguments["displayId"] as? String
      performScroll(
        deltaX: deltaX,
        deltaY: deltaY,
        displayId: displayId
      )
      result(nil)
    case "typeText":
      guard isAccessibilityTrusted() else {
        result(
          FlutterError(
            code: "accessibility_permission_denied",
            message: "Accessibility permission is required for input control.",
            details: nil
          )
        )
        return
      }
      guard let arguments = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing text payload.",
            details: nil
          )
        )
        return
      }
      let text = (arguments["text"] as? String) ?? ""
      let pressEnter = (arguments["pressEnter"] as? Bool) ?? false
      typeText(text, pressEnter: pressEnter)
      result(nil)
    case "pressKey":
      guard isAccessibilityTrusted() else {
        result(
          FlutterError(
            code: "accessibility_permission_denied",
            message: "Accessibility permission is required for input control.",
            details: nil
          )
        )
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let key = arguments["key"] as? String else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing key payload.",
            details: nil
          )
        )
        return
      }
      do {
        try pressKey(key)
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "unsupported_key",
            message: "Key is not supported on macOS.",
            details: "\(error)"
          )
        )
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func buildDesktopStatus() -> [String: Any] {
    let accessibilityTrusted = isAccessibilityTrusted()
    var status: [String: Any] = [
      "permissions": [
        "screenCapture": preflightScreenCapturePermission() ? "available" : "required",
        "inputControl": accessibilityTrusted ? "available" : "required",
        "accessibility": accessibilityTrusted ? "available" : "required",
      ],
      "displays": desktopDisplays(),
      "activeDisplayId": defaultDisplayIdentifier(),
    ]

    if let appName = NSWorkspace.shared.frontmostApplication?.localizedName {
      status["frontmostApp"] = appName
    }
    if let windowTitle = frontmostWindowTitle() {
      status["frontmostWindowTitle"] = windowTitle
    }
    return status
  }

  private func desktopDisplays() -> [[String: Any]] {
    NSScreen.screens.compactMap { screen in
      guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
        return nil
      }
      let frame = screen.frame
      let displayId = CGDirectDisplayID(number.uint32Value)
      return [
        "id": String(displayId),
        "label": screen.localizedName,
        "x": Int(frame.origin.x),
        "y": Int(frame.origin.y),
        "width": Int(frame.width),
        "height": Int(frame.height),
        "scaleFactor": screen.backingScaleFactor,
        "primary": screen == NSScreen.main,
      ]
    }
  }

  private func captureFrame(displayId: String?) throws -> [String: Any] {
    let resolvedDisplayId = resolveDisplayId(displayId)
    guard let image = CGDisplayCreateImage(resolvedDisplayId) else {
      throw NSError(domain: "NeoAgentDesktop", code: 1)
    }

    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
      throw NSError(domain: "NeoAgentDesktop", code: 2)
    }

    return [
      "bytes": FlutterStandardTypedData(bytes: data),
      "mimeType": "image/png",
      "width": image.width,
      "height": image.height,
      "displayId": String(resolvedDisplayId),
      "displays": desktopDisplays(),
      "capturedAt": ISO8601DateFormatter().string(from: Date()),
      "frontmostApp": NSWorkspace.shared.frontmostApplication?.localizedName ?? "",
      "frontmostWindowTitle": frontmostWindowTitle() ?? "",
    ]
  }

  private func preflightScreenCapturePermission() -> Bool {
    if CGPreflightScreenCaptureAccess() { return true }
    // CGPreflightScreenCaptureAccess() caches the result per-process on macOS 14+
    // and won't reflect a System Settings grant until the app restarts. Fall back to
    // a live 1×1 capture probe which returns nil when recording is actually blocked.
    let probe = CGWindowListCreateImage(
      CGRect(x: 0, y: 0, width: 1, height: 1),
      .optionOnScreenOnly,
      kCGNullWindowID,
      .bestResolution
    )
    return probe != nil
  }

  private func isAccessibilityTrusted() -> Bool {
    if AXIsProcessTrusted() { return true }
    // AXIsProcessTrusted() may cache false on macOS 14+ after a System Settings grant.
    // Probe with a live AX read: .apiDisabled is the error returned when the process
    // lacks accessibility permission (AXError has no .notTrusted case in the macOS SDK).
    let sysElement = AXUIElementCreateSystemWide()
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(
      sysElement,
      kAXFocusedApplicationAttribute as CFString,
      &value
    )
    return status != .apiDisabled
  }

  private func resolveDisplayId(_ raw: String?) -> CGDirectDisplayID {
    if let raw,
       let trimmed = optionalTrimmed(raw),
       let screen = screenForDisplayId(trimmed),
       let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
      return CGDirectDisplayID(number.uint32Value)
    }
    if let main = NSScreen.main,
       let number = main.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
      return CGDirectDisplayID(number.uint32Value)
    }
    return CGMainDisplayID()
  }

  private func screenForDisplayId(_ raw: String?) -> NSScreen? {
    guard let trimmed = optionalTrimmed(raw),
          let value = UInt32(trimmed) else {
      return nil
    }
    return NSScreen.screens.first { screen in
      guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
        return false
      }
      return number.uint32Value == value
    }
  }

  private func optionalTrimmed(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }

  private func defaultDisplayIdentifier() -> String {
    String(resolveDisplayId(nil))
  }

  private func frontmostWindowTitle() -> String? {
    guard let app = NSWorkspace.shared.frontmostApplication else {
      return nil
    }
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var focusedWindow: CFTypeRef?
    let focusedStatus = AXUIElementCopyAttributeValue(
      appElement,
      kAXFocusedWindowAttribute as CFString,
      &focusedWindow
    )
    guard focusedStatus == .success, let focusedWindow else {
      return nil
    }
    let windowElement = unsafeBitCast(focusedWindow, to: AXUIElement.self)

    var titleValue: CFTypeRef?
    let titleStatus = AXUIElementCopyAttributeValue(
      windowElement,
      kAXTitleAttribute as CFString,
      &titleValue
    )
    guard titleStatus == .success, let title = titleValue as? String, !title.isEmpty else {
      return nil
    }
    return title
  }

  private func performClick(x: Double, y: Double, button: String, displayId: String?) {
    let point = nativePointForCapturedPixel(x: x, y: y, displayId: displayId)
    let mouseButton = cgMouseButton(button)
    guard let down = CGEvent(
      mouseEventSource: nil,
      mouseType: cgMouseDownType(button),
      mouseCursorPosition: point,
      mouseButton: mouseButton
    ),
    let up = CGEvent(
      mouseEventSource: nil,
      mouseType: cgMouseUpType(button),
      mouseCursorPosition: point,
      mouseButton: mouseButton
    ) else {
      return
    }
    CGWarpMouseCursorPosition(point)
    down.post(tap: .cghidEventTap)
    usleep(12000)
    up.post(tap: .cghidEventTap)
  }

  private func performDrag(
    x1: Double,
    y1: Double,
    x2: Double,
    y2: Double,
    durationMs: Int,
    displayId: String?
  ) {
    let start = nativePointForCapturedPixel(x: x1, y: y1, displayId: displayId)
    let end = nativePointForCapturedPixel(x: x2, y: y2, displayId: displayId)
    let steps = Swift.max(4, Swift.min(90, durationMs / 16))

    CGWarpMouseCursorPosition(start)
    guard let down = CGEvent(
      mouseEventSource: nil,
      mouseType: .leftMouseDown,
      mouseCursorPosition: start,
      mouseButton: .left
    ) else {
      return
    }
    down.post(tap: .cghidEventTap)

    for step in 1...steps {
      let t = Double(step) / Double(steps)
      let point = CGPoint(
        x: start.x + ((end.x - start.x) * t),
        y: start.y + ((end.y - start.y) * t)
      )
      if let dragged = CGEvent(
        mouseEventSource: nil,
        mouseType: .leftMouseDragged,
        mouseCursorPosition: point,
        mouseButton: .left
      ) {
        dragged.post(tap: .cghidEventTap)
      }
      usleep(useconds_t(Swift.max(1, (durationMs * 1000) / Swift.max(1, steps))))
    }

    if let up = CGEvent(
      mouseEventSource: nil,
      mouseType: .leftMouseUp,
      mouseCursorPosition: end,
      mouseButton: .left
    ) {
      up.post(tap: .cghidEventTap)
    }
  }

  private func performScroll(deltaX: Int32, deltaY: Int32, displayId: String?) {
    guard let event = CGEvent(
      scrollWheelEvent2Source: nil,
      units: .pixel,
      wheelCount: 2,
      wheel1: -deltaY,
      wheel2: deltaX,
      wheel3: 0
    ) else {
      return
    }
    if displayId != nil {
      event.location = anchorPointForDisplay(displayId)
    }
    event.post(tap: .cghidEventTap)
  }

  private func typeText(_ text: String, pressEnter: Bool) {
    for scalar in text.unicodeScalars {
      var unicode = UInt16(scalar.value)
      if let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
         let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicode)
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicode)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
      }
    }
    if pressEnter {
      postVirtualKey(36)
    }
  }

  private func pressKey(_ key: String) throws {
    let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let keyCode: CGKeyCode
    switch normalized {
    case "enter", "return":
      keyCode = 36
    case "tab":
      keyCode = 48
    case "space":
      keyCode = 49
    case "backspace", "delete":
      keyCode = 51
    case "escape", "esc":
      keyCode = 53
    case "left":
      keyCode = 123
    case "right":
      keyCode = 124
    case "down":
      keyCode = 125
    case "up":
      keyCode = 126
    default:
      throw NSError(domain: "NeoAgentDesktop", code: 3)
    }
    postVirtualKey(keyCode)
  }

  private func postVirtualKey(_ keyCode: CGKeyCode) {
    let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
  }

  private func cgMouseButton(_ button: String) -> CGMouseButton {
    switch button.lowercased() {
    case "right":
      return .right
    case "middle":
      return .center
    default:
      return .left
    }
  }

  private func cgMouseDownType(_ button: String) -> CGEventType {
    switch button.lowercased() {
    case "right":
      return .rightMouseDown
    case "middle":
      return .otherMouseDown
    default:
      return .leftMouseDown
    }
  }

  private func cgMouseUpType(_ button: String) -> CGEventType {
    switch button.lowercased() {
    case "right":
      return .rightMouseUp
    case "middle":
      return .otherMouseUp
    default:
      return .leftMouseUp
    }
  }

  private func nativePointForCapturedPixel(x: Double, y: Double, displayId: String?) -> CGPoint {
    let resolvedDisplayId = resolveDisplayId(displayId)
    let displayBounds = CGDisplayBounds(resolvedDisplayId)
    let imageWidth = Double(CGDisplayPixelsWide(resolvedDisplayId))
    let imageHeight = Double(CGDisplayPixelsHigh(resolvedDisplayId))

    guard imageWidth > 0, imageHeight > 0 else {
      return CGPoint(x: x, y: y)
    }

    let normalizedX = min(max(x / imageWidth, 0), 1)
    let normalizedY = min(max(y / imageHeight, 0), 1)
    return CGPoint(
      x: displayBounds.origin.x + (displayBounds.width * normalizedX),
      y: displayBounds.origin.y + (displayBounds.height * normalizedY)
    )
  }

  private func anchorPointForDisplay(_ displayId: String?) -> CGPoint {
    let resolvedDisplayId = resolveDisplayId(displayId)
    let displayBounds = CGDisplayBounds(resolvedDisplayId)
    return CGPoint(
      x: displayBounds.midX,
      y: displayBounds.midY
    )
  }
}
