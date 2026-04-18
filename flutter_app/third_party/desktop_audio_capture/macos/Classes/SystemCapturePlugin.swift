import Cocoa
import FlutterMacOS
import AVFoundation
@preconcurrency import ScreenCaptureKit

// MARK: - Error Types
enum CaptureError: Error {
    case noPermission
    case noDisplay
    case alreadyCapturing
    case notCapturing
    case invalidConfiguration(String)
    case streamCreationFailed
    case captureStartFailed(Error)
    case captureStopFailed(Error)
    
    var message: String {
        switch self {
        case .noPermission:
            return "Screen recording permission not granted"
        case .noDisplay:
            return "No display found"
        case .alreadyCapturing:
            return "Capture already in progress"
        case .notCapturing:
            return "No active capture session"
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail)"
        case .streamCreationFailed:
            return "Failed to create capture stream"
        case .captureStartFailed(let error):
            return "Failed to start capture: \(error.localizedDescription)"
        case .captureStopFailed(let error):
            return "Failed to stop capture: \(error.localizedDescription)"
        }
    }
}

// MARK: - Audio Configuration
struct AudioConfiguration {
    let sampleRate: Double
    let channelCount: Int
    
    static let `default` = AudioConfiguration(sampleRate: 16000, channelCount: 1)
    
    static func from(_ dict: [String: Any]?) -> Result<AudioConfiguration, CaptureError> {
        guard let dict = dict else {
            return .success(.default)
        }
        
        let sampleRate = (dict["sampleRate"] as? NSNumber)?.doubleValue ?? 16000
        let channelCount = (dict["channels"] as? NSNumber)?.intValue ?? 1
        
        // Validate
        guard [8000, 16000, 44100, 48000].contains(Int(sampleRate)) else {
            return .failure(.invalidConfiguration("Sample rate must be 8000, 16000, 44100, or 48000"))
        }
        
        guard (1...2).contains(channelCount) else {
            return .failure(.invalidConfiguration("Channel count must be 1 or 2"))
        }
        
        return .success(AudioConfiguration(sampleRate: sampleRate, channelCount: channelCount))
    }
}

// MARK: - Main Plugin
@available(macOS 13.0, *)
final class SystemCapturePlugin: NSObject, FlutterPlugin, @unchecked Sendable {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    private var statusEventChannel: FlutterEventChannel?
    var statusEventSink: FlutterEventSink?  // Changed to var for access from handler
    
    private var decibelEventChannel: FlutterEventChannel?
    var decibelEventSink: FlutterEventSink?

    private var stream: SCStream?
    var streamOutput: StreamOutput? // Internal access for stream handlers
    
    // Thread-safe state management using serial queue
    private let stateQueue = DispatchQueue(label: "com.system_audio_transcriber.state_queue", qos: .utility)
    private var _isCapturing = false
    var isCapturing: Bool {
        get {
            return stateQueue.sync { _isCapturing }
        }
        set {
            stateQueue.async { [weak self] in
                self?._isCapturing = newValue
            }
        }
    }
    
    private let captureQueue = DispatchQueue(label: "com.system_audio_transcriber.capture_queue", qos: .userInitiated)

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SystemCapturePlugin()

        let methodChannel = FlutterMethodChannel(
            name: "com.system_audio_transcriber/audio_capture",
            binaryMessenger: registrar.messenger
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "com.system_audio_transcriber/audio_stream",
            binaryMessenger: registrar.messenger
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)
        
        let statusEventChannel = FlutterEventChannel(
            name: "com.system_audio_transcriber/audio_status",
            binaryMessenger: registrar.messenger
        )
        instance.statusEventChannel = statusEventChannel
        statusEventChannel.setStreamHandler(SystemStatusStreamHandler(plugin: instance))
        
        let decibelEventChannel = FlutterEventChannel(
            name: "com.system_audio_transcriber/audio_decibel",
            binaryMessenger: registrar.messenger
        )
        instance.decibelEventChannel = decibelEventChannel
        decibelEventChannel.setStreamHandler(SystemDecibelStreamHandler(plugin: instance))
        
        // Register for app termination to cleanup
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate() {
        Task {
            await cleanupResources()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "requestPermissions":
            requestPermissions(result: result)

        case "startCapture":
            let config = call.arguments as? [String: Any]
            Task {
                await startCapture(config: config, result: result)
            }

        case "stopCapture":
            Task {
                await stopCapture(result: result)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermissions(result: @escaping FlutterResult) {
        let hasPermission = CGPreflightScreenCaptureAccess()

        if hasPermission {
            result(true)
            return
        }

        let granted = CGRequestScreenCaptureAccess()

        if granted {
            result(true)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.showPermissionAlert()
            }
            result(false)
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        This app needs Screen Recording permission to capture system audio.

        Please follow these steps:
        1. Click "Open System Settings" below
        2. In Privacy & Security → Screen Recording
        3. Enable the toggle for this app
        4. Restart the app
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func startCapture(config: [String: Any]?, result: @escaping FlutterResult) async {
        // Check if already capturing
        if isCapturing {
            print("⚠️ Already capturing, stopping first...")
            await cleanupResources()
            // Wait for cleanup
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Check permission
        guard CGPreflightScreenCaptureAccess() else {
            print("❌ No screen recording permission")
            let errorMessage = CaptureError.noPermission.message
            DispatchQueue.main.async { [weak self] in
                self?.showPermissionAlert()
                result(FlutterError(
                    code: "NO_PERMISSION",
                    message: errorMessage,
                    details: nil
                ))
            }
            return
        }
        
        // Parse and validate configuration
        let audioConfig: AudioConfiguration
        switch AudioConfiguration.from(config) {
        case .success(let cfg):
            audioConfig = cfg
        case .failure(let error):
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "INVALID_CONFIG",
                    message: error.message,
                    details: nil
                ))
            }
            return
        }
        
        do {
            print("🎬 Starting capture with config: \(audioConfig.sampleRate)Hz, \(audioConfig.channelCount)ch")
            
            // Get shareable content
            let availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            guard let display = availableContent.displays.first else {
                throw CaptureError.noDisplay
            }

            print("📺 Display: \(display.displayID)")
            
            // Configure stream
            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.sampleRate = Int(audioConfig.sampleRate)
            configuration.channelCount = audioConfig.channelCount
            configuration.excludesCurrentProcessAudio = true

            // Video settings - minimal to reduce overhead
            // ScreenCaptureKit requires video output even for audio-only capture
            configuration.width = 100
            configuration.height = 100
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS
            configuration.queueDepth = 3
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = false

            // Create filter and stream
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let newStreamOutput = StreamOutput(eventSink: eventSink, decibelEventSink: decibelEventSink)
            let newStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            let stream = newStream
            
            // Add output handlers
            // Note: macOS 13.x requires both audio and video handlers even if video is minimal
            try stream.addStreamOutput(newStreamOutput, type: .audio, sampleHandlerQueue: .main)
            
            // Only add video handler if not explicitly disabled (macOS 13.x compatibility)
            if #available(macOS 14.0, *) {
                // No video handler needed on macOS 14+ when capturesVideo = false
            } else {
                try stream.addStreamOutput(newStreamOutput, type: .screen, sampleHandlerQueue: .main)
            }

            // Start capture
            try await stream.startCapture()
            
            // Update state atomically on state queue
            // Use sync to avoid Sendable capture issues - we're already on async context
            stateQueue.sync { [weak self] in
                guard let self = self else { return }
                self.stream = stream
                self.streamOutput = newStreamOutput
                self._isCapturing = true
            }
            
            // Notify status change
            sendStatusUpdate(isActive: true)
            
            print("✅ Capture started successfully")
            DispatchQueue.main.async {
                result(true)
            }

        } catch let error as CaptureError {
            print("❌ Capture error: \(error.message)")
            await cleanupResources()
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "CAPTURE_ERROR",
                    message: error.message,
                    details: nil
                ))
            }
        } catch {
            print("❌ Unexpected error: \(error)")
            await cleanupResources()
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "CAPTURE_ERROR",
                    message: CaptureError.captureStartFailed(error).message,
                    details: "\(error)"
                ))
            }
        }
    }

    private func stopCapture(result: @escaping FlutterResult) async {
        guard isCapturing else {
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "NOT_CAPTURING",
                    message: CaptureError.notCapturing.message,
                    details: nil
                ))
            }
            return
        }
        
        await cleanupResources()
        
        print("✅ Capture stopped")
        DispatchQueue.main.async {
            result(true)
        }
    }
    
    // Centralized cleanup - idempotent and thread-safe
    private func cleanupResources() async {
        // Get current stream and output atomically
        let (currentStream, currentOutput) = await withCheckedContinuation { (continuation: CheckedContinuation<(SCStream?, StreamOutput?), Never>) in
            stateQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                continuation.resume(returning: (self.stream, self.streamOutput))
            }
        }
        
        guard let stream = currentStream else {
            // Already cleaned up
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                stateQueue.async { [weak self] in
                    self?._isCapturing = false
                    continuation.resume()
                }
            }
            return
        }
        
        do {
            // Remove outputs
            if let output = currentOutput {
                try stream.removeStreamOutput(output, type: .audio)
                
                // Only remove video handler if it was added (macOS 13.x)
                if #available(macOS 14.0, *) {
                    // No video handler to remove
                } else {
                    try stream.removeStreamOutput(output, type: .screen)
                }
            }

            // Stop stream
            try await stream.stopCapture()
            
            // Small delay for graceful shutdown
            try? await Task.sleep(nanoseconds: 50_000_000)
            
        } catch {
            print("⚠️ Cleanup error: \(error.localizedDescription)")
        }
        
        // Clear state atomically
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            stateQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                self.stream = nil
                self.streamOutput = nil
                self._isCapturing = false
                continuation.resume()
            }
        }
        
        // Notify status change
        sendStatusUpdate(isActive: false)
    }
    
    private func sendStatusUpdate(isActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.statusEventSink?([
                "isActive": isActive,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }
}

// MARK: - FlutterStreamHandler
@available(macOS 13.0, *)
extension SystemCapturePlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        streamOutput?.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        streamOutput?.eventSink = nil
        return nil
    }
}

// MARK: - Stream Output Handler
@available(macOS 13.0, *)
final class StreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    var eventSink: FlutterEventSink?
    var decibelEventSink: FlutterEventSink?
    private static var hasLoggedFormat = false
    private let processingQueue = DispatchQueue(label: "com.system_audio_transcriber.processing", qos: .userInitiated)

    init(eventSink: FlutterEventSink?, decibelEventSink: FlutterEventSink? = nil) {
        self.eventSink = eventSink
        self.decibelEventSink = decibelEventSink
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Only process audio, ignore video frames
        guard type == .audio else { return }

        // Process on background queue
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let audioData = self.extractAudioData(from: sampleBuffer) else {
                return
            }
            
            // Calculate decibel from audio data
            let decibel = self.calculateDecibel(from: audioData)
            
            // Send to Flutter on main thread
            DispatchQueue.main.async { [weak self] in
                if let sink = self?.eventSink {
                    sink(FlutterStandardTypedData(bytes: audioData))
                }
                
                // Send decibel data
                if let decibelSink = self?.decibelEventSink {
                    decibelSink([
                        "decibel": decibel,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                }
            }
        }
    }

    private func extractAudioData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer),
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        // Log format once
        if !StreamOutput.hasLoggedFormat {
            StreamOutput.hasLoggedFormat = true
            let desc = audioStreamBasicDescription.pointee
            print("🎤 Audio Format:")
            print("  Sample Rate: \(desc.mSampleRate) Hz")
            print("  Channels: \(desc.mChannelsPerFrame)")
            print("  Bits/Channel: \(desc.mBitsPerChannel)")
            print("  Format ID: \(desc.mFormatID)")
            print("  Format Flags: \(desc.mFormatFlags)")
        }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let pointer = dataPointer else {
            return nil
        }

        let desc = audioStreamBasicDescription.pointee
        
        // Float32 to Int16 conversion
        if desc.mFormatID == kAudioFormatLinearPCM && desc.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            return convertFloat32ToInt16(pointer: pointer, length: length)
        }
        
        // Already Int16
        if desc.mFormatID == kAudioFormatLinearPCM && desc.mBitsPerChannel == 16 {
            return Data(bytes: pointer, count: length)
        }

        print("⚠️ Unsupported audio format: \(desc.mFormatID)")
        return nil
    }
    
    private func convertFloat32ToInt16(pointer: UnsafeMutablePointer<Int8>, length: Int) -> Data {
        let floatPointer = pointer.withMemoryRebound(to: Float32.self, capacity: length / MemoryLayout<Float32>.size) { $0 }
        let sampleCount = length / MemoryLayout<Float32>.size

        var int16Data = Data(capacity: sampleCount * MemoryLayout<Int16>.size)
        
        for i in 0..<sampleCount {
            // Clamp and convert
            let sample = min(max(floatPointer[i], -1.0), 1.0)
            let int16Sample = Int16(sample * 32767.0)
            withUnsafeBytes(of: int16Sample) { int16Data.append(contentsOf: $0) }
        }

        return int16Data
    }
    
    /// Calculate decibel (dB) from Int16 PCM audio data
    /// Returns RMS-based decibel value, typically ranges from -∞ to 0 dB
    private func calculateDecibel(from audioData: Data) -> Double {
        guard audioData.count >= 2 else { return -120.0 } // Silence threshold
        
        // Convert Data to Int16 array
        let sampleCount = audioData.count / MemoryLayout<Int16>.size
        var samples: [Int16] = []
        samples.reserveCapacity(sampleCount)
        
        audioData.withUnsafeBytes { bytes in
            let int16Pointer = bytes.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                samples.append(int16Pointer[i])
            }
        }
        
        guard !samples.isEmpty else { return -120.0 }
        
        // Calculate RMS (Root Mean Square)
        let sumOfSquares = samples.reduce(0.0) { sum, sample in
            let value = Double(sample)
            return sum + (value * value)
        }
        let meanSquare = sumOfSquares / Double(samples.count)
        let rms = sqrt(meanSquare)
        
        // Calculate decibel: dB = 20 * log10(RMS / max_value)
        // For Int16, max_value is 32767.0
        let maxValue = 32767.0
        guard rms > 0 else { return -120.0 } // Avoid log(0)
        
        let decibel = 20.0 * log10(rms / maxValue)
        
        // Clamp to reasonable range (-120 dB to 0 dB)
        return max(-120.0, min(0.0, decibel))
    }
}

// MARK: - System Status Stream Handler
@available(macOS 13.0, *)
class SystemStatusStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: SystemCapturePlugin?
    
    init(plugin: SystemCapturePlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.statusEventSink = events
        // Send current status immediately
        let isActive = plugin?.isCapturing ?? false
        events([
            "isActive": isActive,
            "timestamp": Date().timeIntervalSince1970
        ])
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.statusEventSink = nil
        return nil
    }
}

// MARK: - System Decibel Stream Handler
@available(macOS 13.0, *)
class SystemDecibelStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: SystemCapturePlugin?
    
    init(plugin: SystemCapturePlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.decibelEventSink = events
        // Update StreamOutput with decibel sink
        plugin?.streamOutput?.decibelEventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.decibelEventSink = nil
        plugin?.streamOutput?.decibelEventSink = nil
        return nil
    }
}
