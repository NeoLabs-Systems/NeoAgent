import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../models.dart';

class PacketSyncCoordinator {
  PacketSyncCoordinator({
    required this.ensureDeviceRegistered,
    required this.uploadSyncPayload,
    required this.onSyncStateChanged,
  });

  static const Duration _reconnectSyncWindow = Duration(seconds: 35);
  static const int _reconnectSyncMinBytes = 2048;
  static const Duration _syncRequestRetryDelay = Duration(milliseconds: 250);
  static const int _syncRequestRepeats = 2;

  static const List<String> _packetInitHexSequence = [
    '010183014f000200030a313737343434383234360400100e0500',
    '0101010402050010',
    '0101020100',
  ];

  static const List<String> _packetOfflineSyncRequestHexSequence = [
    '0101020100',
  ];

  final Future<void> Function(String deviceId) ensureDeviceRegistered;
  final Future<void> Function(String deviceId, Uint8List payload) uploadSyncPayload;
  final VoidCallback onSyncStateChanged;

  final BytesBuilder _reconnectSyncBuffer = BytesBuilder(copy: false);
  Timer? _reconnectSyncTimer;
  bool _reconnectSyncActive = false;
  bool _syncRequestInFlight = false;

  bool get isSyncRequestInFlight => _syncRequestInFlight;

  Future<void> onConnected(String deviceId, List<BleService> services) async {
    await _sendPacketInitSequence(deviceId, services);
  }

  Future<void> subscribeNotifications({
    required String deviceId,
    required BleService service,
    required String audioCharUuid,
    String? controlCharUuid,
  }) async {
    final subscribedUuids = <String>{};

    await UniversalBle.subscribeNotifications(deviceId, service.uuid, audioCharUuid);
    subscribedUuids.add(_normalizeUuid(audioCharUuid));
    debugPrint('Subscribed to audio characteristic: $audioCharUuid');

    if (controlCharUuid != null) {
      await UniversalBle.subscribeNotifications(deviceId, service.uuid, controlCharUuid);
      subscribedUuids.add(_normalizeUuid(controlCharUuid));
      debugPrint('Subscribed to control characteristic: $controlCharUuid');
    }

    // Packet firmware can move sync payloads to different notify characteristics.
    for (final char in service.characteristics ?? []) {
      final normalized = _normalizeUuid(char.uuid);
      if (subscribedUuids.contains(normalized)) {
        continue;
      }

      try {
        await UniversalBle.subscribeNotifications(deviceId, service.uuid, char.uuid);
        subscribedUuids.add(normalized);
        debugPrint('Subscribed to packet extra characteristic: ${char.uuid}');
      } catch (subError) {
        debugPrint('Could not subscribe to ${char.uuid}: $subError');
      }
    }
  }

  bool captureSyncChunk(
    String characteristicUuid,
    Uint8List rawPayload,
    Uint8List? Function(Uint8List rawPayload, {String? characteristicUuid}) parseAudioPayload,
  ) {
    if (!_reconnectSyncActive) {
      return false;
    }

    final audio = parseAudioPayload(
      rawPayload,
      characteristicUuid: characteristicUuid,
    );

    if (audio == null || audio.isEmpty) {
      return false;
    }

    _reconnectSyncBuffer.add(audio);
    return true;
  }

  Future<void> requestOfflineSync(
    String deviceId, {
    List<BleService>? services,
    String reason = 'manual',
  }) async {
    if (_syncRequestInFlight) {
      debugPrint('Offline sync request skipped: request already in flight');
      return;
    }

    _syncRequestInFlight = true;
    onSyncStateChanged();

    try {
      var resolvedServices = services ?? <BleService>[];
      if (resolvedServices.isEmpty) {
        try {
          resolvedServices = await UniversalBle.discoverServices(deviceId);
        } catch (e) {
          debugPrint('Service discovery failed during offline sync request: $e');
        }
      }

      if (resolvedServices.isEmpty) {
        debugPrint('Offline sync request skipped: no services available');
        return;
      }

      final service = resolvedServices.firstWhere(
        (s) => _normalizeUuid(s.uuid) == _normalizeUuid(WearableServiceUuids.packetServiceUuid),
        orElse: () => resolvedServices.first,
      );

      await _sendPacketInitSequence(deviceId, resolvedServices);
      _startReconnectSyncWindow(deviceId);

      for (var attempt = 0; attempt < _syncRequestRepeats; attempt++) {
        for (final hexPayload in _packetOfflineSyncRequestHexSequence) {
          try {
            await UniversalBle.write(
              deviceId,
              service.uuid,
              WearableServiceUuids.packetControlRx,
              _bytesFromHex(hexPayload),
              withoutResponse: true,
            );
            await Future.delayed(_syncRequestRetryDelay);
          } catch (e) {
            debugPrint('Packet offline sync write failed [$hexPayload]: $e');
          }
        }

        if (attempt + 1 < _syncRequestRepeats) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }

      debugPrint('Packet offline sync request sent ($reason)');
    } finally {
      _syncRequestInFlight = false;
      onSyncStateChanged();
    }
  }

  void dispose() {
    _reconnectSyncTimer?.cancel();
    _reconnectSyncActive = false;
    _reconnectSyncBuffer.clear();
  }

  Future<void> _sendPacketInitSequence(String deviceId, List<BleService> services) async {
    if (services.isEmpty) {
      debugPrint('No services discovered; skipping packet init sequence');
      return;
    }

    final service = services.firstWhere(
      (s) => _normalizeUuid(s.uuid) == _normalizeUuid(WearableServiceUuids.packetServiceUuid),
      orElse: () => services.first,
    );

    for (final hexPayload in _packetInitHexSequence) {
      try {
        await UniversalBle.write(
          deviceId,
          service.uuid,
          WearableServiceUuids.packetControlRx,
          _bytesFromHex(hexPayload),
          withoutResponse: true,
        );
        await Future.delayed(const Duration(milliseconds: 120));
      } catch (e) {
        debugPrint('Packet init write failed [$hexPayload]: $e');
      }
    }
  }

  void _startReconnectSyncWindow(String deviceId) {
    _reconnectSyncTimer?.cancel();
    _reconnectSyncBuffer.clear();
    _reconnectSyncActive = true;

    _reconnectSyncTimer = Timer(_reconnectSyncWindow, () {
      _flushReconnectSync(deviceId);
    });
  }

  Future<void> _flushReconnectSync(String deviceId) async {
    _reconnectSyncActive = false;
    _reconnectSyncTimer?.cancel();
    _reconnectSyncTimer = null;

    final payload = _reconnectSyncBuffer.takeBytes();
    if (payload.length < _reconnectSyncMinBytes) {
      return;
    }

    try {
      await ensureDeviceRegistered(deviceId);
      await uploadSyncPayload(deviceId, payload);
      debugPrint('Packet reconnect sync uploaded: ${payload.length} bytes');
    } catch (e) {
      debugPrint('Packet reconnect sync failed: $e');
    }
  }

  String _normalizeUuid(String value) {
    return value.toLowerCase().replaceAll('-', '');
  }

  Uint8List _bytesFromHex(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length.isOdd) {
      throw const FormatException('Invalid hex string length');
    }

    final out = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < cleaned.length; i += 2) {
      out[i ~/ 2] = int.parse(cleaned.substring(i, i + 2), radix: 16);
    }
    return out;
  }
}
