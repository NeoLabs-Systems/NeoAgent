import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:audioplayers/audioplayers.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/android_apk_drop_zone.dart';
import 'src/android_launcher_bridge.dart';
import 'src/app_launch_bridge.dart';
import 'src/app_release_updater.dart' as app_release_updater;
import 'src/backend_client.dart';
import 'src/desktop_companion.dart';
import 'src/desktop_screen_capture.dart';
import 'src/diagnostics_logger.dart';
import 'src/health_bridge.dart';
import 'src/live_voice_capture.dart';
import 'src/messaging_access_summary.dart';
import 'src/oauth_launcher.dart';
import 'src/recording_bridge.dart';
import 'src/recording_payloads.dart';
import 'src/theme/palette.dart';
import 'src/web_app_update_monitor.dart';
import 'src/widget_bridge.dart';
import 'src/android_auto_bridge.dart';

import 'features/location/location_service.dart';
import 'features/notifications/notification_interceptor.dart';
import 'features/onboarding/onboarding_shell.dart';

part 'main_theme.dart';
part 'main_app_shell.dart';
part 'main_launcher.dart';
part 'main_integrations.dart';
part 'main_models.dart';
part 'main_shared.dart';
part 'main_voice_assistant.dart';
part 'main_navigation.dart';
part 'main_runtime.dart';
part 'main_controller.dart';
part 'main_devices.dart';
part 'main_recordings.dart';
part 'main_chat.dart';
part 'main_account_settings.dart';
part 'main_settings.dart';
part 'main_operations.dart';
part 'main_admin.dart';

Future<void> main() async {
  await runNeoAgentApp(mode: _appModeFromEnvironment());
}

Future<void> runNeoAgentApp({
  NeoAgentAppMode mode = NeoAgentAppMode.standard,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supportsDesktopShell) {
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();
  }
  runApp(NeoAgentApp(mode: mode));
}

const String _browserUrlPlaceholder = 'https://example.com';
const String _androidLaunchPlaceholder = 'com.android.settings';
const String _packageOrUrlHint = 'Package name or URL';
const String _desktopAssistantHotkeyLabel = 'Ctrl + Shift + Space';
const String _desktopWindowIconAsset = 'assets/branding/app_icon_256.png';
const String _desktopTrayTemplateIconAsset =
    'assets/branding/tray_icon_template.png';
const String _sessionCookiePrefsKey = 'auth.sessionCookie';
const String _sessionCookieBackendPrefsKey = 'auth.sessionCookieBackend';
const String _sessionCookieSecureStorageKey = 'auth.sessionCookie.secure';
const int _voiceAssistantScreenshotMaxDimension = 1600;
const int _voiceAssistantScreenshotMaxBytes = 900 * 1024;

String get _desktopTrayIconAsset =>
    defaultTargetPlatform == TargetPlatform.macOS
    ? _desktopTrayTemplateIconAsset
    : _desktopWindowIconAsset;

bool get _supportsDesktopShell =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);
