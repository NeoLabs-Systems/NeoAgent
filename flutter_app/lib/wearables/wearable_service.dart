import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import '../src/backend_client.dart';
import 'models.dart';
import 'packet/sync_coordinator.dart';
import 'protocols/base.dart';

const _connectionHealthCheckInterval = Duration(seconds: 30);
const _baseReconnectDelayMs = 1000;
const _maxConnectRetries = 5;

class WearableService extends ChangeNotifier {
  WearableService({
    required BackendClient backendClient,
    required ValueGetter<String> getBackendUrl,
  }) : _backendClient = backendClient,
       _getBackendUrl = getBackendUrl {
    _packetSyncCoordinator = PacketSyncCoordinator(
      ensureDeviceRegistered: _ensureDeviceRegistered,
      uploadSyncPayload: _uploadPacketSyncPayload,
      onSyncStateChanged: notifyListeners,
    );
    _init();
  }

  final BackendClient _backendClient;
  final ValueGetter<String> _getBackendUrl;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final Map<String, BleDevice> _discoveredDevices = {};

  List<BleDevice> get scanResults => _discoveredDevices.values
      .where((device) => _identifyDeviceType(device.name ?? '') != WearableDeviceType.unknown)
      .toList();

  BleDevice? _connectedDevice;
  BleDevice? get connectedDevice => _connectedDevice;

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BleConnectionState get connectionState => _connectionState;
  
  Timer? _connectionHealthTimer;
  DateTime? _lastSuccessfulCommunication;

  final Map<String, WearableProtocolBase> _protocols = {};

  WearableDeviceType? _deviceType;
  late final PacketSyncCoordinator _packetSyncCoordinator;

  bool get canRequestOfflineSync =>
      _connectedDevice != null && _deviceType == WearableDeviceType.packet;

  bool get isOfflineSyncRequestInFlight => _packetSyncCoordinator.isSyncRequestInFlight;
  String get packetSyncStatus => _packetSyncCoordinator.lastSyncStatus;
  String get packetSyncLastControlMessage => _packetSyncCoordinator.lastControlMessage;
  int get packetSyncListedFilesCount => _packetSyncCoordinator.listedFilesCount;
  int get packetSyncUploadCommandsSent => _packetSyncCoordinator.uploadCommandsSent;
  bool get packetCallModeEnabled => _packetSyncCoordinator.isCallMode;
  String get packetModeLabel => _packetSyncCoordinator.packetModeLabel;
  bool get packetModeSwitchInFlight => _packetSyncCoordinator.isModeSwitchInFlight;

  void _init() {
    _registerDefaultProtocols();

    UniversalBle.onScanResult = (device) {
      debugPrint("Scan result: ${device.name} (${device.deviceId})");
      
      _discoveredDevices[device.deviceId] = device;
      notifyListeners();
    };

    UniversalBle.onConnectionChange = (deviceId, isConnected, error) {
      debugPrint("Connection change: $deviceId connected=$isConnected error=$error");
      if (_connectedDevice?.deviceId == deviceId) {
        if (!isConnected) {
          debugPrint("Device disconnected: $deviceId");
          _clearConnectionState();
        } else {
          _connectionState = BleConnectionState.connected;
          _lastSuccessfulCommunication = DateTime.now();
          _startConnectionHealthMonitoring();
        }
        notifyListeners();
      }
    };

    UniversalBle.onValueChange = (deviceId, characteristicUuid, value, _) {
      if (_connectedDevice?.deviceId == deviceId) {
        _lastSuccessfulCommunication = DateTime.now();

        if (_deviceType == WearableDeviceType.packet) {
          final packetProtocol = _getProtocolForDevice(WearableDeviceType.packet);
          if (packetProtocol != null) {
            _packetSyncCoordinator.observeControlPayload(value);
            _packetSyncCoordinator.captureSyncChunk(
              characteristicUuid,
              value,
              packetProtocol.parseAudioPayload,
            );
          }
        }
        
        _ensureDeviceRegistered(deviceId).then((_) {
          _backendClient
              .streamWearableData(
                _getBackendUrl(),
                deviceId,
                characteristicUuid,
                value,
              )
              .then((_) {})
              .catchError((e) {
                debugPrint("Error streaming wearable data: $e");
              }, test: (e) => true);
        }).catchError((e) {
          debugPrint("Error registering device: $e");
        });
      }
    };
  }

  void _registerDefaultProtocols() {
    final builtInProtocols = <WearableProtocolBase>[
      OmiProtocol(),
      PlaudProtocol(),
      FriendProtocol(),
      BeeProtocol(),
      LimitlessProtocol(),
      FrameProtocol(),
      FieldyProtocol(),
      PacketProtocol(),
    ];

    for (final protocol in builtInProtocols) {
      _protocols[protocol.id] = protocol;
    }
  }

  WearableDeviceType _identifyDeviceType(String name) {
    final lowerName = name.toLowerCase();

    if (lowerName.contains('openglass')) {
      return WearableDeviceType.openglass;
    }
    if (lowerName.contains('omi') || lowerName.contains('omiglass')) {
      return WearableDeviceType.omi;
    }
    if (lowerName.contains('plaud')) {
      return WearableDeviceType.plaud;
    }
    if (lowerName.contains('friend')) {
      return WearableDeviceType.friend;
    }
    if (lowerName.contains('bee')) {
      return WearableDeviceType.bee;
    }
    if (lowerName.contains('limitless') || lowerName.contains('pendant')) {
      return WearableDeviceType.limitless;
    }
    if (lowerName.contains('frame')) {
      return WearableDeviceType.frame;
    }
    if (lowerName.contains('fieldy')) {
      return WearableDeviceType.fieldy;
    }
    if (lowerName.contains('heypocket') || lowerName.contains('pocket') || lowerName.contains('packet') || lowerName.contains('pkt01')) {
      return WearableDeviceType.packet;
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

  Future<void> startScan() async {
    try {
      _discoveredDevices.clear();
      notifyListeners();
      debugPrint("Starting scan for all wearable devices...");

      final serviceUuids = _buildScanServiceUuids();
      
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
      _isScanning = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error starting scan: $e");
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await UniversalBle.stopScan();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error stopping scan: $e");
    }
  }

  Future<void> connect(BleDevice device) async {
    try {
      debugPrint("Connecting to ${device.name} (${device.deviceId})...");

      _deviceType = _identifyDeviceType(device.name ?? '');
      debugPrint("Identified device type: $_deviceType");

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
          
          final timeoutSeconds = kIsWeb ? 15 : 10;
          await UniversalBle.connect(device.deviceId).timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              throw Exception('Connection timeout after $timeoutSeconds seconds');
            },
          );
          
          success = true;
          debugPrint("Connection attempt ${retryCount + 1} succeeded!");
        } catch (e) {
          retryCount++;
          debugPrint("Connect attempt $retryCount failed: $e");
          
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

      await _subscribeToAudioCharacteristic(device.deviceId, discoveredServices);

      if (_deviceType == WearableDeviceType.packet) {
        await _packetSyncCoordinator.onConnected(device.deviceId, discoveredServices);
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      _clearConnectionState();
      notifyListeners();
      rethrow;
    }
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
    final service = services.firstWhere(
      (s) => s.uuid.toLowerCase().replaceAll('-', '') == normalizedServiceUuid,
      orElse: () => services.first,
    );

    final audioCharUuid = protocol.audioCharUuid;
    if (audioCharUuid != null) {
      try {
        if (_deviceType == WearableDeviceType.packet) {
          await _packetSyncCoordinator.subscribeNotifications(
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

  Future<void> requestPacketOfflineSync() async {
    if (!canRequestOfflineSync) {
      debugPrint('Offline sync request ignored: Packet device not connected');
      return;
    }

    final deviceId = _connectedDevice!.deviceId;
    await _packetSyncCoordinator.requestOfflineSync(
      deviceId,
      reason: 'manual',
    );
  }

  Future<void> setPacketCallMode(bool enabled) async {
    if (!canRequestOfflineSync || _connectedDevice == null) {
      return;
    }

    await _packetSyncCoordinator.setCallMode(
      _connectedDevice!.deviceId,
      enabled,
    );
  }

  Future<void> _uploadPacketSyncPayload(String deviceId, Uint8List payload) {
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
    }
  }
  
  final Set<String> _registeredDevices = {};

  String? _protocolIdForDeviceType(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.omi:
      case WearableDeviceType.openglass:
        return WearableProtocols.omi;
      case WearableDeviceType.plaud:
        return WearableProtocols.plaud;
      case WearableDeviceType.friend:
        return WearableProtocols.friend;
      case WearableDeviceType.bee:
        return WearableProtocols.bee;
      case WearableDeviceType.frame:
        return WearableProtocols.frame;
      case WearableDeviceType.fieldy:
        return WearableProtocols.fieldy;
      case WearableDeviceType.limitless:
        return WearableProtocols.limitless;
      case WearableDeviceType.packet:
        return WearableProtocols.packet;
      case WearableDeviceType.appleWatch:
        return WearableProtocols.appleWatch;
      case WearableDeviceType.custom:
      case WearableDeviceType.unknown:
        return null;
    }
  }

  void _clearConnectionState({bool clearDiscoveredDevices = false}) {
    _connectedDevice = null;
    _deviceType = null;
    _connectionState = BleConnectionState.disconnected;
    _lastSuccessfulCommunication = null;
    _registeredDevices.clear();
    _packetSyncCoordinator.dispose();
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
    if (deviceId != null) {
      try {
        debugPrint("Disconnecting from $deviceId...");
        await UniversalBle.disconnect(deviceId);
      } catch (e) {
        debugPrint("Error disconnecting: $e");
      }
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
    _packetSyncCoordinator.dispose();
    UniversalBle.onScanResult = null;
    UniversalBle.onConnectionChange = null;
    UniversalBle.onValueChange = null;
    super.dispose();
  }
}
