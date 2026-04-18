// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

export 'package:desktop_audio_capture/mic/mic_audio_capture.dart';
export 'package:desktop_audio_capture/system/system_audio_capture.dart';

// Re-export DecibelData from mic_audio_capture (both mic and system use the same class)
export 'package:desktop_audio_capture/model/decibel_data.dart';
export 'package:desktop_audio_capture/model/input_device_type.dart';
export 'package:desktop_audio_capture/model/audio_status.dart';

/// Abstract base class for audio capture functionality.
///
/// This class defines the common interface for capturing audio from different sources
/// (microphone or system audio). Implementations include [MicAudioCapture] and
/// [SystemAudioCapture].
///
/// Example:
/// ```dart
/// final audioCapture = MicAudioCapture();
/// await audioCapture.initialize();
/// await audioCapture.startCapture();
///
/// // Listen to audio stream
/// audioCapture.audioStream?.listen((audioData) {
///   // Process audio data
/// });
///
/// // Stop when done
/// await audioCapture.stopCapture();
/// await audioCapture.dispose();
/// ```
abstract class AudioCapture {
  /// Whether the audio capture is currently recording.
  ///
  /// Returns `true` if capture is active, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (audioCapture.isRecording) {
  ///   print('Audio capture is active');
  /// }
  /// ```
  bool get isRecording;
}

/// Abstract base class for audio capture configuration.
///
/// This class defines the common interface for configuration objects used
/// to configure audio capture settings. Implementations include [MicAudioConfig]
/// and [SystemAudioConfig].
///
/// Example:
/// ```dart
/// final config = MicAudioConfig(
///   sampleRate: 44100,
///   channels: 2,
/// );
/// final capture = MicAudioCapture(config: config);
/// ```
abstract class AudioCaptureConfig {}
