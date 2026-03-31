/// Device types supported by the wearable system
enum WearableDeviceType {
  heypocket,
  custom,
  unknown, // For filtering unknown BLE devices
}

/// Audio codec types
enum BleAudioCodec {
  pcm,
  mp3,
  opus,
  lc3,
  lc3FS1030,
}

/// Connection state for devices
enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// Wearable device model
class WearableDevice {
  final String id;
  final String name;
  final WearableDeviceType type;
  final String? macAddress;
  final String? firmwareVersion;
  final int? batteryLevel;
  final DeviceConnectionState connectionState;

  const WearableDevice({
    required this.id,
    required this.name,
    required this.type,
    this.macAddress,
    this.firmwareVersion,
    this.batteryLevel,
    this.connectionState = DeviceConnectionState.disconnected,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'macAddress': macAddress,
        'firmwareVersion': firmwareVersion,
        'batteryLevel': batteryLevel,
        'connectionState': connectionState.name,
      };

  factory WearableDevice.fromJson(Map<String, dynamic> json) => WearableDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        type: WearableDeviceType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => WearableDeviceType.custom,
        ),
        macAddress: json['macAddress'] as String?,
        firmwareVersion: json['firmwareVersion'] as String?,
        batteryLevel: json['batteryLevel'] as int?,
        connectionState: DeviceConnectionState.values.firstWhere(
          (e) => e.name == json['connectionState'],
          orElse: () => DeviceConnectionState.disconnected,
        ),
      );

  WearableDevice copyWith({
    String? id,
    String? name,
    WearableDeviceType? type,
    String? macAddress,
    String? firmwareVersion,
    int? batteryLevel,
    DeviceConnectionState? connectionState,
  }) =>
      WearableDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        macAddress: macAddress ?? this.macAddress,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        connectionState: connectionState ?? this.connectionState,
      );
}

/// Service UUIDs for various wearable devices
class WearableServiceUuids {
  // HeyPocket Device (PKT01)
  static const String heypocketServiceUuid = '001120a0-2233-4455-6677-889912345678';
  static const String heypocketControlRx = '001120a2-2233-4455-6677-889912345678';
  static const String heypocketControlTx = '001120a1-2233-4455-6677-889912345678';
  static const String heypocketAudioTx = '001120a3-2233-4455-6677-889912345678';

  // Standard Battery Service
  static const String batteryServiceUuid = '0000180f-0000-1000-8000-00805f9b34fb';
  static const String batteryLevelChar = '00002a19-0000-1000-8000-00805f9b34fb';

  // Standard Device Info
  static const String deviceInfoServiceUuid = '0000180a-0000-1000-8000-00805f9b34fb';
  static const String modelNumberChar = '00002a24-0000-1000-8000-00805f9b34fb';
  static const String firmwareRevisionChar = '00002a26-0000-1000-8000-00805f9b34fb';
  static const String manufacturerNameChar = '00002a29-0000-1000-8000-00805f9b34fb';

  /// Get service UUID for a device type
  static String? getServiceUuid(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.heypocket:
        return heypocketServiceUuid;
      default:
        return null;
    }
  }

  /// Get audio characteristic UUID for a device type
  static String? getAudioCharUuid(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.heypocket:
        return heypocketAudioTx;
      default:
        return null;
    }
  }
}

/// Protocol identifier for wearable devices
class WearableProtocols {
  static const String heypocket = 'heypocket';
  static const String custom = 'custom';

  /// Map device type to protocol identifier
  static String fromDeviceType(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.heypocket:
        return heypocket;
      case WearableDeviceType.custom:
      case WearableDeviceType.unknown:
        return custom;
    }
  }

  /// Get device type from protocol identifier
  static WearableDeviceType? toDeviceType(String protocol) {
    switch (protocol) {
      case heypocket:
        return WearableDeviceType.heypocket;
      case custom:
        return WearableDeviceType.custom;
      default:
        return null;
    }
  }
}