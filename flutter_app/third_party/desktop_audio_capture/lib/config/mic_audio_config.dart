import 'package:desktop_audio_capture/audio_capture.dart';

/// Configuration class for microphone audio capture.
///
/// This class allows you to configure various audio capture parameters
/// such as sample rate, channels, bit depth, gain boost, and input volume.
///
/// Example:
/// ```dart
/// // Create with default values
/// final config = MicAudioConfig();
///
/// // Create with custom values
/// final customConfig = MicAudioConfig(
///   sampleRate: 44100,
///   channels: 2,
///   bitDepth: 24,
///   gainBoost: 3.0,
///   inputVolume: 0.8,
/// );
///
/// // Use with capture
/// final capture = MicAudioCapture(config: customConfig);
///
/// // Update configuration
/// final updatedConfig = customConfig.copyWith(
///   gainBoost: 2.5,
///   inputVolume: 1.0,
/// );
/// capture.updateConfig(updatedConfig);
/// ```
class MicAudioConfig extends AudioCaptureConfig {
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

  /// Bit depth (default: 16).
  ///
  /// Common values: 16, 24, 32.
  /// Higher bit depth provides better dynamic range.
  final int bitDepth;

  /// Gain boost multiplier (default: 2.5, range: 0.1 to 10.0).
  ///
  /// Higher values increase microphone sensitivity and amplify the input signal.
  /// Use with caution as very high values may cause distortion.
  final double gainBoost;

  /// Input volume (default: 1.0, range: 0.0 to 1.0).
  ///
  /// Controls the input volume level:
  /// - 0.0: Muted
  /// - 0.5: Half volume
  /// - 1.0: Full volume
  final double inputVolume;

  /// Creates a new [MicAudioConfig] instance.
  ///
  /// All parameters are optional and have default values:
  /// - [sampleRate]: 16000
  /// - [channels]: 1
  /// - [bitDepth]: 16
  /// - [gainBoost]: 2.5
  /// - [inputVolume]: 1.0
  ///
  /// Example:
  /// ```dart
  /// final config = MicAudioConfig(
  ///   sampleRate: 44100,
  ///   channels: 1,
  ///   gainBoost: 2.0,
  /// );
  /// ```
  MicAudioConfig({
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitDepth = 16,
    this.gainBoost = 2.5,
    this.inputVolume = 1.0,
  });

  /// Creates a copy of this configuration with modified values.
  ///
  /// Only the specified parameters will be changed; others remain the same.
  ///
  /// Example:
  /// ```dart
  /// final config = MicAudioConfig(
  ///   sampleRate: 16000,
  ///   gainBoost: 2.5,
  /// );
  ///
  /// // Increase gain boost while keeping other values
  /// final updated = config.copyWith(gainBoost: 3.0);
  /// // updated.sampleRate is still 16000
  /// ```
  MicAudioConfig copyWith({
    int? sampleRate,
    int? channels,
    int? bitDepth,
    double? gainBoost,
    double? inputVolume,
  }) {
    return MicAudioConfig(
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      bitDepth: bitDepth ?? this.bitDepth,
      gainBoost: gainBoost ?? this.gainBoost,
      inputVolume: inputVolume ?? this.inputVolume,
    );
  }

  /// Converts this configuration to a map for method channel communication.
  ///
  /// Returns a map containing all configuration values:
  /// - `sampleRate`: int
  /// - `channels`: int
  /// - `bitDepth`: int
  /// - `gainBoost`: double
  /// - `inputVolume`: double
  ///
  /// Example:
  /// ```dart
  /// final config = MicAudioConfig(
  ///   sampleRate: 44100,
  ///   channels: 2,
  /// );
  /// final map = config.toMap();
  /// // map = {'sampleRate': 44100, 'channels': 2, 'bitDepth': 16, 'gainBoost': 2.5, 'inputVolume': 1.0}
  /// ```
  Map<String, dynamic> toMap() {
    return {
      'sampleRate': sampleRate,
      'channels': channels,
      'bitDepth': bitDepth,
      'gainBoost': gainBoost,
      'inputVolume': inputVolume,
    };
  }

  @override
  String toString() {
    return 'MicConfig(sampleRate: $sampleRate, channels: $channels, bitDepth: $bitDepth, gainBoost: $gainBoost, inputVolume: $inputVolume)';
  }
}
