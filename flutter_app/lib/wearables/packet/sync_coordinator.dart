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
  static const Duration _syncCommandGap = Duration(milliseconds: 180);
  static const Duration _syncListCollectDelay = Duration(seconds: 2);
  static const int _syncListDays = 12;
  static const int _syncUploadMaxFiles = 5;
  static const String _defaultAppSk = '3TMd6HawHvRl2nhg';

  static const List<String> _packetInitHexSequence = [
    '010183014f000200030a313737343434383234360400100e0500',
    '0101010402050010',
    '0101020100',
  ];

  static const List<String> _packetOfflineSyncRequestHexSequence = [
    '0101020100',
  ];

  static const List<String> _officialSyncPreambleCommands = [
    'APP&SK&{sk}',
    'APP&BAT',
    'APP&FW',
    'APP&WF',
    'APP&SPACE',
    'APP&T&{time}',
    'APP&REC&SECEN',
    'APP&STE',
    'APP&FW',
    'APP&WF',
  ];

  final Future<void> Function(String deviceId) ensureDeviceRegistered;
  final Future<void> Function(String deviceId, Uint8List payload) uploadSyncPayload;
  final VoidCallback onSyncStateChanged;

  final BytesBuilder _reconnectSyncBuffer = BytesBuilder(copy: false);
  Timer? _reconnectSyncTimer;
  bool _reconnectSyncActive = false;
  bool _syncRequestInFlight = false;
  final List<_PacketListEntry> _listedFiles = <_PacketListEntry>[];
  final Set<String> _listedFileKeys = <String>{};
  String _lastSyncStatus = 'Idle';
  String _lastControlMessage = '';
  int _uploadCommandsSent = 0;

  static final RegExp _controlPrefix = RegExp(r'^(MCU|APP|BLE|SYS)&');
  static final RegExp _mcuFilePattern = RegExp(r'^MCU&F&([^&]+)&([^&]+)&(\d+)$');
  static final RegExp _mcuUploadSizePattern = RegExp(r'^MCU&U&(\d+)$');
  static final RegExp _mcuOffPattern = RegExp(r'^MCU&OFF$');

  bool get isSyncRequestInFlight => _syncRequestInFlight;
  String get lastSyncStatus => _lastSyncStatus;
  String get lastControlMessage => _lastControlMessage;
  int get listedFilesCount => _listedFiles.length;
  int get uploadCommandsSent => _uploadCommandsSent;

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
    for (final char in service.characteristics) {
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

  void observeControlPayload(Uint8List rawPayload) {
    final text = _parseControlText(rawPayload);
    if (text == null) {
      return;
    }

    _lastControlMessage = text;

    final fileMatch = _mcuFilePattern.firstMatch(text);
    if (fileMatch != null) {
      final date = fileMatch.group(1)!;
      final fileId = fileMatch.group(2)!;
      final size = int.tryParse(fileMatch.group(3) ?? '') ?? 0;
      final key = '$date|$fileId';
      if (_listedFileKeys.add(key)) {
        _listedFiles.add(_PacketListEntry(date: date, fileId: fileId, size: size));
        _lastSyncStatus = 'Discovered ${_listedFiles.length} offline file(s)';
        onSyncStateChanged();
      }
      return;
    }

    final uploadMatch = _mcuUploadSizePattern.firstMatch(text);
    if (uploadMatch != null) {
      final bytes = int.tryParse(uploadMatch.group(1) ?? '') ?? 0;
      _lastSyncStatus = 'Device preparing upload: $bytes bytes';
      onSyncStateChanged();
      return;
    }

    if (_mcuOffPattern.hasMatch(text)) {
      _lastSyncStatus = 'Device upload completed';
      onSyncStateChanged();
    }
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

      _resetSyncDiscoveryState();
      _lastSyncStatus = 'Preparing sync session';
      onSyncStateChanged();

      _startReconnectSyncWindow(deviceId);

      await _sendOfficialSyncPreamble(deviceId, service);
      await _requestRecentLists(deviceId, service);
      await Future.delayed(_syncListCollectDelay);

      var uploads = await _sendUploadsForListedFiles(deviceId, service);

      if (uploads == 0) {
        _lastSyncStatus = 'No files listed; trying legacy sync pulse fallback';
        onSyncStateChanged();
        await _sendLegacySyncPulse(deviceId, service);
        await _requestRecentLists(deviceId, service, days: 5);
        await Future.delayed(_syncListCollectDelay);
        uploads = await _sendUploadsForListedFiles(deviceId, service);
      }

      if (uploads > 0) {
        _lastSyncStatus = 'Requested upload for $uploads file(s)';
      } else {
        _lastSyncStatus = 'No offline files discovered for upload';
      }
      onSyncStateChanged();

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

  Future<void> _sendOfficialSyncPreamble(
    String deviceId,
    BleService service,
  ) async {
    final time = _formatPacketTime(DateTime.now());
    for (final template in _officialSyncPreambleCommands) {
      final cmd = template
          .replaceAll('{sk}', _defaultAppSk)
          .replaceAll('{time}', time);
      await _writeAscii(deviceId, service.uuid, cmd);
    }
  }

  Future<void> _requestRecentLists(
    String deviceId,
    BleService service, {
    int days = _syncListDays,
  }) async {
    final today = DateTime.now();
    for (var i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      final dateText =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await _writeAscii(deviceId, service.uuid, 'APP&LIST&$dateText');
    }
  }

  Future<int> _sendUploadsForListedFiles(String deviceId, BleService service) async {
    if (_listedFiles.isEmpty) {
      _uploadCommandsSent = 0;
      onSyncStateChanged();
      return 0;
    }

    final candidates = List<_PacketListEntry>.from(_listedFiles)
      ..sort((a, b) => b.size.compareTo(a.size));

    final count = candidates.length < _syncUploadMaxFiles
        ? candidates.length
        : _syncUploadMaxFiles;

    for (var i = 0; i < count; i++) {
      final file = candidates[i];
      await _writeAscii(deviceId, service.uuid, 'APP&U&${file.date}&${file.fileId}');
    }

    _uploadCommandsSent = count;
    onSyncStateChanged();
    return count;
  }

  Future<void> _sendLegacySyncPulse(String deviceId, BleService service) async {
    for (var attempt = 0; attempt < _syncRequestRepeats; attempt++) {
      for (final hexPayload in _packetOfflineSyncRequestHexSequence) {
        await _writeHex(deviceId, service.uuid, hexPayload);
        await Future.delayed(_syncRequestRetryDelay);
      }

      if (attempt + 1 < _syncRequestRepeats) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
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
      await _writeHex(deviceId, service.uuid, hexPayload);
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _writeAscii(String deviceId, String serviceUuid, String cmd) async {
    try {
      await UniversalBle.write(
        deviceId,
        serviceUuid,
        WearableServiceUuids.packetControlRx,
        Uint8List.fromList(cmd.codeUnits),
        withoutResponse: false,
      );
    } catch (e) {
      debugPrint('Packet command write failed [$cmd]: $e');
    }
    await Future.delayed(_syncCommandGap);
  }

  Future<void> _writeHex(String deviceId, String serviceUuid, String hexPayload) async {
    try {
      await UniversalBle.write(
        deviceId,
        serviceUuid,
        WearableServiceUuids.packetControlRx,
        _bytesFromHex(hexPayload),
        withoutResponse: true,
      );
    } catch (e) {
      debugPrint('Packet hex write failed [$hexPayload]: $e');
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

  String? _parseControlText(Uint8List rawPayload) {
    if (rawPayload.isEmpty) {
      return null;
    }

    try {
      final text = String.fromCharCodes(rawPayload).replaceAll('\u0000', '').trim();
      if (text.isEmpty) {
        return null;
      }
      if (!_controlPrefix.hasMatch(text)) {
        return null;
      }
      return text;
    } catch (_) {
      return null;
    }
  }

  String _formatPacketTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$mo$d$h$mi$s';
  }

  void _resetSyncDiscoveryState() {
    _listedFiles.clear();
    _listedFileKeys.clear();
    _uploadCommandsSent = 0;
    _lastControlMessage = '';
  }
}

class _PacketListEntry {
  const _PacketListEntry({
    required this.date,
    required this.fileId,
    required this.size,
  });

  final String date;
  final String fileId;
  final int size;
}
