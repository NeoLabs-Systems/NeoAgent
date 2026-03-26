import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import '../src/backend_client.dart';
import 'models.dart';
import 'packet/sync_coordinator.dart';
import 'protocols/base.dart';

/// Connection health monitoring interval
const _connectionHealthCheckInterval = Duration(seconds: 30);

/// Device discovery callback
typedef OnDeviceDiscovered = void Function(BleDevice device, WearableDeviceType? type);

/// Scan filter for different device types
class DeviceScanFilter {
  final String? serviceUuid;
  final String? namePrefix;
  final WearableDeviceType? deviceType;

  const DeviceScanFilter({
    this.serviceUuid,
    this.namePrefix,
    this.deviceType,
  });
}

/// Wearable service supporting multiple device types
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
  
  /// Filter to only show known devices (exclude unknown BLE devices)
  List<BleDevice> get scanResults => _discoveredDevices.values
      .where((device) => _identifyDeviceType(device.name ?? '') != WearableDeviceType.unknown)
      .toList();

  BleDevice? _connectedDevice;
  BleDevice? get connectedDevice => _connectedDevice;

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BleConnectionState get connectionState => _connectionState;
  
  Timer? _connectionHealthTimer;
  DateTime? _lastSuccessfulCommunication;

  /// Registered protocols by ID
  final Map<String, WearableProtocolBase> _protocols = {};

  /// Device type for current connection
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
    // Register built-in protocols
    _registerDefaultProtocols();

    UniversalBle.onScanResult = (device) {
      debugPrint("Scan result: ${device.name} (${device.deviceId})");
      
      _discoveredDevices[device.deviceId] = device;
      
      // Notify listeners with device type info
      notifyListeners();
    };

    UniversalBle.onConnectionChange = (deviceId, isConnected, error) {
      debugPrint("Connection change: $deviceId connected=$isConnected error=$error");
      if (_connectedDevice?.deviceId == deviceId) {
        _connectionState = isConnected ? BleConnectionState.connected : BleConnectionState.disconnected;
        if (!isConnected) {
          debugPrint("Device disconnected: $deviceId");
          _packetSyncCoordinator.dispose();
          _connectedDevice = null;
          _deviceType = null;
          _stopConnectionHealthMonitoring();
        } else {
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
              .then((_) {
                // Success - data streamed
              })
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
    // Register built-in protocols once to avoid duplicate object creation.
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

  /// Identify device type from device name
  WearableDeviceType _identifyDeviceType(String name) {
    final lowerName = name.toLowerCase();
    
    if (lowerName.contains('omi') || lowerName.contains('omiglass') || lowerName.contains('openglass')) {
      return WearableDeviceType.omi;
    }
    if (lowerName.contains('plaud')) {
      return WearableDeviceType.plaud;
    }
    if (lowerName.contains('friend')) {
      return WearableDeviceType.friend;
    }
    if (lowerName.contains('heypocket') || lowerName.contains('pocket') || lowerName.contains('packet') || lowerName.contains('pkt01')) {
      return WearableDeviceType.packet;
    }
    // Only show known devices, not unknown ones
    return WearableDeviceType.unknown;
  }

  /// Get protocol for device type
  WearableProtocolBase? _getProtocolForDevice(WearableDeviceType? type) {
    if (type == null) return null;
    return WearableProtocolBase.fromDeviceType(type);
  }

  /// Get scan filters for all supported device types
  List<DeviceScanFilter> get _scanFilters => [
    const DeviceScanFilter(serviceUuid: '19b10000-e8f2-537e-4f6c-d104768a1214', deviceType: WearableDeviceType.omi),
    const DeviceScanFilter(serviceUuid: '00001910-0000-1000-8000-00805f9b34fb', deviceType: WearableDeviceType.plaud),
    const DeviceScanFilter(serviceUuid: '1a3fd0e7-b1f3-ac9e-2e49-b647b2c4f8da', deviceType: WearableDeviceType.friend),
    const DeviceScanFilter(serviceUuid: '03d5d5c4-a86c-11ee-9d89-8f2089a49e7e', deviceType: WearableDeviceType.bee),
    const DeviceScanFilter(serviceUuid: '632de001-604c-446b-a80f-7963e950f3fb', deviceType: WearableDeviceType.limitless),
    const DeviceScanFilter(serviceUuid: '7A230001-5475-A6A4-654C-8431F6AD49C4', deviceType: WearableDeviceType.frame),
    const DeviceScanFilter(serviceUuid: '4fafc201-1fb5-459e-8fcc-c5c9c331914b', deviceType: WearableDeviceType.fieldy),
    const DeviceScanFilter(serviceUuid: '001120a0-2233-4455-6677-889912345678', deviceType: WearableDeviceType.packet),
  ];

  /// Start scanning for all supported devices
  Future<void> startScan() async {
    try {
      _discoveredDevices.clear();
      notifyListeners();
      debugPrint("Starting scan for all wearable devices...");
      
      // Collect all service UUIDs to scan for
      final serviceUuids = _scanFilters
          .where((f) => f.serviceUuid != null)
          .map((f) => f.serviceUuid!)
          .toList();
      
      // Add standard battery and device info services
      serviceUuids.addAll([
        '0000180f-0000-1000-8000-00805f9b34fb', // Battery
        '0000180a-0000-1000-8000-00805f9b34fb', // Device Info
      ]);
      
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

  /// Connect to a device
  Future<void> connect(BleDevice device) async {
    try {
      debugPrint("Connecting to ${device.name} (${device.deviceId})...");
      
      // Determine device type
      _deviceType = _identifyDeviceType(device.name ?? '');
      debugPrint("Identified device type: $_deviceType");
      
      // Unconditionally stop scan before connecting
      await UniversalBle.stopScan();
      _isScanning = false;
      notifyListeners();

      _connectionState = BleConnectionState.connecting;
      notifyListeners();

      // Check if device is already connected (stuck state)
      if (_connectedDevice?.deviceId == device.deviceId) {
        debugPrint("Device already in connected state - forcing disconnect first...");
        try {
          await UniversalBle.disconnect(device.deviceId);
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint("Warning: Failed to disconnect stuck device: $e");
        }
      }

      // Platform-specific delay
      if (kIsWeb) {
        debugPrint("Web platform detected - adding extra stabilization delay...");
        await Future.delayed(const Duration(milliseconds: 1500));
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Implement retry logic
      int retryCount = 0;
      const maxRetries = 5;
      bool success = false;
      
      while (retryCount < maxRetries && !success) {
        try {
          debugPrint("Connection attempt ${retryCount + 1}/$maxRetries...");
          
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
          
          if (retryCount < maxRetries) {
            final delayMs = 1000 * (1 << (retryCount - 1));
            debugPrint("Retrying in ${delayMs}ms...");
            await Future.delayed(Duration(milliseconds: delayMs));
          } else {
            debugPrint("All $maxRetries connection attempts failed");
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

      // Subscribe to audio characteristic based on device type
      await _subscribeToAudioCharacteristic(device.deviceId, discoveredServices);

      if (_deviceType == WearableDeviceType.packet) {
        await _packetSyncCoordinator.onConnected(device.deviceId, discoveredServices);
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      _connectionState = BleConnectionState.disconnected;
      _connectedDevice = null;
      _deviceType = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Subscribe to the appropriate audio characteristic based on device type
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

    // Find the service
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

    // Find audio characteristic
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
        
        // Try to subscribe to all characteristics in the service
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
      
      // Determine protocol ID from device type
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

  /// Disconnect from current device
  Future<void> disconnect() async {
    final deviceId = _connectedDevice?.deviceId;
    if (deviceId != null) {
      try {
        debugPrint("Disconnecting from $deviceId...");
        _stopConnectionHealthMonitoring();
        await UniversalBle.disconnect(deviceId);
      } catch (e) {
        debugPrint("Error disconnecting: $e");
      }
      _connectedDevice = null;
      _deviceType = null;
      _connectionState = BleConnectionState.disconnected;
      _lastSuccessfulCommunication = null;
      _registeredDevices.clear();
      _packetSyncCoordinator.dispose();
      notifyListeners();
    }
  }

  /// Reset BLE state
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
    
    _connectedDevice = null;
    _deviceType = null;
    _connectionState = BleConnectionState.disconnected;
    _lastSuccessfulCommunication = null;
    _stopConnectionHealthMonitoring();
    _discoveredDevices.clear();
    _registeredDevices.clear();
    _packetSyncCoordinator.dispose();
    
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
