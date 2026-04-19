import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_screen_capture.dart';

const String desktopCompanionEnabledPrefsKey = 'desktop.companion.enabled';
const String desktopCompanionLabelPrefsKey = 'desktop.companion.label';
const String desktopCompanionDeviceIdPrefsKey = 'desktop.companion.deviceId';
const String desktopCompanionActivationIdPrefsKey =
    'desktop.companion.activationId';
const String desktopCompanionPausedPrefsKey = 'desktop.companion.paused';

class DesktopCompanionManager extends ChangeNotifier {
  DesktopCompanionManager({required DesktopScreenCapture screenCapture});

  bool get enabled => false;
  bool get paused => false;
  bool get connecting => false;
  bool get connected => false;
  String? get errorMessage => 'Desktop companion is not available here.';
  String get label => 'Desktop';
  String get deviceId => '';
  String get activationId => '';
  Map<String, Object?> get status => const <String, Object?>{};

  Future<void> bootstrap(SharedPreferences prefs) async {}

  Future<void> updateSession({
    required String backendUrl,
    required String sessionCookie,
    required bool authenticated,
  }) async {}

  Future<void> setEnabled(bool value, SharedPreferences prefs) async {
    throw UnsupportedError('Desktop companion is not available here.');
  }

  Future<void> setLabel(String value, SharedPreferences prefs) async {
    throw UnsupportedError('Desktop companion is not available here.');
  }

  Future<void> setPaused(bool value, SharedPreferences prefs) async {
    throw UnsupportedError('Desktop companion is not available here.');
  }

  Future<void> disconnect() async {}

  Future<void> rotateIdentity(SharedPreferences prefs) async {
    throw UnsupportedError('Desktop companion is not available here.');
  }

  Future<Map<String, Object?>> refreshLocalStatus() async {
    throw UnsupportedError('Desktop companion is not available here.');
  }

  Future<void> openPermissionSettings(String permissionKey) async {
    throw UnsupportedError('Desktop companion is not available here.');
  }
}
