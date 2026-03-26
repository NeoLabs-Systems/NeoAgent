import 'dart:convert';

/// Device types supported by the wearable system
enum WearableDeviceType {
  omi,
  openglass,
  plaud,
  friend,
  bee,
  frame,
  appleWatch,
  fieldy,
  limitless,
  packet,
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
  // Omi / OpenGlass
  static const String omiServiceUuid = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String omiAudioData = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String omiAudioCodec = '19b10002-e8f2-537e-4f6c-d104768a1214';
  static const String omiImageData = '19b10005-e8f2-537e-4f6c-d104768a1214';
  static const String omiTimeSync = '19b10030-e8f2-537e-4f6c-d104768a1214';
  static const String omiAccelData = '32403790-0000-1000-7450-bf445e5829a2';

  // Plaud
  static const String plaudServiceUuid = '00001910-0000-1000-8000-00805f9b34fb';
  static const String plaudNotify = '00002bb0-0000-1000-8000-00805f9b34fb';
  static const String plaudWrite = '00002bb1-0000-1000-8000-00805f9b34fb';

  // Friend Pendant
  static const String friendServiceUuid = '1a3fd0e7-b1f3-ac9e-2e49-b647b2c4f8da';
  static const String friendAudioChar = '01000000-1111-1111-1111-111111111111';

  // Bee
  static const String beeServiceUuid = '03d5d5c4-a86c-11ee-9d89-8f2089a49e7e';

  // Limitless
  static const String limitlessServiceUuid = '632de001-604c-446b-a80f-7963e950f3fb';
  static const String limitlessTx = '632de002-604c-446b-a80f-7963e950f3fb';
  static const String limitlessRx = '632de003-604c-446b-a80f-7963e950f3fb';

  // Frame
  static const String frameServiceUuid = '7A230001-5475-A6A4-654C-8431F6AD49C4';

  // Fieldy
  static const String fieldyServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  // HeyPocket Device (PKT01)
  static const String packetServiceUuid = '001120a0-2233-4455-6677-889912345678';
  static const String packetControlRx = '001120a2-2233-4455-6677-889912345678';
  static const String packetControlTx = '001120a1-2233-4455-6677-889912345678';
  static const String packetAudioTx = '001120a3-2233-4455-6677-889912345678';

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
      case WearableDeviceType.omi:
      case WearableDeviceType.openglass:
        return omiServiceUuid;
      case WearableDeviceType.plaud:
        return plaudServiceUuid;
      case WearableDeviceType.friend:
        return friendServiceUuid;
      case WearableDeviceType.bee:
        return beeServiceUuid;
      case WearableDeviceType.limitless:
        return limitlessServiceUuid;
      case WearableDeviceType.frame:
        return frameServiceUuid;
      case WearableDeviceType.fieldy:
        return fieldyServiceUuid;
      case WearableDeviceType.packet:
        return packetServiceUuid;
      default:
        return null;
    }
  }

  /// Get audio characteristic UUID for a device type
  static String? getAudioCharUuid(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.omi:
      case WearableDeviceType.openglass:
        return omiAudioData;
      case WearableDeviceType.plaud:
        return plaudNotify;
      case WearableDeviceType.friend:
        return friendAudioChar;
      case WearableDeviceType.limitless:
        return limitlessTx;
      case WearableDeviceType.packet:
        return packetAudioTx;
      default:
        return null;
    }
  }
}

/// Protocol identifier for wearable devices
class WearableProtocols {
  static const String omi = 'omi';
  static const String plaud = 'plaud';
  static const String friend = 'friend';
  static const String packet = 'packet';
  static const String limitless = 'limitless';
  static const String bee = 'bee';
  static const String frame = 'frame';
  static const String fieldy = 'fieldy';
  static const String appleWatch = 'apple_watch';
  static const String custom = 'custom';

  /// Map device type to protocol identifier
  static String fromDeviceType(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.omi:
      case WearableDeviceType.openglass:
        return omi;
      case WearableDeviceType.plaud:
        return plaud;
      case WearableDeviceType.friend:
        return friend;
      case WearableDeviceType.bee:
        return bee;
      case WearableDeviceType.frame:
        return frame;
      case WearableDeviceType.fieldy:
        return fieldy;
      case WearableDeviceType.appleWatch:
        return appleWatch;
      case WearableDeviceType.packet:
        return packet;
      case WearableDeviceType.limitless:
        return limitless;
      case WearableDeviceType.custom:
        return custom;
    }
  }

  /// Get device type from protocol identifier
  static WearableDeviceType? toDeviceType(String protocol) {
    switch (protocol) {
      case omi:
        return WearableDeviceType.omi;
      case plaud:
        return WearableDeviceType.plaud;
      case friend:
        return WearableDeviceType.friend;
      case bee:
        return WearableDeviceType.bee;
      case frame:
        return WearableDeviceType.frame;
      case fieldy:
        return WearableDeviceType.fieldy;
      case appleWatch:
        return WearableDeviceType.appleWatch;
      case limitless:
        return WearableDeviceType.limitless;
      case packet:
        return WearableDeviceType.packet;
      default:
        return null;
    }
  }
}