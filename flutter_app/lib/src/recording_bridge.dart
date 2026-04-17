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

  Future<void> startWebMicrophoneRecording({
    required String baseUrl,
    required String sessionId,
  });

  Future<void> startBackgroundRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
  });

  Future<void> startDesktopAudioRecording({
    required String baseUrl,
    required String sessionCookie,
    required String sessionId,
    bool autoShowToolbar = true,
  });

  Future<void> pauseBackgroundRecording();

  Future<void> resumeBackgroundRecording();

  Future<void> pauseDesktopRecording();

  Future<void> resumeDesktopRecording();

  Future<void> showFloatingToolbar();

  Future<void> hideFloatingToolbar();

  Future<void> openMicrophoneSettings();

  Future<void> openSystemAudioSettings();

  Future<void> stopActiveRecording({bool notifyEnded = false});

  Future<void> Function(String sessionId)? onRecordingStopped;
}

enum RecordingPermissionState {
  unsupported,
  unknown,
  granted,
  denied,
  needsRestart,
}

@immutable
class RecordingRuntimeStatus {
  const RecordingRuntimeStatus({
    required this.supportsScreenAndMic,
    required this.supportsBackgroundMic,
    this.supportsSystemAudio = false,
    this.supportsDesktopBackgroundRuntime = false,
    this.supportsFloatingToolbar = false,
    this.supportsGlobalHotkeys = false,
    this.active = false,
    this.paused = false,
    this.sessionId,
    this.platformLabel,
    this.startedAt,
    this.errorMessage,
    this.microphonePermission = RecordingPermissionState.unknown,
    this.systemAudioPermission = RecordingPermissionState.unknown,
    this.backgroundRuntimeActive = false,
    this.floatingToolbarVisible = false,
    this.activeSources = const <String>[],
    this.microphoneLevelDb = -120,
    this.systemAudioLevelDb = -120,
    this.availableInputDevices = const <RecordingInputDevice>[],
    this.selectedInputDeviceId,
    this.selectedInputDeviceName,
  });

  final bool supportsScreenAndMic;
  final bool supportsBackgroundMic;
  final bool supportsSystemAudio;
  final bool supportsDesktopBackgroundRuntime;
  final bool supportsFloatingToolbar;
  final bool supportsGlobalHotkeys;
  final bool active;
  final bool paused;
  final String? sessionId;
  final String? platformLabel;
  final DateTime? startedAt;
  final String? errorMessage;
  final RecordingPermissionState microphonePermission;
  final RecordingPermissionState systemAudioPermission;
  final bool backgroundRuntimeActive;
  final bool floatingToolbarVisible;
  final List<String> activeSources;
  final double microphoneLevelDb;
  final double systemAudioLevelDb;
  final List<RecordingInputDevice> availableInputDevices;
  final String? selectedInputDeviceId;
  final String? selectedInputDeviceName;

  RecordingRuntimeStatus copyWith({
    bool? supportsScreenAndMic,
    bool? supportsBackgroundMic,
    bool? supportsSystemAudio,
    bool? supportsDesktopBackgroundRuntime,
    bool? supportsFloatingToolbar,
    bool? supportsGlobalHotkeys,
    bool? active,
    bool? paused,
    Object? sessionId = _unset,
    Object? platformLabel = _unset,
    Object? startedAt = _unset,
    Object? errorMessage = _unset,
    RecordingPermissionState? microphonePermission,
    RecordingPermissionState? systemAudioPermission,
    bool? backgroundRuntimeActive,
    bool? floatingToolbarVisible,
    List<String>? activeSources,
    double? microphoneLevelDb,
    double? systemAudioLevelDb,
    List<RecordingInputDevice>? availableInputDevices,
    Object? selectedInputDeviceId = _unset,
    Object? selectedInputDeviceName = _unset,
  }) {
    return RecordingRuntimeStatus(
      supportsScreenAndMic: supportsScreenAndMic ?? this.supportsScreenAndMic,
      supportsBackgroundMic:
          supportsBackgroundMic ?? this.supportsBackgroundMic,
      supportsSystemAudio: supportsSystemAudio ?? this.supportsSystemAudio,
      supportsDesktopBackgroundRuntime:
          supportsDesktopBackgroundRuntime ??
          this.supportsDesktopBackgroundRuntime,
      supportsFloatingToolbar:
          supportsFloatingToolbar ?? this.supportsFloatingToolbar,
      supportsGlobalHotkeys:
          supportsGlobalHotkeys ?? this.supportsGlobalHotkeys,
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
      microphonePermission:
          microphonePermission ?? this.microphonePermission,
      systemAudioPermission: systemAudioPermission ?? this.systemAudioPermission,
      backgroundRuntimeActive:
          backgroundRuntimeActive ?? this.backgroundRuntimeActive,
      floatingToolbarVisible:
          floatingToolbarVisible ?? this.floatingToolbarVisible,
      activeSources: activeSources ?? this.activeSources,
      microphoneLevelDb: microphoneLevelDb ?? this.microphoneLevelDb,
      systemAudioLevelDb: systemAudioLevelDb ?? this.systemAudioLevelDb,
      availableInputDevices:
          availableInputDevices ?? this.availableInputDevices,
      selectedInputDeviceId: selectedInputDeviceId == _unset
          ? this.selectedInputDeviceId
          : selectedInputDeviceId as String?,
      selectedInputDeviceName: selectedInputDeviceName == _unset
          ? this.selectedInputDeviceName
          : selectedInputDeviceName as String?,
    );
  }

  static const Object _unset = Object();
}

@immutable
class RecordingInputDevice {
  const RecordingInputDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.channelCount,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String kind;
  final int channelCount;
  final bool isDefault;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RecordingInputDevice &&
        other.id == id &&
        other.name == name &&
        other.kind == kind &&
        other.channelCount == channelCount &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode => Object.hash(id, name, kind, channelCount, isDefault);

  @override
  String toString() {
    return 'RecordingInputDevice(id: $id, name: $name, kind: $kind, '
        'channelCount: $channelCount, isDefault: $isDefault)';
  }
}

class RecordingBridgeException implements Exception {
  const RecordingBridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}
