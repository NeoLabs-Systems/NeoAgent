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
      case WearableDeviceType.heypocket:
        return HeyPocketProtocol();
      default:
        return null;
    }
  }
}

/// HeyPocket Device (PKT01) Protocol
/// Streams 16kHz Mono MP3 frames (32kbps) over BLE
class HeyPocketProtocol extends WearableProtocolBase {
  @override
  String get id => WearableProtocols.heypocket;

  @override
  String get name => 'HeyPocket Device';

  @override
  String get mimeType => 'audio/mpeg';

  @override
  BleAudioCodec get codec => BleAudioCodec.mp3;

  @override
  String? get serviceUuid => WearableServiceUuids.heypocketServiceUuid;

  @override
  String? get audioCharUuid => WearableServiceUuids.heypocketAudioTx;

  @override
  String? get controlCharUuid => WearableServiceUuids.heypocketControlTx;

  @override
  Uint8List? parseAudioPayload(Uint8List rawPayload, {String? characteristicUuid}) {
    if (rawPayload.isEmpty) return null;

    final normalizedCharacteristic = _normalizeUuid(characteristicUuid);
    final audioTx = _normalizeUuid(WearableServiceUuids.heypocketAudioTx);
    final controlTx = _normalizeUuid(WearableServiceUuids.heypocketControlTx);

    if (normalizedCharacteristic != null &&
        normalizedCharacteristic != audioTx &&
        normalizedCharacteristic != controlTx) {
      return null;
    }

    if (_isAsciiControlMessage(rawPayload)) {
      return null;
    }

    return rawPayload;
  }

  @override
  int? extractBatteryLevel(Uint8List rawPayload, {String? characteristicUuid}) {
    if (rawPayload.isEmpty) return null;

    // HeyPocket sends battery as text: "MCU&BAT&98"
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
