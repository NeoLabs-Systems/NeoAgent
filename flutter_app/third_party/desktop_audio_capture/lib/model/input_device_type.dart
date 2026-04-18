/// Enum representing the type of input device (microphone).
///
/// This enum categorizes input devices into three types: built-in, Bluetooth,
/// or external (USB, etc.).
///
/// Example:
/// ```dart
/// final device = InputDevice(
///   id: 'device1',
///   name: 'Built-in Microphone',
///   type: InputDeviceType.builtIn,
///   channelCount: 1,
///   isDefault: true,
/// );
///
/// // Convert to/from string
/// final typeString = device.type.toString(); // 'built-in'
/// final type = InputDeviceType.fromString('bluetooth'); // InputDeviceType.bluetooth
/// ```
enum InputDeviceType {
  /// Built-in device (e.g., laptop microphone)
  builtIn,

  /// Bluetooth device (wireless microphone)
  bluetooth,

  /// External device (USB microphone, etc.)
  external;

  /// Creates an [InputDeviceType] from a string.
  ///
  /// Accepts: 'built-in', 'bluetooth', 'external' (case-insensitive).
  /// Returns [InputDeviceType.external] for unknown values.
  ///
  /// Example:
  /// ```dart
  /// final type1 = InputDeviceType.fromString('built-in'); // InputDeviceType.builtIn
  /// final type2 = InputDeviceType.fromString('BLUETOOTH'); // InputDeviceType.bluetooth
  /// final type3 = InputDeviceType.fromString('unknown'); // InputDeviceType.external (default)
  /// ```
  static InputDeviceType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'built-in':
        return InputDeviceType.builtIn;
      case 'bluetooth':
        return InputDeviceType.bluetooth;
      case 'external':
        return InputDeviceType.external;
      default:
        return InputDeviceType.external;
    }
  }

  /// Converts this [InputDeviceType] to a string representation.
  ///
  /// Returns: 'built-in', 'bluetooth', or 'external'.
  ///
  /// Example:
  /// ```dart
  /// InputDeviceType.builtIn.toString(); // 'built-in'
  /// InputDeviceType.bluetooth.toString(); // 'bluetooth'
  /// InputDeviceType.external.toString(); // 'external'
  /// ```
  @override
  String toString() {
    switch (this) {
      case InputDeviceType.builtIn:
        return 'built-in';
      case InputDeviceType.bluetooth:
        return 'bluetooth';
      case InputDeviceType.external:
        return 'external';
    }
  }
}

/// Class representing information about an input device (microphone).
///
/// This class contains all relevant information about a microphone device,
/// including its ID, name, type, channel count, and whether it's the default device.
///
/// Example:
/// ```dart
/// // Get available devices
/// final devices = await micCapture.getAvailableInputDevices();
///
/// // Find a specific device
/// final usbMic = devices.firstWhere(
///   (device) => device.name.contains('USB'),
/// );
///
/// print('Device: ${usbMic.name}');
/// print('Type: ${usbMic.type}');
/// print('Channels: ${usbMic.channelCount}');
/// print('Default: ${usbMic.isDefault}');
///
/// // Convert to/from map
/// final map = usbMic.toMap();
/// final restored = InputDevice.fromMap(map);
/// ```
class InputDevice {
  /// Unique identifier of the device.
  ///
  /// This ID can be used to identify and select a specific device.
  final String id;

  /// Human-readable name of the device.
  ///
  /// Examples: "Built-in Microphone", "USB Microphone", "AirPods Pro"
  final String name;

  /// Type of the device (built-in, Bluetooth, or external).
  final InputDeviceType type;

  /// Number of audio channels supported by the device.
  ///
  /// Typically 1 for mono, 2 for stereo.
  final int channelCount;

  /// Whether this device is the system default input device.
  final bool isDefault;

  /// Creates a new [InputDevice] instance.
  ///
  /// All parameters are required.
  ///
  /// Example:
  /// ```dart
  /// final device = InputDevice(
  ///   id: 'device-123',
  ///   name: 'Built-in Microphone',
  ///   type: InputDeviceType.builtIn,
  ///   channelCount: 1,
  ///   isDefault: true,
  /// );
  /// ```
  const InputDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.channelCount,
    required this.isDefault,
  });

  /// Creates an [InputDevice] instance from a map.
  ///
  /// The map should contain:
  /// - `id`: String (defaults to empty string if missing)
  /// - `name`: String (defaults to empty string if missing)
  /// - `type`: String (converted via [InputDeviceType.fromString], defaults to external)
  /// - `channelCount`: int (defaults to 0 if missing)
  /// - `isDefault`: bool (defaults to false if missing)
  ///
  /// Example:
  /// ```dart
  /// final map = {
  ///   'id': 'device-123',
  ///   'name': 'USB Microphone',
  ///   'type': 'external',
  ///   'channelCount': 2,
  ///   'isDefault': false,
  /// };
  /// final device = InputDevice.fromMap(map);
  /// ```
  factory InputDevice.fromMap(Map<String, dynamic> map) {
    return InputDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: InputDeviceType.fromString(map['type'] as String? ?? 'external'),
      channelCount: map['channelCount'] as int? ?? 0,
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  /// Converts this [InputDevice] instance to a map.
  ///
  /// Returns a map containing all device information:
  /// - `id`: String
  /// - `name`: String
  /// - `type`: String (from [InputDeviceType.toString])
  /// - `channelCount`: int
  /// - `isDefault`: bool
  ///
  /// Example:
  /// ```dart
  /// final device = InputDevice(
  ///   id: 'device-123',
  ///   name: 'USB Microphone',
  ///   type: InputDeviceType.external,
  ///   channelCount: 2,
  ///   isDefault: false,
  /// );
  /// final map = device.toMap();
  /// ```
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'channelCount': channelCount,
      'isDefault': isDefault,
    };
  }

  @override
  String toString() {
    return 'InputDevice(id: $id, name: $name, type: ${type.toString()}, '
        'channelCount: $channelCount, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InputDevice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
