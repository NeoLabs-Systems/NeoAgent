import 'recording_bridge.dart';

RecordingBridge createPlatformRecordingBridge() => UnsupportedRecordingBridge();

class UnsupportedRecordingBridge extends RecordingBridge {
  RecordingRuntimeStatus _status = const RecordingRuntimeStatus(
    supportsScreenAndMic: false,
    supportsBackgroundMic: false,
    platformLabel: 'Unsupported',
  );

  @override
  RecordingRuntimeStatus get status => _status;

  @override
  Future<void> pauseBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Recording is not supported on this platform.',
    );
  }

  @override
  Future<void> pauseDesktopRecording() async {
    throw const RecordingBridgeException(
      'Desktop recording is not supported on this platform.',
    );
  }

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<void> resumeBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Recording is not supported on this platform.',
    );
  }

  @override
  Future<void> resumeDesktopRecording() async {
    throw const RecordingBridgeException(
      'Desktop recording is not supported on this platform.',
    );
  }

  @override
  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Background recording is not supported on this platform.',
    );
  }

  @override
  Future<void> startDesktopAudioRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
    bool autoShowToolbar = true,
  }) async {
    throw const RecordingBridgeException(
      'Desktop recording is not supported on this platform.',
    );
  }

  @override
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Screen and microphone recording is not supported on this platform.',
    );
  }

  @override
  Future<void> startWebMicrophoneRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Microphone-only browser recording is not supported on this platform.',
    );
  }

  @override
  Future<void> showFloatingToolbar() async {}

  @override
  Future<void> hideFloatingToolbar() async {}

  @override
  Future<void> openMicrophoneSettings() async {
    throw const RecordingBridgeException(
      'Microphone settings are not supported on this platform.',
    );
  }

  @override
  Future<void> openSystemAudioSettings() async {
    throw const RecordingBridgeException(
      'System audio settings are not supported on this platform.',
    );
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    _status = _status.copyWith(
      active: false,
      paused: false,
      sessionId: null,
      errorMessage: null,
      floatingToolbarVisible: false,
    );
    notifyListeners();
  }
}
