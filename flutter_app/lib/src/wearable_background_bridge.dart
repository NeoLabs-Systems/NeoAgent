import 'dart:io';

import 'package:flutter/services.dart';

class WearableBackgroundBridge {
  static const MethodChannel _channel =
      MethodChannel('neoagent/wearables_background');

  bool get isSupported => Platform.isAndroid;

  Future<Map<String, dynamic>> startBackgroundBridge({
    required String backendUrl,
    required String sessionCookie,
    required String macAddress,
    required String deviceName,
    required String protocolId,
    required String serviceUuid,
    required String audioNotifyUuid,
    String? controlNotifyUuid,
    String? controlWriteUuid,
    bool autoStartRecording = false,
  }) async {
    if (!isSupported) {
      return <String, dynamic>{'active': false};
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'startBackgroundBridge',
      <String, dynamic>{
        'backendUrl': backendUrl,
        'sessionCookie': sessionCookie,
        'macAddress': macAddress,
        'deviceName': deviceName,
        'protocolId': protocolId,
        'serviceUuid': serviceUuid,
        'audioNotifyUuid': audioNotifyUuid,
        'controlNotifyUuid': controlNotifyUuid,
        'controlWriteUuid': controlWriteUuid,
        'autoStartRecording': autoStartRecording,
      },
    );

    return result ?? <String, dynamic>{'active': false};
  }

  Future<Map<String, dynamic>> stopBackgroundBridge({
    bool sendStop = false,
  }) async {
    if (!isSupported) {
      return <String, dynamic>{'active': false};
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'stopBackgroundBridge',
      <String, dynamic>{'sendStop': sendStop},
    );

    return result ?? <String, dynamic>{'active': false};
  }

  Future<Map<String, dynamic>> backgroundBridgeStatus() async {
    if (!isSupported) {
      return <String, dynamic>{'active': false};
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'backgroundBridgeStatus',
    );

    return result ?? <String, dynamic>{'active': false};
  }
}
