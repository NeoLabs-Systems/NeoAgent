import Cocoa
import FlutterMacOS

public class AudioCapturePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audio_capture", binaryMessenger: registrar.messenger)
    let instance = AudioCapturePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // Register the microphone plugin
    MicCapturePlugin.register(with: registrar)

    // Register the system audio plugin (only available on macOS 13.0+)
    if #available(macOS 13.0, *) {
      SystemCapturePlugin.register(with: registrar)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
