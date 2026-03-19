import 'package:flutter/foundation.dart';

import 'recording_bridge_stub.dart'
    if (dart.library.html) 'recording_bridge_web.dart'
    if (dart.library.io) 'recording_bridge_io.dart';

RecordingBridge createRecordingBridge() => createPlatformRecordingBridge();

abstract class RecordingBridge extends ChangeNotifier {
  RecordingRuntimeStatus get status;

  Future<void> refreshStatus();

  Future<void> startWebRecording({
    required String baseUrl,
    required String sessionId,
  });

  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  });

  Future<void> pauseBackgroundRecording();

  Future<void> resumeBackgroundRecording();

  Future<void> stopActiveRecording({bool notifyEnded = false});

  Future<void> Function(String sessionId)? onRecordingStopped;
}

@immutable
class RecordingRuntimeStatus {
  const RecordingRuntimeStatus({
    required this.supportsScreenAndMic,
    required this.supportsBackgroundMic,
    this.active = false,
    this.paused = false,
    this.sessionId,
    this.platformLabel,
    this.startedAt,
    this.errorMessage,
  });

  final bool supportsScreenAndMic;
  final bool supportsBackgroundMic;
  final bool active;
  final bool paused;
  final String? sessionId;
  final String? platformLabel;
  final DateTime? startedAt;
  final String? errorMessage;

  RecordingRuntimeStatus copyWith({
    bool? supportsScreenAndMic,
    bool? supportsBackgroundMic,
    bool? active,
    bool? paused,
    Object? sessionId = _unset,
    Object? platformLabel = _unset,
    Object? startedAt = _unset,
    Object? errorMessage = _unset,
  }) {
    return RecordingRuntimeStatus(
      supportsScreenAndMic: supportsScreenAndMic ?? this.supportsScreenAndMic,
      supportsBackgroundMic:
          supportsBackgroundMic ?? this.supportsBackgroundMic,
      active: active ?? this.active,
      paused: paused ?? this.paused,
      sessionId: sessionId == _unset ? this.sessionId : sessionId as String?,
      platformLabel: platformLabel == _unset
          ? this.platformLabel
          : platformLabel as String?,
      startedAt: startedAt == _unset ? this.startedAt : startedAt as DateTime?,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _unset = Object();
}

class RecordingBridgeException implements Exception {
  const RecordingBridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}
