import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HealthBridge {
  static const MethodChannel _channel = MethodChannel('neoagent/health');

  Future<HealthBridgeStatus> getStatus() async {
    if (!_isAndroid) {
      return const HealthBridgeStatus(
        available: false,
        permissionsGranted: false,
        message: 'Health sync is available on Android only.',
      );
    }

    final result = await _channel.invokeMapMethod<String, dynamic>('status');
    if (result == null) {
      return const HealthBridgeStatus(
        available: false,
        permissionsGranted: false,
        message: 'Health status is unavailable.',
      );
    }

    return HealthBridgeStatus(
      available: result['available'] == true,
      permissionsGranted: result['permissionsGranted'] == true,
      message: result['message']?.toString(),
      grantedPermissions:
          (result['grantedPermissions'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      requiredPermissions:
          (result['requiredPermissions'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
  }

  Future<HealthBridgeStatus> requestPermissions() async {
    if (!_isAndroid) {
      return getStatus();
    }
    await _channel.invokeMethod('requestPermissions');
    return getStatus();
  }

  Future<Map<String, dynamic>> collectBatch({
    required DateTime windowStart,
    required DateTime windowEnd,
  }) async {
    if (!_isAndroid) {
      throw const HealthBridgeException(
        'Health sync is available on Android only.',
      );
    }
    final raw = await _channel
        .invokeMethod<String>('collectBatch', <String, dynamic>{
          'windowStart': windowStart.toUtc().toIso8601String(),
          'windowEnd': windowEnd.toUtc().toIso8601String(),
        });
    if (raw == null || raw.isEmpty) {
      throw const HealthBridgeException('No health data payload returned.');
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> configureBackgroundSync({
    required bool enabled,
    required String backendUrl,
    required String sessionCookie,
  }) async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod('configureBackgroundSync', <String, dynamic>{
      'enabled': enabled,
      'backendUrl': backendUrl,
      'sessionCookie': sessionCookie,
    });
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

class HealthBridgeStatus {
  const HealthBridgeStatus({
    required this.available,
    required this.permissionsGranted,
    this.message,
    this.grantedPermissions = const <String>[],
    this.requiredPermissions = const <String>[],
  });

  final bool available;
  final bool permissionsGranted;
  final String? message;
  final List<String> grantedPermissions;
  final List<String> requiredPermissions;
}

class HealthBridgeException implements Exception {
  const HealthBridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}
