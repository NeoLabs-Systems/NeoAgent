import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'diagnostics_logger.dart';
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

  void _requireAndroidOnly() {
    if (!_isAndroid) {
      throw const RecordingBridgeException(
        'Background microphone recording is available on Android only.',
      );
    }
  }

  void _log(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppDiagnostics.log(
      'recording.bridge.io',
      event,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  Future<void> refreshStatus() async {
    if (!_isAndroid) {
      return;
    }
    _log('refresh_status.request');
    final result = await _channel.invokeMapMethod<String, dynamic>('status');
    _status = _status.copyWith(
      active: result?['active'] == true,
      paused: result?['paused'] == true,
      sessionId: result?['sessionId']?.toString(),
      errorMessage: result?['errorMessage']?.toString(),
      startedAt: _parseDate(result?['startedAt']),
    );
    _log('refresh_status.response', data: <String, Object?>{
      'active': _status.active,
      'paused': _status.paused,
      'sessionId': _status.sessionId,
      'startedAt': _status.startedAt?.toIso8601String(),
      'errorMessage': _status.errorMessage,
    });
    notifyListeners();
  }

  @override
  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  }) async {
    _requireAndroidOnly();
    _log('start_background.request', data: <String, Object?>{
      'sessionId': sessionId,
      'baseUrl': baseUrl,
      'hasSessionCookie': sessionCookie.isNotEmpty,
    });
    await _channel.invokeMethod('startBackgroundRecording', <String, dynamic>{
      'backendUrl': baseUrl,
      'sessionCookie': sessionCookie,
      'sessionId': sessionId,
    });
    await refreshStatus();
    _log('start_background.done', data: <String, Object?>{
      'active': _status.active,
      'sessionId': _status.sessionId,
    });
  }

  @override
  Future<void> pauseBackgroundRecording() async {
    _requireAndroidOnly();
    _log('pause_background.request', data: <String, Object?>{
      'sessionId': _status.sessionId,
      'active': _status.active,
      'paused': _status.paused,
    });
    await _channel.invokeMethod('pauseBackgroundRecording');
    await refreshStatus();
    _log('pause_background.done', data: <String, Object?>{
      'active': _status.active,
      'paused': _status.paused,
    });
  }

  @override
  Future<void> resumeBackgroundRecording() async {
    _requireAndroidOnly();
    _log('resume_background.request', data: <String, Object?>{
      'sessionId': _status.sessionId,
      'active': _status.active,
      'paused': _status.paused,
    });
    await _channel.invokeMethod('resumeBackgroundRecording');
    await refreshStatus();
    _log('resume_background.done', data: <String, Object?>{
      'active': _status.active,
      'paused': _status.paused,
    });
  }

  @override
  Future<void> stopActiveRecording({bool notifyEnded = false}) async {
    if (!_isAndroid) {
      return;
    }
    final sessionId = _status.sessionId;
    _log('stop_active.request', data: <String, Object?>{
      'sessionId': sessionId,
      'notifyEnded': notifyEnded,
      'active': _status.active,
      'paused': _status.paused,
    });
    await _channel.invokeMethod('stopBackgroundRecording');
    await refreshStatus();
    _log('stop_active.done', data: <String, Object?>{
      'sessionId': sessionId,
      'active': _status.active,
      'paused': _status.paused,
      'notifyEnded': notifyEnded,
      'hasOnRecordingStopped': onRecordingStopped != null,
    });
    if (notifyEnded && sessionId != null && onRecordingStopped != null) {
      _log('stop_active.notify_ended', data: <String, Object?>{
        'sessionId': sessionId,
      });
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
