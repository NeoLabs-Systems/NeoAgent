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
  Future<void> refreshStatus() async {}

  @override
  Future<void> resumeBackgroundRecording() async {
    throw const RecordingBridgeException(
      'Recording is not supported on this platform.',
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
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Screen and microphone recording is not supported on this platform.',
    );
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    _status = _status.copyWith(
      active: false,
      paused: false,
      sessionId: null,
      errorMessage: null,
    );
    notifyListeners();
  }
}
