import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_ble/universal_ble.dart';
import '../src/backend_client.dart';
import '../src/diagnostics_logger.dart';
import '../src/wearable_background_bridge.dart';
import 'models.dart';
import 'heypocket/sync_coordinator.dart';
import 'pending_chunk_store.dart';
import 'protocols/base.dart';

const _connectionHealthCheckInterval = Duration(seconds: 30);
const _baseReconnectDelayMs = 1000;
const _maxConnectRetries = 5;
const _autoReconnectScanInterval = Duration(seconds: 12);
const _scanRepeatLogInterval = Duration(seconds: 5);
final RegExp _heypocketRecordingStopControlPattern = RegExp(r'^MCU&STO\b');
const _wearableFinalizeCooldown = Duration(seconds: 2);

class WearableService extends ChangeNotifier {
  WearableService({
    required BackendClient backendClient,
    required ValueGetter<String> getBackendUrl,
  }) : _backendClient = backendClient,
       _getBackendUrl = getBackendUrl {
    const heypocketAppSk = String.fromEnvironment('NEOAGENT_HEYPOCKET_APP_SK');
    _heypocketSyncCoordinator = HeyPocketSyncCoordinator(
      ensureDeviceRegistered: _ensureDeviceRegistered,
      uploadSyncPayload: _uploadHeyPocketSyncPayload,
      onSyncStateChanged: notifyListeners,
      appSk: heypocketAppSk,
    );
    _init();
  }

  final BackendClient _backendClient;
  final ValueGetter<String> _getBackendUrl;
  final WearableBackgroundBridge _wearableBackgroundBridge = WearableBackgroundBridge();

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final Map<String, BleDevice> _discoveredDevices = {};
  final Map<String, DateTime> _scanLastLoggedAt = <String, DateTime>{};
  final Map<String, int> _scanSeenCount = <String, int>{};

  List<BleDevice> get scanResults => _discoveredDevices.values
      .where((device) => _identifyDeviceType(device.name ?? '') != WearableDeviceType.unknown)
      .toList();

  BleDevice? _connectedDevice;
  BleDevice? get connectedDevice => _connectedDevice;
  String? _connectingDeviceId;
  String? get connectingDeviceId => _connectingDeviceId;
  bool _backgroundBridgeActive = false;
  bool get backgroundBridgeActive => _backgroundBridgeActive;
  bool _backgroundBridgeConnected = false;
  bool get backgroundBridgeConnected => _backgroundBridgeConnected;
  String? _backgroundBridgeDeviceId;
  String? get backgroundBridgeDeviceId => _backgroundBridgeDeviceId;
  String? _preferredReconnectDeviceId;
  bool get hasReconnectTarget =>
      (_preferredReconnectDeviceId != null && _preferredReconnectDeviceId!.isNotEmpty) ||
      (_backgroundBridgeDeviceId != null && _backgroundBridgeDeviceId!.isNotEmpty);
  bool get isConnecting => _connectionState == BleConnectionState.connecting;
  Timer? _autoReconnectTimer;
  bool _autoReconnectEnabled = false;
  DateTime? _lastFinalizeAt;
  bool _finalizeInFlight = false;

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BleConnectionState get connectionState => _connectionState;
  
  Timer? _connectionHealthTimer;
  DateTime? _lastSuccessfulCommunication;
  final List<_PendingWearableChunk> _pendingWearableChunks = <_PendingWearableChunk>[];
  bool _uploadDrainInFlight = false;
  bool _queuePersistInFlight = false;
  bool _queuePersistRequested = false;
  bool _queueRestoreInFlight = false;
  static const int _maxPendingWearableChunks = 720;
  static const Duration _queueDropLogInterval = Duration(seconds: 20);
  static const int _queueDropLogMinCount = 64;
  final PendingChunkStore _chunkStore = createPendingChunkStore();
  DateTime? _lastQueueDropLogAt;
  int _droppedQueueChunkCount = 0;

  final Map<String, WearableProtocolBase> _protocols = {};

  WearableDeviceType? _deviceType;
  late final HeyPocketSyncCoordinator _heypocketSyncCoordinator;

  bool get canRequestOfflineSync =>
      _connectedDevice != null && _deviceType == WearableDeviceType.heypocket;

  bool get isOfflineSyncRequestInFlight => _heypocketSyncCoordinator.isSyncRequestInFlight;
  String get heypocketSyncStatus => _heypocketSyncCoordinator.lastSyncStatus;
  String get heypocketSyncLastControlMessage => _heypocketSyncCoordinator.lastControlMessage;
  int get heypocketSyncListedFilesCount => _heypocketSyncCoordinator.listedFilesCount;
  List<HeyPocketSyncFile> get heypocketSyncListedFiles => _heypocketSyncCoordinator.listedFiles;
  int get heypocketSyncUploadCommandsSent => _heypocketSyncCoordinator.uploadCommandsSent;
  bool get heypocketCallModeEnabled => _heypocketSyncCoordinator.isCallMode;
  String get heypocketModeLabel => _heypocketSyncCoordinator.heypocketModeLabel;
  bool get heypocketModeSwitchInFlight => _heypocketSyncCoordinator.isModeSwitchInFlight;
  bool _heypocketStartInFlight = false;
  bool get heypocketStartInFlight => _heypocketStartInFlight;
  bool get heypocketRecordingActive => _heypocketSyncCoordinator.isRecordingActive;
  String get heypocketActiveRecordingId => _heypocketSyncCoordinator.activeRecordingId;
  bool get _hasBackgroundHeyPocketTarget =>
      _backgroundBridgeConnected &&
      _backgroundBridgeDeviceId != null &&
      _backgroundBridgeDeviceId!.trim().isNotEmpty;
  String? get _activeHeyPocketDeviceId {
    final connectedId = _connectedDevice?.deviceId;
    if (connectedId != null && connectedId.trim().isNotEmpty) {
      return connectedId;
    }
    final bridgeId = _backgroundBridgeDeviceId;
    if (bridgeId != null && bridgeId.trim().isNotEmpty) {
      return bridgeId.trim();
    }
    return null;
  }
  bool get canStartHeyPocketRecording =>
      (_connectedDevice != null && _deviceType == WearableDeviceType.heypocket) ||
      _hasBackgroundHeyPocketTarget;

  void _log(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppDiagnostics.log(
      'wearable.service',
      event,
      data: <String, Object?>{
        'connectedDeviceId': _connectedDevice?.deviceId,
        'connectedDeviceName': _connectedDevice?.name,
        'deviceType': _deviceType?.name,
        'connectionState': _connectionState.name,
        'queueLength': _pendingWearableChunks.length,
        'isScanning': _isScanning,
        ...data,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _init() {
    _registerDefaultProtocols();
    unawaited(_restorePendingWearableQueue());
    unawaited(_restoreBackgroundBridgeState());

    UniversalBle.onScanResult = (device) {
      final now = DateTime.now();
      final isFirstSight = !_discoveredDevices.containsKey(device.deviceId);
      final seenCount = (_scanSeenCount[device.deviceId] ?? 0) + 1;
      _scanSeenCount[device.deviceId] = seenCount;

      if (isFirstSight) {
        debugPrint("Scan result: ${device.name} (${device.deviceId})");
        _log('scan.result.new', data: <String, Object?>{
          'deviceId': device.deviceId,
          'name': device.name,
          'seenCount': seenCount,
        });
        _scanLastLoggedAt[device.deviceId] = now;
      } else {
        final lastLogged = _scanLastLoggedAt[device.deviceId];
        if (lastLogged == null || now.difference(lastLogged) >= _scanRepeatLogInterval) {
          _log('scan.result.repeat', data: <String, Object?>{
            'deviceId': device.deviceId,
            'name': device.name,
            'seenCount': seenCount,
          });
          _scanLastLoggedAt[device.deviceId] = now;
        }
      }
      
      _discoveredDevices[device.deviceId] = device;

      if (_shouldAutoReconnectTo(device)) {
        debugPrint('Auto-reconnect candidate found: ${device.deviceId}');
        unawaited(_attemptAutoReconnect(device));
      }

      notifyListeners();
    };

    UniversalBle.onConnectionChange = (deviceId, isConnected, error) {
      debugPrint("Connection change: $deviceId connected=$isConnected error=$error");
      _log('connection.change', data: <String, Object?>{
        'deviceId': deviceId,
        'isConnected': isConnected,
      }, error: error);
      if (_connectedDevice?.deviceId == deviceId) {
        if (!isConnected) {
          debugPrint("Device disconnected: $deviceId");
          _clearConnectionState();
          _maybeStartAutoReconnect();
        } else {
          _connectionState = BleConnectionState.connected;
          _lastSuccessfulCommunication = DateTime.now();
          _connectingDeviceId = null;
          _stopAutoReconnectLoop();
          _startConnectionHealthMonitoring();
        }
        notifyListeners();
      }
    };

    UniversalBle.onValueChange = (deviceId, characteristicUuid, value, _) {
      if (_connectedDevice?.deviceId == deviceId) {
        _lastSuccessfulCommunication = DateTime.now();
        _log('value.change', data: <String, Object?>{
          'deviceId': deviceId,
          'characteristicUuid': characteristicUuid,
          'size': value.length,
        });

        bool shouldEnqueue = true;

        if (_deviceType == WearableDeviceType.heypocket) {
          final heypocketProtocol = _getProtocolForDevice(WearableDeviceType.heypocket);
          if (heypocketProtocol != null) {
            _heypocketSyncCoordinator.observeControlPayload(value);

            if (_isHeyPocketControlCharacteristic(characteristicUuid) &&
                _isHeyPocketRecordingStopControl(value)) {
              unawaited(_finalizeActiveWearableRecording(deviceId));
            }

            final capturedForReconnectSync = _heypocketSyncCoordinator.captureSyncChunk(
              characteristicUuid,
              value,
              heypocketProtocol.parseAudioPayload,
            );

            final parsedAudio = heypocketProtocol.parseAudioPayload(
              value,
              characteristicUuid: characteristicUuid,
            );
            final hasAudioPayload = parsedAudio != null && parsedAudio.isNotEmpty;

            // For heypocket devices, only forward actual audio payloads to live-stream ingestion.
            // Sync-captured audio is uploaded separately via reconnect sync payload.
            shouldEnqueue = hasAudioPayload && !capturedForReconnectSync;
          }
        }

        if (shouldEnqueue) {
          _enqueueWearableChunk(
            deviceId: deviceId,
            characteristicUuid: characteristicUuid,
            payload: value,
          );
        }
      }
    };
  }

  void _enqueueWearableChunk({
    required String deviceId,
    required String characteristicUuid,
    required Uint8List payload,
  }) {
    if (_pendingWearableChunks.length >= _maxPendingWearableChunks) {
      _pendingWearableChunks.removeAt(0);
      _droppedQueueChunkCount += 1;
      _logQueueDropIfNeeded();
    }

    _pendingWearableChunks.add(
      _PendingWearableChunk(
        deviceId: deviceId,
        characteristicUuid: characteristicUuid,
        payload: Uint8List.fromList(payload),
      ),
    );

    _log('queue.enqueued', data: <String, Object?>{
      'deviceId': deviceId,
      'characteristicUuid': characteristicUuid,
      'payloadSize': payload.length,
      'queueLength': _pendingWearableChunks.length,
    });

    _scheduleQueuePersist();
    _drainWearableQueue();
  }

  void _logQueueDropIfNeeded() {
    final now = DateTime.now();
    final last = _lastQueueDropLogAt;
    final intervalElapsed = last == null || now.difference(last) >= _queueDropLogInterval;
    final highDropBurst = _droppedQueueChunkCount >= _queueDropLogMinCount;
    if (intervalElapsed && highDropBurst) {
      debugPrint(
        'Wearable upload queue full; dropped $_droppedQueueChunkCount oldest pending chunks in the last ${_queueDropLogInterval.inSeconds}s.',
      );
      _droppedQueueChunkCount = 0;
      _lastQueueDropLogAt = now;
    }
  }

  Future<void> _drainWearableQueue() async {
    if (_uploadDrainInFlight) {
      return;
    }
    _uploadDrainInFlight = true;
    try {
      while (_pendingWearableChunks.isNotEmpty) {
        final activeDeviceId = _connectedDevice?.deviceId;
        if (activeDeviceId == null) {
          return;
        }

        final next = _pendingWearableChunks.first;
        if (next.deviceId != activeDeviceId) {
          // Drop stale chunks from a previous connection.
          _pendingWearableChunks.removeAt(0);
          _scheduleQueuePersist();
          continue;
        }

        try {
          await _ensureDeviceRegistered(activeDeviceId);
        } catch (e) {
          debugPrint('Error registering wearable before upload: $e');
          _log('queue.register_before_upload.failed',
              data: <String, Object?>{'deviceId': activeDeviceId}, error: e);
          await Future<void>.delayed(const Duration(milliseconds: 600));
          continue;
        }

        try {
          final response = await _backendClient.streamWearableData(
            _getBackendUrl(),
            next.deviceId,
            next.characteristicUuid,
            next.payload,
          );
          final accepted = response['accepted'] == true;
          final ignored = response['ignored'] == true;
          final duplicate = response['duplicate'] == true;
          if (!accepted && !ignored && !duplicate) {
            throw StateError('Wearable chunk not acknowledged: $response');
          }

          _pendingWearableChunks.removeAt(0);
          _scheduleQueuePersist();
          _log('queue.upload_chunk.ok', data: <String, Object?>{
            'deviceId': next.deviceId,
            'characteristicUuid': next.characteristicUuid,
            'queueLength': _pendingWearableChunks.length,
            'attempts': next.attempts,
            'responseAccepted': accepted,
            'responseIgnored': ignored,
            'responseDuplicate': duplicate,
          });
        } catch (e) {
          next.attempts += 1;
          _log('queue.upload_chunk.failed', data: <String, Object?>{
            'deviceId': next.deviceId,
            'characteristicUuid': next.characteristicUuid,
            'attempts': next.attempts,
            'queueLength': _pendingWearableChunks.length,
          }, error: e);
          if (next.attempts > 6) {
            debugPrint('Dropping wearable chunk after repeated failures: $e');
            _pendingWearableChunks.removeAt(0);
            _scheduleQueuePersist();
            continue;
          }

          final delayMs = (350 * (1 << (next.attempts - 1))).clamp(350, 6000);
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
      }
    } finally {
      _uploadDrainInFlight = false;
    }
  }

  Future<void> _restorePendingWearableQueue() async {
    if (_queueRestoreInFlight) {
      return;
    }
    _queueRestoreInFlight = true;
    try {
      final rows = await _chunkStore.readRows();
      if (rows.isEmpty) {
        return;
      }

      for (final row in rows) {
        try {
          final decoded = jsonDecode(row);
          if (decoded is! Map<String, dynamic>) {
            continue;
          }
          _pendingWearableChunks.add(_PendingWearableChunk.fromJson(decoded));
        } catch (_) {
          // Ignore malformed queue entries and continue restore.
        }
      }

      if (_pendingWearableChunks.length > _maxPendingWearableChunks) {
        final overflow = _pendingWearableChunks.length - _maxPendingWearableChunks;
        _pendingWearableChunks.removeRange(0, overflow);
      }

      if (_pendingWearableChunks.isNotEmpty) {
        debugPrint('Restored ${_pendingWearableChunks.length} pending wearable chunks.');
        _drainWearableQueue();
      }
    } catch (e) {
      debugPrint('Failed to restore wearable upload queue: $e');
    } finally {
      _queueRestoreInFlight = false;
    }
  }

  void _scheduleQueuePersist() {
    if (_queuePersistInFlight) {
      _queuePersistRequested = true;
      return;
    }

    _queuePersistInFlight = true;
    unawaited(_persistPendingWearableQueue());
  }

  Future<void> _persistPendingWearableQueue() async {
    do {
      _queuePersistRequested = false;
      try {
        final serialized = _pendingWearableChunks
            .map((chunk) => jsonEncode(chunk.toJson()))
            .toList(growable: false);
        await _chunkStore.writeRows(serialized);
      } catch (e) {
        debugPrint('Failed to persist wearable upload queue: $e');
      }
    } while (_queuePersistRequested);

    _queuePersistInFlight = false;
  }

  void _registerDefaultProtocols() {
    final builtInProtocols = <WearableProtocolBase>[
      HeyPocketProtocol(),
    ];

    for (final protocol in builtInProtocols) {
      _protocols[protocol.id] = protocol;
    }
  }

  WearableDeviceType _identifyDeviceType(String name) {
    final lowerName = name.toLowerCase();

    if (lowerName.contains('heypocket') || lowerName.contains('pocket') || lowerName.contains('pkt01')) {
      return WearableDeviceType.heypocket;
    }

    return WearableDeviceType.unknown;
  }

  WearableProtocolBase? _getProtocolForDevice(WearableDeviceType? type) {
    if (type == null) return null;
    final protocolId = _protocolIdForDeviceType(type);
    if (protocolId == null) {
      return null;
    }
    return _protocols[protocolId];
  }

  List<String> _buildScanServiceUuids() {
    final services = <String>{};
    for (final protocol in _protocols.values) {
      final serviceUuid = protocol.serviceUuid;
      if (serviceUuid != null && serviceUuid.isNotEmpty) {
        services.add(serviceUuid);
      }
    }

    services.add(WearableServiceUuids.batteryServiceUuid);
    services.add(WearableServiceUuids.deviceInfoServiceUuid);
    return services.toList(growable: false);
  }

  Future<bool> _ensureScanPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    if (!scanGranted || !connectGranted) {
      debugPrint(
        'BLE scan permissions missing: '
        'scan=$scanGranted connect=$connectGranted location=$locationGranted',
      );
      return false;
    }

    if (!locationGranted) {
      debugPrint('Location permission not granted; BLE scan may be limited on older Android versions.');
    }

    return true;
  }

  Future<void> startScan() async {
    try {
      _discoveredDevices.clear();
      _scanLastLoggedAt.clear();
      _scanSeenCount.clear();
      notifyListeners();
      debugPrint("Starting scan for HeyPocket devices...");
      _log('scan.start.request');

      final canScan = await _ensureScanPermissions();
      if (!canScan) {
        debugPrint('Scan aborted: required Android BLE permissions are not granted.');
        return;
      }

      final serviceUuids = _buildScanServiceUuids();

      if (kIsWeb) {
        await UniversalBle.startScan(
          scanFilter: ScanFilter(
            withServices: serviceUuids,
          ),
          platformConfig: PlatformConfig(
            web: WebOptions(
              optionalServices: serviceUuids,
            ),
          ),
        );
      } else {
        // Native discovery is more reliable without strict advertised-service filters.
        await UniversalBle.startScan();
      }

      _isScanning = true;
      _log('scan.start.ok', data: <String, Object?>{
        'serviceFilterCount': serviceUuids.length,
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Error starting scan: $e");
      _log('scan.start.failed', error: e);
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await UniversalBle.stopScan();
      _isScanning = false;
      _log('scan.stop.ok');
      notifyListeners();
    } catch (e) {
      debugPrint("Error stopping scan: $e");
      _log('scan.stop.failed', error: e);
    }
  }

  Future<void> connect(BleDevice device) async {
    return _connectInternal(device, fromAutoReconnect: false);
  }

  Future<void> reconnectToPreferredDevice() async {
    final reconnectDeviceId = _preferredReconnectDeviceId?.trim().isNotEmpty == true
        ? _preferredReconnectDeviceId!.trim()
        : _backgroundBridgeDeviceId?.trim();

    if (reconnectDeviceId == null || reconnectDeviceId.isEmpty) {
      debugPrint('Reconnect ignored: no preferred wearable device id available');
      return;
    }

    if (_connectionState == BleConnectionState.connecting ||
        _connectionState == BleConnectionState.connected) {
      return;
    }

    _preferredReconnectDeviceId = reconnectDeviceId;
    _autoReconnectEnabled = true;

    final cachedDevice = _discoveredDevices[reconnectDeviceId];
    if (cachedDevice != null) {
      await _attemptAutoReconnect(cachedDevice);
      return;
    }

    _maybeStartAutoReconnect();
  }

  Future<void> _connectInternal(BleDevice device, {required bool fromAutoReconnect}) async {
    try {
      _log('connect.request', data: <String, Object?>{
        'deviceId': device.deviceId,
        'deviceName': device.name,
        'fromAutoReconnect': fromAutoReconnect,
      });
      if (_connectionState == BleConnectionState.connecting) {
        if (_connectingDeviceId == device.deviceId) {
          return;
        }
        debugPrint('Ignoring connect for ${device.deviceId}; another connect is in flight.');
        return;
      }

      debugPrint("Connecting to ${device.name} (${device.deviceId})...");

      _deviceType = _identifyDeviceType(device.name ?? '');
      debugPrint("Identified device type: $_deviceType");

      _connectingDeviceId = device.deviceId;
      if (!fromAutoReconnect) {
        _preferredReconnectDeviceId = device.deviceId;
        _autoReconnectEnabled = true;
      }

      await UniversalBle.stopScan();
      _isScanning = false;
      notifyListeners();

      _connectionState = BleConnectionState.connecting;
      notifyListeners();

      if (_connectedDevice?.deviceId == device.deviceId) {
        debugPrint("Device already in connected state - forcing disconnect first...");
        try {
          await UniversalBle.disconnect(device.deviceId);
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint("Warning: Failed to disconnect stuck device: $e");
        }
      }

      if (kIsWeb) {
        debugPrint("Web platform detected - adding extra stabilization delay...");
        await Future.delayed(const Duration(milliseconds: 1500));
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      int retryCount = 0;
      bool success = false;
      
      while (retryCount < _maxConnectRetries && !success) {
        try {
          debugPrint("Connection attempt ${retryCount + 1}/$_maxConnectRetries...");
          _log('connect.attempt', data: <String, Object?>{
            'deviceId': device.deviceId,
            'attempt': retryCount + 1,
            'maxAttempts': _maxConnectRetries,
          });
          
          final timeoutSeconds = kIsWeb ? 15 : 10;
          await UniversalBle.connect(device.deviceId).timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              throw Exception('Connection timeout after $timeoutSeconds seconds');
            },
          );
          
          success = true;
          debugPrint("Connection attempt ${retryCount + 1} succeeded!");
          _log('connect.attempt.ok', data: <String, Object?>{
            'deviceId': device.deviceId,
            'attempt': retryCount + 1,
          });
        } catch (e) {
          retryCount++;
          debugPrint("Connect attempt $retryCount failed: $e");
          _log('connect.attempt.failed', data: <String, Object?>{
            'deviceId': device.deviceId,
            'attempt': retryCount,
          }, error: e);
          
          if (retryCount < _maxConnectRetries) {
            final delayMs = _baseReconnectDelayMs * (1 << (retryCount - 1));
            debugPrint("Retrying in ${delayMs}ms...");
            await Future.delayed(Duration(milliseconds: delayMs));
          } else {
            debugPrint("All $_maxConnectRetries connection attempts failed");
            rethrow;
          }
        }
      }
      
      debugPrint("Connected. Discovering services...");
      final stabilizationDelay = kIsWeb ? 1000 : 500;
      await Future.delayed(Duration(milliseconds: stabilizationDelay));
      
      List<BleService> discoveredServices = [];
      try {
        discoveredServices = await UniversalBle.discoverServices(device.deviceId);
        debugPrint("Services discovered. Found ${discoveredServices.length} services");
        
        for (final service in discoveredServices) {
          debugPrint("  Service: ${service.uuid}");
          for (final char in service.characteristics) {
            debugPrint("    Characteristic: ${char.uuid}");
          }
        }
      } catch (e) {
        debugPrint("Warning: Service discovery failed: $e");
      }

      _connectedDevice = device;
      _connectionState = BleConnectionState.connected;
      _connectingDeviceId = null;
      _preferredReconnectDeviceId = device.deviceId;
      _autoReconnectEnabled = true;
      _stopAutoReconnectLoop();

      await _subscribeToAudioCharacteristic(device.deviceId, discoveredServices);
  unawaited(_ensureNativeBackgroundBridge(autoStartRecording: false));

      if (_deviceType == WearableDeviceType.heypocket) {
        await _heypocketSyncCoordinator.onConnected(device.deviceId, discoveredServices);
      }

      _log('connect.ok', data: <String, Object?>{
        'deviceId': device.deviceId,
        'serviceCount': discoveredServices.length,
      });

      notifyListeners();
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      _log('connect.failed', data: <String, Object?>{
        'deviceId': device.deviceId,
      }, error: e);
      _connectingDeviceId = null;
      _clearConnectionState();
      _maybeStartAutoReconnect();
      notifyListeners();
      rethrow;
    }
  }

  bool _shouldAutoReconnectTo(BleDevice device) {
    if (!_autoReconnectEnabled) {
      return false;
    }
    if (_connectionState == BleConnectionState.connecting ||
        _connectionState == BleConnectionState.connected) {
      return false;
    }
    final preferred = _preferredReconnectDeviceId;
    if (preferred == null || preferred.isEmpty) {
      return false;
    }
    return device.deviceId == preferred;
  }

  Future<void> _attemptAutoReconnect(BleDevice device) async {
    try {
      await _connectInternal(device, fromAutoReconnect: true);
    } catch (e) {
      debugPrint('Auto-reconnect attempt failed for ${device.deviceId}: $e');
    }
  }

  void _maybeStartAutoReconnect() {
    if (!_autoReconnectEnabled ||
        _preferredReconnectDeviceId == null ||
        _preferredReconnectDeviceId!.isEmpty) {
      return;
    }

    _autoReconnectTimer ??= Timer.periodic(_autoReconnectScanInterval, (_) {
      if (_connectionState == BleConnectionState.connected ||
          _connectionState == BleConnectionState.connecting) {
        return;
      }
      if (_isScanning) {
        return;
      }
      unawaited(startScan());
    });

    if (!_isScanning) {
      unawaited(startScan());
    }
  }

  void _stopAutoReconnectLoop() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;
  }

  Future<void> _subscribeToAudioCharacteristic(String deviceId, List<BleService> services) async {
    if (services.isEmpty) {
      debugPrint('No services discovered; skipping notification subscription');
      return;
    }

    final protocol = _getProtocolForDevice(_deviceType);
    if (protocol == null) {
      debugPrint("No protocol found for device type: $_deviceType");
      return;
    }

    final serviceUuid = protocol.serviceUuid;
    if (serviceUuid == null) {
      debugPrint("No service UUID for protocol: ${protocol.id}");
      return;
    }

    final normalizedServiceUuid = serviceUuid.toLowerCase().replaceAll('-', '');
    final serviceMatches = services.where(
      (s) => s.uuid.toLowerCase().replaceAll('-', '') == normalizedServiceUuid,
    );
    if (serviceMatches.isEmpty) {
      debugPrint('Service UUID not found on device: $serviceUuid');
      return;
    }
    final service = serviceMatches.first;

    final audioCharUuid = protocol.audioCharUuid;
    if (audioCharUuid != null) {
      try {
        if (_deviceType == WearableDeviceType.heypocket) {
          await _heypocketSyncCoordinator.subscribeNotifications(
            deviceId: deviceId,
            service: service,
            audioCharUuid: audioCharUuid,
            controlCharUuid: protocol.controlCharUuid,
          );
        } else {
          await UniversalBle.subscribeNotifications(
            deviceId,
            service.uuid,
            audioCharUuid,
          );
          debugPrint("Subscribed to audio characteristic: $audioCharUuid");
        }
      } catch (e) {
        debugPrint("Failed to subscribe to audio characteristic: $e");
        
        for (final char in service.characteristics) {
          try {
            await UniversalBle.subscribeNotifications(deviceId, service.uuid, char.uuid);
            debugPrint("Subscribed to: ${char.uuid}");
          } catch (subError) {
            debugPrint("Could not subscribe to ${char.uuid}: $subError");
          }
        }
      }
    }
  }

  Future<void> requestHeyPocketOfflineSync() async {
    if (!canRequestOfflineSync) {
      debugPrint('Offline sync request ignored: HeyPocket device not connected');
      return;
    }

    final deviceId = _connectedDevice!.deviceId;
    await _heypocketSyncCoordinator.requestOfflineSync(
      deviceId,
      reason: 'manual',
    );
  }

  Future<void> cancelHeyPocketOfflineSync() async {
    if (!canRequestOfflineSync || _connectedDevice == null) {
      return;
    }

    await _heypocketSyncCoordinator.cancelOfflineSync(_connectedDevice!.deviceId);
  }

  Future<void> deleteHeyPocketOfflineFile(HeyPocketSyncFile file) async {
    if (!canRequestOfflineSync || _connectedDevice == null) {
      return;
    }

    await _heypocketSyncCoordinator.deleteOfflineSyncFile(
      _connectedDevice!.deviceId,
      file,
    );
  }

  Future<void> startHeyPocketRecordingFromApp() async {
    if (!canStartHeyPocketRecording) {
      return;
    }
    if (_heypocketStartInFlight) {
      _log('recording.start.ignored_in_flight');
      return;
    }
    _heypocketStartInFlight = true;
    notifyListeners();

    try {
      final deviceId = _activeHeyPocketDeviceId;
      if (deviceId == null) {
        _log('recording.start.ignored_no_device');
        return;
      }
      var nativeBridgeStarted = false;
      var nativeBridgeConnected = false;

      if (!kIsWeb && Platform.isAndroid) {
        nativeBridgeStarted =
            await _ensureNativeBackgroundBridge(autoStartRecording: true);
        nativeBridgeConnected = _backgroundBridgeConnected;
        _log('recording.start.bridge.ensure_result', data: <String, Object?>{
          'deviceId': deviceId,
          'nativeBridgeStarted': nativeBridgeStarted,
          'nativeBridgeConnected': nativeBridgeConnected,
        });
      }

      Object? startError;
      try {
        await _heypocketSyncCoordinator.startRecordingFromApp(deviceId);
        _log('recording.start.command.dispatched', data: <String, Object?>{
          'deviceId': deviceId,
          'path': 'flutter.direct',
          'nativeBridgeStarted': nativeBridgeStarted,
          'nativeBridgeConnected': nativeBridgeConnected,
        });
      } catch (e, stackTrace) {
        startError = e;
        _log(
          'recording.start.command.failed',
          data: <String, Object?>{
            'deviceId': deviceId,
            'path': 'flutter.direct',
            'nativeBridgeStarted': nativeBridgeStarted,
            'nativeBridgeConnected': nativeBridgeConnected,
          },
          error: e,
          stackTrace: stackTrace,
        );
      }

      if (nativeBridgeStarted) {
        _log('recording.start.bridge.fallback_ready', data: <String, Object?>{
          'deviceId': deviceId,
          'nativeBridgeConnected': nativeBridgeConnected,
          'directCommandError': startError != null,
        });
        return;
      }

      if (startError != null) {
        return;
      }
    } finally {
      _heypocketStartInFlight = false;
      notifyListeners();
    }
  }

  Future<void> stopHeyPocketRecordingFromApp() async {
    if (!canStartHeyPocketRecording) {
      return;
    }

    final deviceId = _activeHeyPocketDeviceId;
    if (deviceId == null) {
      _log('recording.stop.ignored_no_device');
      return;
    }

    _heypocketSyncCoordinator.setRecordingStateFromBridge(active: false);
    notifyListeners();

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final status = await _wearableBackgroundBridge.stopBackgroundBridge(sendStop: true);
        _backgroundBridgeActive = status['active'] == true;
        _backgroundBridgeConnected = status['connected'] == true;
        _heypocketSyncCoordinator.setRecordingStateFromBridge(active: false);
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to stop native wearable bridge: $e');
      }
    }

    if (_connectedDevice != null) {
      await _heypocketSyncCoordinator.stopRecordingFromApp(deviceId);
    }
    await _finalizeActiveWearableRecording(deviceId);
  }

  bool _isHeyPocketRecordingStopControl(Uint8List payload) {
    try {
      final text = String.fromCharCodes(payload).replaceAll('\u0000', '').trim();
      if (text.isEmpty) {
        return false;
      }
      return _heypocketRecordingStopControlPattern.hasMatch(text);
    } catch (_) {
      return false;
    }
  }

  bool _isHeyPocketControlCharacteristic(String characteristicUuid) {
    final normalized = characteristicUuid.toLowerCase().replaceAll('-', '');
    final control = WearableServiceUuids.heypocketControlTx
        .toLowerCase()
        .replaceAll('-', '');
    return normalized == control;
  }

  Future<void> _finalizeActiveWearableRecording(String deviceId) async {
    final now = DateTime.now();
    if (_finalizeInFlight) {
      _log('stream.finalize.skipped_inflight', data: <String, Object?>{
        'deviceId': deviceId,
      });
      return;
    }
    final previous = _lastFinalizeAt;
    if (previous != null && now.difference(previous) < _wearableFinalizeCooldown) {
      _log('stream.finalize.skipped_cooldown', data: <String, Object?>{
        'deviceId': deviceId,
        'elapsedMs': now.difference(previous).inMilliseconds,
      });
      return;
    }

    _finalizeInFlight = true;
    _lastFinalizeAt = now;
    try {
      _log('stream.finalize.request', data: <String, Object?>{
        'deviceId': deviceId,
      });
      final response = await _backendClient.stopWearableLiveStream(
        _getBackendUrl(),
        deviceId,
      );
      debugPrint('Requested wearable live stream finalize: $response');
      _log('stream.finalize.ok', data: <String, Object?>{
        'deviceId': deviceId,
        'response': response,
      });
    } catch (e) {
      debugPrint('Failed to finalize wearable live stream: $e');
      _log('stream.finalize.failed', data: <String, Object?>{
        'deviceId': deviceId,
      }, error: e);
    } finally {
      _finalizeInFlight = false;
    }
  }

  Future<bool> _ensureNativeBackgroundBridge({
    required bool autoStartRecording,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    final deviceId = _activeHeyPocketDeviceId;
    if (deviceId == null) {
      return false;
    }

    final sessionCookie = _backendClient.sessionCookie ?? '';
    if (sessionCookie.isEmpty) {
      return false;
    }

    try {
      final status = await _wearableBackgroundBridge.startBackgroundBridge(
        backendUrl: _getBackendUrl(),
        sessionCookie: sessionCookie,
        macAddress: deviceId,
        deviceName: _connectedDevice?.name ?? 'Wearable Device',
        protocolId: WearableProtocols.heypocket,
        serviceUuid: WearableServiceUuids.heypocketServiceUuid,
        audioNotifyUuid: WearableServiceUuids.heypocketAudioTx,
        controlNotifyUuid: WearableServiceUuids.heypocketControlTx,
        controlWriteUuid: WearableServiceUuids.heypocketControlRx,
        autoStartRecording: autoStartRecording,
      );

      final active = status['active'] == true;
      final connected = status['connected'] == true;
      final statusDeviceId = status['macAddress']?.toString();

      _backgroundBridgeActive = active;
      _backgroundBridgeConnected = connected;
      _backgroundBridgeDeviceId =
          statusDeviceId != null && statusDeviceId.trim().isNotEmpty
              ? statusDeviceId.trim()
            : deviceId;
      notifyListeners();
      return active;
    } catch (e) {
      debugPrint('Failed to start native wearable bridge: $e');
      return false;
    }
  }

  Future<void> _restoreBackgroundBridgeState() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      final status = await _wearableBackgroundBridge.backgroundBridgeStatus();
      final active = status['active'] == true;
        final connected = status['connected'] == true;
      final deviceId = status['macAddress']?.toString();

      _backgroundBridgeActive = active;
        _backgroundBridgeConnected = connected;
      _backgroundBridgeDeviceId =
          deviceId != null && deviceId.trim().isNotEmpty ? deviceId.trim() : null;

      if (active && _backgroundBridgeDeviceId != null) {
        _preferredReconnectDeviceId = _backgroundBridgeDeviceId;
        _autoReconnectEnabled = true;
        _maybeStartAutoReconnect();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to restore wearable background bridge status: $e');
    }
  }

  Future<void> setHeyPocketCallMode(bool enabled) async {
    if (!canRequestOfflineSync || _connectedDevice == null) {
      return;
    }

    await _heypocketSyncCoordinator.setCallMode(
      _connectedDevice!.deviceId,
      enabled,
    );
  }

  Future<void> _uploadHeyPocketSyncPayload(String deviceId, Uint8List payload) {
    return _backendClient.syncWearableData(
      _getBackendUrl(),
      deviceId,
      payload,
    );
  }

  /// Ensure device is registered with the backend
  Future<void> _ensureDeviceRegistered(String deviceId) async {
    final registrationKey = '_deviceRegistered_$deviceId';
    if (_registeredDevices.contains(registrationKey)) {
      return;
    }
    
    try {
      debugPrint("Registering device with backend: $deviceId");

      final protocolId = _deviceType != null 
          ? WearableProtocols.fromDeviceType(_deviceType!)
          : 'custom';
      
      await _backendClient.registerWearable(
        _getBackendUrl(),
        deviceId,
        protocolId,
        _connectedDevice?.name ?? 'Unknown Device',
      );
      
      _registeredDevices.add(registrationKey);
      debugPrint("Device registered successfully: $deviceId");
    } catch (e) {
      debugPrint("Failed to register device: $e");
      rethrow;
    }
  }
  
  final Set<String> _registeredDevices = {};

  String? _protocolIdForDeviceType(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.heypocket:
        return WearableProtocols.heypocket;
      case WearableDeviceType.custom:
      case WearableDeviceType.unknown:
        return null;
    }
  }

  void _clearConnectionState({bool clearDiscoveredDevices = false}) {
    _connectedDevice = null;
    _deviceType = null;
    _heypocketSyncCoordinator.setRecordingStateFromBridge(active: false);
    _connectionState = BleConnectionState.disconnected;
    _lastSuccessfulCommunication = null;
    _registeredDevices.clear();
    _stopConnectionHealthMonitoring();
    if (clearDiscoveredDevices) {
      _discoveredDevices.clear();
    }
  }
  
  void _startConnectionHealthMonitoring() {
    _stopConnectionHealthMonitoring();
    _connectionHealthTimer = Timer.periodic(_connectionHealthCheckInterval, (_) {
      _checkConnectionHealth();
    });
  }
  
  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }
  
  void _checkConnectionHealth() {
    if (_connectedDevice == null) return;
    
    final now = DateTime.now();
    final lastComm = _lastSuccessfulCommunication;
    
    if (lastComm != null) {
      final timeSinceLastComm = now.difference(lastComm);
      if (timeSinceLastComm > const Duration(minutes: 2)) {
        debugPrint("Warning: No communication for ${timeSinceLastComm.inSeconds}s - device may be unresponsive");
      }
    }
  }

  Future<void> disconnect() async {
    final deviceId = _connectedDevice?.deviceId;
    if (deviceId != null || _backgroundBridgeActive) {
      try {
        if (deviceId != null) {
          debugPrint("Disconnecting from $deviceId...");
          await UniversalBle.disconnect(deviceId);
        }
      } catch (e) {
        debugPrint("Error disconnecting: $e");
      }
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _wearableBackgroundBridge.stopBackgroundBridge(sendStop: false);
          _backgroundBridgeActive = false;
          _backgroundBridgeConnected = false;
          _backgroundBridgeDeviceId = null;
        } catch (e) {
          debugPrint('Error stopping native wearable bridge: $e');
        }
      }
      _autoReconnectEnabled = false;
      _preferredReconnectDeviceId = null;
      _connectingDeviceId = null;
      _stopAutoReconnectLoop();
      _clearConnectionState();
      notifyListeners();
    }
  }

  Future<void> resetBleState() async {
    debugPrint("Resetting BLE state...");
    
    if (_isScanning) {
      try {
        await UniversalBle.stopScan();
      } catch (e) {
        debugPrint("Error stopping scan during reset: $e");
      }
      _isScanning = false;
    }
    
    if (_connectedDevice != null) {
      try {
        await UniversalBle.disconnect(_connectedDevice!.deviceId);
      } catch (e) {
        debugPrint("Error disconnecting during reset: $e");
      }
    }

    _clearConnectionState(clearDiscoveredDevices: true);
    
    notifyListeners();
    debugPrint("BLE state reset complete");
  }

  @override
  void dispose() {
    _stopConnectionHealthMonitoring();
    _stopAutoReconnectLoop();
    _heypocketSyncCoordinator.dispose();
    UniversalBle.onScanResult = null;
    UniversalBle.onConnectionChange = null;
    UniversalBle.onValueChange = null;
    super.dispose();
  }
}

class _PendingWearableChunk {
  _PendingWearableChunk({
    required this.deviceId,
    required this.characteristicUuid,
    required this.payload,
    this.attempts = 0,
  });

  factory _PendingWearableChunk.fromJson(Map<String, dynamic> json) {
    final payloadBase64 = json['payloadBase64'];
    final payloadString = payloadBase64 is String ? payloadBase64 : '';
    final attemptsValue = json['attempts'];
    final attempts = attemptsValue is int
        ? attemptsValue
        : int.tryParse('$attemptsValue') ?? 0;

    return _PendingWearableChunk(
      deviceId: '${json['deviceId'] ?? ''}',
      characteristicUuid: '${json['characteristicUuid'] ?? ''}',
      payload: base64Decode(payloadString),
      attempts: attempts,
    );
  }

  final String deviceId;
  final String characteristicUuid;
  final Uint8List payload;
  int attempts;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'characteristicUuid': characteristicUuid,
      'payloadBase64': base64Encode(payload),
      'attempts': attempts,
    };
  }
}
