import 'dart:async';

import 'package:desktop_audio_capture/audio_capture.dart';
import 'package:flutter/services.dart';
export 'package:desktop_audio_capture/config/mic_audio_config.dart';

enum _MicAudioMethod {
  startCapture,
  stopCapture,
  requestPermissions,
  hasInputDevice,
  getAvailableInputDevices,
}

/// Class for capturing audio from microphone input devices.
///
/// This class allows you to capture audio from connected microphones,
/// including built-in microphones, external USB microphones, and Bluetooth
/// microphones. It requires microphone permissions.
///
/// Example:
/// ```dart
/// final micCapture = MicAudioCapture(
///   config: MicAudioConfig(
///     sampleRate: 44100,
///     channels: 1,
///     gainBoost: 2.5,
///   ),
/// );
///
/// // Check for available devices
/// final devices = await micCapture.getAvailableInputDevices();
/// print('Available microphones: ${devices.length}');
///
/// await micCapture.startCapture();
///
/// // Listen to audio stream
/// micCapture.audioStream?.listen((audioData) {
///   // Process audio bytes
///   print('Received ${audioData.length} bytes');
/// });
///
/// // Listen to status updates
/// micCapture.statusStream?.listen((status) {
///   print('Mic active: ${status.isActive}, Device: ${status.deviceName}');
/// });
///
/// // Listen to decibel readings
/// micCapture.decibelStream?.listen((data) {
///   print('Mic level: ${data.decibel} dB');
/// });
///
/// // Stop when done
/// await micCapture.stopCapture();
/// ```
class MicAudioCapture extends AudioCapture {
  static const MethodChannel _channel = MethodChannel(
    'com.mic_audio_transcriber/mic_capture',
  );
  static const EventChannel _audioStreamChannel = EventChannel(
    'com.mic_audio_transcriber/mic_stream',
  );
  static const EventChannel _statusStreamChannel = EventChannel(
    'com.mic_audio_transcriber/mic_status',
  );
  static const EventChannel _decibelStreamChannel = EventChannel(
    'com.mic_audio_transcriber/mic_decibel',
  );

  Stream<Uint8List>? _audioStream;
  Stream<MicAudioStatus>? _statusStream;
  Stream<DecibelData>? _decibelStream;
  bool _isRecording = false;

  /// Stream of raw audio data bytes from microphone capture.
  ///
  /// Returns a [Stream<Uint8List>] containing the captured audio data.
  /// The stream is only available after [startCapture] has been called.
  ///
  /// Example:
  /// ```dart
  /// await micCapture.startCapture();
  ///
  /// micCapture.audioStream?.listen((audioData) {
  ///   // Process audio bytes
  ///   final audioBuffer = audioData.buffer.asUint8List();
  ///   // Use audio buffer for processing, saving, streaming, etc.
  /// });
  /// ```
  Stream<Uint8List>? get audioStream {
    // Return existing stream if available
    if (_audioStream != null) {
      return _audioStream;
    }
    // If not recording, return null
    if (!_isRecording) {
      return null;
    }
    // Create stream lazily if recording but stream not created yet
    _audioStream = _audioStreamChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      if (event is Uint8List) {
        return event;
      } else if (event is List<int>) {
        return Uint8List.fromList(event);
      }
      throw Exception('Unexpected audio data type: ${event.runtimeType}');
    });
    return _audioStream;
  }

  /// Stream of microphone status updates.
  ///
  /// Returns a [Stream<MicStatus>] containing:
  /// - `isActive`: bool - whether mic is currently active
  /// - `deviceName`: String? - name of the microphone device (if available)
  ///
  /// Example:
  /// ```dart
  /// micCapture.statusStream?.listen((status) {
  ///   if (status.isActive) {
  ///     print('Microphone is active');
  ///     if (status.deviceName != null) {
  ///       print('Using device: ${status.deviceName}');
  ///     }
  ///   } else {
  ///     print('Microphone is inactive');
  ///   }
  /// });
  /// ```
  Stream<MicAudioStatus>? get statusStream {
    // Create status stream if not already created
    _statusStream ??= _statusStreamChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      if (event is Map) {
        return MicAudioStatus.fromJson(Map<String, dynamic>.from(event));
      }
      return const MicAudioStatus(isActive: false);
    });
    return _statusStream;
  }

  /// Stream of microphone decibel (dB) readings.
  ///
  /// Returns a [Stream<DecibelData>] containing:
  /// - `decibel`: double - decibel value (-120 to 0 dB)
  /// - `timestamp`: double - Unix timestamp
  ///
  /// The stream is only available while recording is active.
  ///
  /// Example:
  /// ```dart
  /// await micCapture.startCapture();
  ///
  /// micCapture.decibelStream?.listen((data) {
  ///   print('Microphone level: ${data.decibel.toStringAsFixed(1)} dB');
  ///   print('Timestamp: ${DateTime.fromMillisecondsSinceEpoch((data.timestamp * 1000).toInt())}');
  ///
  ///   // Use for visual feedback, volume meters, etc.
  ///   if (data.decibel > -40) {
  ///     print('Loud input detected!');
  ///   }
  /// });
  /// ```
  Stream<DecibelData>? get decibelStream => _decibelStream;

  MicAudioConfig _config = MicAudioConfig();

  /// Creates a new [MicAudioCapture] instance.
  ///
  /// [config] is optional. If not provided, default configuration will be used
  /// (sampleRate: 16000, channels: 1, bitDepth: 16, gainBoost: 2.5, inputVolume: 1.0).
  ///
  /// Example:
  /// ```dart
  /// final capture = MicAudioCapture(
  ///   config: MicAudioConfig(
  ///     sampleRate: 44100,
  ///     channels: 1,
  ///     gainBoost: 3.0,
  ///     inputVolume: 0.8,
  ///   ),
  /// );
  /// ```
  MicAudioCapture({MicAudioConfig? config}) {
    _config = config ?? MicAudioConfig();
  }

  /// Updates the audio capture configuration.
  ///
  /// This method allows you to change the configuration after the instance
  /// has been created. The new configuration will be applied on the next
  /// [startCapture] call.
  ///
  /// Example:
  /// ```dart
  /// final capture = MicAudioCapture();
  ///
  /// // Update config before starting
  /// capture.updateConfig(MicAudioConfig(
  ///   sampleRate: 48000,
  ///   channels: 2,
  ///   gainBoost: 2.0,
  /// ));
  ///
  /// await capture.startCapture();
  /// ```
  void updateConfig(MicAudioConfig config) {
    _config = config;
  }

  /// Starts capturing audio from the microphone.
  ///
  /// This method will request necessary permissions (microphone permission)
  /// and begin capturing audio from the default or configured microphone.
  ///
  /// [config] is optional. If provided, it will update the current configuration
  /// before starting capture.
  ///
  /// Throws an [Exception] if:
  /// - Permissions are not granted
  /// - No microphone is available
  /// - Capture fails to start
  ///
  /// Example:
  /// ```dart
  /// final capture = MicAudioCapture();
  ///
  /// try {
  ///   await capture.startCapture(
  ///     config: MicAudioConfig(
  ///       sampleRate: 44100,
  ///       channels: 1,
  ///       gainBoost: 2.5,
  ///     ),
  ///   );
  ///   print('Microphone capture started');
  /// } catch (e) {
  ///   print('Failed to start: $e');
  /// }
  /// ```
  Future<void> startCapture({MicAudioConfig? config}) async {
    if (_isRecording) {
      return;
    }

    if (config != null) {
      updateConfig(config);
    }

    try {
      await requestPermissions();

      try {
        final result = await _channel.invokeMethod<dynamic>(
          _MicAudioMethod.startCapture.name,
          _config.toMap(),
        );

        if (result is! bool || result != true) {
          final errorMsg = result is String
              ? result
              : 'Failed to start microphone capture. Returned: $result';
          throw Exception(errorMsg);
        }
      } on PlatformException catch (e) {
        throw Exception(
            'Failed to start microphone capture: ${e.message ?? e.code}');
      }

      // Create audio stream
      // Note: Stream will be subscribed by listeners, which triggers onListen on native side
      _audioStream = _audioStreamChannel.receiveBroadcastStream().map((
        dynamic event,
      ) {
        if (event is Uint8List) {
          return event;
        } else if (event is List<int>) {
          return Uint8List.fromList(event);
        }
        throw Exception('Unexpected audio data type: ${event.runtimeType}');
      });

      // Create decibel stream
      _decibelStream = _decibelStreamChannel.receiveBroadcastStream().map((
        dynamic event,
      ) {
        if (event is Map) {
          return DecibelData.fromMap(Map<String, dynamic>.from(event));
        }
        return DecibelData(
            decibel: -120.0,
            timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0);
      });

      // Status stream is created lazily via getter, no need to recreate here

      _isRecording = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Stops capturing microphone audio.
  ///
  /// This method will stop the active capture and close all associated streams.
  /// If capture is not active, this method does nothing.
  ///
  /// Throws an [Exception] if stopping fails.
  ///
  /// Example:
  /// ```dart
  /// await micCapture.startCapture();
  ///
  /// // ... use audio stream ...
  ///
  /// await micCapture.stopCapture();
  /// print('Microphone capture stopped');
  /// ```
  Future<void> stopCapture() async {
    if (!_isRecording) return;

    try {
      final stoped = await _channel.invokeMethod<bool>(
        _MicAudioMethod.stopCapture.name,
      );

      if (stoped != true) {
        throw Exception("Failed to stop microphone capture");
      }

      _isRecording = false;
      _audioStream = null;
      _statusStream = null;
      _decibelStream = null;
    } catch (e) {
      rethrow;
    }
  }

  /// Whether microphone capture is currently recording.
  ///
  /// Returns `true` if capture is active, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (micCapture.isRecording) {
  ///   print('Microphone is being captured');
  /// } else {
  ///   print('Microphone capture is not active');
  /// }
  /// ```
  @override
  bool get isRecording => _isRecording;

  /// Requests necessary permissions for microphone capture.
  ///
  /// This requests microphone permission which is required to capture audio
  /// from input devices.
  ///
  /// Returns `true` if permissions are granted.
  ///
  /// Throws an [Exception] if permissions are not granted.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final hasPermission = await micCapture.requestPermissions();
  ///   if (hasPermission) {
  ///     await micCapture.startCapture();
  ///   }
  /// } catch (e) {
  ///   print('Permission denied: $e');
  /// }
  /// ```
  Future<bool> requestPermissions() async {
    final hasPermission = await _channel.invokeMethod<bool>(
      _MicAudioMethod.requestPermissions.name,
    );
    if (hasPermission != true) {
      throw Exception('Microphone permission not granted');
    }
    return true;
  }

  /// Checks if there is any available input device (microphone).
  ///
  /// Returns `true` if there is at least one available input device,
  /// `false` if there is no available input device.
  ///
  /// Example:
  /// ```dart
  /// final hasDevice = await micCapture.hasInputDevice();
  /// if (hasDevice) {
  ///   print('Microphone available');
  ///   await micCapture.startCapture();
  /// } else {
  ///   print('No microphone found');
  /// }
  /// ```
  Future<bool> hasInputDevice() async {
    try {
      final hasDevice = await _channel.invokeMethod<bool>(
        _MicAudioMethod.hasInputDevice.name,
      );
      return hasDevice ?? false;
    } catch (e) {
      rethrow;
    }
  }

  /// Gets a list of all available input devices (microphones).
  ///
  /// Returns a list of [InputDevice] containing device information:
  /// - `id`: String - unique device ID
  /// - `name`: String - device name
  /// - `type`: [InputDeviceType] - device type (builtIn, bluetooth, external)
  /// - `channelCount`: int - number of audio channels
  /// - `isDefault`: bool - whether the device is the default device
  ///
  /// Example:
  /// ```dart
  /// final devices = await micCapture.getAvailableInputDevices();
  ///
  /// for (final device in devices) {
  ///   print('Device: ${device.name}');
  ///   print('  Type: ${device.type}');
  ///   print('  Channels: ${device.channelCount}');
  ///   print('  Default: ${device.isDefault}');
  /// }
  ///
  /// // Find default device
  /// final defaultDevice = devices.firstWhere(
  ///   (device) => device.isDefault,
  ///   orElse: () => devices.first,
  /// );
  /// print('Using device: ${defaultDevice.name}');
  /// ```
  Future<List<InputDevice>> getAvailableInputDevices() async {
    try {
      final devices = await _channel.invokeMethod<List<dynamic>>(
        _MicAudioMethod.getAvailableInputDevices.name,
      );

      if (devices == null) {
        return [];
      }

      return devices
          .whereType<Map>()
          .map((device) => InputDevice.fromMap(
                Map<String, dynamic>.from(device),
              ))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
