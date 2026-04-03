import 'dart:io';

import 'package:flutter/services.dart';

import 'diagnostics_logger.dart';

class WearableBackgroundBridge {
  static const MethodChannel _channel = MethodChannel(
    'neoagent/wearables_background',
  );

  bool get isSupported => Platform.isAndroid;

  void _log(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppDiagnostics.log(
      'wearable.bridge',
      event,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _maskMacAddress(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final suffix = normalized.length <= 5
        ? normalized
        : normalized.substring(normalized.length - 5);
    return '***$suffix';
  }

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

    _log(
      'start.request',
      data: <String, Object?>{
        'backendUrl': backendUrl,
        'macAddressMasked': _maskMacAddress(macAddress),
        'deviceName': deviceName,
        'protocolId': protocolId,
        'serviceUuid': serviceUuid,
        'audioNotifyUuid': audioNotifyUuid,
        'controlNotifyUuid': controlNotifyUuid,
        'controlWriteUuid': controlWriteUuid,
        'autoStartRecording': autoStartRecording,
        'hasSessionCookie': sessionCookie.isNotEmpty,
      },
    );

    try {
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
      final mapped = result ?? <String, dynamic>{'active': false};
      _log(
        'start.response',
        data: <String, Object?>{
          'active': mapped['active'] == true,
          'connected': mapped['connected'] == true,
          'macAddressMasked': _maskMacAddress(
            mapped['macAddress']?.toString() ?? '',
          ),
        },
      );
      return mapped;
    } on PlatformException catch (err, stackTrace) {
      _log(
        'start.error',
        data: <String, Object?>{'code': err.code},
        error: err,
        stackTrace: stackTrace,
      );
    } on MissingPluginException catch (err, stackTrace) {
      _log('start.error', error: err, stackTrace: stackTrace);
    } catch (err, stackTrace) {
      _log('start.error', error: err, stackTrace: stackTrace);
    }
    return <String, dynamic>{'active': false};
  }

  Future<Map<String, dynamic>> stopBackgroundBridge({
    bool sendStop = false,
  }) async {
    if (!isSupported) {
      return <String, dynamic>{'active': false};
    }

    _log('stop.request', data: <String, Object?>{'sendStop': sendStop});
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'stopBackgroundBridge',
        <String, dynamic>{'sendStop': sendStop},
      );
      final mapped =
          result ??
          <String, dynamic>{
            'active': false,
            'connected': false,
            'macAddress': null,
          };
      _log(
        'stop.response',
        data: <String, Object?>{
          'active': mapped['active'] == true,
          'connected': mapped['connected'] == true,
          'macAddressMasked': _maskMacAddress(
            mapped['macAddress']?.toString() ?? '',
          ),
        },
      );
      return mapped;
    } catch (err, stackTrace) {
      _log('stop.error', error: err, stackTrace: stackTrace);
      return <String, dynamic>{
        'active': false,
        'connected': false,
        'macAddress': null,
      };
    }
  }

  Future<Map<String, dynamic>> backgroundBridgeStatus() async {
    if (!isSupported) {
      return <String, dynamic>{'active': false};
    }

    _log('status.request');
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'backgroundBridgeStatus',
      );
      final mapped = result ?? <String, dynamic>{'active': false};
      _log(
        'status.response',
        data: <String, Object?>{
          'active': mapped['active'] == true,
          'connected': mapped['connected'] == true,
          'macAddressMasked': _maskMacAddress(
            mapped['macAddress']?.toString() ?? '',
          ),
        },
      );
      return mapped;
    } catch (err, stackTrace) {
      _log('status.error', error: err, stackTrace: stackTrace);
      return <String, dynamic>{'active': false};
    }
  }
}
