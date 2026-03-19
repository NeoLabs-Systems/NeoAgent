import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'recording_bridge.dart';

RecordingBridge createPlatformRecordingBridge() => IoRecordingBridge();

class IoRecordingBridge extends RecordingBridge {
  static const MethodChannel _channel = MethodChannel('neoagent/recordings');

  RecordingRuntimeStatus _status = RecordingRuntimeStatus(
    supportsScreenAndMic: false,
    supportsBackgroundMic:
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    platformLabel: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'Android background recorder'
        : 'Unsupported',
  );

  @override
  RecordingRuntimeStatus get status => _status;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> refreshStatus() async {
    if (!_isAndroid) {
      return;
    }
    final result = await _channel.invokeMapMethod<String, dynamic>('status');
    _status = _status.copyWith(
      active: result?['active'] == true,
      paused: result?['paused'] == true,
      sessionId: result?['sessionId']?.toString(),
      errorMessage: result?['errorMessage']?.toString(),
      startedAt: _parseDate(result?['startedAt']),
    );
    notifyListeners();
  }

  @override
  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  }) async {
    if (!_isAndroid) {
      throw const RecordingBridgeException(
        'Background microphone recording is available on Android only.',
      );
    }
    await _channel.invokeMethod('startBackgroundRecording', <String, dynamic>{
      'backendUrl': baseUrl,
      'sessionCookie': sessionCookie,
      'sessionId': sessionId,
    });
    await refreshStatus();
  }

  @override
  Future<void> pauseBackgroundRecording() async {
    if (!_isAndroid) {
      throw const RecordingBridgeException(
        'Background microphone recording is available on Android only.',
      );
    }
    await _channel.invokeMethod('pauseBackgroundRecording');
    await refreshStatus();
  }

  @override
  Future<void> resumeBackgroundRecording() async {
    if (!_isAndroid) {
      throw const RecordingBridgeException(
        'Background microphone recording is available on Android only.',
      );
    }
    await _channel.invokeMethod('resumeBackgroundRecording');
    await refreshStatus();
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    if (!_isAndroid) {
      return;
    }
    final sessionId = _status.sessionId;
    await _channel.invokeMethod('stopBackgroundRecording');
    await refreshStatus();
    if (notifyEnded && sessionId != null && onRecordingStopped != null) {
      await onRecordingStopped!(sessionId);
    }
  }

  @override
  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  }) async {
    throw const RecordingBridgeException(
      'Screen and microphone recording is available on web only.',
    );
  }

  DateTime? _parseDate(Object? raw) {
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString());
  }
}
