import 'dart:typed_data';
import '../models.dart';

/// Base protocol for all wearable devices
abstract class WearableProtocolBase {
  /// Protocol identifier
  String get id;

  /// Human-readable name
  String get name;

  /// MIME type for audio data
  String get mimeType;

  /// Audio codec used
  BleAudioCodec get codec;

  String? get serviceUuid => null;

  String? get audioCharUuid => null;

  String? get controlCharUuid => null;

  /// Parse raw audio payload from BLE notification
  Uint8List? parseAudioPayload(Uint8List rawPayload, {String? characteristicUuid}) {
    return rawPayload;
  }

  /// Extract battery level from payload (if embedded)
  int? extractBatteryLevel(Uint8List rawPayload, {String? characteristicUuid}) {
    return null;
  }

  /// Process offline sync data
  Uint8List? processOfflineSync(Uint8List fileBuffer) {
    return fileBuffer;
  }

  /// Get protocol from device type
  static WearableProtocolBase? fromDeviceType(WearableDeviceType type) {
    switch (type) {
      case WearableDeviceType.omi:
      case WearableDeviceType.openglass:
        return OmiProtocol();
      case WearableDeviceType.plaud:
        return PlaudProtocol();
      case WearableDeviceType.friend:
        return FriendProtocol();
      case WearableDeviceType.bee:
        return BeeProtocol();
      case WearableDeviceType.limitless:
        return LimitlessProtocol();
      case WearableDeviceType.frame:
        return FrameProtocol();
      case WearableDeviceType.fieldy:
        return FieldyProtocol();
      case WearableDeviceType.packet:
        return PacketProtocol();
      default:
        return null;
    }
  }
}

/// Omi / OpenGlass Protocol
/// Uses standard PCM audio streaming
class OmiProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.omi;

  @override
  String get name => 'Omi / OpenGlass';

  @override
  String get mimeType => 'audio/wav';

  @override
  BleAudioCodec get codec => BleAudioCodec.pcm;

  @override
  String? get serviceUuid => WearableServiceUuids.omiServiceUuid;

  @override
  String? get audioCharUuid => WearableServiceUuids.omiAudioData;
}

/// Plaud Protocol
/// Uses custom notification format with 10-byte header
class PlaudProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.plaud;

  @override
  String get name => 'Plaud Note';

  @override
  String get mimeType => 'audio/mp4';

  @override
  BleAudioCodec get codec => BleAudioCodec.opus;

  @override
  String? get serviceUuid => WearableServiceUuids.plaudServiceUuid;

  @override
  String? get audioCharUuid => WearableServiceUuids.plaudNotify;

  @override
  Uint8List? parseAudioPayload(Uint8List rawPayload, {String? characteristicUuid}) {
    // Plaud format: [command(1)][sessionId(4)][position(4)][length(1)][data...]
    const headerLength = 10;
    if (rawPayload.length < headerLength) return null;
    
    // Check if it's an audio data packet (command = 2)
    if (rawPayload[0] != 2) return null;
    
    final position = _bytesToInt32(rawPayload.sublist(5, 9));
    if (position == 0xFFFFFFFF) return null; // End marker
    
    final length = rawPayload[9];
    if (rawPayload.length < headerLength + length) return null;
    
    return rawPayload.sublist(headerLength, headerLength + length);
  }

  int _bytesToInt32(List<int> bytes) {
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }

  @override
  int? extractBatteryLevel(Uint8List rawPayload, {String? characteristicUuid}) {
    // Battery response format: [isCharging(1)][level(1)]
    if (rawPayload.length == 2) {
      final level = rawPayload[1];
      if (level >= 0 && level <= 100) return level;
    }
    return null;
  }
}

/// Friend Pendant Protocol
/// Uses LC3 codec at 16kHz with 30-byte frames
class FriendProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.friend;

  @override
  String get name => 'Friend Pendant';

  @override
  String get mimeType => 'audio/lc3';

  @override
  BleAudioCodec get codec => BleAudioCodec.lc3FS1030;

  @override
  String? get serviceUuid => WearableServiceUuids.friendServiceUuid;

  @override
  String? get audioCharUuid => WearableServiceUuids.friendAudioChar;

  @override
  Uint8List? parseAudioPayload(Uint8List rawPayload, {String? characteristicUuid}) {
    // Friend sends 95-byte packets: 90 bytes LC3 + 5 bytes footer
    // Strip the 5-byte footer
    if (rawPayload.length < 5) return null;
    return rawPayload.sublist(0, rawPayload.length - 5);
  }
}

/// Bee Protocol
class BeeProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.bee;

  @override
  String get name => 'Bee';

  @override
  String get mimeType => 'audio/mp3';

  @override
  BleAudioCodec get codec => BleAudioCodec.mp3;

  @override
  String? get serviceUuid => WearableServiceUuids.beeServiceUuid;
}

/// Limitless Protocol
/// Uses custom notification format
class LimitlessProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.limitless;

  @override
  String get name => 'Limitless';

  @override
  String get mimeType => 'audio/mp4';

  @override
  BleAudioCodec get codec => BleAudioCodec.opus;

  @override
  String? get serviceUuid => WearableServiceUuids.limitlessServiceUuid;

  @override
  String? get audioCharUuid => WearableServiceUuids.limitlessTx;
}

/// Frame Protocol
class FrameProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.frame;

  @override
  String get name => 'Frame';

  @override
  String get mimeType => 'audio/mp3';

  @override
  BleAudioCodec get codec => BleAudioCodec.mp3;

  @override
  String? get serviceUuid => WearableServiceUuids.frameServiceUuid;
}

/// Fieldy Protocol
class FieldyProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.fieldy;

  @override
  String get name => 'Fieldy';

  @override
  String get mimeType => 'audio/mp3';

  @override
  BleAudioCodec get codec => BleAudioCodec.mp3;

  @override
  String? get serviceUuid => WearableServiceUuids.fieldyServiceUuid;
}

/// HeyPocket Device (PKT01) Protocol
/// Streams 16kHz Mono MP3 frames (32kbps) over BLE
class PacketProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.packet;

  @override
  String get name => 'HeyPocket Device';

  @override
  String get mimeType => 'audio/mpeg';

  @override
  BleAudioCodec get codec => BleAudioCodec.mp3;

  @override
  String? get serviceUuid => WearableServiceUuids.packetServiceUuid;

  @override
  String? get audioCharUuid => WearableServiceUuids.packetAudioTx;

  @override
  String? get controlCharUuid => WearableServiceUuids.packetControlTx;

  @override
  Uint8List? parseAudioPayload(Uint8List rawPayload, {String? characteristicUuid}) {
    if (rawPayload.isEmpty) return null;

    final normalizedCharacteristic = _normalizeUuid(characteristicUuid);
    final audioTx = _normalizeUuid(WearableServiceUuids.packetAudioTx);

    if (normalizedCharacteristic != null && normalizedCharacteristic == audioTx) {
      return rawPayload;
    }

    if (_isAsciiControlMessage(rawPayload)) {
      return null;
    }

    return rawPayload;
  }

  @override
  int? extractBatteryLevel(Uint8List rawPayload, {String? characteristicUuid}) {
    if (rawPayload.isEmpty) return null;

    // Packet sends battery as text: "MCU&BAT&98"
    try {
      final text = String.fromCharCodes(rawPayload);
      final match = RegExp(r'MCU&BAT&(\d+)').firstMatch(text);
      if (match != null) {
        final level = int.tryParse(match.group(1)!);
        if (level != null && level >= 0 && level <= 100) {
          return level;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _normalizeUuid(String? value) {
    if (value == null) return null;
    return value.trim().toLowerCase().replaceAll('-', '');
  }

  bool _isAsciiControlMessage(Uint8List rawPayload) {
    if (rawPayload.length < 5) {
      return false;
    }

    try {
      final text = String.fromCharCodes(rawPayload);
      final asciiOnly = RegExp(r'^[\x20-\x7E\r\n\t]+$').hasMatch(text);
      if (!asciiOnly) {
        return false;
      }
      return RegExp(r'^(MCU|APP|BLE|SYS)&').hasMatch(text.trim());
    } catch (_) {
      return false;
    }
  }
}