import 'dart:async';

import 'package:desktop_audio_capture/audio_capture.dart';
import 'package:flutter/services.dart';

export 'package:desktop_audio_capture/config/system_adudio_config.dart';

enum _SystemAudioMethod {
  startCapture,
  stopCapture,
  requestPermissions,
}

/// Class for capturing system audio (audio output from the device).
///
/// This class allows you to capture audio that is being played by the system,
/// such as music, videos, or other applications. It requires screen recording
/// permissions on macOS.
///
/// Example:
/// ```dart
/// final systemCapture = SystemAudioCapture(
///   config: SystemAudioConfig(
///     sampleRate: 44100,
///     channels: 2,
///   ),
/// );
///
/// await systemCapture.startCapture();
///
/// // Listen to audio stream
/// systemCapture.audioStream?.listen((audioData) {
///   // Process audio bytes
///   print('Received ${audioData.length} bytes');
/// });
///
/// // Listen to decibel readings
/// systemCapture.decibelStream?.listen((data) {
///   print('Decibel: ${data.decibel} dB');
/// });
///
/// // Stop when done
/// await systemCapture.stopCapture();
/// ```
class SystemAudioCapture extends AudioCapture {
  static const MethodChannel _channel = MethodChannel(
    'com.system_audio_transcriber/audio_capture',
  );
  static const EventChannel _audioStreamChannel = EventChannel(
    'com.system_audio_transcriber/audio_stream',
  );
  static const EventChannel _statusStreamChannel = EventChannel(
    'com.system_audio_transcriber/audio_status',
  );
  static const EventChannel _decibelStreamChannel = EventChannel(
    'com.system_audio_transcriber/audio_decibel',
  );

  Stream<Uint8List>? _audioStream;
  Stream<SystemAudioStatus>? _statusStream;
  Stream<DecibelData>? _decibelStream;
  bool _isRecording = false;

  /// Stream of raw audio data bytes from system audio capture.
  ///
  /// Returns a [Stream<Uint8List>] containing the captured audio data.
  /// The stream is only available after [startCapture] has been called.
  ///
  /// Example:
  /// ```dart
  /// await systemCapture.startCapture();
  ///
  /// systemCapture.audioStream?.listen((audioData) {
  ///   // Process audio bytes
  ///   final audioBuffer = audioData.buffer.asUint8List();
  ///   // Use audio buffer for processing, saving, etc.
  /// });
  /// ```
  Stream<Uint8List>? get audioStream => _audioStream;

  /// Stream of system audio capture status updates.
  ///
  /// Returns a [Stream<SystemAudioStatus>] containing status information:
  /// - [SystemAudioStatus.isActive]: bool - whether system audio capture is currently active
  ///
  /// Example:
  /// ```dart
  /// systemCapture.statusStream?.listen((status) {
  ///   if (status.isActive) {
  ///     print('System audio capture is active');
  ///   } else {
  ///     print('System audio capture is inactive');
  ///   }
  /// });
  /// ```
  Stream<SystemAudioStatus>? get statusStream {
    // Create status stream if not already created
    _statusStream ??= _statusStreamChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      if (event is Map) {
        return SystemAudioStatus.fromJson(Map<String, dynamic>.from(event));
      }
      return SystemAudioStatus(isActive: false);
    });
    return _statusStream;
  }

  /// Stream of system audio decibel (dB) readings.
  ///
  /// Returns a [Stream<DecibelData>] containing:
  /// - `decibel`: double - decibel value (-120 to 0 dB)
  /// - `timestamp`: double - Unix timestamp
  ///
  /// The stream is only available while recording is active.
  ///
  /// Example:
  /// ```dart
  /// await systemCapture.startCapture();
  ///
  /// systemCapture.decibelStream?.listen((data) {
  ///   print('System audio level: ${data.decibel.toStringAsFixed(1)} dB');
  ///   print('Timestamp: ${DateTime.fromMillisecondsSinceEpoch((data.timestamp * 1000).toInt())}');
  /// });
  /// ```
  Stream<DecibelData>? get decibelStream {
    if (!_isRecording) {
      return null;
    }
    // Create decibel stream if not already created
    _decibelStream ??= _decibelStreamChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      if (event is Map) {
        return DecibelData.fromMap(Map<String, dynamic>.from(event));
      }
      return DecibelData(
          decibel: -120.0,
          timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0);
    });
    return _decibelStream;
  }

  SystemAudioConfig _config = SystemAudioConfig();

  /// Creates a new [SystemAudioCapture] instance.
  ///
  /// [config] is optional. If not provided, default configuration will be used
  /// (sampleRate: 16000, channels: 1).
  ///
  /// Example:
  /// ```dart
  /// final capture = SystemAudioCapture(
  ///   config: SystemAudioConfig(
  ///     sampleRate: 44100,
  ///     channels: 2,
  ///   ),
  /// );
  /// ```
  SystemAudioCapture({SystemAudioConfig? config}) {
    _config = config ?? SystemAudioConfig();
  }

  /// Updates the audio capture configuration.
  ///
  /// This method allows you to change the configuration after the instance
  /// has been created. The new configuration will be applied on the next
  /// [startCapture] call.
  ///
  /// Example:
  /// ```dart
  /// final capture = SystemAudioCapture();
  ///
  /// // Update config before starting
  /// capture.updateConfig(SystemAudioConfig(
  ///   sampleRate: 48000,
  ///   channels: 2,
  /// ));
  ///
  /// await capture.startCapture();
  /// ```
  void updateConfig(SystemAudioConfig config) {
    _config = config;
  }

  /// Starts capturing system audio.
  ///
  /// This method will request necessary permissions (screen recording on macOS)
  /// and begin capturing audio from the system output.
  ///
  /// [config] is optional. If provided, it will update the current configuration
  /// before starting capture.
  ///
  /// Throws an [Exception] if:
  /// - Permissions are not granted
  /// - Capture fails to start
  ///
  /// Example:
  /// ```dart
  /// final capture = SystemAudioCapture();
  ///
  /// try {
  ///   await capture.startCapture(
  ///     config: SystemAudioConfig(
  ///       sampleRate: 44100,
  ///       channels: 2,
  ///     ),
  ///   );
  ///   print('System audio capture started');
  /// } catch (e) {
  ///   print('Failed to start: $e');
  /// }
  /// ```
  Future<void> startCapture({SystemAudioConfig? config}) async {
    if (_isRecording) {
      return;
    }

    if (config != null) {
      updateConfig(config);
    }

    try {
      await requestPermissions();

      final started = await _channel.invokeMethod<bool>(
        _SystemAudioMethod.startCapture.name,
        _config.toMap(),
      );

      if (started != true) {
        throw Exception('Failed to start system audio capture');
      }

      // Listen to audio stream
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

      // Status stream is created lazily via getter, no need to recreate here

      _isRecording = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Stops capturing system audio.
  ///
  /// This method will stop the active capture and close all associated streams.
  /// If capture is not active, this method does nothing.
  ///
  /// Throws an [Exception] if stopping fails.
  ///
  /// Example:
  /// ```dart
  /// await systemCapture.startCapture();
  ///
  /// // ... use audio stream ...
  ///
  /// await systemCapture.stopCapture();
  /// print('System audio capture stopped');
  /// ```
  Future<void> stopCapture() async {
    if (!_isRecording) return;

    try {
      final stopped = await _channel.invokeMethod<bool>(
        _SystemAudioMethod.stopCapture.name,
      );

      if (stopped != true) {
        throw Exception("Failed to stop system audio capture");
      }

      _isRecording = false;
      _audioStream = null;
      _statusStream = null;
      _decibelStream = null;
    } catch (e) {
      rethrow;
    }
  }

  /// Whether system audio capture is currently recording.
  ///
  /// Returns `true` if capture is active, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (systemCapture.isRecording) {
  ///   print('System audio is being captured');
  /// } else {
  ///   print('System audio capture is not active');
  /// }
  /// ```
  @override
  bool get isRecording => _isRecording;

  /// Requests necessary permissions for system audio capture.
  ///
  /// On macOS, this requests screen recording permission which is required
  /// to capture system audio.
  ///
  /// Returns `true` if permissions are granted.
  ///
  /// Throws an [Exception] if permissions are not granted.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final hasPermission = await systemCapture.requestPermissions();
  ///   if (hasPermission) {
  ///     await systemCapture.startCapture();
  ///   }
  /// } catch (e) {
  ///   print('Permission denied: $e');
  /// }
  /// ```
  Future<bool> requestPermissions() async {
    final hasPermission = await _channel.invokeMethod<bool>(
      _SystemAudioMethod.requestPermissions.name,
    );
    if (hasPermission != true) {
      throw Exception('Screen recording permission not granted');
    }
    return true;
  }
}
