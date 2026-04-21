import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidLauncherBridge {
  AndroidLauncherBridge._();

  static final AndroidLauncherBridge instance = AndroidLauncherBridge._();

  static const MethodChannel _deviceChannel = MethodChannel(
    'neoagent/launcher_device',
  );
  static const EventChannel _buttonChannel = EventChannel(
    'neoagent/launcher_buttons',
  );

  Stream<LauncherHardwareButtonEvent>? _buttonEvents;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<LauncherVolumeState?> fetchVolumeState() async {
    if (!supported) {
      return null;
    }
    Map<String, dynamic>? raw;
    try {
      raw = await _deviceChannel.invokeMapMethod<String, dynamic>(
        'getVolumeState',
      );
    } on MissingPluginException {
      return null;
    }
    if (raw == null) {
      return null;
    }
    return LauncherVolumeState.fromMap(raw);
  }

  Future<LauncherVolumeState?> setVolume(int value) async {
    if (!supported) {
      return null;
    }
    Map<String, dynamic>? raw;
    try {
      raw = await _deviceChannel.invokeMapMethod<String, dynamic>(
        'setVolume',
        <String, dynamic>{'value': value},
      );
    } on MissingPluginException {
      return null;
    }
    if (raw == null) {
      return null;
    }
    return LauncherVolumeState.fromMap(raw);
  }

  Future<LauncherVolumeState?> adjustVolume(int delta) async {
    if (!supported) {
      return null;
    }
    Map<String, dynamic>? raw;
    try {
      raw = await _deviceChannel.invokeMapMethod<String, dynamic>(
        'adjustVolume',
        <String, dynamic>{'delta': delta},
      );
    } on MissingPluginException {
      return null;
    }
    if (raw == null) {
      return null;
    }
    return LauncherVolumeState.fromMap(raw);
  }

  Future<bool> openWifiSettings() async {
    if (!supported) {
      return false;
    }
    try {
      await _deviceChannel.invokeMethod<void>('openWifiSettings');
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> openTimeSettings() async {
    if (!supported) {
      return false;
    }
    try {
      await _deviceChannel.invokeMethod<void>('openDateSettings');
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      try {
        await _deviceChannel.invokeMethod<void>('openTimeSettings');
        return true;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        try {
          await _deviceChannel.invokeMethod<void>('openSystemSettings');
          return true;
        } on MissingPluginException {
          return false;
        } on PlatformException {
          return false;
        }
      }
    }
  }

  Future<LauncherDeviceStatus?> fetchDeviceStatus() async {
    if (!supported) {
      return null;
    }
    Map<String, dynamic>? raw;
    try {
      raw = await _deviceChannel.invokeMapMethod<String, dynamic>(
        'getDeviceStatus',
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      try {
        raw = await _deviceChannel.invokeMapMethod<String, dynamic>(
          'getBatteryState',
        );
      } on PlatformException {
        return null;
      } on MissingPluginException {
        return null;
      }
    }
    if (raw == null) {
      return null;
    }
    return LauncherDeviceStatus.fromMap(raw);
  }

  Stream<LauncherHardwareButtonEvent> get buttonEvents {
    return _buttonEvents ??= _buttonChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          final map = event is Map
              ? Map<String, dynamic>.from(event)
              : const <String, dynamic>{};
          return LauncherHardwareButtonEvent.fromMap(map);
        })
        .handleError((Object error, StackTrace stackTrace) {},
            test: (error) => error is MissingPluginException);
  }
}

@immutable
class LauncherVolumeState {
  const LauncherVolumeState({
    required this.current,
    required this.max,
    required this.min,
    required this.muted,
  });

  factory LauncherVolumeState.fromMap(Map<String, dynamic> map) {
    return LauncherVolumeState(
      current: (map['current'] as num?)?.round() ?? 0,
      max: (map['max'] as num?)?.round() ?? 0,
      min: (map['min'] as num?)?.round() ?? 0,
      muted: map['muted'] == true,
    );
  }

  final int current;
  final int max;
  final int min;
  final bool muted;

  double get normalized {
    final span = max - min;
    if (span <= 0) {
      return 0;
    }
    return ((current - min) / span).clamp(0, 1).toDouble();
  }
}

@immutable
class LauncherHardwareButtonEvent {
  const LauncherHardwareButtonEvent({
    required this.keyCode,
    required this.scanCode,
    required this.action,
    required this.repeatCount,
    required this.eventTimeMs,
  });

  factory LauncherHardwareButtonEvent.fromMap(Map<String, dynamic> map) {
    return LauncherHardwareButtonEvent(
      keyCode: (map['keyCode'] as num?)?.round() ?? 0,
      scanCode: (map['scanCode'] as num?)?.round() ?? 0,
      action: (map['action'] ?? 'unknown').toString(),
      repeatCount: (map['repeatCount'] as num?)?.round() ?? 0,
      eventTimeMs: (map['eventTimeMs'] as num?)?.toInt() ?? 0,
    );
  }

  final int keyCode;
  final int scanCode;
  final String action;
  final int repeatCount;
  final int eventTimeMs;

  bool get isDown => action == 'down';

  bool get isUp => action == 'up';
}

@immutable
class LauncherDeviceStatus {
  const LauncherDeviceStatus({required this.batteryPercent, required this.charging});

  factory LauncherDeviceStatus.fromMap(Map<String, dynamic> map) {
    return LauncherDeviceStatus(
      batteryPercent: (map['batteryPercent'] as num?)?.round(),
      charging: map['charging'] == true,
    );
  }

  final int? batteryPercent;
  final bool charging;
}
