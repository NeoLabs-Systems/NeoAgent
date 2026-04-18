import 'package:desktop_audio_capture/audio_capture.dart';

/// Configuration class for system audio capture.
///
/// This class allows you to configure audio capture parameters for system audio
/// (audio output from the device), such as sample rate and number of channels.
///
/// Example:
/// ```dart
/// // Create with default values
/// final config = SystemAudioConfig();
///
/// // Create with custom values
/// final customConfig = SystemAudioConfig(
///   sampleRate: 44100,
///   channels: 2,
/// );
///
/// // Use with capture
/// final capture = SystemAudioCapture(config: customConfig);
///
/// // Update configuration
/// final updatedConfig = customConfig.copyWith(
///   sampleRate: 48000,
/// );
/// capture.updateConfig(updatedConfig);
/// ```
class SystemAudioConfig extends AudioCaptureConfig {
  /// Sample rate in Hz (default: 16000).
  ///
  /// Common values: 8000, 16000, 44100, 48000.
  /// Higher sample rates provide better quality but use more resources.
  final int sampleRate;

  /// Number of audio channels (default: 1 for mono).
  ///
  /// - 1: Mono (single channel)
  /// - 2: Stereo (two channels)
  final int channels;

  /// Creates a new [SystemAudioConfig] instance.
  ///
  /// All parameters are optional and have default values:
  /// - [sampleRate]: 16000
  /// - [channels]: 1
  ///
  /// Example:
  /// ```dart
  /// final config = SystemAudioConfig(
  ///   sampleRate: 44100,
  ///   channels: 2,
  /// );
  /// ```
  SystemAudioConfig({
    this.sampleRate = 16000,
    this.channels = 1,
  });

  /// Creates a copy of this configuration with modified values.
  ///
  /// Only the specified parameters will be changed; others remain the same.
  ///
  /// Example:
  /// ```dart
  /// final config = SystemAudioConfig(
  ///   sampleRate: 16000,
  ///   channels: 1,
  /// );
  ///
  /// // Change to stereo while keeping sample rate
  /// final updated = config.copyWith(channels: 2);
  /// // updated.sampleRate is still 16000
  /// ```
  SystemAudioConfig copyWith({
    int? sampleRate,
    int? channels,
  }) {
    return SystemAudioConfig(
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
    );
  }

  /// Converts this configuration to a map for method channel communication.
  ///
  /// Returns a map containing all configuration values:
  /// - `sampleRate`: int
  /// - `channels`: int
  ///
  /// Example:
  /// ```dart
  /// final config = SystemAudioConfig(
  ///   sampleRate: 44100,
  ///   channels: 2,
  /// );
  /// final map = config.toMap();
  /// // map = {'sampleRate': 44100, 'channels': 2}
  /// ```
  Map<String, dynamic> toMap() {
    return {
      'sampleRate': sampleRate,
      'channels': channels,
    };
  }

  @override
  String toString() {
    return 'SystemAudioConfig(sampleRate: $sampleRate, channels: $channels)';
  }
}
