import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ringtone.dart';

/// Whether the phone lets NeoAgent put a call in front of the user: drawing
/// over other apps (to come forward from the background), full-screen
/// notifications (to ring over the lock screen) and running without battery
/// restrictions (so the connection calls arrive on survives).
class CallPermissionStatus {
  const CallPermissionStatus({
    required this.overlay,
    required this.fullScreenIntent,
    required this.unrestrictedBattery,
  });

  static const granted = CallPermissionStatus(
    overlay: true,
    fullScreenIntent: true,
    unrestrictedBattery: true,
  );

  final bool overlay;
  final bool fullScreenIntent;
  final bool unrestrictedBattery;

  bool get allGranted => overlay && fullScreenIntent && unrestrictedBattery;
}

/// The platform side of a call: ringing, presenting the call screen from the
/// background or over the lock screen, and the speakerphone.
///
/// Android does all of it natively. Elsewhere the ring is a looping ringtone
/// with haptics, and the rest is a no-op.
class CallBridge {
  CallBridge._();

  static const MethodChannel _channel = MethodChannel('neoagent/call');
  static const Duration _hapticInterval = Duration(seconds: 3);

  static Timer? _haptics;

  static bool get _native => !kIsWeb && Platform.isAndroid;

  /// The speakerphone can only be switched where the call audio is routed
  /// natively.
  static bool get supportsSpeakerphone => _native;

  static Future<CallPermissionStatus> permissionStatus() async {
    if (!_native) return CallPermissionStatus.granted;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'permissionStatus',
      );
      return CallPermissionStatus(
        overlay: raw?['overlay'] == true,
        fullScreenIntent: raw?['fullScreenIntent'] == true,
        unrestrictedBattery: raw?['unrestrictedBattery'] == true,
      );
    } on PlatformException {
      return CallPermissionStatus.granted;
    }
  }

  static Future<void> openOverlaySettings() => _invoke('openOverlaySettings');

  static Future<void> openFullScreenIntentSettings() =>
      _invoke('openFullScreenIntentSettings');

  static Future<void> requestUnrestrictedBattery() =>
      _invoke('requestUnrestrictedBattery');

  static Future<void> startRinging() async {
    if (_native) return _invoke('startRinging');
    _haptics?.cancel();
    unawaited(HapticFeedback.heavyImpact());
    _haptics = Timer.periodic(
      _hapticInterval,
      (_) => unawaited(HapticFeedback.heavyImpact()),
    );
    await Ringtone.start();
  }

  static Future<void> stopRinging() async {
    if (_native) return _invoke('stopRinging');
    _haptics?.cancel();
    _haptics = null;
    await Ringtone.stop();
  }

  /// Brings the app forward and lets it show over the lock screen. Returns
  /// whether it had been in the background.
  static Future<bool> present() async {
    if (!_native) return false;
    try {
      return await _channel.invokeMethod<bool>('present') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stops ringing and stops showing over the lock screen; [moveToBack]
  /// returns the app to wherever the user was before the call came in.
  static Future<void> dismiss({bool moveToBack = false}) async {
    if (!_native) return stopRinging();
    await _invoke('dismiss', <String, Object?>{'moveToBack': moveToBack});
  }

  static Future<void> setSpeakerphone(bool on) =>
      _invoke('setSpeakerphone', <String, Object?>{'on': on});

  static Future<void> _invoke(String method, [Object? arguments]) async {
    if (!_native) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Call bridge $method failed: ${error.message}');
    }
  }
}
