import 'package:flutter/services.dart';

/// What the phone's native sync last reported.
class DeviceSyncStatus {
  const DeviceSyncStatus({
    this.enabled = false,
    this.kinds = const <String>[],
    this.lastSuccessAt,
    this.lastError,
  });

  factory DeviceSyncStatus.fromMap(Map<dynamic, dynamic>? map) {
    final raw = map ?? const <dynamic, dynamic>{};
    final error = raw['lastError']?.toString().trim() ?? '';
    return DeviceSyncStatus(
      enabled: raw['enabled'] == true,
      kinds: (raw['kinds'] as List? ?? const <dynamic>[])
          .map((kind) => kind.toString())
          .toList(growable: false),
      lastSuccessAt: DateTime.tryParse(raw['lastSuccessAt']?.toString() ?? ''),
      lastError: error.isEmpty ? null : error,
    );
  }

  final bool enabled;
  final List<String> kinds;
  final DateTime? lastSuccessAt;
  final String? lastError;
}

/// `neoagent/device_sync`: the native code that reads and changes the phone's
/// calendars and contacts, and syncs them with the server in the background.
class DeviceSyncBridge {
  static const MethodChannel _channel = MethodChannel('neoagent/device_sync');

  Future<String> deviceName() async =>
      (await _channel.invokeMethod<String>('deviceName'))?.trim() ?? '';

  Future<List<String>> grantedKinds() async => _kinds(
    await _channel.invokeMethod<List<dynamic>>('grantedKinds'),
  );

  Future<List<String>> requestPermissions(List<String> kinds) async => _kinds(
    await _channel.invokeMethod<List<dynamic>>(
      'requestPermissions',
      <String, dynamic>{'kinds': kinds},
    ),
  );

  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  Future<void> configure({
    required bool enabled,
    String backendUrl = '',
    String sessionCookie = '',
    String agentId = '',
    String deviceId = '',
    List<String> kinds = const <String>[],
  }) {
    return _channel.invokeMethod<void>('configure', <String, dynamic>{
      'enabled': enabled,
      'backendUrl': backendUrl,
      'sessionCookie': sessionCookie,
      'agentId': agentId,
      'deviceId': deviceId,
      'kinds': kinds,
    });
  }

  Future<DeviceSyncStatus> syncNow() async => DeviceSyncStatus.fromMap(
    await _channel.invokeMethod<Map<dynamic, dynamic>>('syncNow'),
  );

  Future<DeviceSyncStatus> status() async => DeviceSyncStatus.fromMap(
    await _channel.invokeMethod<Map<dynamic, dynamic>>('status'),
  );

  static List<String> _kinds(List<dynamic>? raw) =>
      (raw ?? const <dynamic>[]).map((kind) => kind.toString()).toList();
}
