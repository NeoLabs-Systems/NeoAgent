import Cocoa
import FlutterMacOS
import AVFoundation
import CoreAudio

class MicCapturePlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    private var statusEventChannel: FlutterEventChannel?
    var statusEventSink: FlutterEventSink?
    
    private var decibelEventChannel: FlutterEventChannel?
    var decibelEventSink: FlutterEventSink?
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    var isCapturing = false
    var currentDeviceName: String?
    
    // Serial queue to ensure thread safety
    private let audioQueue = DispatchQueue(label: "com.mic_audio_transcriber.audio_queue", qos: .userInitiated)
    
    // Audio format configuration (defaults, can be overridden by config)
    private var sampleRate: Double = 16000.0
    private var channels: UInt32 = 1
    private var bitDepth: UInt32 = 16
    
    // Gain boost to increase microphone sensitivity (default: 2.5)
    private var gainBoost: Float = 2.5
    
    // Input volume (default: 1.0)
    private var inputVolume: Float = 1.0
    
    // Debug counters for logging
    private var decibelLogCount = 0
    private var audioDataLogCount = 0
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = MicCapturePlugin()
        
        let methodChannel = FlutterMethodChannel(
            name: "com.mic_audio_transcriber/mic_capture",
            binaryMessenger: registrar.messenger
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        let eventChannel = FlutterEventChannel(
            name: "com.mic_audio_transcriber/mic_stream",
            binaryMessenger: registrar.messenger
        )
        instance.eventChannel = eventChannel
        eventChannel.setStreamHandler(instance)
        
        let statusEventChannel = FlutterEventChannel(
            name: "com.mic_audio_transcriber/mic_status",
            binaryMessenger: registrar.messenger
        )
        instance.statusEventChannel = statusEventChannel
        statusEventChannel.setStreamHandler(StatusStreamHandler(plugin: instance))
        
        let decibelEventChannel = FlutterEventChannel(
            name: "com.mic_audio_transcriber/mic_decibel",
            binaryMessenger: registrar.messenger
        )
        instance.decibelEventChannel = decibelEventChannel
        decibelEventChannel.setStreamHandler(MicDecibelStreamHandler(plugin: instance))
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            
        case "requestPermissions":
            requestPermissions(result: result)
            
        case "hasInputDevice":
            hasInputDevice(result: result)
            
        case "getAvailableInputDevices":
            getAvailableInputDevices(result: result)
            
        case "startCapture":
            if let args = call.arguments as? [String: Any] {
                startCapture(config: args, result: result)
            } else {
                startCapture(config: nil, result: result)
            }
            
        case "stopCapture":
            stopCapture(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func requestPermissions(result: @escaping FlutterResult) {
        // Check permission status on macOS
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            result(true)
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    result(granted)
                }
            }
        case .denied, .restricted:
            result(false)
        @unknown default:
            result(false)
        }
    }
    
    private func hasInputDevice(result: @escaping FlutterResult) {
        // Check if there's any input device available
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        // If status is not OK or deviceID is invalid (kAudioDeviceUnknown = 0)
        if status != noErr || deviceID == kAudioObjectUnknown {
            print("❌ No input device available")
            result(false)
            return
        }
        
        // Double check: try to get device name to ensure it's a real device
        propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
        propertySize = UInt32(MemoryLayout<CFString>.size)
        var deviceNameCFString: Unmanaged<CFString>?
        
        let nameStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceNameCFString
        )
        
        if nameStatus == noErr, let cfString = deviceNameCFString?.takeRetainedValue() {
            let deviceName = cfString as String
            print("✅ Input device available: \(deviceName)")
            result(true)
        } else {
            print("❌ No valid input device found")
            result(false)
        }
    }
    
    private func getAvailableInputDevices(result: @escaping FlutterResult) {
        var devices: [[String: Any]] = []
        
        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else {
            print("❌ Failed to get audio devices size")
            result(devices)
            return
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &audioDevices
        )
        
        guard status == noErr else {
            print("❌ Failed to get audio devices")
            result(devices)
            return
        }
        
        // Get default input device for comparison
        var defaultDeviceID: AudioDeviceID = 0
        var defaultPropertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultPropertyAddress,
            0,
            nil,
            &defaultPropertySize,
            &defaultDeviceID
        )
        
        // Filter for input devices
        for deviceID in audioDevices {
            // Check if device has input channels
            propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration
            propertyAddress.mScope = kAudioDevicePropertyScopeInput
            propertySize = 0
            
            status = AudioObjectGetPropertyDataSize(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize
            )
            
            guard status == noErr else { continue }
            
            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferListPointer.deallocate() }
            
            status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                bufferListPointer
            )
            
            guard status == noErr else { continue }
            
            let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            var channelCount = 0
            for buffer in bufferList {
                channelCount += Int(buffer.mNumberChannels)
            }
            
            // Skip if no input channels
            if channelCount == 0 { continue }
            
            // Get device name
            propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
            propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
            propertySize = UInt32(MemoryLayout<CFString>.size)
            var deviceNameCFString: Unmanaged<CFString>?
            
            status = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &deviceNameCFString
            )
            
            guard status == noErr, let cfString = deviceNameCFString?.takeRetainedValue() else {
                continue
            }
            
            let deviceName = cfString as String
            
            // Get transport type
            propertyAddress.mSelector = kAudioDevicePropertyTransportType
            propertySize = UInt32(MemoryLayout<UInt32>.size)
            var transportType: UInt32 = 0
            
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &transportType
            )
            
            let isBluetooth = (transportType == 0x626c7565) // 'blue'
            let isBuiltIn = (transportType == 0x62756c74) // 'bult'
            
            var deviceType = "external"
            if isBuiltIn {
                deviceType = "built-in"
            } else if isBluetooth {
                deviceType = "bluetooth"
            }
            
            let deviceInfo: [String: Any] = [
                "id": String(deviceID),
                "name": deviceName,
                "type": deviceType,
                "channelCount": channelCount,
                "isDefault": deviceID == defaultDeviceID
            ]
            
            devices.append(deviceInfo)
            print("🎤 Found input device: \(deviceName) (\(deviceType), \(channelCount) channels)")
        }
        
        print("✅ Total input devices found: \(devices.count)")
        result(devices)
    }
    
    private func startCapture(config: [String: Any]?, result: @escaping FlutterResult) {
        // Ensure operations run on audio queue to avoid race conditions
        audioQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { result(false) }
                return
            }
            
            // Always cleanup any existing engine first to ensure clean start
            // This is important even if isCapturing is false (state might be out of sync)
            if let existingEngine = self.audioEngine {
                print("⚠️ Found existing engine, cleaning up first...")
                if existingEngine.isRunning {
                    existingEngine.stop()
                }
                if let existingInput = self.inputNode {
                    existingInput.removeTap(onBus: 0)
                }
                self.audioEngine = nil
                self.inputNode = nil
                self.isCapturing = false
                // Wait for cleanup to complete (longer for Bluetooth devices)
                Thread.sleep(forTimeInterval: 0.5)
            } else if self.isCapturing {
                // If no engine but isCapturing is true, just reset state
                print("⚠️ State mismatch: isCapturing=true but no engine, resetting...")
                self.isCapturing = false
                self.inputNode = nil
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // Parse configuration from Flutter
            if let config = config {
                if let sampleRateValue = config["sampleRate"] as? NSNumber {
                    self.sampleRate = sampleRateValue.doubleValue
                }
                if let channelsValue = config["channels"] as? NSNumber {
                    self.channels = channelsValue.uint32Value
                }
                if let bitDepthValue = config["bitDepth"] as? NSNumber {
                    self.bitDepth = bitDepthValue.uint32Value
                }
                if let gainBoostValue = config["gainBoost"] as? NSNumber {
                    self.gainBoost = gainBoostValue.floatValue
                    // Clamp gain boost to reasonable range (0.1 to 10.0)
                    self.gainBoost = max(0.1, min(10.0, self.gainBoost))
                }
                if let inputVolumeValue = config["inputVolume"] as? NSNumber {
                    self.inputVolume = inputVolumeValue.floatValue
                    // Clamp input volume to valid range (0.0 to 1.0)
                    self.inputVolume = max(0.0, min(1.0, self.inputVolume))
                }
            }
            
            // Check permission before starting
            let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if permissionStatus != .authorized {
                print("❌ Microphone permission not granted. Status: \(permissionStatus.rawValue)")
                DispatchQueue.main.async { 
                    result(FlutterError(
                        code: "PERMISSION_DENIED",
                        message: "Microphone permission not granted. Status: \(permissionStatus.rawValue)",
                        details: nil
                    ))
                }
                return
            }
            
            // Create new audio engine
            // All cleanup should be done above
            let engine = AVAudioEngine()
            let input = engine.inputNode
            
            // Check if input is available
            let inputFormat = input.outputFormat(forBus: 0)
            if inputFormat.sampleRate == 0 {
                print("❌ No input device available or input format invalid")
                DispatchQueue.main.async { 
                    result(FlutterError(
                        code: "NO_INPUT_DEVICE",
                        message: "No microphone input device available",
                        details: nil
                    ))
                }
                return
            }
            
            // Detect if device is Bluetooth and adjust wait times accordingly
            let isBluetooth = self.isBluetoothDevice()
            let initialWait: Double = isBluetooth ? 1.5 : 0.3
            let postPrepareWait: Double = isBluetooth ? 0.8 : 0.3
            
            if isBluetooth {
                print("🔵 Bluetooth device detected - using extended wait times")
            }
            
            // Wait for device to be fully ready
            print("⏳ Waiting \(initialWait)s for device to be ready...")
            Thread.sleep(forTimeInterval: initialWait)
            
            // Set input volume from config
            // Note: input.volume affects the input level, but system input volume also matters
            input.volume = self.inputVolume
            print("🎤 Input Format:")
            print("  Sample Rate: \(inputFormat.sampleRate) Hz")
            print("  Channels: \(inputFormat.channelCount)")
            print("  Format: \(inputFormat.commonFormat.rawValue)")
            print("  Is Interleaved: \(inputFormat.isInterleaved)")
            print("  Output Sample Rate: \(self.sampleRate) Hz")
            print("  Output Channels: \(self.channels)")
            print("  Gain Boost: \(self.gainBoost)x")
            print("  Input Volume: \(self.inputVolume)")
            print("  Input Node Volume: \(input.volume)")
            
            // Check system input volume using CoreAudio
            // Get default input device
            var defaultDeviceID: AudioDeviceID = 0
            var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &defaultDeviceID
            )
            
            if status == noErr && defaultDeviceID != 0 {
                // Get input volume
                var inputVolume: Float32 = 0.0
                propertySize = UInt32(MemoryLayout<Float32>.size)
                propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                
                let getStatus = AudioObjectGetPropertyData(
                    defaultDeviceID,
                    &propertyAddress,
                    0,
                    nil,
                    &propertySize,
                    &inputVolume
                )
                
                if getStatus == noErr {
                    print("  System Input Volume: \(inputVolume)")
                    if inputVolume == 0.0 {
                        print("⚠️ WARNING: System input volume is 0! Audio may be silent.")
                        print("⚠️ Please check System Settings > Sound > Input and increase input volume.")
                    }
                } else {
                    print("  System Input Volume: Unable to read (may not be supported on this device)")
                }
            } else {
                print("  System Input Volume: Unable to get default input device")
            }
            
            // Create output format
            guard let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: self.sampleRate,
                channels: self.channels,
                interleaved: false
            ) else {
                print("❌ Failed to create output format")
                DispatchQueue.main.async { 
                    result(FlutterError(
                        code: "FORMAT_ERROR",
                        message: "Failed to create output format",
                        details: nil
                    ))
                }
                return
            }
            
            // Connect input to main mixer FIRST with nil format
            // This lets AVAudioEngine use the node's native format automatically
            let mainMixer = engine.mainMixerNode
            let output = engine.outputNode
            engine.connect(input, to: mainMixer, format: nil)
            
            // Connect main mixer to output node to complete the audio graph
            // This is required for the engine to start properly
            engine.connect(mainMixer, to: output, format: nil)
            
            // Mute the output to prevent audio playback
            mainMixer.outputVolume = 0.0
            
            // Install tap on input node AFTER connecting
            // Use nil format to let AVAudioEngine automatically use the correct format
            // This avoids format mismatch errors
            let bufferSize: AVAudioFrameCount = 4096
            input.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] (buffer, time) in
                self?.processAudioBuffer(buffer, outputFormat: outputFormat)
            }
            
            // Prepare the engine before starting
            engine.prepare()
            
            // Wait for engine initialization (longer for Bluetooth)
            print("⏳ Waiting \(postPrepareWait)s after engine.prepare()...")
            Thread.sleep(forTimeInterval: postPrepareWait)
            
            // Start audio engine with retry mechanism
            // Bluetooth devices often need multiple attempts with longer waits
            var startSuccess = false
            var lastError: Error?
            let maxRetries = isBluetooth ? 5 : 3  // More retries for Bluetooth
            let retryDelays: [Double] = isBluetooth 
                ? [0.5, 1.0, 1.5, 2.0, 2.5]  // Progressive delays for Bluetooth
                : [0.3, 0.6, 1.0, 0, 0]      // Shorter delays for wired devices
            
            for attempt in 1...maxRetries {
                do {
                    try engine.start()
                    startSuccess = true
                    print("✅ Engine started successfully on attempt \(attempt)")
                    break
                } catch let startError {
                    lastError = startError
                    let errorMsg = (startError as NSError).localizedDescription
                    let errorCode = (startError as NSError).code
                    
                    print("⚠️ Attempt \(attempt)/\(maxRetries) failed: \(errorMsg)")
                    print("   Error domain: \((startError as NSError).domain)")
                    print("   Error code: \(errorCode)")
                    
                    // Check if it's the specific Bluetooth error (-10877)
                    if errorCode == -10877 {
                        print("   This is kAudioUnitErr_CannotDoInCurrentContext - device not ready")
                    }
                    
                    if attempt < maxRetries {
                        // Use progressive wait times
                        let waitTime = retryDelays[attempt - 1]
                        let totalWaited = retryDelays.prefix(attempt).reduce(0, +) + initialWait + postPrepareWait
                        print("   ⏳ Waiting \(waitTime)s before retry (total time: \(String(format: "%.1f", totalWaited + waitTime))s)...")
                        Thread.sleep(forTimeInterval: waitTime)
                    }
                }
            }
            
            // If all retries failed, clean up and return error
            if !startSuccess {
                let errorMsg = (lastError as NSError?)?.localizedDescription ?? "Unknown error"
                let errorCode = (lastError as NSError?)?.code ?? 0
                let totalTime = initialWait + postPrepareWait + retryDelays.prefix(maxRetries - 1).reduce(0, +)
                print("❌ Failed to start engine after \(maxRetries) attempts")
                print("   Total time waited: ~\(String(format: "%.1f", totalTime))s")
                
                // Clean up
                engine.stop()
                input.removeTap(onBus: 0)
                
                var detailedMessage = "Failed to start audio engine after \(maxRetries) attempts (\(String(format: "%.1f", totalTime))s): \(errorMsg)."
                if errorCode == -10877 {
                    if isBluetooth {
                        detailedMessage += " Bluetooth device needs more time to connect. Please ensure the device is fully connected in System Settings, then try again."
                    } else {
                        detailedMessage += " Device is not ready yet. Please wait a moment and try again."
                    }
                } else {
                    detailedMessage += " Device may need more time to connect."
                }
                
                DispatchQueue.main.async { 
                    result(FlutterError(
                        code: "ENGINE_START_FAILED",
                        message: detailedMessage,
                        details: ["errorCode": errorCode, "totalRetries": maxRetries, "isBluetooth": isBluetooth]
                    ))
                }
                return
            }
            
            // Wait a bit to ensure engine has fully started
            Thread.sleep(forTimeInterval: 0.2)
            
            // Check if engine is running
            guard engine.isRunning else {
                print("❌ Audio engine failed to start - isRunning: \(engine.isRunning)")
                print("   Engine state after start attempt:")
                print("   - isRunning: \(engine.isRunning)")
                
                // Try to get more error info
                if let error = engine.outputNode.lastRenderTime {
                    print("   - Last render time: \(error)")
                }
                
                // Clean up
                engine.stop()
                input.removeTap(onBus: 0)
                
                DispatchQueue.main.async { 
                    result(FlutterError(
                        code: "ENGINE_START_FAILED",
                        message: "Audio engine failed to start - engine is not running after start() call",
                        details: nil
                    ))
                }
                return
            }
            
            // Get device name
            let deviceName = self.getCurrentDeviceName()
            self.currentDeviceName = deviceName
            
            // Update state
            self.audioEngine = engine
            self.inputNode = input
            self.isCapturing = true
            
            // Send status update
            self.sendStatusUpdate(isActive: true, deviceName: deviceName)
            
            print("✅ Microphone capture started successfully!")
            if let deviceName = deviceName {
                print("  Device: \(deviceName)")
            }
            DispatchQueue.main.async { result(true) }
        }
    }
    
    private func stopCapture(result: @escaping FlutterResult) {
        audioQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { result(false) }
                return
            }
            
            self.forceStop()
            DispatchQueue.main.async { result(true) }
        }
    }
    
    // Force stop - complete cleanup, can be called from any thread
    private func forceStop() {
        guard isCapturing else {
            // Even if not capturing, clean up any remaining engine
            if let engine = audioEngine {
                if engine.isRunning {
                    engine.stop()
                }
                audioEngine = nil
            }
            if let input = inputNode {
                input.removeTap(onBus: 0)
                inputNode = nil
            }
            return
        }
        
        if let engine = audioEngine, let input = inputNode {
            // Remove tap first (must be done before stopping)
            input.removeTap(onBus: 0)
            
            // Stop engine
            if engine.isRunning {
                engine.stop()
            }
            
            // Wait a bit to ensure engine has fully stopped
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Clean up state
        audioEngine = nil
        inputNode = nil
        isCapturing = false
        currentDeviceName = nil
        
        // Send status update
        sendStatusUpdate(isActive: false, deviceName: nil)
        
        print("✅ Microphone capture stopped")
    }
    
    // Get current microphone device name using CoreAudio
    private func getCurrentDeviceName() -> String? {
        var deviceName: String? = nil
        
        // Get default input device ID
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            return "Default Microphone"
        }
        
        // Get device name
        propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
        propertySize = UInt32(MemoryLayout<CFString>.size)
        var deviceNameCFString: Unmanaged<CFString>?
        
        let nameStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceNameCFString
        )
        
        if nameStatus == noErr, let cfString = deviceNameCFString?.takeRetainedValue() {
            deviceName = cfString as String
        }
        
        return deviceName ?? "Default Microphone"
    }
    
    // Check if device is Bluetooth by name or transport type
    private func isBluetoothDevice() -> Bool {
        // Get default input device ID
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            return false
        }
        
        // Check transport type
        propertyAddress.mSelector = kAudioDevicePropertyTransportType
        propertySize = UInt32(MemoryLayout<UInt32>.size)
        var transportType: UInt32 = 0
        
        let transportStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &transportType
        )
        
        // kAudioDeviceTransportTypeBluetooth = 'blue' = 0x626c7565
        if transportStatus == noErr && transportType == 0x626c7565 {
            print("🔵 Detected Bluetooth device via transport type")
            return true
        }
        
        // Fallback: check device name for Bluetooth keywords
        if let deviceName = getCurrentDeviceName()?.lowercased() {
            let bluetoothKeywords = ["bluetooth", "airpods", "beats", "jabra", "sony", "bose", "jbl"]
            for keyword in bluetoothKeywords {
                if deviceName.contains(keyword) {
                    print("🔵 Detected Bluetooth device via name: \(deviceName)")
                    return true
                }
            }
        }
        
        return false
    }
    
    // Send status update to Flutter
    private func sendStatusUpdate(isActive: Bool, deviceName: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let sink = self.statusEventSink else { return }
            
            var status: [String: Any] = [
                "isActive": isActive
            ]
            
            if let deviceName = deviceName {
                status["deviceName"] = deviceName
            }
            
            sink(status)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, outputFormat: AVAudioFormat) {
        // Calculate decibel directly from original buffer (Float32) for accuracy
        // This avoids potential data loss during conversion
        let decibel = calculateDecibelFromFloatBuffer(buffer)
        
        // Debug: Check original buffer
        audioDataLogCount += 1
        if audioDataLogCount % 100 == 0 {
            print("🔊 Original buffer: frameLength=\(buffer.frameLength), format=\(buffer.format), channels=\(buffer.format.channelCount)")
            if let floatChannelData = buffer.floatChannelData {
                let channel = floatChannelData.pointee
                let firstFew = (0..<min(5, Int(buffer.frameLength))).map { channel[$0] }
                print("🔊 Original buffer first few float samples: \(firstFew)")
            }
            if let int16ChannelData = buffer.int16ChannelData {
                let channel = int16ChannelData.pointee
                let firstFew = (0..<min(5, Int(buffer.frameLength))).map { channel[$0] }
                print("🔊 Original buffer first few int16 samples: \(firstFew)")
            }
            print("🔊 Decibel from original buffer: \(String(format: "%.1f", decibel)) dB")
        }
        
        // Convert buffer to target format if needed
        guard let convertedBuffer = convertBuffer(buffer, to: outputFormat) else {
            print("⚠️ Decibel: Failed to convert buffer")
            return
        }
        
        // Debug: Check converted buffer
        if audioDataLogCount % 100 == 0 {
            print("🔊 Converted buffer: frameLength=\(convertedBuffer.frameLength), format=\(convertedBuffer.format)")
            if let int16ChannelData = convertedBuffer.int16ChannelData {
                let channel = int16ChannelData.pointee
                let firstFew = (0..<min(5, Int(convertedBuffer.frameLength))).map { channel[$0] }
                print("🔊 Converted buffer first few int16 samples: \(firstFew)")
            }
        }
        
        // Extract PCM data
        guard let audioData = extractPCMData(from: convertedBuffer) else {
            print("⚠️ Decibel: Failed to extract PCM data")
            return
        }
        
        // Debug: log audio data size
        if audioDataLogCount % 100 == 0 {
            print("🔊 Final audio data size: \(audioData.count) bytes")
        }
        
        // Debug log occasionally
        decibelLogCount += 1
        if decibelLogCount % 100 == 0 {
            print("🔊 Decibel calculated: \(String(format: "%.1f", decibel)) dB, audioData size: \(audioData.count) bytes")
        }
        
        // Send to Flutter via event channel on main thread
        // Check eventSink in closure to ensure thread safety
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let sink = self.eventSink {
                sink(FlutterStandardTypedData(bytes: audioData))
            } else {
                // Log warning if eventSink is not set (stream not subscribed)
                print("⚠️ Audio data received but eventSink is nil - stream may not be subscribed")
            }
            
            // Send decibel data
            if let decibelSink = self.decibelEventSink {
                decibelSink([
                    "decibel": decibel,
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
        }
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // If formats match, return as is
        if buffer.format.isEqual(format) {
            return buffer
        }
        
        // Create converter
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }
        
        // Calculate output buffer size
        let ratio = format.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCapacity) else {
            return nil
        }
        
        // Convert
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("⚠️ Conversion error: \(error)")
            return nil
        }
        
        return outputBuffer
    }
    
    private func extractPCMData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let int16ChannelData = buffer.int16ChannelData else {
            print("⚠️ Decibel: int16ChannelData is nil")
            return nil
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Debug: Check if buffer has data
        if audioDataLogCount % 100 == 0 {
            let channel = int16ChannelData.pointee
            let maxSample = (0..<frameLength).map { abs(channel[$0]) }.max() ?? 0
            print("🔊 Extract PCM: frameLength=\(frameLength), channels=\(channelCount), maxSample=\(maxSample)")
        }
        
        // Apply gain boost and convert to mono if needed
        var monoData = Data(capacity: frameLength * MemoryLayout<Int16>.size)
        let maxValue: Float = 32767.0
        let minValue: Float = -32768.0
        
        if channelCount == 1 {
            // Mono: apply gain boost
            let channel = int16ChannelData.pointee
            for i in 0..<frameLength {
                let sample = Float(channel[i]) * gainBoost
                // Clamp to prevent clipping
                let clamped = max(minValue, min(maxValue, sample))
                let boosted = Int16(clamped)
                withUnsafeBytes(of: boosted) { monoData.append(contentsOf: $0) }
            }
        } else {
            // Stereo: convert to mono and apply gain boost
            let leftChannel = int16ChannelData.pointee
            let rightChannel = int16ChannelData.advanced(by: 1).pointee
            
            for i in 0..<frameLength {
                let left = Float(leftChannel[i])
                let right = Float(rightChannel[i])
                // Average channels then apply gain boost
                let mono = (left + right) / 2.0 * gainBoost
                // Clamp to prevent clipping
                let clamped = max(minValue, min(maxValue, mono))
                let boosted = Int16(clamped)
                withUnsafeBytes(of: boosted) { monoData.append(contentsOf: $0) }
            }
        }
        
        // Debug: Check extracted data
        if audioDataLogCount % 100 == 0 {
            let firstFewBytes = monoData.prefix(10).map { Int8(bitPattern: $0) }
            print("🔊 Extracted data first few bytes: \(firstFewBytes)")
        }
        
        return monoData
    }
    
    /// Calculate decibel (dB) directly from Float32 buffer
    /// Returns RMS-based decibel value, typically ranges from -∞ to 0 dB
    private func calculateDecibelFromFloatBuffer(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let floatChannelData = buffer.floatChannelData else {
            return -120.0
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameLength > 0 else { return -120.0 }
        
        // Calculate RMS from all channels
        var sumOfSquares: Double = 0.0
        var sampleCount = 0
        
        if channelCount == 1 {
            let channel = floatChannelData.pointee
            for i in 0..<frameLength {
                let value = Double(channel[i])
                sumOfSquares += value * value
                sampleCount += 1
            }
        } else {
            // Multi-channel: use average of all channels
            for channelIndex in 0..<channelCount {
                let channel = floatChannelData.advanced(by: channelIndex).pointee
                for i in 0..<frameLength {
                    let value = Double(channel[i])
                    sumOfSquares += value * value
                    sampleCount += 1
                }
            }
            // Average across channels
            sumOfSquares /= Double(channelCount)
        }
        
        guard sampleCount > 0 else { return -120.0 }
        
        let meanSquare = sumOfSquares / Double(sampleCount)
        let rms = sqrt(meanSquare)
        
        // Calculate decibel: dB = 20 * log10(RMS / max_value)
        // For Float32, max_value is 1.0
        guard rms > 0 else { return -120.0 } // Avoid log(0)
        
        let decibel = 20.0 * log10(rms)
        
        // Clamp to reasonable range (-120 dB to 0 dB)
        return max(-120.0, min(0.0, decibel))
    }
    
    /// Calculate decibel (dB) from Int16 PCM audio data
    /// Returns RMS-based decibel value, typically ranges from -∞ to 0 dB
    private func calculateDecibel(from audioData: Data) -> Double {
        guard audioData.count >= 2 else {
            print("⚠️ Decibel: audioData too small: \(audioData.count) bytes")
            return -120.0 // Silence threshold
        }
        
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
        
        guard !samples.isEmpty else {
            print("⚠️ Decibel: no samples extracted")
            return -120.0
        }
        
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
        guard rms > 0 else {
            print("⚠️ Decibel: RMS is 0, all samples are silent. Sample count: \(samples.count), first few: \(samples.prefix(5))")
            return -120.0 // Avoid log(0)
        }
        
        let decibel = 20.0 * log10(rms / maxValue)
        
        // Clamp to reasonable range (-120 dB to 0 dB)
        let clampedDecibel = max(-120.0, min(0.0, decibel))
        
        return clampedDecibel
    }
}

// MARK: - FlutterStreamHandler
extension MicCapturePlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("🎧 Audio stream listener attached")
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("🎧 Audio stream listener cancelled")
        self.eventSink = nil
        return nil
    }
}

// MARK: - Status Stream Handler
class StatusStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: MicCapturePlugin?
    
    init(plugin: MicCapturePlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.statusEventSink = events
        // Send current status immediately
        let isActive = plugin?.isCapturing ?? false
        let deviceName = plugin?.currentDeviceName
        var status: [String: Any] = ["isActive": isActive]
        if let deviceName = deviceName {
            status["deviceName"] = deviceName
        }
        events(status)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.statusEventSink = nil
        return nil
    }
}

// MARK: - Mic Decibel Stream Handler
class MicDecibelStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: MicCapturePlugin?
    
    init(plugin: MicCapturePlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.decibelEventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.decibelEventSink = nil
        return nil
    }
}