import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

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
import 'src/widget_bridge.dart';

import 'features/location/location_service.dart';
import 'features/notifications/notification_interceptor.dart';

part 'main_theme.dart';
part 'main_app_shell.dart';
part 'main_launcher.dart';
part 'main_integrations.dart';
part 'main_models.dart';
part 'main_shared.dart';
part 'main_voice_assistant.dart';

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

enum NeoAgentAppMode { standard, launcher }

NeoAgentAppMode _appModeFromEnvironment() {
  const rawMode = String.fromEnvironment(
    'NEOAGENT_APP_MODE',
    defaultValue: 'standard',
  );
  return rawMode.toLowerCase() == 'launcher'
      ? NeoAgentAppMode.launcher
      : NeoAgentAppMode.standard;
}

enum AppSection {
  chat,
  voiceAssistant,
  devices,
  recordings,
  messaging,
  runs,
  settings,
  accountSettings,
  logs,
  skills,
  agents,
  integrations,
  memory,
  tasks,
  widgets,
  mcp,
  health,
}

enum SidebarGroup { chat, agents, recordings, activity, automation, settings }

extension SidebarGroupX on SidebarGroup {
  String get label {
    switch (this) {
      case SidebarGroup.chat:
        return 'Chat';
      case SidebarGroup.agents:
        return 'Agents';
      case SidebarGroup.recordings:
        return 'Recording';
      case SidebarGroup.activity:
        return 'Activity';
      case SidebarGroup.automation:
        return 'Automation';
      case SidebarGroup.settings:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case SidebarGroup.chat:
        return Icons.chat_bubble_outline;
      case SidebarGroup.agents:
        return Icons.smart_toy_outlined;
      case SidebarGroup.recordings:
        return Icons.fiber_smart_record_outlined;
      case SidebarGroup.activity:
        return Icons.insights_outlined;
      case SidebarGroup.automation:
        return Icons.auto_awesome_outlined;
      case SidebarGroup.settings:
        return Icons.tune;
    }
  }
}

extension AppSectionX on AppSection {
  String get label {
    switch (this) {
      case AppSection.chat:
        return 'Chat';
      case AppSection.voiceAssistant:
        return 'Voice assistant';
      case AppSection.devices:
        return 'Devices';
      case AppSection.recordings:
        return 'Recordings';
      case AppSection.messaging:
        return 'Messaging';
      case AppSection.runs:
        return 'Runs';
      case AppSection.settings:
        return 'Settings';
      case AppSection.accountSettings:
        return 'Account settings';
      case AppSection.logs:
        return 'Logs';
      case AppSection.skills:
        return 'Skills';
      case AppSection.agents:
        return 'Agents';
      case AppSection.integrations:
        return 'Integrations';
      case AppSection.memory:
        return 'Memory';
      case AppSection.tasks:
        return 'Tasks';
      case AppSection.widgets:
        return 'Widgets';
      case AppSection.mcp:
        return 'MCP';
      case AppSection.health:
        return 'Health';
    }
  }

  IconData get icon {
    switch (this) {
      case AppSection.chat:
        return Icons.chat_bubble_outline;
      case AppSection.voiceAssistant:
        return Icons.keyboard_voice_outlined;
      case AppSection.devices:
        return Icons.devices_other_outlined;
      case AppSection.recordings:
        return Icons.fiber_smart_record_outlined;
      case AppSection.messaging:
        return Icons.forum_outlined;
      case AppSection.runs:
        return Icons.history;
      case AppSection.settings:
        return Icons.tune;
      case AppSection.accountSettings:
        return Icons.manage_accounts_outlined;
      case AppSection.logs:
        return Icons.article_outlined;
      case AppSection.skills:
        return Icons.extension_outlined;
      case AppSection.agents:
        return Icons.smart_toy_outlined;
      case AppSection.integrations:
        return Icons.integration_instructions_outlined;
      case AppSection.memory:
        return Icons.psychology_outlined;
      case AppSection.tasks:
        return Icons.schedule_outlined;
      case AppSection.widgets:
        return Icons.dashboard_customize_outlined;
      case AppSection.mcp:
        return Icons.hub_outlined;
      case AppSection.health:
        return Icons.favorite_border;
    }
  }

  SidebarGroup get group {
    switch (this) {
      case AppSection.chat:
      case AppSection.voiceAssistant:
        return SidebarGroup.chat;
      case AppSection.recordings:
        return SidebarGroup.recordings;
      case AppSection.runs:
      case AppSection.logs:
        return SidebarGroup.activity;
      case AppSection.devices:
      case AppSection.skills:
      case AppSection.integrations:
      case AppSection.memory:
      case AppSection.tasks:
      case AppSection.widgets:
      case AppSection.mcp:
      case AppSection.health:
        return SidebarGroup.automation;
      case AppSection.agents:
      case AppSection.settings:
      case AppSection.accountSettings:
      case AppSection.messaging:
        return SidebarGroup.settings;
    }
  }

  String get navigationTitle {
    final groupLabel = group.label;
    if (this == AppSection.voiceAssistant) {
      return label;
    }
    if (group == SidebarGroup.chat || group == SidebarGroup.recordings) {
      return groupLabel;
    }
    if (groupLabel == label) {
      return groupLabel;
    }
    return '$groupLabel · $label';
  }
}

class NeoAgentApp extends StatefulWidget {
  const NeoAgentApp({super.key, this.mode = NeoAgentAppMode.standard});

  final NeoAgentAppMode mode;

  @override
  State<NeoAgentApp> createState() => _NeoAgentAppState();
}

class _NeoAgentAppState extends State<NeoAgentApp>
    with WindowListener, TrayListener {
  late final NeoAgentController _controller;
  final AppLaunchBridge _appLaunchBridge = AppLaunchBridge();
  StreamSubscription<String>? _appLaunchSubscription;
  StreamSubscription<String>? _widgetOpenSubscription;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _navigatorScopeSignature;
  Menu? _trayMenu;
  HotKey? _assistantHotKey;
  Timer? _assistantHotKeyHoldTimer;
  bool _desktopShellInitialized = false;
  bool _handlingDesktopClose = false;
  bool _desktopToolbarWindowMode = false;
  bool _desktopAssistantPopupWindowMode = false;
  bool _syncingDesktopPresentation = false;
  bool _assistantHotKeyPressed = false;
  bool _assistantHotKeyHandledAsHold = false;
  bool _assistantPttActive = false;
  bool _desktopAssistantBlockedHintVisible = false;
  bool _desktopAssistantReturnToHidden = false;
  bool _desktopToolbarReturnToHidden = false;
  Rect? _desktopNormalWindowBounds;

  static const Size _desktopToolbarWindowSize = Size(840, 128);
  static const Size _desktopAssistantPopupWindowSize = Size(460, 112);
  static const Duration _desktopAssistantHoldThreshold = Duration(
    milliseconds: 220,
  );
  static const Duration _desktopAssistantBlockedHintDuration = Duration(
    milliseconds: 1400,
  );

  @override
  void initState() {
    super.initState();
    final backendClient = BackendClient();
    _controller = NeoAgentController(
      appMode: widget.mode,
      backendClient: backendClient,
      healthBridge: HealthBridge(),
      widgetBridge: WidgetBridge(),
      recordingBridge: createRecordingBridge(),
    )..bootstrap();
    _controller.addListener(_handleControllerChanged);
    _appLaunchSubscription = _appLaunchBridge.launchRequests.listen(
      _handleAppLaunchRequest,
    );
    _widgetOpenSubscription = _controller.widgetOpenRequests.listen(
      _controller.openWidgetSurface,
    );
    if (_supportsDesktopShell) {
      unawaited(_initializeDesktopShell());
    }
  }

  @override
  void dispose() {
    _appLaunchSubscription?.cancel();
    _widgetOpenSubscription?.cancel();
    _controller.removeListener(_handleControllerChanged);
    if (_supportsDesktopShell) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      _assistantHotKeyHoldTimer?.cancel();
      if (_assistantHotKey != null) {
        unawaited(hotKeyManager.unregister(_assistantHotKey!));
      }
      unawaited(trayManager.destroy());
    }
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!_supportsDesktopShell) {
      return;
    }
    unawaited(_syncDesktopShell());
  }

  void _handleAppLaunchRequest(String action) {
    if (action == AppLaunchBridge.voiceAssistantAction) {
      _controller.openVoiceAssistantSurface();
    }
  }

  Future<void> _initializeDesktopShell() async {
    if (_desktopShellInitialized) {
      return;
    }
    var windowListenerAdded = false;
    var trayListenerAdded = false;
    try {
      windowManager.addListener(this);
      windowListenerAdded = true;
      trayManager.addListener(this);
      trayListenerAdded = true;
      await windowManager.setPreventClose(true);
      await windowManager.setTitle('NeoAgent');
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await windowManager.setIcon(_desktopWindowIconAsset);
      }
      await trayManager.setIcon(
        _desktopTrayIconAsset,
        isTemplate: defaultTargetPlatform == TargetPlatform.macOS,
      );
      await trayManager.setToolTip('NeoAgent');
      await _syncTrayMenu();
      await _syncAssistantHotkey();
      _desktopShellInitialized = true;
    } catch (error, stackTrace) {
      _desktopShellInitialized = false;
      if (trayListenerAdded) {
        trayManager.removeListener(this);
      }
      if (windowListenerAdded) {
        windowManager.removeListener(this);
      }
      AppDiagnostics.log(
        'desktop.shell',
        'initialize.failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _syncDesktopShell() async {
    if (!_desktopShellInitialized) {
      return;
    }
    await _syncTrayMenu();
    await _syncAssistantHotkey();
    await _syncDesktopPresentation();
  }

  Future<void> _syncDesktopPresentation() async {
    if (_syncingDesktopPresentation) {
      return;
    }
    _syncingDesktopPresentation = true;
    try {
      final runtime = _controller.recordingRuntime;
      if (_desktopAssistantPopupWindowMode) {
        return;
      }
      final isWindowVisible = await windowManager.isVisible();
      if (_desktopToolbarWindowMode &&
          (!runtime.active || !runtime.floatingToolbarVisible)) {
        await _restoreMainWindowPresentation(
          hideAfterRestore: _desktopToolbarReturnToHidden,
          focusWindow: false,
        );
        _desktopToolbarReturnToHidden = false;
        return;
      }
      if (!_desktopToolbarWindowMode &&
          runtime.active &&
          runtime.supportsFloatingToolbar &&
          runtime.floatingToolbarVisible &&
          (_controller.desktopFloatingToolbarPopupRequested ||
              !isWindowVisible)) {
        await _showDetachedToolbarWindow(
          focusWindow:
              _controller.desktopFloatingToolbarPopupRequested ||
              isWindowVisible,
        );
        _controller.acknowledgeDesktopFloatingToolbarPopupRequest();
      }
    } finally {
      _syncingDesktopPresentation = false;
    }
  }

  Future<void> _syncTrayMenu() async {
    final runtime = _controller.recordingRuntime;
    final isRecordingActive = runtime.active;
    final pauseLabel = runtime.paused ? 'Resume' : 'Pause';
    final toolbarLabel = runtime.floatingToolbarVisible
        ? 'Hide floating bar'
        : 'Show floating bar';
    _trayMenu = Menu(
      items: <MenuItem>[
        MenuItem(key: 'open', label: 'Open'),
        MenuItem(
          key: 'start_recording',
          label: 'Start recording',
          disabled: isRecordingActive || !_controller.canStartDesktopRecording,
        ),
        MenuItem(
          key: 'pause_resume_recording',
          label: pauseLabel,
          disabled: !isRecordingActive,
        ),
        MenuItem(
          key: 'stop_recording',
          label: 'Stop',
          disabled: !isRecordingActive,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_toolbar',
          label: toolbarLabel,
          disabled:
              !_controller.recordingRuntime.supportsFloatingToolbar ||
              !isRecordingActive,
        ),
        MenuItem(key: 'open_voice_assistant', label: 'Open voice assistant'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ],
    );
    await trayManager.setContextMenu(_trayMenu!);
  }

  Future<void> _syncAssistantHotkey() async {
    final shouldRegister =
        _controller.desktopAssistantHotkeyEnabled &&
        _controller.recordingRuntime.supportsGlobalHotkeys;
    if (!shouldRegister) {
      if (_assistantHotKey != null) {
        await hotKeyManager.unregister(_assistantHotKey!);
        _assistantHotKey = null;
      }
      return;
    }

    final hotKey = HotKey(
      key: LogicalKeyboardKey.space,
      modifiers: const <HotKeyModifier>[
        HotKeyModifier.control,
        HotKeyModifier.shift,
      ],
      scope: HotKeyScope.system,
    );
    if (_assistantHotKey != null && _hotKeysMatch(_assistantHotKey!, hotKey)) {
      return;
    }
    if (_assistantHotKey != null) {
      await hotKeyManager.unregister(_assistantHotKey!);
    }
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: _handleAssistantHotKeyDown,
      keyUpHandler: _handleAssistantHotKeyUp,
    );
    _assistantHotKey = hotKey;
  }

  Future<void> _handleAssistantHotKeyDown(HotKey hotKey) async {
    if (_assistantHotKeyPressed) {
      return;
    }
    _assistantHotKeyPressed = true;
    _assistantHotKeyHandledAsHold = false;
    _assistantPttActive = false;
    _desktopAssistantBlockedHintVisible = false;
    _assistantHotKeyHoldTimer?.cancel();
    _assistantHotKeyHoldTimer = Timer(
      _desktopAssistantHoldThreshold,
      () => unawaited(_activateAssistantPushToTalkMode()),
    );
  }

  Future<void> _handleAssistantHotKeyUp(HotKey hotKey) async {
    _assistantHotKeyPressed = false;
    _assistantHotKeyHoldTimer?.cancel();
    if (_assistantHotKeyHandledAsHold) {
      _assistantHotKeyHandledAsHold = false;
      _desktopAssistantBlockedHintVisible = false;
      if (_assistantPttActive ||
          _controller.isLiveVoiceCaptureStarting ||
          _controller.isLiveVoiceCaptureActive) {
        _assistantPttActive = false;
        try {
          await _controller.stopLiveVoiceCapture();
        } catch (_) {}
      }
      await _hideAssistantPopupWindow();
      return;
    }
    if (_desktopAssistantPopupWindowMode) {
      await _hideAssistantPopupWindow();
      return;
    }
    await _showAssistantPopupWindow();
  }

  Future<void> _activateAssistantPushToTalkMode() async {
    if (!_assistantHotKeyPressed) {
      return;
    }
    _desktopAssistantBlockedHintVisible = false;
    _assistantHotKeyHandledAsHold = true;
    if (_controller.recordingRuntime.active) {
      await _showAssistantBlockedHint();
      return;
    }
    try {
      await _showAssistantPopupWindow();
      await _controller.startLiveVoiceCapture();
      _assistantPttActive = true;
    } catch (error, stackTrace) {
      _assistantPttActive = false;
      AppDiagnostics.log(
        'desktop.assistant',
        'ptt.start_failed',
        error: error,
        stackTrace: stackTrace,
      );
      await _hideAssistantPopupWindow();
    }
  }

  Future<void> _showAssistantBlockedHint() async {
    _desktopAssistantBlockedHintVisible = true;
    await _showAssistantPopupWindow();
    if (mounted) {
      setState(() {});
    }
    await Future<void>.delayed(_desktopAssistantBlockedHintDuration);
    if (_desktopAssistantBlockedHintVisible) {
      _desktopAssistantBlockedHintVisible = false;
      await _hideAssistantPopupWindow();
    }
  }

  bool _hotKeysMatch(HotKey first, HotKey second) {
    final firstModifiers = Set<HotKeyModifier>.from(
      first.modifiers ?? const <HotKeyModifier>[],
    );
    final secondModifiers = Set<HotKeyModifier>.from(
      second.modifiers ?? const <HotKeyModifier>[],
    );
    return first.scope == second.scope &&
        first.key == second.key &&
        firstModifiers.length == secondModifiers.length &&
        firstModifiers.containsAll(secondModifiers);
  }

  Future<void> _openMainWindow() async {
    if (_desktopToolbarWindowMode || _desktopAssistantPopupWindowMode) {
      await _restoreMainWindowPresentation();
    }
    _controller.acknowledgeDesktopFloatingToolbarPopupRequest();
    _desktopToolbarReturnToHidden = false;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _hideMainWindow() async {
    final runtime = _controller.recordingRuntime;
    if (_desktopAssistantPopupWindowMode) {
      await _restoreMainWindowPresentation(
        hideAfterRestore: true,
        focusWindow: false,
      );
      return;
    }
    if (runtime.active &&
        runtime.supportsFloatingToolbar &&
        runtime.floatingToolbarVisible) {
      await _showDetachedToolbarWindow(focusWindow: false);
      return;
    }
    if (_desktopToolbarWindowMode) {
      await _restoreMainWindowPresentation(
        hideAfterRestore: true,
        focusWindow: false,
      );
      return;
    }
    await windowManager.hide();
  }

  Future<void> _showDetachedToolbarWindow({required bool focusWindow}) async {
    final runtime = _controller.recordingRuntime;
    if (!runtime.active || !runtime.supportsFloatingToolbar) {
      return;
    }
    final isVisible = await windowManager.isVisible();
    _desktopToolbarReturnToHidden =
        !isVisible &&
        !_desktopToolbarWindowMode &&
        !_desktopAssistantPopupWindowMode;
    if (!_desktopToolbarWindowMode && !_desktopAssistantPopupWindowMode) {
      _desktopNormalWindowBounds = await windowManager.getBounds();
    }
    if (mounted &&
        (!_desktopToolbarWindowMode || _desktopAssistantPopupWindowMode)) {
      setState(() {
        _desktopToolbarWindowMode = true;
        _desktopAssistantPopupWindowMode = false;
      });
    }
    await windowManager.setTitle('NeoAgent');
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      await windowManager.setHasShadow(false);
    }
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setSize(_desktopToolbarWindowSize);
    await windowManager.center();
    await windowManager.show(inactive: !focusWindow);
    if (focusWindow) {
      await windowManager.focus();
    }
  }

  Future<void> _restoreMainWindowPresentation({
    bool hideAfterRestore = false,
    bool focusWindow = true,
  }) async {
    if (mounted &&
        (_desktopToolbarWindowMode || _desktopAssistantPopupWindowMode)) {
      setState(() {
        _desktopToolbarWindowMode = false;
        _desktopAssistantPopupWindowMode = false;
      });
    }
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      await windowManager.setHasShadow(true);
    }
    await windowManager.setSkipTaskbar(false);
    await windowManager.setTitle('NeoAgent');
    final restoreBounds = _desktopNormalWindowBounds;
    if (restoreBounds != null) {
      await windowManager.setBounds(restoreBounds);
    } else {
      await windowManager.setSize(const Size(1280, 720));
      await windowManager.center();
    }
    if (hideAfterRestore) {
      await windowManager.hide();
      return;
    }
    await windowManager.show();
    if (focusWindow) {
      await windowManager.focus();
    }
  }

  Future<void> _showAssistantPopupWindow() async {
    final isVisible = await windowManager.isVisible();
    _desktopAssistantReturnToHidden = !isVisible;
    if (!_desktopToolbarWindowMode && !_desktopAssistantPopupWindowMode) {
      _desktopNormalWindowBounds = await windowManager.getBounds();
    }
    if (mounted &&
        (!_desktopAssistantPopupWindowMode || _desktopToolbarWindowMode)) {
      setState(() {
        _desktopToolbarWindowMode = false;
        _desktopAssistantPopupWindowMode = true;
      });
    }
    await windowManager.setTitle('NeoAgent Assistant');
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      await windowManager.setHasShadow(false);
    }
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setSize(_desktopAssistantPopupWindowSize);
    await windowManager.setAlignment(const Alignment(0, 0.92));
    await windowManager.show(inactive: false);
    await windowManager.focus();
  }

  Future<void> _hideAssistantPopupWindow() async {
    if (!_desktopAssistantPopupWindowMode) {
      return;
    }
    _desktopAssistantBlockedHintVisible = false;
    final shouldHideWindow = _desktopAssistantReturnToHidden;
    _desktopAssistantReturnToHidden = false;
    await _restoreMainWindowPresentation(
      hideAfterRestore: shouldHideWindow,
      focusWindow: !shouldHideWindow,
    );
  }

  Future<void> _cancelAssistantPopupFromUi() async {
    _assistantHotKeyPressed = false;
    _assistantHotKeyHandledAsHold = false;
    _assistantPttActive = false;
    _assistantHotKeyHoldTimer?.cancel();
    if (_controller.isLiveVoiceCaptureActive ||
        _controller.isLiveVoiceCaptureStarting) {
      try {
        await _controller.stopLiveVoiceCapture();
      } catch (_) {}
    }
    await _hideAssistantPopupWindow();
  }

  Future<void> _toggleAssistantPopupCaptureFromUi() async {
    if (_desktopAssistantBlockedHintVisible) {
      return;
    }
    try {
      _assistantPttActive = !_controller.isLiveVoiceCaptureEngaged;
      await _controller.toggleLiveVoiceCapture();
    } catch (error, stackTrace) {
      _assistantPttActive = false;
      AppDiagnostics.log(
        'desktop.assistant',
        'popup.start_failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (!_controller.isLiveVoiceCaptureActive &&
          !_controller.isLiveVoiceCaptureStarting) {
        _assistantPttActive = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final rootStateSignature =
            'boot:${_controller.isBooting}'
            '|backend:${_controller.requiresBackendUrlSetup}'
            '|auth:${_controller.isAuthenticated}'
            '|refresh:${_controller.isRefreshing}'
            '|section:${_controller.selectedSection.name}'
            '|toolbarMode:$_desktopToolbarWindowMode'
            '|assistantPopupMode:$_desktopAssistantPopupWindowMode'
            '|assistantPttActive:${_controller.isLiveVoiceCaptureActive}'
            '|assistantPttStarting:${_controller.isLiveVoiceCaptureStarting}'
            '|assistantBlockedHint:$_desktopAssistantBlockedHintVisible';
        if (_navigatorScopeSignature != rootStateSignature) {
          _navigatorScopeSignature = rootStateSignature;
          _navigatorKey = GlobalKey<NavigatorState>();
        }
        return MaterialApp(
          key: ValueKey<String>(rootStateSignature),
          navigatorKey: _navigatorKey,
          title: widget.mode == NeoAgentAppMode.launcher
              ? 'NeoAgent Launcher'
              : 'NeoAgent',
          debugShowCheckedModeBanner: false,
          theme: _buildNeoAgentTheme(_lightPalette, Brightness.light),
          darkTheme: _buildNeoAgentTheme(_darkPalette, Brightness.dark),
          themeMode: ThemeMode.system,
          builder: (context, child) {
            return Stack(
              children: <Widget>[
                if (child != null) child,
                if (!_desktopToolbarWindowMode &&
                    !_desktopAssistantPopupWindowMode &&
                    _controller.showOfflineBanner)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: _GlobalNetworkBanner(
                              controller: _controller,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_supportsDesktopShell &&
                    !_desktopToolbarWindowMode &&
                    !_desktopAssistantPopupWindowMode)
                  _DesktopFloatingToolbar(controller: _controller),
              ],
            );
          },
          home: _desktopAssistantPopupWindowMode
              ? _DesktopAssistantPopupShell(
                  controller: _controller,
                  blockedHintVisible: _desktopAssistantBlockedHintVisible,
                  onPrimaryAction: _toggleAssistantPopupCaptureFromUi,
                  onCancel: _cancelAssistantPopupFromUi,
                )
              : (_desktopToolbarWindowMode
                    ? _DetachedDesktopFloatingToolbarShell(
                        controller: _controller,
                        onOpenMainWindow: _openMainWindow,
                      )
                    : NeoAgentRoot(controller: _controller)),
        );
      },
    );
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key == null) {
      return;
    }
    switch (key) {
      case 'open':
        unawaited(_openMainWindow());
        break;
      case 'start_recording':
        if (_controller.canStartDesktopRecording) {
          unawaited(_controller.startDesktopRecording());
        }
        break;
      case 'pause_resume_recording':
        if (_controller.recordingRuntime.paused) {
          unawaited(_controller.resumeDesktopRecording());
        } else {
          unawaited(_controller.pauseDesktopRecording());
        }
        break;
      case 'stop_recording':
        unawaited(_controller.stopRecording());
        break;
      case 'toggle_toolbar':
        if (_controller.recordingRuntime.floatingToolbarVisible) {
          unawaited(_controller.hideDesktopFloatingToolbar());
        } else {
          unawaited(_controller.showDesktopFloatingToolbar());
        }
        break;
      case 'open_voice_assistant':
        unawaited(_openMainWindow());
        _controller.setSelectedSection(AppSection.voiceAssistant);
        break;
      case 'quit':
        unawaited(_quitDesktopShell());
        break;
    }
  }

  @override
  void onWindowClose() {
    if (!_supportsDesktopShell || _handlingDesktopClose) {
      return;
    }
    _handlingDesktopClose = true;
    unawaited(_handleDesktopWindowClose());
  }

  Future<void> _handleDesktopWindowClose() async {
    try {
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext == null) {
        await _quitDesktopShell();
        return;
      }

      final shouldPrompt = _controller.desktopAskOnClose;
      if (!shouldPrompt) {
        if (_controller.desktopKeepRunningOnClose) {
          await _hideMainWindow();
        } else {
          await _quitDesktopShell();
        }
        return;
      }

      final decision = await showDialog<_DesktopCloseDecision>(
        context: navigatorContext,
        builder: (context) {
          var rememberChoice = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: _bgCard,
                title: Text('Keep NeoAgent running?'),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Closing the window can either keep NeoAgent running in the background with tray access, or fully quit the desktop runtime.',
                        style: TextStyle(color: _textSecondary, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: rememberChoice,
                        onChanged: (value) {
                          setDialogState(() {
                            rememberChoice = value == true;
                          });
                        },
                        title: Text('Remember this choice'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      _DesktopCloseDecision(
                        keepRunning: false,
                        rememberChoice: rememberChoice,
                      ),
                    ),
                    child: Text('Quit'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _DesktopCloseDecision(
                        keepRunning: true,
                        rememberChoice: rememberChoice,
                      ),
                    ),
                    child: Text('Keep running'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (decision == null) {
        return;
      }
      if (decision.rememberChoice) {
        await _controller.setDesktopClosePreference(
          askOnClose: false,
          keepRunningOnClose: decision.keepRunning,
        );
      }
      if (decision.keepRunning) {
        await _hideMainWindow();
      } else {
        await _quitDesktopShell();
      }
    } finally {
      _handlingDesktopClose = false;
    }
  }

  Future<void> _quitDesktopShell() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}

class NeoAgentRoot extends StatelessWidget {
  const NeoAgentRoot({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isBooting) {
      return const SplashView();
    }
    if (controller.requiresBackendUrlSetup) {
      return BackendSetupView(controller: controller);
    }
    if (!controller.isAuthenticated) {
      return AuthView(controller: controller);
    }
    if (controller.isLauncherMode) {
      return LauncherHomeView(controller: controller);
    }
    return HomeView(controller: controller);
  }
}

class NeoAgentController extends ChangeNotifier {
  NeoAgentController({
    this.appMode = NeoAgentAppMode.standard,
    required BackendClient backendClient,
    required HealthBridge healthBridge,
    required WidgetBridge widgetBridge,
    required RecordingBridge recordingBridge,
    OAuthLauncher? oauthLauncher,
  }) : _backendClient = backendClient,
       _healthBridge = healthBridge,
       _widgetBridge = widgetBridge,
       _recordingBridge = recordingBridge,
       _oauthLauncher = oauthLauncher ?? createOAuthLauncher() {
    _recordingBridge.onRecordingStopped = _handleRecordingStopped;
    _recordingBridge.addListener(_handleRecordingBridgeChanged);
    _desktopCompanion.addListener(notifyListeners);
    _clientLogs = AppDiagnostics.recentEntries
        .map(_logEntryFromDiagnostic)
        .toList(growable: false);
    _rebuildMergedLogs();
    _diagnosticLogSubscription = AppDiagnostics.stream.listen(
      _handleDiagnosticLogEntry,
    );
  }

  final NeoAgentAppMode appMode;
  final BackendClient _backendClient;
  final HealthBridge _healthBridge;
  final WidgetBridge _widgetBridge;
  final RecordingBridge _recordingBridge;
  final OAuthLauncher _oauthLauncher;
  final app_release_updater.AppReleaseUpdater _appReleaseUpdater =
      app_release_updater.AppReleaseUpdater();
  final LiveVoiceCapture _liveVoiceCapture = LiveVoiceCapture();
  final DesktopScreenCapture _desktopScreenCapture =
      createDesktopScreenCapture();
  final DesktopCompanionManager _desktopCompanion = DesktopCompanionManager(
    screenCapture: createDesktopScreenCapture(),
  );
  StreamSubscription<AppDiagnosticEntry>? _diagnosticLogSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _connectivityPluginAvailable = true;
  static const int _maxVisibleLogs = 400;

  static const String _configuredBackendUrl = String.fromEnvironment(
    'NEOAGENT_BACKEND_URL',
  );

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  io.Socket? _socket;
  Timer? _updatePollTimer;
  Timer? _qrLoginPollTimer;
  Timer? _manualRunCooldownTimer;
  final Set<String> _backgroundRunIds = <String>{};
  final Set<String> _voiceRunIds = <String>{};
  final Set<String> _busyOfficialIntegrationKeys = <String>{};
  final Map<String, DateTime> _manualRunCooldowns = <String, DateTime>{};
  static const Duration _manualRunCooldownDuration = Duration(seconds: 10);
  static const Duration _homeWidgetSyncCooldown = Duration(seconds: 5);
  DateTime? _lastHomeWidgetSyncAt;
  int _authCycle = 0;
  bool _isPollingQrLogin = false;
  List<LogEntry> _serverLogs = const <LogEntry>[];
  List<LogEntry> _clientLogs = const <LogEntry>[];

  bool isBooting = true;
  bool isAuthenticated = false;
  bool isAuthenticating = false;
  bool isAwaitingTwoFactor = false;
  bool isRefreshing = false;
  bool isRefreshingDevices = false;
  bool isSendingMessage = false;
  bool isSavingSettings = false;
  bool isSavingBackendUrl = false;
  bool isLoadingAccountSettings = false;
  bool isSavingAccountSettings = false;
  bool isConfiguringTwoFactor = false;
  bool isRevokingSession = false;
  bool isTriggeringUpdate = false;
  bool isSavingReleaseChannel = false;
  bool isSyncingHealth = false;
  bool isRunningDeviceAction = false;
  bool isPreparingQrLogin = false;
  bool isApprovingQrLogin = false;
  bool isCheckingAppUpdate = false;
  bool isOpeningAppUpdate = false;
  bool socketConnected = false;
  bool hasNetworkConnection = true;
  bool networkStatusKnown = false;
  bool _desktopFloatingToolbarPopupRequested = false;
  bool _voiceAssistantIncludeScreenContext = false;

  bool hasUser = true;
  bool registrationOpen = false;
  bool serviceEmailConfigured = false;
  String deploymentProfile = 'private';
  String backendUrl = _defaultBackendUrl;
  String username = '';
  String email = '';
  String password = '';
  String pendingTwoFactorUsername = '';
  String? errorMessage;
  String? authInfoMessage;
  String? qrLoginErrorMessage;
  String appUpdateChannel = 'stable';
  bool appUpdateAutoCheckEnabled = true;
  String? installedAppVersion;
  app_release_updater.AppReleaseInfo? availableAppUpdate;
  String? appUpdateErrorMessage;
  DateTime? appUpdateLastCheckedAt;

  AppSection selectedSection = AppSection.chat;
  Map<String, dynamic>? user;
  Map<String, dynamic> accountTwoFactor = const <String, dynamic>{};
  List<AccountSessionItem> accountSessions = const <AccountSessionItem>[];
  List<AuthProviderCatalogItem> authProviders =
      const <AuthProviderCatalogItem>[];
  List<LinkedAuthProviderItem> linkedAuthProviders =
      const <LinkedAuthProviderItem>[];
  QrLoginChallenge? qrLoginChallenge;
  Map<String, dynamic> settings = const <String, dynamic>{};
  Map<String, dynamic>? versionInfo;
  Map<String, dynamic>? backendHealthStatus;
  HealthBridgeStatus? deviceHealthStatus;
  List<RecordingSessionItem> recordingSessions = const <RecordingSessionItem>[];

  List<ChatEntry> chatMessages = const <ChatEntry>[];
  List<AgentProfile> agentProfiles = const <AgentProfile>[];
  String? selectedAgentId;
  List<ModelMeta> supportedModels = const <ModelMeta>[];
  List<AiProviderMeta> aiProviders = const <AiProviderMeta>[];
  List<RunSummary> recentRuns = const <RunSummary>[];
  TokenUsageSnapshot? tokenUsage;
  UpdateStatusSnapshot updateStatus = const UpdateStatusSnapshot();
  List<LogEntry> logs = const <LogEntry>[];
  Map<String, MessagingPlatformStatus> messagingStatuses =
      const <String, MessagingPlatformStatus>{};
  List<MessagingMessage> messagingMessages = const <MessagingMessage>[];
  Map<String, MessagingAccessCatalog> messagingAccessCatalogs =
      const <String, MessagingAccessCatalog>{};
  MessagingQrState? pendingMessagingQr;
  final List<BlockedSenderNotice> _blockedSenderQueue = <BlockedSenderNotice>[];
  List<SkillItem> skills = const <SkillItem>[];
  List<StoreSkillItem> storeSkills = const <StoreSkillItem>[];
  List<OfficialIntegrationItem> officialIntegrations =
      const <OfficialIntegrationItem>[];
  MemoryOverview memoryOverview = const MemoryOverview();
  List<MemoryItem> memories = const <MemoryItem>[];
  List<MemoryItem> memoryRecallResults = const <MemoryItem>[];
  List<ConversationItem> memoryConversations = const <ConversationItem>[];
  List<TaskItem> taskItems = const <TaskItem>[];
  List<AiWidgetItem> widgets = const <AiWidgetItem>[];
  List<McpServerItem> mcpServers = const <McpServerItem>[];
  Map<String, dynamic> browserRuntime = const <String, dynamic>{};
  Map<String, dynamic> browserExtensionStatus = const <String, dynamic>{};
  Map<String, dynamic> androidRuntime = const <String, dynamic>{};
  Map<String, dynamic> desktopRuntime = const <String, dynamic>{};
  List<String> androidInstalledApps = const <String>[];
  List<Map<String, dynamic>> androidUiPreview = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> desktopDevices = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> desktopDisplays = const <Map<String, dynamic>>[];
  Map<String, dynamic> desktopPermissions = const <String, dynamic>{};
  String? selectedDesktopDeviceId;
  String? browserScreenshotPath;
  String? androidScreenshotPath;
  String? desktopScreenshotPath;
  String? browserLastResult;
  String? androidLastResult;
  String? desktopLastResult;
  String? androidUiDumpPath;
  final Map<String, RunDetailSnapshot> _runDetailsCache =
      <String, RunDetailSnapshot>{};
  String? _selectedWidgetId;
  String? _pendingChatDraft;

  ActiveRunState? activeRun;
  List<ToolEventItem> toolEvents = const <ToolEventItem>[];
  String streamingAssistant = '';
  bool isStartingRecording = false;
  bool isStoppingRecording = false;
  bool _isStartingLiveVoice = false;
  bool _isStoppingLiveVoice = false;
  bool _liveVoiceCaptureActive = false;
  DateTime? _liveVoiceCaptureStartedAt;
  bool _pendingLiveVoiceStop = false;
  int _liveVoiceTurnCounter = 0;
  String? _liveVoiceTurnId;
  final List<LiveVoiceBufferedChunk> _liveVoiceBufferedChunks =
      <LiveVoiceBufferedChunk>[];
  int _liveVoiceAckThrough = -1;
  int _liveVoiceFinalSequence = -1;
  bool _liveVoiceCommitPending = false;
  bool _liveVoiceAwaitingResponse = false;
  Map<String, dynamic>? _liveVoicePendingCommitPayload;
  DateTime? _liveVoiceRecoverableUntil;
  Timer? _liveVoiceRecoveryTimer;
  Completer<void>? _liveVoiceSessionOpenCompleter;
  VoiceAssistantLiveState voiceAssistantLiveState = VoiceAssistantLiveState();
  bool _desktopAskOnClose = true;
  bool _desktopKeepRunningOnClose = true;
  bool _desktopAutoShowFloatingToolbar = true;
  bool _desktopAssistantHotkeyEnabled = true;

  bool get desktopCompanionEnabled => _desktopCompanion.enabled;
  bool get isLauncherMode => appMode == NeoAgentAppMode.launcher;
  bool get desktopCompanionConnected => _desktopCompanion.connected;
  bool get desktopCompanionConnecting => _desktopCompanion.connecting;
  bool get desktopCompanionPaused => _desktopCompanion.paused;
  String get desktopCompanionLabel => _desktopCompanion.label;
  String? get desktopCompanionErrorMessage => _desktopCompanion.errorMessage;
  Map<String, Object?> get desktopCompanionStatus => _desktopCompanion.status;

  bool get hasLiveRun => isSendingMessage && activeRun != null;

  bool isOfficialIntegrationBusy(String key) =>
      _busyOfficialIntegrationKeys.contains(key);

  String get chatComposerHint => hasLiveRun
      ? 'Send a steering update or next-up note for the current run...'
      : 'Ask a question or start a task...';

  AgentProfile? get activeAgent {
    for (final agent in agentProfiles) {
      if (agent.id == selectedAgentId) {
        return agent;
      }
    }
    return agentProfiles.isEmpty ? null : agentProfiles.first;
  }

  String get activeAgentLabel => activeAgent?.displayName ?? 'Main';

  String? get _scopedAgentId => selectedAgentId;

  bool get requiresBackendUrlSetup =>
      !kIsWeb &&
      _configuredBackendUrl.trim().isEmpty &&
      backendUrl.trim().isEmpty;

  String agentLabelFor(String? id) {
    if (id == null || id.isEmpty) return 'Main';
    for (final agent in agentProfiles) {
      if (agent.id == id) return agent.displayName;
    }
    return 'Unknown agent';
  }

  String get chatStatusLabel {
    if (activeRun == null) {
      return 'Idle';
    }

    final base =
        '${activeRun!.phase} (${toolEvents.where((event) => event.status == 'running').length} active tools)';
    if (activeRun!.pendingSteeringCount > 0) {
      return '$base · ${activeRun!.pendingSteeringCount} steering queued';
    }
    if (hasLiveRun) {
      return '$base · new messages steer this run';
    }
    return base;
  }

  static String get _defaultBackendUrl {
    final configured = _configuredBackendUrl.trim();

    if (kIsWeb) {
      if (configured.isEmpty) {
        return '';
      }

      final configuredUri = Uri.tryParse(configured);
      final currentHost = Uri.base.host;
      final currentIsLoopback = _isLoopbackHost(currentHost);
      final configuredHost = configuredUri?.host ?? '';

      // If a web bundle was accidentally built against localhost and is later
      // served from a real host, prefer same-origin instead of bricking prod.
      if (!currentIsLoopback && _isLoopbackHost(configuredHost)) {
        return '';
      }

      return configured;
    }

    if (configured.isNotEmpty) {
      return configured;
    }

    return '';
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized == '[::1]';
  }

  @override
  void dispose() {
    _updatePollTimer?.cancel();
    _qrLoginPollTimer?.cancel();
    _manualRunCooldownTimer?.cancel();
    _liveVoiceRecoveryTimer?.cancel();
    _socket?.dispose();
    _diagnosticLogSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _appReleaseUpdater.dispose();
    _desktopCompanion.removeListener(notifyListeners);
    unawaited(_desktopCompanion.disconnect());
    _recordingBridge.removeListener(_handleRecordingBridgeChanged);
    _recordingBridge.dispose();
    unawaited(_liveVoiceCapture.dispose());
    _oauthLauncher.dispose();
    super.dispose();
  }

  RecordingRuntimeStatus get recordingRuntime => _recordingBridge.status;

  bool get desktopAskOnClose => _desktopAskOnClose;

  bool get desktopKeepRunningOnClose => _desktopKeepRunningOnClose;

  bool get desktopAutoShowFloatingToolbar => _desktopAutoShowFloatingToolbar;

  bool get desktopAssistantHotkeyEnabled => _desktopAssistantHotkeyEnabled;

  String? get sessionCookie => _backendClient.sessionCookie;

  bool get desktopFloatingToolbarPopupRequested =>
      _desktopFloatingToolbarPopupRequested;

  bool get voiceAssistantIncludeScreenContext =>
      _voiceAssistantIncludeScreenContext;

  bool get canCaptureVoiceAssistantScreenContext =>
      _desktopScreenCapture.isSupported;

  bool get isLiveVoiceCaptureEngaged =>
      _isStartingLiveVoice || _liveVoiceCaptureActive;

  bool get appUpdaterConfigured =>
      !kIsWeb && app_release_updater.appUpdaterConfigured;

  bool get appUpdateAvailable => availableAppUpdate != null;

  bool get showOfflineBanner => networkStatusKnown && !hasNetworkConnection;

  String get offlineBannerMessage => isAuthenticated
      ? 'No network connection. NeoAgent will reconnect when the device is back online.'
      : 'No network connection. Connect to keep using NeoAgent.';

  String get appUpdateChannelLabel =>
      appUpdateChannel == 'beta' ? 'Beta' : 'Stable';

  String get appUpdateLastCheckedLabel {
    final checkedAt = appUpdateLastCheckedAt;
    if (checkedAt == null) {
      return 'Not checked yet';
    }
    final local = checkedAt.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:$minute';
  }

  bool get canStartDesktopRecording =>
      _supportsDesktopShell &&
      isAuthenticated &&
      !isBooting &&
      !requiresBackendUrlSetup &&
      backendUrl.trim().isNotEmpty &&
      !isStartingRecording &&
      !isLiveVoiceCaptureActive &&
      !isLiveVoiceCaptureStarting &&
      !recordingRuntime.active &&
      recordingRuntime.supportsSystemAudio;

  Map<String, Object?> _recordingRuntimeSnapshot() {
    final runtime = recordingRuntime;
    return <String, Object?>{
      'runtimeActive': runtime.active,
      'runtimePaused': runtime.paused,
      'runtimeSessionId': runtime.sessionId,
      'runtimeStartedAt': runtime.startedAt?.toIso8601String(),
      'runtimeError': runtime.errorMessage,
      'runtimeSupportsSystemAudio': runtime.supportsSystemAudio,
      'runtimeFloatingToolbarVisible': runtime.floatingToolbarVisible,
      'sessionsLoaded': recordingSessions.length,
    };
  }

  void _upsertRecordingSession(RecordingSessionItem session) {
    final existingIndex = recordingSessions.indexWhere(
      (item) => item.id == session.id,
    );
    if (existingIndex >= 0) {
      recordingSessions = <RecordingSessionItem>[
        ...recordingSessions.sublist(0, existingIndex),
        session,
        ...recordingSessions.sublist(existingIndex + 1),
      ];
      return;
    }
    recordingSessions = <RecordingSessionItem>[session, ...recordingSessions];
  }

  void _removeRecordingSession(String sessionId) {
    recordingSessions = recordingSessions
        .where((item) => item.id != sessionId)
        .toList();
  }

  void _appendChatMessage(
    String content, {
    required String role,
    required String platform,
    bool transient = false,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final previous = chatMessages.isNotEmpty ? chatMessages.last : null;
    if (previous != null &&
        previous.role == role &&
        previous.platform == platform &&
        previous.content.trim() == trimmed) {
      return;
    }

    chatMessages = <ChatEntry>[
      ...chatMessages,
      ChatEntry(
        id: '',
        role: role,
        content: trimmed,
        platform: platform,
        createdAt: DateTime.now(),
        transient: transient,
      ),
    ];
  }

  String _settingString(String key, String fallback, {bool lowercase = false}) {
    final value = settings[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      return fallback;
    }
    return lowercase ? value.toLowerCase() : value;
  }

  Future<void> _finalizeRecordingSessionQuietly(String? sessionId) async {
    final trimmed = sessionId?.trim() ?? '';
    if (trimmed.isEmpty) {
      return;
    }
    try {
      await _backendClient.finalizeRecordingSession(
        backendUrl,
        trimmed,
        stopReason: 'cancelled',
      );
    } catch (_) {}
  }

  Future<void> _startRecordingCapture({
    required String logKey,
    required Map<String, dynamic> payload,
    required Future<void> Function(String sessionId) startCapture,
  }) async {
    if (isStartingRecording || recordingRuntime.active) {
      return;
    }
    isStartingRecording = true;
    errorMessage = null;
    notifyListeners();

    String? sessionId;
    try {
      _logRecording('$logKey.request');
      final response = await _backendClient.createRecordingSession(
        backendUrl,
        payload,
      );
      final session = RecordingSessionItem.fromJson(
        _jsonMap(response['session']),
      );
      sessionId = session.id;
      _upsertRecordingSession(session);
      await startCapture(session.id);
      _logRecording(
        '$logKey.done',
        data: <String, Object?>{'sessionId': session.id},
      );
      notifyListeners();
    } catch (error) {
      _logRecording(
        '$logKey.failed',
        data: <String, Object?>{'sessionId': sessionId},
        error: error,
      );
      await _finalizeRecordingSessionQuietly(sessionId);
      errorMessage = _friendlyErrorMessage(error);
      await refreshRecordings();
    } finally {
      isStartingRecording = false;
      notifyListeners();
    }
  }

  void _logRecording(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppDiagnostics.log(
      'recording.controller',
      event,
      data: <String, Object?>{..._recordingRuntimeSnapshot(), ...data},
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logRecordingConsistency(String reason) {
    final activeSessionId = recordingRuntime.sessionId;
    RecordingSessionItem? activeSession;
    if (activeSessionId != null) {
      for (final session in recordingSessions) {
        if (session.id == activeSessionId) {
          activeSession = session;
          break;
        }
      }
    }

    final serverRecordingCount = recordingSessions
        .where((session) => session.status == 'recording')
        .length;

    _logRecording(
      'consistency.snapshot',
      data: <String, Object?>{
        'reason': reason,
        'activeSessionId': activeSessionId,
        'activeSessionStatus': activeSession?.status,
        'serverRecordingCount': serverRecordingCount,
      },
    );

    if (!recordingRuntime.active &&
        activeSession != null &&
        activeSession.status == 'recording') {
      _logRecording(
        'consistency.mismatch_runtime_inactive_server_recording',
        data: <String, Object?>{
          'reason': reason,
          'sessionId': activeSession.id,
        },
      );
    }

    if (recordingRuntime.active &&
        activeSession != null &&
        activeSession.status != 'recording') {
      _logRecording(
        'consistency.mismatch_runtime_active_server_not_recording',
        data: <String, Object?>{
          'reason': reason,
          'sessionId': activeSession.id,
          'serverStatus': activeSession.status,
        },
      );
    }
  }

  BlockedSenderNotice? get pendingBlockedSenderNotice =>
      _blockedSenderQueue.isEmpty ? null : _blockedSenderQueue.first;

  void _handleRecordingBridgeChanged() {
    _logRecording('bridge.changed');
    notifyListeners();
  }

  static LogEntry _logEntryFromDiagnostic(AppDiagnosticEntry entry) {
    final buffer = StringBuffer('[${entry.area}] ${entry.event}');
    if (entry.data.isNotEmpty) {
      buffer.write(' ${jsonEncode(entry.data)}');
    }
    if (entry.error != null && entry.error!.trim().isNotEmpty) {
      buffer.write('\nerror: ${entry.error}');
    }
    if (entry.stackTrace != null && entry.stackTrace!.trim().isNotEmpty) {
      buffer.write('\n${entry.stackTrace}');
    }
    return LogEntry(
      type: entry.error == null ? 'info' : 'error',
      message: buffer.toString(),
      timestamp: entry.timestamp,
      source: 'flutter',
    );
  }

  void _handleDiagnosticLogEntry(AppDiagnosticEntry entry) {
    final next = <LogEntry>[..._clientLogs, _logEntryFromDiagnostic(entry)];
    _clientLogs = next.length > _maxVisibleLogs
        ? next.sublist(next.length - _maxVisibleLogs)
        : next;
    _rebuildMergedLogs();
    notifyListeners();
  }

  void _setServerLogs(List<LogEntry> entries) {
    _serverLogs = entries.length > _maxVisibleLogs
        ? entries.sublist(entries.length - _maxVisibleLogs)
        : List<LogEntry>.from(entries, growable: false);
    _rebuildMergedLogs();
  }

  void _appendServerLog(LogEntry entry) {
    final next = <LogEntry>[..._serverLogs, entry];
    _serverLogs = next.length > _maxVisibleLogs
        ? next.sublist(next.length - _maxVisibleLogs)
        : next;
    _rebuildMergedLogs();
  }

  void _rebuildMergedLogs() {
    final merged = <LogEntry>[..._serverLogs, ..._clientLogs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    logs = merged.length > _maxVisibleLogs
        ? merged.sublist(merged.length - _maxVisibleLogs)
        : merged;
  }

  Future<void> _handleRecordingStopped(String sessionId) async {
    _logRecording(
      'bridge.on_recording_stopped',
      data: <String, Object?>{'sessionId': sessionId},
    );
    try {
      await _backendClient.finalizeRecordingSession(
        backendUrl,
        sessionId,
        stopReason: 'ended',
      );
      _logRecording(
        'finalize.ok',
        data: <String, Object?>{'sessionId': sessionId, 'stopReason': 'ended'},
      );
      await refreshRecordings();
    } catch (error) {
      _logRecording(
        'finalize.failed',
        data: <String, Object?>{'sessionId': sessionId, 'stopReason': 'ended'},
        error: error,
      );
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    await _desktopCompanion.bootstrap(_prefs!);
    final configured = _configuredBackendUrl.trim();
    final savedBackendUrl = _prefs?.getString('backend_url')?.trim() ?? '';
    backendUrl = configured.isNotEmpty ? _defaultBackendUrl : savedBackendUrl;
    username = _prefs?.getString('username') ?? '';
    password = '';
    _desktopAskOnClose = _prefs?.getBool('desktop.askOnClose') ?? true;
    _desktopKeepRunningOnClose =
        _prefs?.getBool('desktop.keepRunningOnClose') ?? true;
    _desktopAutoShowFloatingToolbar =
        _prefs?.getBool('desktop.autoShowFloatingToolbar') ?? true;
    _desktopAssistantHotkeyEnabled =
        _prefs?.getBool('desktop.assistantHotkeyEnabled') ?? true;
    _voiceAssistantIncludeScreenContext =
        (_prefs?.getBool('voiceAssistant.includeScreenContext') ?? false) &&
        canCaptureVoiceAssistantScreenContext;
    appUpdateChannel =
        _prefs?.getString('app.update.channel')?.trim().toLowerCase() == 'beta'
        ? 'beta'
        : 'stable';
    appUpdateAutoCheckEnabled =
        _prefs?.getBool('app.update.autoCheckEnabled') ?? true;
    installedAppVersion = await _safeLoadInstalledAppVersion();
    await refreshConnectivityStatus();
    if (_connectivityPluginAvailable && _connectivitySubscription == null) {
      try {
        _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (results) {
            _applyConnectivityResults(results);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (error is MissingPluginException) {
              _handleMissingConnectivityPlugin();
            }
          },
        );
      } on MissingPluginException {
        _handleMissingConnectivityPlugin();
      }
    }

    final savedCookieBackend =
        _prefs?.getString(_sessionCookieBackendPrefsKey)?.trim() ?? '';
    String savedCookie = '';
    try {
      savedCookie =
          (await _secureStorage.read(
            key: _sessionCookieSecureStorageKey,
          ))?.trim() ??
          '';
    } catch (_) {
      savedCookie = '';
    }
    if (savedCookie.isEmpty) {
      // Legacy fallback for older builds; migrate immediately to secure storage.
      savedCookie = _prefs?.getString(_sessionCookiePrefsKey)?.trim() ?? '';
      if (savedCookie.isNotEmpty) {
        try {
          await _secureStorage.write(
            key: _sessionCookieSecureStorageKey,
            value: savedCookie,
          );
          await _prefs?.remove(_sessionCookiePrefsKey);
        } catch (_) {}
      }
    }
    if (savedCookieBackend == backendUrl && savedCookie.isNotEmpty) {
      _backendClient.restoreSessionCookie(savedCookie);
    } else {
      _backendClient.clearSessionCookie();
    }

    await _recordingBridge.refreshStatus();
    notifyListeners();

    if (appUpdaterConfigured &&
        appUpdateAutoCheckEnabled &&
        hasNetworkConnection) {
      unawaited(checkForAppUpdates(silent: true));
    }

    if (requiresBackendUrlSetup) {
      isBooting = false;
      errorMessage = null;
      notifyListeners();
      return;
    }

    try {
      final status = await _backendClient.getAuthStatus(backendUrl);
      hasUser = status['hasUser'] != false;
      registrationOpen = status['registrationOpen'] == true;
      serviceEmailConfigured =
          (status['email'] is Map &&
          (status['email'] as Map)['configured'] == true);
      deploymentProfile = status['deploymentProfile']?.toString() ?? 'private';
      final rawAuthProviders = status['providers'];
      final authProviderRows = rawAuthProviders is List
          ? rawAuthProviders
          : rawAuthProviders is Map
          ? rawAuthProviders.values.toList(growable: false)
          : const <dynamic>[];
      authProviders = authProviderRows
          .whereType<Map<dynamic, dynamic>>()
          .map(AuthProviderCatalogItem.fromJson)
          .toList();

      if (status['authenticated'] == true &&
          status['user'] is Map<String, dynamic>) {
        user = Map<String, dynamic>.from(
          status['user'] as Map<String, dynamic>,
        );
        isAuthenticated = true;
      }
      if (isAuthenticated) {
        unawaited(refresh());
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isBooting = false;
      notifyListeners();
    }
  }

  Future<String?> _safeLoadInstalledAppVersion() async {
    try {
      return await _appReleaseUpdater.currentVersion();
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshConnectivityStatus() async {
    if (!_connectivityPluginAvailable) {
      if (!networkStatusKnown || !hasNetworkConnection) {
        networkStatusKnown = true;
        hasNetworkConnection = true;
        notifyListeners();
      }
      return;
    }
    try {
      final results = await Connectivity().checkConnectivity();
      _applyConnectivityResults(results);
    } on MissingPluginException {
      _handleMissingConnectivityPlugin();
    } catch (_) {
      if (!networkStatusKnown) {
        networkStatusKnown = true;
        hasNetworkConnection = true;
        notifyListeners();
      }
    }
  }

  void _applyConnectivityResults(List<ConnectivityResult> results) {
    final connected = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final changed = !networkStatusKnown || connected != hasNetworkConnection;
    networkStatusKnown = true;
    hasNetworkConnection = connected;
    if (connected &&
        appUpdateErrorMessage ==
            'No network connection. Reconnect to check for updates.') {
      appUpdateErrorMessage = null;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _handleMissingConnectivityPlugin() {
    _connectivityPluginAvailable = false;
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    if (!networkStatusKnown || !hasNetworkConnection) {
      networkStatusKnown = true;
      hasNetworkConnection = true;
      notifyListeners();
    }
  }

  Future<void> setAppUpdateChannel(String channel) async {
    final normalized = channel.trim().toLowerCase() == 'beta'
        ? 'beta'
        : 'stable';
    if (appUpdateChannel == normalized) {
      return;
    }
    appUpdateChannel = normalized;
    availableAppUpdate = null;
    appUpdateErrorMessage = null;
    await _prefs?.setString('app.update.channel', normalized);
    notifyListeners();
  }

  Future<void> setAppUpdateAutoCheckEnabled(bool enabled) async {
    appUpdateAutoCheckEnabled = enabled;
    await _prefs?.setBool('app.update.autoCheckEnabled', enabled);
    notifyListeners();
  }

  Future<void> checkForAppUpdates({bool silent = false}) async {
    if (isCheckingAppUpdate) {
      return;
    }
    if (!appUpdaterConfigured) {
      appUpdateErrorMessage = kIsWeb
          ? 'Client app update checks are unavailable in the web app.'
          : 'App updates are not configured for this build.';
      if (!silent) {
        notifyListeners();
      }
      return;
    }
    if (!hasNetworkConnection) {
      appUpdateErrorMessage =
          'No network connection. Reconnect to check for updates.';
      if (!silent) {
        notifyListeners();
      }
      return;
    }

    isCheckingAppUpdate = true;
    if (!silent) {
      appUpdateErrorMessage = null;
    }
    notifyListeners();

    try {
      final result = await _appReleaseUpdater.checkForUpdate(
        channel: appUpdateChannel,
        launcherMode: isLauncherMode,
      );
      installedAppVersion = result.currentVersion;
      appUpdateLastCheckedAt = DateTime.now();
      appUpdateErrorMessage = result.errorMessage;
      availableAppUpdate = result.updateAvailable ? result.release : null;
    } finally {
      isCheckingAppUpdate = false;
      notifyListeners();
    }
  }

  Future<void> openAppUpdate() async {
    final release = availableAppUpdate;
    if (release == null || isOpeningAppUpdate) {
      return;
    }
    isOpeningAppUpdate = true;
    appUpdateErrorMessage = null;
    notifyListeners();
    try {
      final result = await _appReleaseUpdater.openReleaseAsset(
        launcher: _oauthLauncher,
        release: release,
      );
      if (!result.launched) {
        appUpdateErrorMessage =
            result.error ?? 'Could not open the release asset.';
      }
    } finally {
      isOpeningAppUpdate = false;
      notifyListeners();
    }
  }

  Future<bool> saveBackendUrl(String rawValue) async {
    final normalized = _normalizeBackendUrl(rawValue);
    if (normalized.isEmpty) {
      errorMessage = 'Enter the NeoAgent backend URL.';
      notifyListeners();
      return false;
    }

    isSavingBackendUrl = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.getAuthStatus(normalized);
      await _prefs?.setString('backend_url', normalized);
      if (backendUrl != normalized) {
        _backendClient.clearSessionCookie();
        await _prefs?.remove(_sessionCookiePrefsKey);
        await _prefs?.remove(_sessionCookieBackendPrefsKey);
        try {
          await _secureStorage.delete(key: _sessionCookieSecureStorageKey);
        } catch (_) {}
      }
      backendUrl = normalized;
      isBooting = true;
      notifyListeners();
      await bootstrap();
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isSavingBackendUrl = false;
      if (requiresBackendUrlSetup) {
        isBooting = false;
      }
      notifyListeners();
    }
  }

  String _normalizeBackendUrl(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.contains('://')) {
      return trimmed.replaceFirst(RegExp(r'/$'), '');
    }

    final lower = trimmed.toLowerCase();
    final is172Private = RegExp(
      r'^172\.(1[6-9]|2[0-9]|3[0-1])\.',
    ).hasMatch(lower);
    final isLocal =
        lower.startsWith('localhost') ||
        lower.startsWith('127.0.0.1') ||
        lower.startsWith('10.') ||
        lower.startsWith('192.168.') ||
        is172Private;
    final scheme = isLocal ? 'http://' : 'https://';
    return '$scheme${trimmed.replaceFirst(RegExp(r'/$'), '')}';
  }

  Map<String, dynamic> _qrLoginClientMetadata() {
    final platformLabel = switch (true) {
      _ when kIsWeb => 'Web browser',
      _ when defaultTargetPlatform == TargetPlatform.android => 'Android app',
      _ when defaultTargetPlatform == TargetPlatform.iOS => 'iPhone app',
      _ when defaultTargetPlatform == TargetPlatform.macOS => 'macOS app',
      _ when defaultTargetPlatform == TargetPlatform.windows => 'Windows app',
      _ when defaultTargetPlatform == TargetPlatform.linux => 'Linux app',
      _ => 'NeoAgent app',
    };
    final deviceClass = switch (true) {
      _ when kIsWeb => 'desktop',
      _
          when defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS =>
        'mobile',
      _
          when defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux =>
        'desktop',
      _ => 'unknown',
    };
    return <String, dynamic>{
      'deviceLabel': platformLabel,
      'platformLabel': platformLabel,
      'browserLabel': kIsWeb ? 'Browser' : 'Flutter app',
      'deviceClass': deviceClass,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'appMode': appMode.name,
    };
  }

  void _stopQrLoginPolling() {
    _qrLoginPollTimer?.cancel();
    _qrLoginPollTimer = null;
  }

  void _clearQrLoginChallenge() {
    _stopQrLoginPolling();
    qrLoginChallenge = null;
    qrLoginErrorMessage = null;
    _isPollingQrLogin = false;
  }

  void _ensureQrLoginPolling() {
    _stopQrLoginPolling();
    final challenge = qrLoginChallenge;
    if (challenge == null || !challenge.isUsable || isAuthenticated) {
      return;
    }
    _qrLoginPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollQrLoginChallenge());
    });
  }

  Future<void> prepareQrLoginChallenge({bool force = false}) async {
    if (requiresBackendUrlSetup || isAuthenticated || isAwaitingTwoFactor) {
      _clearQrLoginChallenge();
      notifyListeners();
      return;
    }
    if (isPreparingQrLogin) return;
    if (!force && qrLoginChallenge?.isUsable == true) {
      _ensureQrLoginPolling();
      return;
    }

    isPreparingQrLogin = true;
    qrLoginErrorMessage = null;
    if (force) {
      qrLoginChallenge = null;
    }
    notifyListeners();

    try {
      final response = await _backendClient.createQrLoginChallenge(
        baseUrl: backendUrl,
        requestMetadata: _qrLoginClientMetadata(),
      );
      final challenge = QrLoginChallenge.fromJson(response);
      if (!challenge.isUsable) {
        throw Exception('QR login could not be started.');
      }
      qrLoginChallenge = challenge;
      qrLoginErrorMessage = null;
      _ensureQrLoginPolling();
    } catch (error) {
      _clearQrLoginChallenge();
      qrLoginErrorMessage = _friendlyErrorMessage(error);
    } finally {
      isPreparingQrLogin = false;
      notifyListeners();
    }
  }

  Future<void> _pollQrLoginChallenge() async {
    final challenge = qrLoginChallenge;
    if (_isPollingQrLogin || challenge == null || !challenge.isUsable) {
      return;
    }
    _isPollingQrLogin = true;
    try {
      final status = await _backendClient.getQrLoginChallengeStatus(
        baseUrl: backendUrl,
        challengeId: challenge.challengeId,
        pollToken: challenge.pollToken,
      );
      final nextStatus = status['status']?.toString() ?? 'pending';
      if (nextStatus == 'approved') {
        await _claimQrLoginChallenge(challenge);
        return;
      }
      if (nextStatus == 'expired' || nextStatus == 'claimed') {
        await prepareQrLoginChallenge(force: true);
      }
    } catch (error) {
      qrLoginErrorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    } finally {
      _isPollingQrLogin = false;
    }
  }

  Future<void> _claimQrLoginChallenge(QrLoginChallenge challenge) async {
    try {
      final response = await _backendClient.claimQrLoginChallenge(
        baseUrl: backendUrl,
        challengeId: challenge.challengeId,
        pollToken: challenge.pollToken,
      );
      _clearQrLoginChallenge();
      await _completeAuthenticatedResponse(
        response,
        retentionErrorMessage:
            'QR login completed, but NeoAgent could not keep the session. Please try again.',
      );
    } catch (error) {
      final message = _friendlyErrorMessage(error);
      qrLoginErrorMessage = message;
      if (message.toLowerCase().contains('expired') ||
          message.toLowerCase().contains('already used')) {
        await prepareQrLoginChallenge(force: true);
      } else {
        notifyListeners();
      }
    }
  }

  Future<QrLoginApprovalPreview> resolveQrLoginApproval(
    QrLoginScanPayload payload,
  ) async {
    final response = await _backendClient.resolveQrLoginChallenge(
      baseUrl: backendUrl,
      challengeId: payload.challengeId,
      secret: payload.secret,
    );
    return QrLoginApprovalPreview.fromJson(response);
  }

  Future<QrLoginApprovalPreview> approveQrLogin(
    QrLoginScanPayload payload,
  ) async {
    isApprovingQrLogin = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.approveQrLoginChallenge(
        baseUrl: backendUrl,
        challengeId: payload.challengeId,
        secret: payload.secret,
        approvalMetadata: _qrLoginClientMetadata(),
      );
      return QrLoginApprovalPreview.fromJson(response);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      isApprovingQrLogin = false;
      notifyListeners();
    }
  }

  Future<void> _completeAuthenticatedResponse(
    Map<String, dynamic> response, {
    String? fallbackUsername,
    String? retentionErrorMessage,
  }) async {
    user = Map<String, dynamic>.from(
      response['user'] as Map<dynamic, dynamic>? ??
          <String, dynamic>{
            if (fallbackUsername != null && fallbackUsername.trim().isNotEmpty)
              'username': fallbackUsername.trim(),
          },
    );
    hasUser = true;
    isAuthenticated = true;
    isAwaitingTwoFactor = false;
    pendingTwoFactorUsername = '';
    password = '';
    _clearQrLoginChallenge();
    await _persistCredentials();
    await refresh();
    if (!isAuthenticated && retentionErrorMessage != null) {
      errorMessage = retentionErrorMessage;
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    this.username = username.trim();
    this.password = password;
    await _authenticate(register: false);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    this.username = username.trim();
    this.email = email.trim();
    this.password = password;
    await _authenticate(register: true);
  }

  Future<void> authenticateWithProvider({
    required String provider,
    required bool register,
  }) async {
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    notifyListeners();

    try {
      final begin = await _backendClient.beginProviderAuth(
        baseUrl: backendUrl,
        provider: provider,
        mode: register ? 'register' : 'login',
      );
      final url = begin['url']?.toString();
      final state = begin['state']?.toString();
      if (url == null || state == null || url.isEmpty || state.isEmpty) {
        throw Exception('Provider sign-in could not be started.');
      }
      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: provider,
      );
      if (!launchResult.launched) {
        throw Exception(
          launchResult.error ?? 'Could not open the provider sign-in page.',
        );
      }
      final response = await _pollForProviderAuthCompletion(state);
      if (response['requiresTwoFactor'] == true) {
        final responseUser =
            response['user'] as Map<dynamic, dynamic>? ??
            const <dynamic, dynamic>{};
        pendingTwoFactorUsername = responseUser['username']?.toString() ?? '';
        isAwaitingTwoFactor = true;
        isAuthenticated = false;
        password = '';
        await _persistCredentials();
        return;
      }
      await _completeAuthenticatedResponse(
        response,
        retentionErrorMessage:
            'Sign-in completed, but NeoAgent could not keep the browser session. Please sign in again. If this keeps happening, check backend session cookie settings.',
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      isAuthenticated = false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> completeTwoFactorLogin({required String code}) async {
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    notifyListeners();

    try {
      final response = await _backendClient.completeTwoFactorLogin(
        baseUrl: backendUrl,
        code: code.trim(),
      );
      await _completeAuthenticatedResponse(
        response,
        fallbackUsername: pendingTwoFactorUsername,
        retentionErrorMessage:
            'Two-factor sign-in completed, but NeoAgent could not keep the browser session. Please sign in again.',
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      isAuthenticated = false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<bool> requestPasswordReset(String account) async {
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.requestPasswordReset(
        baseUrl: backendUrl,
        account: account.trim(),
      );
      authInfoMessage =
          response['message']?.toString() ??
          'If that account has a confirmed email, NeoAgent will send a password reset link.';
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  void cancelTwoFactorLogin() {
    isAwaitingTwoFactor = false;
    pendingTwoFactorUsername = '';
    password = '';
    notifyListeners();
  }

  Future<void> _authenticate({
    required bool register,
    bool silent = false,
  }) async {
    isAuthenticating = true;
    errorMessage = null;
    authInfoMessage = null;
    if (!silent) {
      notifyListeners();
    }

    try {
      final response = register
          ? await _backendClient.register(
              baseUrl: backendUrl,
              username: username,
              email: email,
              password: password,
            )
          : await _backendClient.login(
              baseUrl: backendUrl,
              username: username,
              password: password,
            );
      if (response['requiresTwoFactor'] == true) {
        pendingTwoFactorUsername = username;
        isAwaitingTwoFactor = true;
        isAuthenticated = false;
        password = '';
        await _persistCredentials();
        return;
      }
      if (response['requiresEmailConfirmation'] == true) {
        hasUser = true;
        isAuthenticated = false;
        isAwaitingTwoFactor = false;
        pendingTwoFactorUsername = '';
        password = '';
        authInfoMessage =
            response['message']?.toString() ??
            'Check your email to confirm your NeoAgent account before signing in.';
        await _persistCredentials();
        return;
      }
      await _completeAuthenticatedResponse(
        response,
        fallbackUsername: username,
        retentionErrorMessage:
            'Sign-in completed, but NeoAgent could not keep the browser session. Please sign in again. If this keeps happening, the backend session cookie is likely not being retained.',
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      isAuthenticated = false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final recordingSessionId = recordingRuntime.sessionId;
    if (recordingRuntime.active && recordingSessionId != null) {
      try {
        await _recordingBridge.stopActiveRecording();
        if (!recordingRuntime.supportsBackgroundMic) {
          await _backendClient.finalizeRecordingSession(
            backendUrl,
            recordingSessionId,
            stopReason: 'ended',
          );
        }
      } catch (_) {}
    }

    final logoutFuture = _backendClient.logout(backendUrl);
    _authCycle += 1;
    _clearAuthenticatedState();
    isAuthenticating = true;
    notifyListeners();

    try {
      await logoutFuture;
    } catch (_) {}
    await _persistCredentials();
    isAuthenticating = false;
    notifyListeners();
  }

  void _clearAuthenticatedState() {
    _disconnectSocket();
    _updatePollTimer?.cancel();
    _updatePollTimer = null;
    _clearQrLoginChallenge();
    isAuthenticated = false;
    isRefreshing = false;
    isAwaitingTwoFactor = false;
    pendingTwoFactorUsername = '';
    errorMessage = null;
    authInfoMessage = null;
    user = null;
    accountTwoFactor = const <String, dynamic>{};
    accountSessions = const <AccountSessionItem>[];
    linkedAuthProviders = const <LinkedAuthProviderItem>[];
    settings = const <String, dynamic>{};
    chatMessages = const <ChatEntry>[];
    agentProfiles = const <AgentProfile>[];
    selectedAgentId = null;
    supportedModels = const <ModelMeta>[];
    aiProviders = const <AiProviderMeta>[];
    recentRuns = const <RunSummary>[];
    tokenUsage = null;
    updateStatus = const UpdateStatusSnapshot();
    _serverLogs = const <LogEntry>[];
    _clientLogs = const <LogEntry>[];
    logs = const <LogEntry>[];
    messagingStatuses = const <String, MessagingPlatformStatus>{};
    messagingMessages = const <MessagingMessage>[];
    messagingAccessCatalogs = const <String, MessagingAccessCatalog>{};
    pendingMessagingQr = null;
    skills = const <SkillItem>[];
    storeSkills = const <StoreSkillItem>[];
    officialIntegrations = const <OfficialIntegrationItem>[];
    memoryOverview = const MemoryOverview();
    memories = const <MemoryItem>[];
    memoryRecallResults = const <MemoryItem>[];
    memoryConversations = const <ConversationItem>[];
    taskItems = const <TaskItem>[];
    widgets = const <AiWidgetItem>[];
    mcpServers = const <McpServerItem>[];
    browserRuntime = const <String, dynamic>{};
    browserExtensionStatus = const <String, dynamic>{};
    androidRuntime = const <String, dynamic>{};
    desktopRuntime = const <String, dynamic>{};
    androidInstalledApps = const <String>[];
    androidUiPreview = const <Map<String, dynamic>>[];
    desktopDevices = const <Map<String, dynamic>>[];
    desktopDisplays = const <Map<String, dynamic>>[];
    desktopPermissions = const <String, dynamic>{};
    selectedDesktopDeviceId = null;
    browserScreenshotPath = null;
    androidScreenshotPath = null;
    desktopScreenshotPath = null;
    browserLastResult = null;
    androidLastResult = null;
    desktopLastResult = null;
    androidUiDumpPath = null;
    versionInfo = null;
    backendHealthStatus = null;
    recordingSessions = const <RecordingSessionItem>[];
    activeRun = null;
    toolEvents = const <ToolEventItem>[];
    streamingAssistant = '';
    selectedSection = AppSection.chat;
    _selectedWidgetId = null;
    _pendingChatDraft = null;
    _runDetailsCache.clear();
    unawaited(
      _healthBridge.configureBackgroundSync(
        enabled: false,
        backendUrl: backendUrl,
        sessionCookie: '',
      ),
    );
    unawaited(
      _widgetBridge.configureHomeWidgets(
        enabled: false,
        backendUrl: backendUrl,
        sessionCookie: '',
      ),
    );
    unawaited(_syncDesktopCompanionSession());
  }

  Future<void> _persistCredentials() async {
    await _prefs?.setString('username', username);
    await _prefs?.remove('password');
    final sessionCookie = _backendClient.sessionCookie?.trim() ?? '';
    final shouldPersistSession = isAuthenticated && sessionCookie.isNotEmpty;
    if (shouldPersistSession) {
      try {
        await _secureStorage.write(
          key: _sessionCookieSecureStorageKey,
          value: sessionCookie,
        );
      } catch (_) {}
      await _prefs?.remove(_sessionCookiePrefsKey);
      await _prefs?.setString(_sessionCookieBackendPrefsKey, backendUrl);
      await _syncDesktopCompanionSession();
      unawaited(_syncHomeWidgetConfig());
      return;
    }
    await _prefs?.remove(_sessionCookiePrefsKey);
    await _prefs?.remove(_sessionCookieBackendPrefsKey);
    try {
      await _secureStorage.delete(key: _sessionCookieSecureStorageKey);
    } catch (_) {}
    await _syncDesktopCompanionSession();
    unawaited(_syncHomeWidgetConfig());
  }

  Future<void> _syncDesktopCompanionSession() {
    return _desktopCompanion.updateSession(
      backendUrl: backendUrl,
      sessionCookie: _backendClient.sessionCookie ?? '',
      authenticated: isAuthenticated,
    );
  }

  void setSelectedSection(AppSection section) {
    selectedSection = section;
    if (section == AppSection.devices) {
      unawaited(refreshDevices());
    }
    if (section == AppSection.accountSettings) {
      unawaited(refreshAccountSettings());
    }
    notifyListeners();
  }

  void _ensureSelectedAgent() {
    if (agentProfiles.isEmpty) {
      selectedAgentId = null;
      return;
    }
    final selectedExists = agentProfiles.any(
      (agent) => agent.id == selectedAgentId,
    );
    if (selectedExists) {
      return;
    }
    selectedAgentId = agentProfiles
        .firstWhere(
          (agent) => agent.isDefault,
          orElse: () => agentProfiles.first,
        )
        .id;
  }

  Future<void> switchAgent(String id) async {
    if (selectedAgentId == id) {
      return;
    }
    selectedAgentId = id;
    chatMessages = const <ChatEntry>[];
    recentRuns = const <RunSummary>[];
    messagingStatuses = const <String, MessagingPlatformStatus>{};
    messagingMessages = const <MessagingMessage>[];
    messagingAccessCatalogs = const <String, MessagingAccessCatalog>{};
    officialIntegrations = const <OfficialIntegrationItem>[];
    memoryOverview = const MemoryOverview();
    memories = const <MemoryItem>[];
    memoryRecallResults = const <MemoryItem>[];
    memoryConversations = const <ConversationItem>[];
    _runDetailsCache.clear();
    notifyListeners();
    await refresh();
  }

  Future<bool> saveAgentProfile({
    String? id,
    required String displayName,
    required String slug,
    String description = '',
    String responsibilities = '',
    String instructions = '',
    String status = 'active',
    bool canDelegate = false,
    bool canBeDelegatedTo = true,
    List<String> delegateTargets = const <String>[],
  }) async {
    final payload = <String, dynamic>{
      'displayName': displayName,
      'slug': slug,
      'description': description,
      'responsibilities': responsibilities,
      'instructions': instructions,
      'status': status,
      'canDelegate': canDelegate,
      'canBeDelegatedTo': canBeDelegatedTo,
      'delegateTargets': delegateTargets,
    };
    try {
      if (id == null) {
        final created = AgentProfile.fromJson(
          await _backendClient.createAgentProfile(backendUrl, payload),
        );
        selectedAgentId = created.id;
      } else {
        await _backendClient.updateAgentProfile(backendUrl, id, payload);
        selectedAgentId = id;
      }
      await refresh();
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> makeAgentDefault(String id) async {
    try {
      await _backendClient.setDefaultAgentProfile(backendUrl, id);
      selectedAgentId = id;
      await refresh();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> archiveAgent(String id) async {
    try {
      await _backendClient.archiveAgentProfile(backendUrl, id);
      if (selectedAgentId == id) {
        selectedAgentId = null;
      }
      await refresh();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  void showInlineError(String message) {
    errorMessage = message;
    authInfoMessage = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _pollForProviderAuthCompletion(
    String state,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      final response = await _backendClient.completeProviderAuth(
        baseUrl: backendUrl,
        state: state,
      );
      if (response['status']?.toString() == 'pending') {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      return response;
    }
    throw Exception(
      'Authentication is still pending. Finish the browser flow and try again.',
    );
  }

  void clearLogs() {
    _serverLogs = const <LogEntry>[];
    _clientLogs = const <LogEntry>[];
    logs = const <LogEntry>[];
    notifyListeners();
  }

  MessagingAccessCatalog currentMessagingAccessCatalog(String platform) {
    return messagingAccessCatalogs[platform] ??
        MessagingAccessCatalog.empty(platform);
  }

  MessagingAccessPolicy currentMessagingAccessPolicy(String platform) {
    return currentMessagingAccessCatalog(platform).policy;
  }

  List<MessagingAccessRule> _dedupeAccessRules(
    List<MessagingAccessRule> rules,
  ) {
    final seen = <String>{};
    final result = <MessagingAccessRule>[];
    for (final rule in rules) {
      if (rule.value.trim().isEmpty) continue;
      if (!seen.add(rule.id)) continue;
      result.add(rule);
    }
    return result;
  }

  MessagingAccessPolicy _policyWithAddedRule(
    MessagingAccessPolicy policy,
    QuickAllowSuggestion suggestion,
  ) {
    switch (suggestion.bucket) {
      case 'directRules':
        return policy.copyWith(
          directPolicy: policy.directPolicy == 'disabled'
              ? 'allowlist'
              : policy.directPolicy,
          directRules: _dedupeAccessRules(<MessagingAccessRule>[
            ...policy.directRules,
            suggestion.rule,
          ]),
        );
      case 'sharedActorRules':
        return policy.copyWith(
          sharedPolicy: policy.sharedPolicy == 'disabled'
              ? 'allowlist'
              : policy.sharedPolicy,
          sharedActorRules: _dedupeAccessRules(<MessagingAccessRule>[
            ...policy.sharedActorRules,
            suggestion.rule,
          ]),
        );
      default:
        return policy.copyWith(
          sharedPolicy: policy.sharedPolicy == 'disabled'
              ? 'allowlist'
              : policy.sharedPolicy,
          sharedSpaceRules: _dedupeAccessRules(<MessagingAccessRule>[
            ...policy.sharedSpaceRules,
            suggestion.rule,
          ]),
        );
    }
  }

  Future<MessagingAccessCatalog> loadMessagingAccessCatalog(
    String platform, {
    bool force = false,
  }) async {
    if (!force && messagingAccessCatalogs.containsKey(platform)) {
      return messagingAccessCatalogs[platform]!;
    }
    final data = await _backendClient.fetchMessagingAccessPolicy(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    final catalog = MessagingAccessCatalog.fromJson(platform, data);
    messagingAccessCatalogs = <String, MessagingAccessCatalog>{
      ...messagingAccessCatalogs,
      platform: catalog,
    };
    notifyListeners();
    return catalog;
  }

  Future<void> allowMessagingSuggestion(
    String platform,
    QuickAllowSuggestion suggestion,
  ) async {
    try {
      final nextPolicy = _policyWithAddedRule(
        currentMessagingAccessPolicy(platform),
        suggestion,
      );
      await saveMessagingAccessPolicy(platform, nextPolicy);
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  void consumeBlockedSenderNotice(String id) {
    if (_blockedSenderQueue.isNotEmpty && _blockedSenderQueue.first.id == id) {
      _blockedSenderQueue.removeAt(0);
    } else {
      _blockedSenderQueue.removeWhere((notice) => notice.id == id);
    }
    notifyListeners();
  }

  void _enqueueBlockedSenderNotice(BlockedSenderNotice notice) {
    final exists = _blockedSenderQueue.any((item) => item.id == notice.id);
    if (!exists) {
      _blockedSenderQueue.add(notice);
    }
  }

  MessagingQrState? _derivePendingMessagingQr(
    Map<String, MessagingPlatformStatus> statuses,
  ) {
    for (final entry in statuses.entries) {
      final status = entry.value;
      final qr = status.authInfo['qrCode']?.toString() ?? '';
      if (status.status == 'awaiting_qr' && qr.trim().isNotEmpty) {
        return MessagingQrState(platform: entry.key, qr: qr);
      }
    }
    return null;
  }

  Future<void> refresh() async {
    if (!isAuthenticated) {
      return;
    }

    final authCycle = _authCycle;
    isRefreshing = true;
    errorMessage = null;
    notifyListeners();

    try {
      final authStatus = await _backendClient.getAuthStatus(backendUrl);
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      if (authStatus['authenticated'] != true ||
          authStatus['user'] is! Map<String, dynamic>) {
        final hadAuthenticatedSession = isAuthenticated;
        _authCycle += 1;
        _clearAuthenticatedState();
        if (hadAuthenticatedSession) {
          errorMessage =
              'Your session expired or was not retained by the browser. Please sign in again.';
          notifyListeners();
        }
        return;
      }

      user = Map<String, dynamic>.from(
        authStatus['user'] as Map<String, dynamic>,
      );

      final profilesResponse = await _backendClient.fetchAgentProfiles(
        backendUrl,
      );
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      agentProfiles = _decodeModelList(
        'agent_profiles',
        profilesResponse['agents'],
        AgentProfile.fromJson,
        fallbackToMapValues: true,
      ).where((agent) => agent.id.isNotEmpty).toList();
      _ensureSelectedAgent();
      final agentId = _scopedAgentId;

      final historyFuture = _softRefreshLoad<Map<String, dynamic>>(
        'chat_history',
        _backendClient.fetchChatHistory(backendUrl, agentId: agentId),
        const <String, dynamic>{'messages': <dynamic>[]},
      );
      final modelsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'supported_models',
        _backendClient.fetchSupportedModels(backendUrl, agentId: agentId),
        const <String, dynamic>{'models': <dynamic>[]},
      );
      final providersFuture = _softRefreshLoad<Map<String, dynamic>>(
        'ai_providers',
        _backendClient.fetchAiProviders(backendUrl, agentId: agentId),
        const <String, dynamic>{'providers': <dynamic>[]},
      );
      final settingsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'settings',
        _backendClient.fetchSettings(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final runsFuture = _softRefreshLoad<Map<String, dynamic>>(
        'runs',
        _backendClient.fetchRuns(backendUrl, agentId: agentId),
        const <String, dynamic>{'runs': <dynamic>[]},
      );
      final versionFuture = _softRefreshLoad<Map<String, dynamic>>(
        'version',
        _backendClient.fetchVersion(backendUrl),
        const <String, dynamic>{},
      );
      final tokenFuture = _softRefreshLoad<Map<String, dynamic>>(
        'token_usage',
        _backendClient.fetchTokenUsageSummary(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final updateFuture = _backendClient
          .fetchUpdateStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final messagingFuture = _softRefreshLoad<Map<String, dynamic>>(
        'messaging_status',
        _backendClient.fetchMessagingStatus(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final messagingMessagesFuture =
          _softRefreshLoad<List<Map<String, dynamic>>>(
            'messaging_messages',
            _backendClient.fetchMessagingMessages(backendUrl, agentId: agentId),
            const <Map<String, dynamic>>[],
          );
      final skillsFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'skills',
        _backendClient.fetchSkills(backendUrl),
        const <Map<String, dynamic>>[],
      );
      final storeSkillsFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'skill_store',
        _backendClient.fetchSkillStore(backendUrl),
        const <Map<String, dynamic>>[],
      );
      final officialIntegrationsFuture =
          _softRefreshLoad<List<Map<String, dynamic>>>(
            'official_integrations',
            _backendClient.fetchOfficialIntegrations(
              backendUrl,
              agentId: agentId,
            ),
            const <Map<String, dynamic>>[],
          );
      final memoryFuture = _softRefreshLoad<Map<String, dynamic>>(
        'memory_overview',
        _backendClient.fetchMemoryOverview(backendUrl, agentId: agentId),
        const <String, dynamic>{},
      );
      final memoriesFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'memories',
        _backendClient.fetchMemories(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final conversationsFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'memory_conversations',
        _backendClient.fetchConversations(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final tasksFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'tasks',
        _backendClient.fetchTasks(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final widgetsFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'widgets',
        _backendClient.fetchWidgets(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final mcpFuture = _softRefreshLoad<List<Map<String, dynamic>>>(
        'mcp_servers',
        _backendClient.fetchMcpServers(backendUrl, agentId: agentId),
        const <Map<String, dynamic>>[],
      );
      final recordingsFuture = _backendClient
          .fetchRecordingSessions(backendUrl)
          .catchError((_) => const <Map<String, dynamic>>[]);
      final browserFuture = _backendClient
          .fetchBrowserStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final browserExtensionFuture = _backendClient
          .fetchBrowserExtensionStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final androidFuture = _backendClient
          .fetchAndroidStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});
      final desktopFuture = _backendClient
          .fetchDesktopStatus(backendUrl)
          .catchError((_) => const <String, dynamic>{});

      Map<String, dynamic>? healthResponse;
      try {
        healthResponse = await _softRefreshLoad<Map<String, dynamic>>(
          'health_status',
          _backendClient.fetchHealthStatus(backendUrl),
          const <String, dynamic>{},
        );
      } catch (_) {
        healthResponse = null;
      }
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      officialIntegrations = _decodeModelList(
        'official_integrations',
        await officialIntegrationsFuture,
        OfficialIntegrationItem.fromJson,
      );
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      final history = await historyFuture;
      final modelsResponse = await modelsFuture;
      final providersResponse = await providersFuture;
      final settingsResponse = await settingsFuture;
      final runsResponse = await runsFuture;
      final versionResponse = await versionFuture;
      final tokenResponse = await tokenFuture;
      final updateResponse = await updateFuture;
      final messagingResponse = await messagingFuture;
      final messagingMessagesResponse = await messagingMessagesFuture;
      final skillsResponse = await skillsFuture;
      final storeSkillsResponse = await storeSkillsFuture;
      final memoryResponse = await memoryFuture;
      final memoriesResponse = await memoriesFuture;
      final conversationsResponse = await conversationsFuture;
      final tasksResponse = await tasksFuture;
      final widgetsResponse = await widgetsFuture;
      final mcpResponse = await mcpFuture;
      final recordingsResponse = await recordingsFuture;
      final browserResponse = await browserFuture;
      final browserExtensionResponse = await browserExtensionFuture;
      final androidResponse = await androidFuture;
      final desktopResponse = await desktopFuture;
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }

      chatMessages = _decodeModelList(
        'chat_history',
        history['messages'],
        ChatEntry.fromJson,
        fallbackToMapValues: true,
      );

      supportedModels = _decodeModelList(
        'supported_models',
        modelsResponse['models'],
        ModelMeta.fromJson,
        fallbackToMapValues: true,
      );

      aiProviders = _decodeModelList(
        'ai_providers',
        providersResponse['providers'],
        AiProviderMeta.fromJson,
        fallbackToMapValues: true,
      );

      settings = Map<String, dynamic>.from(settingsResponse);
      recentRuns = _decodeModelList(
        'runs',
        runsResponse['runs'],
        RunSummary.fromJson,
        fallbackToMapValues: true,
      );
      versionInfo = versionResponse;
      backendHealthStatus = healthResponse;
      tokenUsage = TokenUsageSnapshot.fromJson(tokenResponse);
      updateStatus = UpdateStatusSnapshot.fromJson(updateResponse);
      messagingStatuses = messagingResponse.map(
        (key, value) => MapEntry(
          key,
          MessagingPlatformStatus.fromJson(
            key,
            value is Map
                ? Map<String, dynamic>.from(value)
                : const <String, dynamic>{},
          ),
        ),
      );
      pendingMessagingQr = _derivePendingMessagingQr(messagingStatuses);
      messagingMessages = _decodeModelList(
        'messaging_messages',
        messagingMessagesResponse,
        MessagingMessage.fromJson,
      );
      skills = _decodeModelList('skills', skillsResponse, SkillItem.fromJson);
      storeSkills = _decodeModelList(
        'skill_store',
        storeSkillsResponse,
        StoreSkillItem.fromJson,
      );
      memoryOverview = MemoryOverview.fromJson(memoryResponse);
      memories = _decodeModelList(
        'memories',
        memoriesResponse,
        MemoryItem.fromJson,
      );
      memoryConversations = _decodeModelList(
        'memory_conversations',
        conversationsResponse,
        ConversationItem.fromJson,
      );
      taskItems = _decodeModelList('tasks', tasksResponse, TaskItem.fromJson);
      widgets = _decodeModelList(
        'widgets',
        widgetsResponse,
        AiWidgetItem.fromJson,
      );
      _selectedWidgetId =
          widgets.any((widget) => widget.id == _selectedWidgetId)
          ? _selectedWidgetId
          : (widgets.isEmpty ? null : widgets.first.id);
      mcpServers = _decodeModelList(
        'mcp_servers',
        mcpResponse,
        McpServerItem.fromJson,
      );
      recordingSessions = _decodeModelList(
        'recordings',
        recordingsResponse,
        RecordingSessionItem.fromJson,
      );
      browserRuntime = Map<String, dynamic>.from(browserResponse);
      browserExtensionStatus = Map<String, dynamic>.from(
        browserExtensionResponse,
      );
      androidRuntime = Map<String, dynamic>.from(androidResponse);
      desktopRuntime = Map<String, dynamic>.from(desktopResponse);
      selectedDesktopDeviceId =
          desktopRuntime['selectedDeviceId']?.toString().trim().isEmpty ?? true
          ? null
          : desktopRuntime['selectedDeviceId']?.toString();
      desktopDevices = _jsonMapList(
        desktopRuntime['devices'],
        fallbackToMapValues: true,
      );
      await _recordingBridge.refreshStatus();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      deviceHealthStatus = await _healthBridge.getStatus();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      await _syncBackgroundHealthConfig();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      await _syncHomeWidgetConfig();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      await _syncDesktopCompanionSession();
      if (!_isCurrentAuthCycle(authCycle)) {
        return;
      }
      _ensureSocketConnected();
      _ensureUpdatePolling();
    } catch (error) {
      if (_isCurrentAuthCycle(authCycle)) {
        errorMessage = _friendlyErrorMessage(error);
      }
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  bool _isCurrentAuthCycle(int authCycle) =>
      isAuthenticated && _authCycle == authCycle;

  Future<T> _softRefreshLoad<T>(
    String label,
    Future<T> future,
    T fallback,
  ) async {
    try {
      return await future;
    } catch (error, stackTrace) {
      AppDiagnostics.log(
        'ui.refresh',
        '$label.failed',
        error: error,
        stackTrace: stackTrace,
      );
      return fallback;
    }
  }

  List<T> _decodeModelList<T>(
    String label,
    dynamic raw,
    T Function(Map<dynamic, dynamic> json) fromJson, {
    bool fallbackToMapValues = false,
  }) {
    final rows = _jsonMapList(raw, fallbackToMapValues: fallbackToMapValues);
    if (rows.isEmpty) {
      return <T>[];
    }

    final parsed = <T>[];
    for (var index = 0; index < rows.length; index += 1) {
      final row = rows[index];
      try {
        parsed.add(fromJson(row));
      } catch (error, stackTrace) {
        AppDiagnostics.log(
          'ui.refresh',
          '$label.item_parse_failed',
          data: <String, Object?>{
            'index': index,
            'keys': row.keys.take(16).join(','),
          },
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return parsed;
  }

  Future<void> refreshRunsOnly() async {
    try {
      final runsResponse = await _backendClient.fetchRuns(
        backendUrl,
        agentId: _scopedAgentId,
      );
      recentRuns = _decodeModelList(
        'runs',
        runsResponse['runs'],
        RunSummary.fromJson,
        fallbackToMapValues: true,
      );
      _runDetailsCache.clear();
      tokenUsage = TokenUsageSnapshot.fromJson(
        await _backendClient.fetchTokenUsageSummary(
          backendUrl,
          agentId: _scopedAgentId,
        ),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshMessaging() async {
    try {
      final statuses = await _backendClient.fetchMessagingStatus(
        backendUrl,
        agentId: _scopedAgentId,
      );
      messagingStatuses = statuses.map(
        (key, value) => MapEntry(
          key,
          MessagingPlatformStatus.fromJson(
            key,
            value is Map
                ? Map<String, dynamic>.from(value)
                : const <String, dynamic>{},
          ),
        ),
      );
      pendingMessagingQr = _derivePendingMessagingQr(messagingStatuses);
      messagingMessages = _decodeModelList(
        'messaging_messages',
        await _backendClient.fetchMessagingMessages(
          backendUrl,
          agentId: _scopedAgentId,
        ),
        MessagingMessage.fromJson,
      );
      final policyResponses = await Future.wait(
        messagingPlatforms.map((platform) async {
          try {
            final data = await _backendClient.fetchMessagingAccessPolicy(
              backendUrl,
              platform: platform.id,
              agentId: _scopedAgentId,
            );
            return MapEntry(
              platform.id,
              MessagingAccessCatalog.fromJson(platform.id, data),
            );
          } catch (_) {
            return MapEntry(
              platform.id,
              MessagingAccessCatalog.empty(platform.id),
            );
          }
        }),
      );
      messagingAccessCatalogs = Map<String, MessagingAccessCatalog>.fromEntries(
        policyResponses,
      );
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> refreshSkills() async {
    skills = _decodeModelList(
      'skills',
      await _backendClient.fetchSkills(backendUrl),
      SkillItem.fromJson,
    );
    storeSkills = _decodeModelList(
      'skill_store',
      await _backendClient.fetchSkillStore(backendUrl),
      StoreSkillItem.fromJson,
    );
    try {
      officialIntegrations = _decodeModelList(
        'official_integrations',
        await _backendClient.fetchOfficialIntegrations(
          backendUrl,
          agentId: _scopedAgentId,
        ),
        OfficialIntegrationItem.fromJson,
      );
    } catch (_) {
      officialIntegrations = const <OfficialIntegrationItem>[];
    }
    notifyListeners();
  }

  Future<void> refreshMemory() async {
    memoryOverview = MemoryOverview.fromJson(
      await _backendClient.fetchMemoryOverview(
        backendUrl,
        agentId: _scopedAgentId,
      ),
    );
    memories = _decodeModelList(
      'memories',
      await _backendClient.fetchMemories(backendUrl, agentId: _scopedAgentId),
      MemoryItem.fromJson,
    );
    memoryConversations = _decodeModelList(
      'memory_conversations',
      await _backendClient.fetchConversations(
        backendUrl,
        agentId: _scopedAgentId,
      ),
      ConversationItem.fromJson,
    );
    notifyListeners();
  }

  Future<void> refreshTasks() async {
    taskItems = _decodeModelList(
      'tasks',
      await _backendClient.fetchTasks(backendUrl, agentId: _scopedAgentId),
      TaskItem.fromJson,
    );
    notifyListeners();
  }

  Future<void> refreshWidgets({bool all = false}) async {
    widgets = _decodeModelList(
      'widgets',
      await _backendClient.fetchWidgets(
        backendUrl,
        agentId: all ? null : _scopedAgentId,
        all: all,
      ),
      AiWidgetItem.fromJson,
    );
    _selectedWidgetId = widgets.any((widget) => widget.id == _selectedWidgetId)
        ? _selectedWidgetId
        : (widgets.isEmpty ? null : widgets.first.id);
    if (isAuthenticated) {
      unawaited(_maybeSyncHomeWidgets());
    }
    notifyListeners();
  }

  Future<void> refreshMcp() async {
    mcpServers = _decodeModelList(
      'mcp_servers',
      await _backendClient.fetchMcpServers(backendUrl, agentId: _scopedAgentId),
      McpServerItem.fromJson,
    );
    notifyListeners();
  }

  Future<void> refreshRecordings() async {
    _logRecording('refresh.request');
    recordingSessions = _decodeModelList(
      'recordings',
      await _backendClient.fetchRecordingSessions(backendUrl),
      RecordingSessionItem.fromJson,
    );
    await _recordingBridge.refreshStatus();
    _logRecording(
      'refresh.done',
      data: <String, Object?>{
        'sessionStatuses': recordingSessions
            .take(5)
            .map((item) => '${item.id}:${item.status}')
            .join(','),
      },
    );
    _logRecordingConsistency('refreshRecordings');
    notifyListeners();
  }

  Future<void> _refreshRecordingSessionById(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty || !isAuthenticated) {
      return;
    }

    try {
      _logRecording(
        'refresh_by_id.request',
        data: <String, Object?>{'sessionId': trimmed},
      );
      final response = await _backendClient.fetchRecordingSession(
        backendUrl,
        trimmed,
      );
      final session = RecordingSessionItem.fromJson(
        _jsonMap(response['session']),
      );
      _upsertRecordingSession(session);

      await _recordingBridge.refreshStatus();
      _logRecording(
        'refresh_by_id.done',
        data: <String, Object?>{
          'sessionId': trimmed,
          'status': session.status,
          'endedAt': session.endedAt?.toIso8601String(),
        },
      );
      _logRecordingConsistency('refreshRecordingSessionById');
      notifyListeners();
    } catch (error) {
      _logRecording(
        'refresh_by_id.fallback_full_refresh',
        data: <String, Object?>{'sessionId': trimmed},
        error: error,
      );
      // Session may have been pruned or unavailable; fall back to full refresh.
      await refreshRecordings();
    }
  }

  Future<void> refreshDevices() async {
    if (!isAuthenticated || isRefreshingDevices) {
      return;
    }
    isRefreshingDevices = true;
    notifyListeners();
    try {
      final browserResponse = await _backendClient.fetchBrowserStatus(
        backendUrl,
      );
      final browserExtensionResponse = await _backendClient
          .fetchBrowserExtensionStatus(backendUrl);
      final androidResponse = await _backendClient.fetchAndroidStatus(
        backendUrl,
      );
      final desktopResponse = await _backendClient.fetchDesktopStatus(
        backendUrl,
      );
      browserRuntime = Map<String, dynamic>.from(browserResponse);
      browserExtensionStatus = Map<String, dynamic>.from(
        browserExtensionResponse,
      );
      androidRuntime = Map<String, dynamic>.from(androidResponse);
      desktopRuntime = Map<String, dynamic>.from(desktopResponse);
      selectedDesktopDeviceId =
          desktopRuntime['selectedDeviceId']?.toString().trim().isEmpty ?? true
          ? null
          : desktopRuntime['selectedDeviceId']?.toString();
      desktopDevices = _jsonMapList(
        desktopRuntime['devices'],
        fallbackToMapValues: true,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRefreshingDevices = false;
      notifyListeners();
    }
  }

  String get browserExtensionDownloadUrl =>
      '${_socketOrigin()}/api/browser-extension/download';

  Future<void> refreshBrowserExtensionStatus() async {
    try {
      final response = await _backendClient.fetchBrowserExtensionStatus(
        backendUrl,
      );
      browserExtensionStatus = Map<String, dynamic>.from(response);
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> downloadBrowserExtension() async {
    final result = await _oauthLauncher.openExternal(
      url: browserExtensionDownloadUrl,
      label: 'neoagent_browser_extension_download',
    );
    if (!result.launched) {
      errorMessage =
          result.error ?? 'Could not open browser extension download.';
      notifyListeners();
    }
  }

  Future<void> refreshAndroidApps({bool includeSystem = false}) async {
    try {
      final response = await _backendClient.fetchAndroidApps(
        backendUrl,
        includeSystem: includeSystem,
      );
      androidInstalledApps = _jsonStringList(
        response['packages'],
        nestedKeys: const <String>[
          'items',
          'data',
          'results',
          'rows',
          'values',
          'list',
          'packages',
        ],
        fallbackToMapValues: true,
      );
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> _runDeviceAction(
    Future<Map<String, dynamic>> Function() action, {
    required bool browser,
    bool refreshDevicesAfter = true,
    bool refreshAppsAfter = false,
  }) async {
    if (isRunningDeviceAction) {
      return;
    }
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await action();
      final pretty = const JsonEncoder.withIndent('  ').convert(result);
      if (browser) {
        browserLastResult = pretty;
        final screenshot = result['screenshotPath']?.toString();
        if (screenshot != null && screenshot.isNotEmpty) {
          browserScreenshotPath = screenshot;
        }
      } else {
        androidLastResult = pretty;
        final screenshot = result['screenshotPath']?.toString();
        if (screenshot != null && screenshot.isNotEmpty) {
          androidScreenshotPath = screenshot;
        }
        final dumpPath = result['uiDumpPath']?.toString();
        if (dumpPath != null && dumpPath.isNotEmpty) {
          androidUiDumpPath = dumpPath;
        }
        final preview = result['preview'];
        if (preview is List) {
          androidUiPreview = preview
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList();
        }
      }
      if (refreshDevicesAfter) {
        await refreshDevices();
      }
      if (refreshAppsAfter) {
        await refreshAndroidApps();
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> launchBrowserRuntime() async {
    await _runDeviceAction(
      () => _backendClient.launchBrowser(backendUrl),
      browser: true,
    );
  }

  Future<void> navigateBrowserRuntime({
    required String url,
    String? waitFor,
  }) async {
    await _runDeviceAction(
      () => _backendClient.navigateBrowser(
        backendUrl,
        url: url,
        waitFor: waitFor,
      ),
      browser: true,
    );
  }

  Future<void> clickBrowserRuntime({String? selector, String? text}) async {
    await _runDeviceAction(
      () => _backendClient.clickBrowser(
        backendUrl,
        selector: selector,
        text: text,
      ),
      browser: true,
    );
  }

  Future<void> clickBrowserPointRuntime({
    required int x,
    required int y,
  }) async {
    await _runDeviceAction(
      () => _backendClient.clickBrowserPoint(backendUrl, x: x, y: y),
      browser: true,
    );
  }

  Future<void> fillBrowserRuntime({
    required String selector,
    required String value,
    bool pressEnter = false,
  }) async {
    await _runDeviceAction(
      () => _backendClient.fillBrowser(
        backendUrl,
        selector: selector,
        value: value,
        pressEnter: pressEnter,
      ),
      browser: true,
    );
  }

  Future<void> typeBrowserTextRuntime(
    String text, {
    bool pressEnter = false,
  }) async {
    await _runDeviceAction(
      () => _backendClient.typeBrowserText(
        backendUrl,
        text: text,
        pressEnter: pressEnter,
      ),
      browser: true,
    );
  }

  Future<void> pressBrowserKeyRuntime(String key) async {
    await _runDeviceAction(
      () => _backendClient.pressBrowserKey(backendUrl, key: key),
      browser: true,
    );
  }

  Future<void> scrollBrowserRuntime({int deltaX = 0, int deltaY = 0}) async {
    await _runDeviceAction(
      () => _backendClient.scrollBrowser(
        backendUrl,
        deltaX: deltaX,
        deltaY: deltaY,
      ),
      browser: true,
    );
  }

  Future<void> screenshotBrowserRuntime() async {
    await _runDeviceAction(
      () => _backendClient.screenshotBrowser(backendUrl),
      browser: true,
    );
  }

  Future<void> refreshBrowserFrameRuntime() async {
    if (isRunningDeviceAction || browserRuntime['launched'] != true) {
      return;
    }
    try {
      final result = await _backendClient.screenshotBrowser(backendUrl);
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        browserScreenshotPath = screenshot;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> closeBrowserRuntime() async {
    await _runDeviceAction(
      () => _backendClient.closeBrowser(backendUrl),
      browser: true,
    );
  }

  Future<void> startAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.startAndroidEmulator(backendUrl),
      browser: false,
      refreshAppsAfter: true,
    );
  }

  Future<void> stopAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.stopAndroidEmulator(backendUrl),
      browser: false,
    );
  }

  Future<void> screenshotAndroidRuntime() async {
    await _runDeviceAction(
      () => _backendClient.screenshotAndroid(backendUrl),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> refreshAndroidFrameRuntime() async {
    if (isRunningDeviceAction) {
      return;
    }
    final devices = _jsonMapList(
      androidRuntime['devices'],
      fallbackToMapValues: true,
    );
    final online = devices.any(
      (device) => device['status']?.toString() == 'device',
    );
    if (!online) {
      return;
    }
    try {
      final result = await _backendClient.screenshotAndroid(backendUrl);
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        androidScreenshotPath = screenshot;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> dumpAndroidUiRuntime() async {
    await _runDeviceAction(
      () => _backendClient.dumpAndroidUi(backendUrl),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> openAndroidAppRuntime({
    required String packageName,
    String? activity,
  }) async {
    await _runDeviceAction(
      () => _backendClient.openAndroidApp(
        backendUrl,
        packageName: packageName,
        activity: activity,
        uiDump: false,
        includeNodes: false,
      ),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> openAndroidIntentRuntime({
    String? action,
    String? dataUri,
    String? packageName,
    String? component,
  }) async {
    await _runDeviceAction(
      () => _backendClient.openAndroidIntent(
        backendUrl,
        action: action,
        dataUri: dataUri,
        packageName: packageName,
        component: component,
        uiDump: false,
        includeNodes: false,
      ),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> tapAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.tapAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> typeAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.typeAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> swipeAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.swipeAndroid(backendUrl, <String, dynamic>{
        ...payload,
        'uiDump': false,
        'includeNodes': false,
      }),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> pressAndroidKeyRuntime(String key) async {
    await _runDeviceAction(
      () => _backendClient.pressAndroidKey(
        backendUrl,
        key: key,
        uiDump: false,
        includeNodes: false,
      ),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> waitForAndroidRuntime(Map<String, dynamic> payload) async {
    await _runDeviceAction(
      () => _backendClient.waitForAndroid(backendUrl, payload),
      browser: false,
      refreshDevicesAfter: false,
    );
  }

  Future<void> installAndroidApkRuntime({
    required String filename,
    required Uint8List bytes,
  }) async {
    await _runDeviceAction(
      () => _backendClient.installAndroidApk(
        backendUrl,
        filename: filename,
        bytes: bytes,
      ),
      browser: false,
      refreshAppsAfter: true,
    );
  }

  Future<void> _runDesktopDeviceAction(
    Future<Map<String, dynamic>> Function() action, {
    bool refreshDevicesAfter = true,
  }) async {
    if (isRunningDeviceAction) {
      return;
    }
    isRunningDeviceAction = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await action();
      desktopLastResult = const JsonEncoder.withIndent('  ').convert(result);
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        desktopScreenshotPath = screenshot;
      }
      final displays = _jsonMapList(
        result['displays'],
        fallbackToMapValues: true,
      );
      if (displays.isNotEmpty) {
        desktopDisplays = displays;
      }
      final permissions = result['permissions'];
      if (permissions is Map) {
        desktopPermissions = permissions.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      if (refreshDevicesAfter) {
        await refreshDevices();
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRunningDeviceAction = false;
      notifyListeners();
    }
  }

  Future<void> selectDesktopDeviceRuntime(String deviceId) async {
    await _runDesktopDeviceAction(
      () => _backendClient.selectDesktopDevice(backendUrl, deviceId: deviceId),
    );
    desktopScreenshotPath = null;
    await refreshDesktopFrameRuntime();
  }

  Future<void> openDesktopSelectionRuntime() async {
    await refreshDevices();
    errorMessage =
        'Select a desktop companion from the Desktop device dropdown.';
    notifyListeners();
  }

  Future<void> screenshotDesktopRuntime() async {
    await _runDesktopDeviceAction(
      () => _backendClient.screenshotDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> observeDesktopRuntime() async {
    await _runDesktopDeviceAction(
      () => _backendClient.observeDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        includeTree: true,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> refreshDesktopFrameRuntime() async {
    if (isRunningDeviceAction) {
      return;
    }
    final onlineDesktop = desktopDevices.firstWhere(
      (device) => device['online'] == true,
      orElse: () => const <String, dynamic>{},
    );
    if (onlineDesktop.isEmpty) {
      return;
    }
    final selectedId = selectedDesktopDeviceId;
    final selectedOnline = (selectedId ?? '').isNotEmpty
        ? desktopDevices.any(
            (device) =>
                device['online'] == true &&
                device['deviceId']?.toString() == selectedId,
          )
        : false;
    final targetDeviceId = selectedOnline
        ? selectedId
        : onlineDesktop['deviceId']?.toString();
    if ((targetDeviceId ?? '').isEmpty) {
      return;
    }
    try {
      final result = await _backendClient.screenshotDesktop(
        backendUrl,
        deviceId: targetDeviceId,
      );
      final screenshot = result['screenshotPath']?.toString();
      if (screenshot != null && screenshot.isNotEmpty) {
        desktopScreenshotPath = screenshot;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> clickDesktopRuntime({required int x, required int y}) async {
    await _runDesktopDeviceAction(
      () => _backendClient.clickDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        x: x,
        y: y,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> dragDesktopRuntime({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
  }) async {
    await _runDesktopDeviceAction(
      () => _backendClient.dragDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> scrollDesktopRuntime({int deltaY = 0}) async {
    await _runDesktopDeviceAction(
      () => _backendClient.scrollDesktop(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        deltaY: deltaY,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> typeDesktopRuntime(
    String text, {
    bool pressEnter = false,
  }) async {
    await _runDesktopDeviceAction(
      () => _backendClient.typeDesktopText(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        text: text,
        pressEnter: pressEnter,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> pressDesktopKeyRuntime(String key) async {
    await _runDesktopDeviceAction(
      () => _backendClient.pressDesktopKey(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        key: key,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> launchDesktopAppRuntime(String app) async {
    await _runDesktopDeviceAction(
      () => _backendClient.launchDesktopApp(
        backendUrl,
        deviceId: selectedDesktopDeviceId,
        app: app,
      ),
      refreshDevicesAfter: false,
    );
  }

  Future<void> revokeDesktopDeviceRuntime(String deviceId) async {
    await _runDesktopDeviceAction(
      () => _backendClient.revokeDesktopDevice(backendUrl, deviceId: deviceId),
    );
  }

  Future<void> pauseDesktopDeviceRuntime(
    String deviceId, {
    bool paused = true,
  }) async {
    await _runDesktopDeviceAction(
      () => _backendClient.pauseDesktopDevice(
        backendUrl,
        deviceId: deviceId,
        paused: paused,
      ),
    );
  }

  Uri resolveRuntimeAsset(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return _backendClient.resolveAssetUri(
      backendUrl,
      '$path${separator}t=${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Uri resolveRecordingSourceAudioUri(String sessionId, String sourceKey) {
    final encodedSessionId = Uri.encodeComponent(sessionId);
    final encodedSourceKey = Uri.encodeComponent(sourceKey);
    return resolveRuntimeAsset(
      '/api/recordings/$encodedSessionId/audio/$encodedSourceKey',
    );
  }

  Future<Uint8List> fetchRecordingSourceAudioBytes(
    String sessionId,
    String sourceKey,
  ) {
    final encodedSessionId = Uri.encodeComponent(sessionId);
    final encodedSourceKey = Uri.encodeComponent(sourceKey);
    return fetchRuntimeAssetBytes(
      '/api/recordings/$encodedSessionId/audio/$encodedSourceKey',
    );
  }

  Future<Uint8List> fetchRuntimeAssetBytes(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return _backendClient.fetchBinary(
      backendUrl,
      '$path${separator}t=${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Map<String, String>? get authenticatedImageHeaders {
    final cookie = _backendClient.sessionCookie;
    if (cookie == null || cookie.isEmpty) {
      return null;
    }
    return <String, String>{'Cookie': cookie};
  }

  Future<void> startWebRecording() async {
    await _startRecordingCapture(
      logKey: 'start_web',
      payload: buildWebScreenAndMicRecordingPayload(),
      startCapture: (sessionId) => _recordingBridge.startWebRecording(
        baseUrl: backendUrl,
        sessionId: sessionId,
      ),
    );
  }

  Future<void> startWebMicrophoneRecording() async {
    await _startRecordingCapture(
      logKey: 'start_web_mic_only',
      payload: buildWebMicrophoneRecordingPayload(),
      startCapture: (sessionId) => _recordingBridge.startWebMicrophoneRecording(
        baseUrl: backendUrl,
        sessionId: sessionId,
      ),
    );
  }

  Future<void> startBackgroundRecording() async {
    await _startRecordingCapture(
      logKey: 'start_background',
      payload: buildAndroidBackgroundRecordingPayload(),
      startCapture: (sessionId) => _recordingBridge.startBackgroundRecording(
        baseUrl: backendUrl,
        sessionCookie: _backendClient.sessionCookie ?? '',
        sessionId: sessionId,
      ),
    );
  }

  Future<void> startDesktopRecording() async {
    if (isLiveVoiceCaptureActive || isLiveVoiceCaptureStarting) {
      errorMessage =
          'Finish assistant push-to-talk before starting desktop recording.';
      notifyListeners();
      return;
    }
    if (!canStartDesktopRecording) {
      if (!isAuthenticated || requiresBackendUrlSetup) {
        errorMessage =
            'Sign in and finish backend setup before starting desktop recording.';
        notifyListeners();
      }
      return;
    }
    await _startRecordingCapture(
      logKey: 'start_desktop',
      payload: buildDesktopRecordingPayload(),
      startCapture: (sessionId) => _recordingBridge.startDesktopAudioRecording(
        baseUrl: backendUrl,
        sessionCookie: _backendClient.sessionCookie ?? '',
        sessionId: sessionId,
        autoShowToolbar: _desktopAutoShowFloatingToolbar,
      ),
    );
  }

  Future<void> pauseBackgroundRecording() async {
    try {
      _logRecording('pause_background.request');
      await _recordingBridge.pauseBackgroundRecording();
      _logRecording('pause_background.done');
    } catch (error) {
      _logRecording('pause_background.failed', error: error);
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> resumeBackgroundRecording() async {
    try {
      _logRecording('resume_background.request');
      await _recordingBridge.resumeBackgroundRecording();
      _logRecording('resume_background.done');
    } catch (error) {
      _logRecording('resume_background.failed', error: error);
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> pauseDesktopRecording() async {
    try {
      _logRecording('pause_desktop.request');
      await _recordingBridge.pauseDesktopRecording();
      _logRecording('pause_desktop.done');
    } catch (error) {
      _logRecording('pause_desktop.failed', error: error);
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> resumeDesktopRecording() async {
    try {
      _logRecording('resume_desktop.request');
      await _recordingBridge.resumeDesktopRecording();
      _logRecording('resume_desktop.done');
    } catch (error) {
      _logRecording('resume_desktop.failed', error: error);
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> showDesktopFloatingToolbar() async {
    try {
      _desktopFloatingToolbarPopupRequested = true;
      await _recordingBridge.showFloatingToolbar();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> hideDesktopFloatingToolbar() async {
    try {
      _desktopFloatingToolbarPopupRequested = false;
      await _recordingBridge.hideFloatingToolbar();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> openDesktopMicrophoneSettings() async {
    try {
      await _recordingBridge.openMicrophoneSettings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> openDesktopSystemAudioSettings() async {
    try {
      await _recordingBridge.openSystemAudioSettings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setDesktopClosePreference({
    required bool askOnClose,
    required bool keepRunningOnClose,
  }) async {
    _desktopAskOnClose = askOnClose;
    _desktopKeepRunningOnClose = keepRunningOnClose;
    await _prefs?.setBool('desktop.askOnClose', askOnClose);
    await _prefs?.setBool('desktop.keepRunningOnClose', keepRunningOnClose);
    notifyListeners();
  }

  Future<void> setDesktopAutoShowFloatingToolbar(bool value) async {
    _desktopAutoShowFloatingToolbar = value;
    await _prefs?.setBool('desktop.autoShowFloatingToolbar', value);
    notifyListeners();
  }

  Future<void> setDesktopAssistantHotkeyEnabled(bool value) async {
    _desktopAssistantHotkeyEnabled = value;
    await _prefs?.setBool('desktop.assistantHotkeyEnabled', value);
    notifyListeners();
  }

  Future<void> setDesktopCompanionEnabled(bool value) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _desktopCompanion.setEnabled(value, prefs);
      await _syncDesktopCompanionSession();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setDesktopCompanionLabel(String value) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _desktopCompanion.setLabel(value, prefs);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setDesktopCompanionPaused(bool value) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _desktopCompanion.setPaused(value, prefs);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> rotateDesktopCompanionIdentity() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    try {
      await _desktopCompanion.rotateIdentity(prefs);
      await _syncDesktopCompanionSession();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> refreshDesktopCompanionStatus() async {
    try {
      await _desktopCompanion.refreshLocalStatus();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> openDesktopCompanionPermissionSettings(
    String permissionKey,
  ) async {
    try {
      await _desktopCompanion.openPermissionSettings(permissionKey);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> setVoiceAssistantIncludeScreenContext(bool value) async {
    _voiceAssistantIncludeScreenContext =
        value && canCaptureVoiceAssistantScreenContext;
    await _prefs?.setBool(
      'voiceAssistant.includeScreenContext',
      _voiceAssistantIncludeScreenContext,
    );
    notifyListeners();
  }

  Future<void> toggleVoiceAssistantScreenContext() {
    return setVoiceAssistantIncludeScreenContext(
      !voiceAssistantIncludeScreenContext,
    );
  }

  void acknowledgeDesktopFloatingToolbarPopupRequest() {
    _desktopFloatingToolbarPopupRequested = false;
  }

  Future<Map<String, String>> _captureVoiceAssistantScreenshotPayload() async {
    if (!_voiceAssistantIncludeScreenContext ||
        !canCaptureVoiceAssistantScreenContext) {
      return const <String, String>{};
    }

    try {
      final capture = await _desktopScreenCapture.captureCurrentScreen();
      if (capture == null || capture.bytes.isEmpty) {
        return const <String, String>{};
      }
      final optimized = _optimizeVoiceAssistantScreenshotPayload(capture);
      if (optimized == null) {
        AppDiagnostics.log(
          'desktop.assistant',
          'screen_capture.optimize_failed',
          data: <String, Object?>{
            'mimeType': capture.mimeType,
            'originalByteLength': capture.bytes.length,
          },
        );
        return const <String, String>{};
      }
      AppDiagnostics.log(
        'desktop.assistant',
        'screen_capture.success',
        data: <String, Object?>{
          'mimeType': optimized.mimeType,
          'byteLength': optimized.bytes.length,
          'originalByteLength': capture.bytes.length,
          'resizedOrReencoded': optimized.resizedOrReencoded,
        },
      );
      return <String, String>{
        'screenshotMimeType': optimized.mimeType,
        'screenshotBase64': base64Encode(optimized.bytes),
      };
    } catch (error, stackTrace) {
      AppDiagnostics.log(
        'desktop.assistant',
        'screen_capture.failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const <String, String>{};
    }
  }

  Future<Map<String, String>> buildVoiceAssistantContextPayload() async {
    return _captureVoiceAssistantScreenshotPayload();
  }

  _OptimizedScreenshotPayload? _optimizeVoiceAssistantScreenshotPayload(
    DesktopScreenCaptureResult capture,
  ) {
    final sourceBytes = Uint8List.fromList(capture.bytes);
    final sourceMime = _normalizeScreenshotMimeType(capture.mimeType);
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      if (sourceBytes.length <= _voiceAssistantScreenshotMaxBytes) {
        return _OptimizedScreenshotPayload(
          bytes: sourceBytes,
          mimeType: sourceMime,
          resizedOrReencoded: false,
        );
      }
      return null;
    }

    var workingImage = decoded;
    var transformed = false;
    if (workingImage.width > _voiceAssistantScreenshotMaxDimension ||
        workingImage.height > _voiceAssistantScreenshotMaxDimension) {
      final scale = math.min(
        _voiceAssistantScreenshotMaxDimension / workingImage.width,
        _voiceAssistantScreenshotMaxDimension / workingImage.height,
      );
      final nextWidth = math.max(1, (workingImage.width * scale).round());
      final nextHeight = math.max(1, (workingImage.height * scale).round());
      workingImage = img.copyResize(
        workingImage,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.average,
      );
      transformed = true;
    }

    if (!transformed &&
        sourceBytes.length <= _voiceAssistantScreenshotMaxBytes) {
      return _OptimizedScreenshotPayload(
        bytes: sourceBytes,
        mimeType: sourceMime,
        resizedOrReencoded: false,
      );
    }

    final qualitySteps = <int>[84, 74, 64, 54, 46, 40];
    var bestBytes = Uint8List(0);
    for (var pass = 0; pass < qualitySteps.length; pass += 1) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(workingImage, quality: qualitySteps[pass]),
      );
      if (bestBytes.isEmpty || encoded.length < bestBytes.length) {
        bestBytes = encoded;
      }
      if (encoded.length <= _voiceAssistantScreenshotMaxBytes) {
        return _OptimizedScreenshotPayload(
          bytes: encoded,
          mimeType: 'image/jpeg',
          resizedOrReencoded: true,
        );
      }
      if (pass % 2 == 1) {
        final nextWidth = math.max(1, (workingImage.width * 0.85).round());
        final nextHeight = math.max(1, (workingImage.height * 0.85).round());
        if (nextWidth == workingImage.width &&
            nextHeight == workingImage.height) {
          continue;
        }
        workingImage = img.copyResize(
          workingImage,
          width: nextWidth,
          height: nextHeight,
          interpolation: img.Interpolation.average,
        );
      }
    }

    if (bestBytes.isNotEmpty &&
        bestBytes.length <= _voiceAssistantScreenshotMaxBytes) {
      return _OptimizedScreenshotPayload(
        bytes: bestBytes,
        mimeType: 'image/jpeg',
        resizedOrReencoded: true,
      );
    }
    return null;
  }

  String _normalizeScreenshotMimeType(String mimeType) {
    final normalized = mimeType.trim().toLowerCase();
    if (normalized.startsWith('image/')) {
      return normalized;
    }
    return 'image/png';
  }

  Future<void> stopRecording({String stopReason = 'stopped'}) async {
    final sessionId = recordingRuntime.sessionId;
    if (sessionId == null || isStoppingRecording) {
      return;
    }
    final isAndroidBackgroundStop =
        recordingRuntime.supportsBackgroundMic &&
        !recordingRuntime.supportsScreenAndMic;
    isStoppingRecording = true;
    errorMessage = null;
    _logRecording(
      'stop.request',
      data: <String, Object?>{
        'sessionId': sessionId,
        'isAndroidBackgroundStop': isAndroidBackgroundStop,
      },
    );
    notifyListeners();
    try {
      _desktopFloatingToolbarPopupRequested = false;
      await _recordingBridge.stopActiveRecording();
      if (isAndroidBackgroundStop) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      } else {
        await _backendClient.finalizeRecordingSession(
          backendUrl,
          sessionId,
          stopReason: stopReason,
        );
      }
      await refreshRecordings();
      _logRecording(
        'stop.done',
        data: <String, Object?>{'sessionId': sessionId},
      );
    } catch (error) {
      _logRecording(
        'stop.failed',
        data: <String, Object?>{
          'sessionId': sessionId,
          'isAndroidBackgroundStop': isAndroidBackgroundStop,
        },
        error: error,
      );
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    } finally {
      isStoppingRecording = false;
      notifyListeners();
    }
  }

  Future<void> retryRecording(String sessionId) async {
    try {
      await _backendClient.retryRecordingSession(backendUrl, sessionId);
      await refreshRecordings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> deleteRecordingSegment(String sessionId, int segmentId) async {
    try {
      errorMessage = null;
      final response = await _backendClient.deleteRecordingTranscriptSegment(
        backendUrl,
        sessionId,
        segmentId,
      );
      final session = RecordingSessionItem.fromJson(
        _jsonMap(response['session']),
      );
      _upsertRecordingSession(session);
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> deleteRecordingSession(String sessionId) async {
    try {
      errorMessage = null;
      await _backendClient.deleteRecordingSession(backendUrl, sessionId);
      _removeRecordingSession(sessionId);
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<VoiceAssistantTurnResult> runVoiceAssistantTurn({
    required String sessionId,
    String? ttsProvider,
    String? ttsVoice,
    String? ttsModel,
  }) async {
    final screenshotPayload = await buildVoiceAssistantContextPayload();
    final response = await _backendClient.runVoiceAssistantTurn(
      backendUrl,
      sessionId: sessionId,
      ttsProvider:
          ttsProvider?.trim().ifEmpty(voiceTtsProvider) ?? voiceTtsProvider,
      ttsVoice: ttsVoice?.trim().ifEmpty(voiceTtsVoice) ?? voiceTtsVoice,
      ttsModel: ttsModel?.trim().ifEmpty(voiceTtsModel) ?? voiceTtsModel,
      agentId: _scopedAgentId,
      screenshotBase64: screenshotPayload['screenshotBase64'],
      screenshotMimeType: screenshotPayload['screenshotMimeType'],
    );

    final result = VoiceAssistantTurnResult.fromJson(response);
    _upsertRecordingSession(result.session);

    if (result.transcript.trim().isNotEmpty) {
      _appendUserChatMessage(result.transcript, platform: 'voice_assistant');
    }
    if (result.replyText.trim().isNotEmpty) {
      _appendAssistantChatMessage(
        result.replyText,
        platform: 'voice_assistant',
      );
    }
    notifyListeners();
    return result;
  }

  Future<bool> _ensureSocketReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _ensureSocketConnected();
    if (socketConnected && _socket != null) {
      return true;
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (socketConnected && _socket != null) {
        return true;
      }
    }
    return socketConnected && _socket != null;
  }

  Future<void> ensureLiveVoiceSession() async {
    if (voiceAssistantLiveState.hasActiveSession) {
      return;
    }
    if (_liveVoiceSessionOpenCompleter != null) {
      return _liveVoiceSessionOpenCompleter!.future;
    }
    final ready = await _ensureSocketReady();
    if (!ready || _socket == null) {
      throw StateError('Live voice connection is not available.');
    }
    final completer = Completer<void>();
    _liveVoiceSessionOpenCompleter = completer;
    _socket!.emit('voice:session_open', <String, dynamic>{
      'agentId': _scopedAgentId,
    });
    try {
      await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw StateError('Live voice session did not initialize.');
        },
      );
    } finally {
      if (identical(_liveVoiceSessionOpenCompleter, completer)) {
        _liveVoiceSessionOpenCompleter = null;
      }
    }
  }

  String _createLiveVoiceTurnId() {
    _liveVoiceTurnCounter += 1;
    return 'live_${DateTime.now().millisecondsSinceEpoch}_$_liveVoiceTurnCounter';
  }

  bool _hasRecoverableLiveVoiceTurn() {
    final recoverableUntil = _liveVoiceRecoverableUntil;
    if ((_liveVoiceTurnId ?? '').trim().isEmpty) {
      return false;
    }
    if (recoverableUntil == null || !recoverableUntil.isAfter(DateTime.now())) {
      return false;
    }
    return _liveVoiceBufferedChunks.isNotEmpty ||
        _liveVoiceCaptureActive ||
        _liveVoiceCommitPending ||
        _liveVoiceAwaitingResponse;
  }

  void _setLiveVoiceRecoveryWindow() {
    _liveVoiceRecoveryTimer?.cancel();
    final recoverableUntil = DateTime.now().add(const Duration(seconds: 15));
    _liveVoiceRecoverableUntil = recoverableUntil;
    _liveVoiceRecoveryTimer = Timer(const Duration(seconds: 15), () {
      if (!_hasRecoverableLiveVoiceTurn()) {
        return;
      }
      _liveVoiceCaptureActive = false;
      _pendingLiveVoiceStop = false;
      unawaited(_liveVoiceCapture.stop());
      _resetLiveVoiceTurnBuffer();
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        sessionId: '',
        transportState: 'disconnected',
        state: 'error',
        error: 'Live voice reconnect timed out. Try again.',
        clearAudio: true,
        clearRecoverableUntil: true,
      );
      notifyListeners();
    });
    voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
      recoverableUntil: recoverableUntil,
    );
  }

  void _resetLiveVoiceTurnBuffer({bool clearRecovery = true}) {
    _liveVoiceTurnId = null;
    _liveVoiceBufferedChunks.clear();
    _liveVoiceAckThrough = -1;
    _liveVoiceFinalSequence = -1;
    _liveVoiceCommitPending = false;
    _liveVoiceAwaitingResponse = false;
    _liveVoicePendingCommitPayload = null;
    _liveVoiceCaptureStartedAt = null;
    if (clearRecovery) {
      _liveVoiceRecoveryTimer?.cancel();
      _liveVoiceRecoveryTimer = null;
      _liveVoiceRecoverableUntil = null;
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        clearRecoverableUntil: true,
      );
    }
  }

  void _markLiveVoiceChunksForReplay() {
    _liveVoiceAckThrough = -1;
    for (final chunk in _liveVoiceBufferedChunks) {
      chunk.sent = false;
    }
  }

  void _sendLiveVoiceInputStart({
    required String sessionId,
    required String turnId,
  }) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    socket.emit('voice:interrupt', <String, dynamic>{'sessionId': sessionId});
    socket.emit('voice:input_start', <String, dynamic>{
      'sessionId': sessionId,
      'turnId': turnId,
      'mimeType': 'audio/pcm;rate=16000;channels=1',
    });
  }

  Future<void> _flushLiveVoiceBufferedChunks() async {
    final socket = _socket;
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    final turnId = (_liveVoiceTurnId ?? '').trim();
    if (socket == null ||
        !socketConnected ||
        sessionId.isEmpty ||
        turnId.isEmpty) {
      return;
    }
    for (final chunk in _liveVoiceBufferedChunks) {
      if (chunk.sent) {
        continue;
      }
      socket.emit('voice:audio_chunk', <String, dynamic>{
        'sessionId': sessionId,
        'turnId': turnId,
        'sequence': chunk.sequence,
        'mimeType': 'audio/pcm;rate=16000;channels=1',
        'audioBase64': base64Encode(chunk.bytes),
      });
      chunk.sent = true;
    }
  }

  Future<void> _emitPendingLiveVoiceCommitIfReady() async {
    final socket = _socket;
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    final turnId = (_liveVoiceTurnId ?? '').trim();
    if (!_liveVoiceCommitPending ||
        socket == null ||
        !socketConnected ||
        sessionId.isEmpty ||
        turnId.isEmpty ||
        _liveVoiceFinalSequence < 0 ||
        _liveVoiceAckThrough < _liveVoiceFinalSequence) {
      return;
    }
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'turnId': turnId,
      'finalSequence': _liveVoiceFinalSequence,
      ...?_liveVoicePendingCommitPayload,
    };
    _liveVoiceCommitPending = false;
    _liveVoiceAwaitingResponse = true;
    socket.emit('voice:input_commit', payload);
  }

  Future<void> _restoreBufferedLiveVoiceTurnToActiveSession() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    final turnId = (_liveVoiceTurnId ?? '').trim();
    if (sessionId.isEmpty ||
        turnId.isEmpty ||
        !_hasRecoverableLiveVoiceTurn()) {
      return;
    }
    _markLiveVoiceChunksForReplay();
    _sendLiveVoiceInputStart(sessionId: sessionId, turnId: turnId);
    await _flushLiveVoiceBufferedChunks();
    await _emitPendingLiveVoiceCommitIfReady();
  }

  Future<void> startLiveVoiceCapture() async {
    if (recordingRuntime.active || isStartingRecording || isStoppingRecording) {
      throw StateError(
        'Stop recording before starting the assistant push-to-talk flow.',
      );
    }
    if (_isStartingLiveVoice) {
      return;
    }
    _isStartingLiveVoice = true;
    _pendingLiveVoiceStop = false;
    errorMessage = null;
    AppDiagnostics.log(
      'desktop.assistant',
      'ptt.start_request',
      data: <String, Object?>{
        'hasActiveSession': voiceAssistantLiveState.hasActiveSession,
        'socketConnected': socketConnected,
      },
    );
    notifyListeners();

    try {
      await ensureLiveVoiceSession();
      final sessionId = voiceAssistantLiveState.sessionId.trim();
      if (sessionId.isEmpty || _socket == null) {
        throw StateError('Live voice session did not initialize.');
      }
      final turnId = _createLiveVoiceTurnId();
      _resetLiveVoiceTurnBuffer(clearRecovery: false);
      _liveVoiceTurnId = turnId;
      _setLiveVoiceRecoveryWindow();
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        transportState: 'connected',
        state: 'listening',
        partialTranscript: '',
        finalTranscript: '',
        interimAssistantText: '',
        finalAssistantText: '',
        assistantText: '',
        clearAudio: true,
        clearError: true,
      );
      notifyListeners();
      _sendLiveVoiceInputStart(sessionId: sessionId, turnId: turnId);
      await _liveVoiceCapture.start(
        onChunk: (Uint8List chunk) {
          final sequence = _liveVoiceBufferedChunks.length;
          _liveVoiceBufferedChunks.add(
            LiveVoiceBufferedChunk(sequence: sequence, bytes: chunk),
          );
          _setLiveVoiceRecoveryWindow();
          unawaited(_flushLiveVoiceBufferedChunks());
        },
        onError: (Object error, StackTrace stackTrace) {
          AppDiagnostics.log(
            'desktop.assistant',
            'ptt.capture_error',
            error: error,
            stackTrace: stackTrace,
          );
          if (!_liveVoiceCaptureActive && !_isStartingLiveVoice) {
            return;
          }
          _liveVoiceCaptureActive = false;
          _resetLiveVoiceTurnBuffer();
          voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
            state: 'error',
            error: _friendlyErrorMessage(error),
          );
          notifyListeners();
        },
        onStoppedUnexpectedly: () {
          AppDiagnostics.log(
            'desktop.assistant',
            'ptt.capture_stopped_unexpectedly',
          );
          if (!_liveVoiceCaptureActive && !_isStartingLiveVoice) {
            return;
          }
          _liveVoiceCaptureActive = false;
          _resetLiveVoiceTurnBuffer();
          voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
            state: 'error',
            error:
                'Microphone capture stopped unexpectedly. Re-open the assistant and try again.',
          );
          notifyListeners();
        },
      );
      _liveVoiceCaptureActive = true;
      _liveVoiceCaptureStartedAt = DateTime.now();
      AppDiagnostics.log(
        'desktop.assistant',
        'ptt.capture_started',
        data: <String, Object?>{'sessionId': sessionId},
      );
      if (_pendingLiveVoiceStop) {
        _pendingLiveVoiceStop = false;
        await stopLiveVoiceCapture();
        return;
      }
    } catch (error) {
      _liveVoiceCaptureActive = false;
      _pendingLiveVoiceStop = false;
      rethrow;
    } finally {
      _isStartingLiveVoice = false;
      notifyListeners();
    }
  }

  Future<void> toggleLiveVoiceCapture() async {
    if (isLiveVoiceCaptureEngaged) {
      await stopLiveVoiceCapture();
      return;
    }
    await startLiveVoiceCapture();
  }

  Future<void> stopLiveVoiceCapture() async {
    AppDiagnostics.log(
      'desktop.assistant',
      'ptt.stop_request',
      data: <String, Object?>{
        'isStarting': _isStartingLiveVoice,
        'isActive': _liveVoiceCaptureActive,
      },
    );
    if (_isStoppingLiveVoice) {
      return;
    }
    if (_isStartingLiveVoice && !_liveVoiceCaptureActive) {
      _pendingLiveVoiceStop = true;
      return;
    }
    if (!_liveVoiceCaptureActive) {
      return;
    }
    _isStoppingLiveVoice = true;
    try {
      _liveVoiceCaptureActive = false;
      _liveVoiceCaptureStartedAt = null;
      await _liveVoiceCapture.stop();
      if (_liveVoiceBufferedChunks.isEmpty) {
        _resetLiveVoiceTurnBuffer();
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          state: 'idle',
          clearRecoverableUntil: true,
        );
        return;
      }
      final screenshotPayload = await buildVoiceAssistantContextPayload();
      AppDiagnostics.log(
        'desktop.assistant',
        'ptt.capture_committing',
        data: <String, Object?>{
          'sessionId': voiceAssistantLiveState.sessionId.trim(),
          'turnId': _liveVoiceTurnId,
        },
      );
      _liveVoiceFinalSequence = _liveVoiceBufferedChunks.length - 1;
      _liveVoiceCommitPending = true;
      _liveVoicePendingCommitPayload = <String, dynamic>{
        if ((screenshotPayload['screenshotBase64'] ?? '').isNotEmpty)
          'screenshotBase64': screenshotPayload['screenshotBase64'],
        if ((screenshotPayload['screenshotMimeType'] ?? '').isNotEmpty)
          'screenshotMimeType': screenshotPayload['screenshotMimeType'],
      };
      _setLiveVoiceRecoveryWindow();
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        state: 'transcribing',
      );
      await _flushLiveVoiceBufferedChunks();
      await _emitPendingLiveVoiceCommitIfReady();
    } finally {
      _isStoppingLiveVoice = false;
      notifyListeners();
    }
  }

  Future<void> interruptLiveVoiceAssistant() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) {
      return;
    }
    _socket!.emit('voice:interrupt', <String, dynamic>{'sessionId': sessionId});
    _liveVoiceCaptureActive = false;
    _liveVoiceCaptureStartedAt = null;
    _pendingLiveVoiceStop = false;
    _resetLiveVoiceTurnBuffer();
    voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
      state: 'idle',
      clearRecoverableUntil: true,
    );
    notifyListeners();
  }

  Future<void> closeLiveVoiceSession() async {
    final sessionId = voiceAssistantLiveState.sessionId.trim();
    if (sessionId.isEmpty || _socket == null) {
      return;
    }
    _socket!.emit('voice:session_close', <String, dynamic>{
      'sessionId': sessionId,
    });
    _liveVoiceCaptureActive = false;
    _liveVoiceCaptureStartedAt = null;
    _pendingLiveVoiceStop = false;
    _resetLiveVoiceTurnBuffer();
    voiceAssistantLiveState = VoiceAssistantLiveState();
    notifyListeners();
  }

  bool _matchesLiveVoiceSessionPayload(Map<String, dynamic> payload) {
    final payloadSessionId = payload['sessionId']?.toString().trim() ?? '';
    final activeSessionId = voiceAssistantLiveState.sessionId.trim();
    if (payloadSessionId.isEmpty) {
      return activeSessionId.isEmpty;
    }
    if (activeSessionId.isEmpty) {
      return true;
    }
    return payloadSessionId == activeSessionId;
  }

  void _appendAssistantChatMessage(
    String content, {
    required String platform,
    bool transient = false,
  }) {
    _appendChatMessage(
      content,
      role: 'assistant',
      platform: platform,
      transient: transient,
    );
  }

  void _appendUserChatMessage(String content, {required String platform}) {
    _appendChatMessage(content, role: 'user', platform: platform);
  }

  void _appendToolNote(String summary, {String toolName = 'note'}) {
    final trimmed = summary.trim();
    if (trimmed.isEmpty) {
      return;
    }
    toolEvents = <ToolEventItem>[
      ...toolEvents,
      ToolEventItem(
        id: 'note-${DateTime.now().microsecondsSinceEpoch}',
        toolName: toolName,
        type: 'note',
        status: 'completed',
        summary: trimmed,
      ),
    ];
  }

  Future<void> refreshUpdateStatus() async {
    try {
      updateStatus = UpdateStatusSnapshot.fromJson(
        await _backendClient.fetchUpdateStatus(backendUrl),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<RunDetailSnapshot> fetchRunDetail(
    String runId, {
    bool force = false,
  }) async {
    final cached = _runDetailsCache[runId];
    if (!force && cached != null && cached.response.trim().isNotEmpty) {
      return cached;
    }
    final response = await _backendClient.fetchRunSteps(backendUrl, runId);
    final detail = RunDetailSnapshot.fromJson(response);
    _runDetailsCache[runId] = detail;
    return detail;
  }

  Future<void> deleteRun(String runId) async {
    try {
      await _backendClient.deleteRun(backendUrl, runId);
      _runDetailsCache.remove(runId);
      recentRuns = recentRuns.where((run) => run.id != runId).toList();
      notifyListeners();
      await refreshRunsOnly();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> sendMessage(String task) async {
    final trimmed = task.trim();
    final canSteerLiveRun = hasLiveRun && _socket != null && socketConnected;
    if (trimmed.isEmpty || (isSendingMessage && !canSteerLiveRun)) {
      return;
    }

    final optimistic = ChatEntry(
      id: '',
      role: 'user',
      content: trimmed,
      platform: 'flutter',
      createdAt: DateTime.now(),
    );
    chatMessages = <ChatEntry>[...chatMessages, optimistic];
    errorMessage = null;
    if (!canSteerLiveRun) {
      isSendingMessage = true;
      toolEvents = const <ToolEventItem>[];
      streamingAssistant = '';
      activeRun = ActiveRunState.pending(trimmed);
    }
    notifyListeners();

    try {
      if (_socket != null && socketConnected) {
        _socket!.emit('agent:run', <String, dynamic>{
          'task': trimmed,
          'agentId': _scopedAgentId,
          'options': <String, dynamic>{'agentId': _scopedAgentId},
        });
        return;
      }

      final response = await _backendClient.runTask(
        backendUrl,
        trimmed,
        agentId: _scopedAgentId,
      );
      final content = response['content']?.toString().trim();
      if (content != null && content.isNotEmpty) {
        _appendAssistantChatMessage(content, platform: 'web');
      }
      activeRun = null;
      await refreshRunsOnly();
    } catch (error) {
      chatMessages = <ChatEntry>[
        ...chatMessages,
        ChatEntry(
          id: '',
          role: 'assistant',
          content:
              'I could not complete that request right now. Please try again in a moment.',
          platform: 'flutter',
          createdAt: DateTime.now(),
        ),
      ];
      activeRun = null;
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      if (_socket == null || !socketConnected) {
        isSendingMessage = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveSettings({
    required bool headlessBrowser,
    required String browserBackend,
    required bool smarterSelector,
    required List<String> enabledModels,
    required String defaultChatModel,
    required String defaultSubagentModel,
    required String defaultSpeechModel,
    required String defaultRecordingTranscriptionProvider,
    required String defaultRecordingTranscriptionModel,
    required String defaultRecordingSummaryProvider,
    required String defaultRecordingSummaryModel,
    required String fallbackModel,
    required String voiceSttProvider,
    required String voiceSttModel,
    required String voiceTtsProvider,
    required String voiceTtsModel,
    required String voiceTtsVoice,
    required String voiceRuntimeMode,
    required String voiceLiveProvider,
    required String voiceLiveModel,
    required String voiceLiveVoice,
    required Map<String, dynamic> aiProviderConfigs,
  }) async {
    isSavingSettings = true;
    errorMessage = null;
    notifyListeners();

    final payload = <String, dynamic>{
      'headless_browser': headlessBrowser,
      'browser_backend': browserBackend,
      'smarter_model_selector': smarterSelector,
      'enabled_models': enabledModels,
      'default_chat_model': defaultChatModel,
      'default_subagent_model': defaultSubagentModel,
      'default_speech_model': defaultSpeechModel,
      'default_recording_transcription_provider':
          defaultRecordingTranscriptionProvider,
      'default_recording_transcription_model':
          defaultRecordingTranscriptionModel,
      'default_recording_summary_provider': defaultRecordingSummaryProvider,
      'default_recording_summary_model': defaultRecordingSummaryModel,
      'fallback_model_id': fallbackModel,
      'voice_stt_provider': voiceSttProvider,
      'voice_stt_model': voiceSttModel,
      'voice_tts_provider': voiceTtsProvider,
      'voice_tts_model': voiceTtsModel,
      'voice_tts_voice': voiceTtsVoice,
      'voice_runtime_mode': voiceRuntimeMode,
      'voice_live_provider': voiceLiveProvider,
      'voice_live_model': voiceLiveModel,
      'voice_live_voice': voiceLiveVoice,
      'ai_provider_configs': aiProviderConfigs,
    };

    try {
      await _backendClient.saveSettings(
        backendUrl,
        payload,
        agentId: _scopedAgentId,
      );
      settings = <String, dynamic>{...settings, ...payload};
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingSettings = false;
      notifyListeners();
    }
  }

  void _applyAccountResponse(Map<String, dynamic> response) {
    if (response['user'] is Map) {
      user = Map<String, dynamic>.from(response['user'] as Map);
    }
    if (response['twoFactor'] is Map) {
      accountTwoFactor = Map<String, dynamic>.from(
        response['twoFactor'] as Map,
      );
    }
    final sessions = response['sessions'];
    if (sessions is List) {
      accountSessions = sessions
          .whereType<Map<dynamic, dynamic>>()
          .map(AccountSessionItem.fromJson)
          .toList();
    }
    final authProviderRows = response['authProviders'];
    if (authProviderRows is List) {
      linkedAuthProviders = authProviderRows
          .whereType<Map<dynamic, dynamic>>()
          .map(LinkedAuthProviderItem.fromJson)
          .toList();
    }
  }

  Future<void> refreshAccountSettings() async {
    if (!isAuthenticated) return;
    isLoadingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(await _backendClient.fetchAccount(backendUrl));
      final sessionsResponse = await _backendClient.fetchAccountSessions(
        backendUrl,
      );
      _applyAccountResponse(sessionsResponse);
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isLoadingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<bool> updateAccountEmail({
    required String email,
    required String currentPassword,
  }) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.updateAccountEmail(
          baseUrl: backendUrl,
          email: email,
          currentPassword: currentPassword,
        ),
      );
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<bool> updateAccountPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.updateAccountPassword(
          baseUrl: backendUrl,
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<void> linkAccountProvider(String provider) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      final begin = await _backendClient.beginProviderAuth(
        baseUrl: backendUrl,
        provider: provider,
        mode: 'link',
      );
      final url = begin['url']?.toString();
      final state = begin['state']?.toString();
      if (url == null || state == null || url.isEmpty || state.isEmpty) {
        throw Exception('Provider linking could not be started.');
      }
      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: provider,
      );
      if (!launchResult.launched) {
        throw Exception(
          launchResult.error ?? 'Could not open the provider linking page.',
        );
      }
      await _pollForProviderAuthCompletion(state);
      await refreshAccountSettings();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<void> unlinkAccountProvider(int providerLinkId) async {
    isSavingAccountSettings = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.unlinkAccountProvider(
          baseUrl: backendUrl,
          providerLinkId: providerLinkId,
        ),
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingAccountSettings = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> beginTwoFactorSetup(
    String currentPassword,
  ) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.beginTwoFactorSetup(
        baseUrl: backendUrl,
        currentPassword: currentPassword,
      );
      if (response['status'] is Map) {
        accountTwoFactor = Map<String, dynamic>.from(response['status'] as Map);
      }
      return response;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return null;
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<List<String>> enableTwoFactor(String code) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.enableTwoFactor(
        baseUrl: backendUrl,
        code: code,
      );
      if (response['status'] is Map) {
        accountTwoFactor = Map<String, dynamic>.from(response['status'] as Map);
      }
      return _jsonStringList(
        response['recoveryCodes'],
        nestedKeys: const <String>[
          'items',
          'data',
          'results',
          'rows',
          'values',
          'list',
          'recoveryCodes',
          'codes',
        ],
        fallbackToMapValues: true,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return const <String>[];
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<void> disableTwoFactor({
    required String currentPassword,
    required String code,
  }) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.disableTwoFactor(
        baseUrl: backendUrl,
        currentPassword: currentPassword,
        code: code,
      );
      if (response['status'] is Map) {
        accountTwoFactor = Map<String, dynamic>.from(response['status'] as Map);
      }
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<List<String>> regenerateRecoveryCodes({
    required String currentPassword,
    required String code,
  }) async {
    isConfiguringTwoFactor = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _backendClient.regenerateRecoveryCodes(
        baseUrl: backendUrl,
        currentPassword: currentPassword,
        code: code,
      );
      if (response['status'] is Map) {
        accountTwoFactor = Map<String, dynamic>.from(response['status'] as Map);
      }
      return _jsonStringList(
        response['recoveryCodes'],
        nestedKeys: const <String>[
          'items',
          'data',
          'results',
          'rows',
          'values',
          'list',
          'recoveryCodes',
          'codes',
        ],
        fallbackToMapValues: true,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      return const <String>[];
    } finally {
      isConfiguringTwoFactor = false;
      notifyListeners();
    }
  }

  Future<void> revokeAccountSession(int sessionId) async {
    isRevokingSession = true;
    errorMessage = null;
    notifyListeners();
    try {
      _applyAccountResponse(
        await _backendClient.revokeAccountSession(backendUrl, sessionId),
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isRevokingSession = false;
      notifyListeners();
    }
  }

  Future<void> triggerUpdate() async {
    isTriggeringUpdate = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _backendClient.triggerUpdate(backendUrl);
      await refreshUpdateStatus();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isTriggeringUpdate = false;
      notifyListeners();
    }
  }

  Future<void> setReleaseChannel(String channel) async {
    if (isSavingReleaseChannel) {
      return;
    }

    isSavingReleaseChannel = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _backendClient.setReleaseChannel(
        backendUrl,
        channel,
      );
      final nextChannel = response['releaseChannel']?.toString() ?? channel;
      updateStatus = UpdateStatusSnapshot.fromJson(<String, dynamic>{
        ...?versionInfo,
        'state': updateStatus.state,
        'progress': updateStatus.progress,
        'message': updateStatus.message,
        'releaseChannel': nextChannel,
        'targetBranch': response['targetBranch'],
        'npmDistTag': response['npmDistTag'],
        'versionBefore': updateStatus.versionBefore,
        'versionAfter': updateStatus.versionAfter,
        'backendVersion': updateStatus.backendVersion,
        'installedVersion': updateStatus.installedVersion,
        'changelog': updateStatus.changelog,
        'logs': updateStatus.logs,
      });
      if (versionInfo != null) {
        versionInfo = <String, dynamic>{
          ...versionInfo!,
          'releaseChannel': nextChannel,
          'targetBranch': response['targetBranch'],
          'npmDistTag': response['npmDistTag'],
        };
      }
      await refreshUpdateStatus();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSavingReleaseChannel = false;
      notifyListeners();
    }
  }

  Future<SkillDocument> fetchSkillDocument(String name) async {
    return SkillDocument.fromJson(
      await _backendClient.fetchSkillDocument(backendUrl, name),
    );
  }

  Future<void> saveSkillContent({
    required String name,
    required String content,
  }) async {
    await _backendClient.saveSkillContent(
      backendUrl,
      name: name,
      content: content,
    );
    await refreshSkills();
  }

  Future<void> createSkill({
    required String filename,
    required String content,
  }) async {
    await _backendClient.createSkill(
      backendUrl,
      filename: filename,
      content: content,
    );
    await refreshSkills();
  }

  Future<void> setSkillEnabled(String name, bool enabled) async {
    await _backendClient.setSkillEnabled(
      backendUrl,
      name: name,
      enabled: enabled,
    );
    await refreshSkills();
  }

  Future<void> deleteSkill(String name) async {
    await _backendClient.deleteSkill(backendUrl, name);
    await refreshSkills();
  }

  Future<void> installStoreSkill(String id) async {
    await _backendClient.installStoreSkill(backendUrl, id);
    await refreshSkills();
  }

  Future<void> uninstallStoreSkill(String id) async {
    await _backendClient.uninstallStoreSkill(backendUrl, id);
    await refreshSkills();
  }

  Future<void> connectOfficialIntegration(
    String providerId, {
    required String appId,
  }) async {
    final busyKey = '$providerId:$appId:connect';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    final before = _findOfficialIntegrationApp(providerId, appId);
    final beforeCount = before?.accounts.length ?? 0;
    final beforeLatest = before?.accounts
        .map((account) => account.lastConnectedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, value) {
          if (latest == null || value.isAfter(latest)) {
            return value;
          }
          return latest;
        });

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _backendClient.connectOfficialIntegration(
        backendUrl,
        providerId,
        appId: appId,
        agentId: _scopedAgentId,
      );
      final url = response['url']?.toString();
      final status = response['status']?.toString() ?? '';
      if ((status != 'oauth_redirect' && status != 'interactive_connect') ||
          url == null ||
          url.isEmpty) {
        throw Exception(
          'Official integration did not return a connection URL.',
        );
      }

      final launchResult = await _oauthLauncher.launch(
        url: url,
        provider: providerId,
      );
      if (!launchResult.launched) {
        throw Exception(launchResult.error ?? 'Failed to launch OAuth flow.');
      }
      if (launchResult.completed) {
        await refreshSkills();
        return;
      }
      if (launchResult.error != null) {
        throw Exception(launchResult.error!);
      }

      await _pollForOfficialIntegrationConnection(
        providerId,
        appId: appId,
        previousAccountCount: beforeCount,
        previousLatestConnectedAt: beforeLatest,
      );
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getOfficialIntegrationConfig(
    String providerId,
  ) async {
    final response = await _backendClient.fetchOfficialIntegrationConfig(
      backendUrl,
      providerId,
      agentId: _scopedAgentId,
    );
    final raw = response['config'];
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return const <String, dynamic>{};
  }

  Future<void> saveOfficialIntegrationConfig(
    String providerId, {
    required Map<String, dynamic> config,
  }) async {
    final busyKey = '$providerId:config:save';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.saveOfficialIntegrationConfig(
        backendUrl,
        providerId,
        config: config,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  Future<void> clearOfficialIntegrationConfig(String providerId) async {
    final busyKey = '$providerId:config:clear';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.clearOfficialIntegrationConfig(
        backendUrl,
        providerId,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      rethrow;
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  Future<void> disconnectOfficialIntegration(
    String providerId, {
    required int connectionId,
  }) async {
    final busyKey = '$providerId:$connectionId:disconnect';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.disconnectOfficialIntegration(
        backendUrl,
        providerId,
        connectionId: connectionId,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  Future<void> setOfficialIntegrationAccessMode(
    String providerId, {
    required int connectionId,
    required String accessMode,
  }) async {
    final busyKey = '$providerId:$connectionId:access_mode';
    if (_busyOfficialIntegrationKeys.contains(busyKey)) {
      return;
    }

    _busyOfficialIntegrationKeys.add(busyKey);
    errorMessage = null;
    notifyListeners();

    try {
      await _backendClient.setOfficialIntegrationAccessMode(
        backendUrl,
        providerId,
        connectionId: connectionId,
        accessMode: accessMode,
        agentId: _scopedAgentId,
      );
      await refreshSkills();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      _busyOfficialIntegrationKeys.remove(busyKey);
      notifyListeners();
    }
  }

  OfficialIntegrationAppItem? _findOfficialIntegrationApp(
    String providerId,
    String appId,
  ) {
    for (final item in officialIntegrations) {
      if (item.id != providerId) continue;
      for (final app in item.apps) {
        if (app.id == appId) {
          return app;
        }
      }
    }
    return null;
  }

  Future<void> _pollForOfficialIntegrationConnection(
    String providerId, {
    required String appId,
    required int previousAccountCount,
    required DateTime? previousLatestConnectedAt,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final items = await _backendClient.fetchOfficialIntegrations(
          backendUrl,
          agentId: _scopedAgentId,
        );
        officialIntegrations = items
            .map(OfficialIntegrationItem.fromJson)
            .toList();
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      final match = _findOfficialIntegrationApp(providerId, appId);
      final latestConnectedAt = match?.accounts
          .map((account) => account.lastConnectedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (latest, value) {
            if (latest == null || value.isAfter(latest)) {
              return value;
            }
            return latest;
          });
      if (match != null &&
          match.isConnected &&
          (match.accounts.length > previousAccountCount ||
              (previousLatestConnectedAt == null &&
                  latestConnectedAt != null) ||
              (previousLatestConnectedAt != null &&
                  latestConnectedAt != null &&
                  latestConnectedAt.isAfter(previousLatestConnectedAt)))) {
        await refreshSkills();
        notifyListeners();
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    throw Exception(
      'Authentication is still pending. Finish the browser flow and refresh.',
    );
  }

  Future<void> connectMessagingPlatform({
    required String platform,
    Map<String, dynamic>? config,
    Map<String, dynamic>? configSnapshot,
  }) async {
    if (configSnapshot != null) {
      await _backendClient.saveSettings(
        backendUrl,
        configSnapshot,
        agentId: _scopedAgentId,
      );
      settings = <String, dynamic>{...settings, ...configSnapshot};
    }
    await _backendClient.connectMessagingPlatform(
      backendUrl,
      platform: platform,
      config: config,
      agentId: _scopedAgentId,
    );
    await refreshMessaging();
  }

  Future<void> disconnectMessagingPlatform(String platform) async {
    await _backendClient.disconnectMessagingPlatform(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    await refreshMessaging();
  }

  Future<void> logoutMessagingPlatform(String platform) async {
    await _backendClient.logoutMessagingPlatform(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    await refreshMessaging();
  }

  Future<List<Map<String, dynamic>>> fetchMessagingPlatformDevices(
    String platform,
  ) async {
    final data = await _backendClient.fetchMessagingPlatformDevices(
      backendUrl,
      platform: platform,
      agentId: _scopedAgentId,
    );
    final raw = data['devices'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> saveTelnyxVoiceSecret(String secret) async {
    await _backendClient.saveTelnyxVoiceSecret(
      backendUrl,
      secret,
      agentId: _scopedAgentId,
    );
    settings = <String, dynamic>{
      ...settings,
      'platform_voice_secret_telnyx': secret,
    };
    notifyListeners();
  }

  Future<void> saveMessagingAccessPolicy(
    String platform,
    MessagingAccessPolicy policy,
  ) async {
    final response = await _backendClient.saveMessagingAccessPolicy(
      backendUrl,
      platform: platform,
      policy: policy.toJson(),
      agentId: _scopedAgentId,
    );
    final saved = MessagingAccessCatalog.fromJson(platform, <String, dynamic>{
      'policy': _jsonMap(response['policy']),
      'capabilities': currentMessagingAccessCatalog(
        platform,
      ).capabilities.toJson(),
      'discoveredTargets': currentMessagingAccessCatalog(
        platform,
      ).discoveredTargets.map((item) => item.toJson()).toList(growable: false),
      'suggestedTargets': currentMessagingAccessCatalog(
        platform,
      ).suggestedTargets.map((item) => item.toJson()).toList(growable: false),
      'summary': response['summary']?.toString() ?? 'Access policy',
    });
    messagingAccessCatalogs = <String, MessagingAccessCatalog>{
      ...messagingAccessCatalogs,
      platform: saved,
    };
    notifyListeners();
  }

  Future<void> createMemory({
    required String content,
    required String category,
    required int importance,
  }) async {
    await _backendClient.createMemory(
      backendUrl,
      content: content,
      category: category,
      importance: importance,
      agentId: _scopedAgentId,
    );
    memoryRecallResults = const <MemoryItem>[];
    await refreshMemory();
  }

  Future<void> deleteMemory(String id) async {
    await deleteMemories(<String>[id]);
  }

  Future<void> deleteMemories(List<String> ids) async {
    final uniqueIds = ids.toSet().where((id) => id.trim().isNotEmpty).toSet();
    if (uniqueIds.isEmpty) {
      return;
    }
    await _backendClient.deleteMemories(
      backendUrl,
      uniqueIds.toList(growable: false),
      agentId: _scopedAgentId,
    );
    memoryRecallResults = memoryRecallResults
        .where((memory) => !uniqueIds.contains(memory.id))
        .toList();
    await refreshMemory();
  }

  Future<void> archiveMemories(List<String> ids) async {
    final uniqueIds = ids.toSet().where((id) => id.trim().isNotEmpty).toSet();
    if (uniqueIds.isEmpty) {
      return;
    }
    await _backendClient.archiveMemories(
      backendUrl,
      uniqueIds.toList(growable: false),
      agentId: _scopedAgentId,
    );
    memoryRecallResults = memoryRecallResults
        .where((memory) => !uniqueIds.contains(memory.id))
        .toList();
    await refreshMemory();
  }

  Future<void> searchMemories(String query) async {
    memoryRecallResults = (await _backendClient.recallMemories(
      backendUrl,
      query,
      agentId: _scopedAgentId,
    )).map(MemoryItem.fromJson).toList();
    notifyListeners();
  }

  void clearMemorySearch() {
    memoryRecallResults = const <MemoryItem>[];
    notifyListeners();
  }

  Future<void> updateAssistantBehaviorNotes(String content) async {
    await _backendClient.saveSettings(backendUrl, <String, dynamic>{
      'assistant_behavior_notes': content,
    }, agentId: _scopedAgentId);
    await refreshMemory();
  }

  Future<void> updateCoreMemory(String key, String value) async {
    await _backendClient.updateCoreMemory(
      backendUrl,
      key: key,
      value: value,
      agentId: _scopedAgentId,
    );
    await refreshMemory();
  }

  Future<void> deleteCoreMemory(String key) async {
    await _backendClient.deleteCoreMemory(
      backendUrl,
      key,
      agentId: _scopedAgentId,
    );
    await refreshMemory();
  }

  Future<void> saveTask({
    int? id,
    required String name,
    required String triggerType,
    required Map<String, dynamic> triggerConfig,
    required String prompt,
    String? model,
    bool enabled = true,
    String? agentId,
  }) async {
    await _backendClient.saveTask(
      backendUrl,
      id: id,
      name: name,
      triggerType: triggerType,
      triggerConfig: triggerConfig,
      prompt: prompt,
      model: model,
      enabled: enabled,
      agentId: agentId ?? _scopedAgentId,
    );
    await refreshTasks();
  }

  String _manualRunCooldownKey(String scope, String id) => '$scope:$id';

  void _pruneManualRunCooldowns() {
    final now = DateTime.now();
    _manualRunCooldowns.removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
  }

  void _ensureManualRunCooldownTicker() {
    if (_manualRunCooldowns.isEmpty) {
      _manualRunCooldownTimer?.cancel();
      _manualRunCooldownTimer = null;
      return;
    }
    _manualRunCooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _pruneManualRunCooldowns();
      if (_manualRunCooldowns.isEmpty) {
        _manualRunCooldownTimer?.cancel();
        _manualRunCooldownTimer = null;
      }
      notifyListeners();
    });
  }

  void _startManualRunCooldown(String scope, String id) {
    _manualRunCooldowns[_manualRunCooldownKey(scope, id)] = DateTime.now().add(
      _manualRunCooldownDuration,
    );
    _ensureManualRunCooldownTicker();
    notifyListeners();
  }

  int _manualRunCooldownSeconds(String scope, String id) {
    _pruneManualRunCooldowns();
    final expiresAt = _manualRunCooldowns[_manualRunCooldownKey(scope, id)];
    if (expiresAt == null) {
      return 0;
    }
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    return remaining <= 0 ? 0 : remaining + 1;
  }

  bool canRunTaskNow(int id) => _manualRunCooldownSeconds('task', '$id') == 0;

  int taskRunCooldownSeconds(int id) =>
      _manualRunCooldownSeconds('task', '$id');

  bool canRefreshWidgetNow(String id) =>
      _manualRunCooldownSeconds('widget', id) == 0;

  int widgetRunCooldownSeconds(String id) =>
      _manualRunCooldownSeconds('widget', id);

  Future<void> toggleWidgetEnabled(AiWidgetItem item) async {
    await _backendClient.saveWidget(
      backendUrl,
      id: item.id,
      payload: <String, dynamic>{
        'name': item.name,
        'template': item.template,
        'layoutVariant': item.layoutVariant,
        'refreshCron': item.refreshCron,
        'definition': item.definition,
        'enabled': !item.enabled,
        'agentId': item.agentId ?? _scopedAgentId,
      },
    );
    await refreshWidgets();
    await refreshTasks();
  }

  Future<void> refreshWidgetNow(String id) async {
    if (!canRefreshWidgetNow(id)) {
      notifyListeners();
      return;
    }
    _startManualRunCooldown('widget', id);
    await _backendClient.refreshWidget(backendUrl, id);
    await refreshWidgets();
    await refreshTasks();
    await refreshRunsOnly();
  }

  Future<void> deleteWidget(String id) async {
    await _backendClient.deleteWidget(backendUrl, id);
    widgets = widgets.where((widget) => widget.id != id).toList();
    _selectedWidgetId = widgets.any((widget) => widget.id == _selectedWidgetId)
        ? _selectedWidgetId
        : (widgets.isEmpty ? null : widgets.first.id);
    notifyListeners();
    await refreshTasks();
  }

  void openWidgetCreateFlow() {
    queueChatDraft(
      'Create a new AI widget for the current agent. Choose the best template and approved layout variant, set a refresh cadence of at least 1 hour, create it, and run an initial refresh if appropriate.',
    );
  }

  void openWidgetEditFlow(AiWidgetItem item) {
    queueChatDraft(
      'Update the AI widget "${item.name}" (ID: ${item.id}) for the current agent. Keep the cadence at 1 hour or longer. Change the layout variant only if the edit explicitly requires it.\n\nCurrent template: ${item.template}\nCurrent layout variant: ${item.layoutVariant}\nCurrent refresh cron: ${item.refreshCron}\nCurrent definition prompt:\n${item.prompt}',
    );
  }

  void queueChatDraft(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    _pendingChatDraft = normalized;
    selectedSection = AppSection.chat;
    notifyListeners();
  }

  String? takePendingChatDraft() {
    final draft = _pendingChatDraft;
    _pendingChatDraft = null;
    return draft;
  }

  void selectWidget(String? widgetId) {
    if (widgetId != null && !widgets.any((widget) => widget.id == widgetId)) {
      return;
    }
    _selectedWidgetId = widgetId;
    notifyListeners();
  }

  void openWidgetSurface(String widgetId) {
    final normalized = widgetId.trim();
    selectedSection = AppSection.widgets;
    if (normalized.isNotEmpty) {
      _selectedWidgetId = normalized;
      unawaited(refreshWidgets(all: true));
    }
    notifyListeners();
  }

  void openVoiceAssistantSurface() {
    selectedSection = AppSection.voiceAssistant;
    notifyListeners();
  }

  String? get selectedWidgetId => _selectedWidgetId;

  AiWidgetItem? get selectedWidget {
    final widgetId = _selectedWidgetId;
    if (widgetId == null) {
      return widgets.isEmpty ? null : widgets.first;
    }
    for (final item in widgets) {
      if (item.id == widgetId) {
        return item;
      }
    }
    return widgets.isEmpty ? null : widgets.first;
  }

  Future<void> toggleTask(TaskItem task) async {
    await _backendClient.updateTask(backendUrl, task.id, <String, dynamic>{
      'enabled': !task.enabled,
      if (task.agentId != null && task.agentId!.isNotEmpty)
        'agentId': task.agentId,
    });
    await refreshTasks();
  }

  Future<void> runTaskNow(int id) async {
    if (!canRunTaskNow(id)) {
      notifyListeners();
      return;
    }
    _startManualRunCooldown('task', '$id');
    await _backendClient.runSavedTask(backendUrl, id);
    await refreshTasks();
    await refreshRunsOnly();
  }

  Future<void> deleteTask(int id) async {
    await _backendClient.deleteTask(backendUrl, id);
    await refreshTasks();
  }

  Future<void> saveMcpServer({
    int? id,
    required String name,
    required String command,
    required Map<String, dynamic> config,
    required bool enabled,
    String? agentId,
  }) async {
    await _backendClient.saveMcpServer(
      backendUrl,
      id: id,
      name: name,
      command: command,
      config: config,
      enabled: enabled,
      agentId: agentId ?? _scopedAgentId,
    );
    await refreshMcp();
  }

  Future<void> startMcpServer(int id) async {
    await _backendClient.startMcpServer(backendUrl, id);
    await refreshMcp();
  }

  Future<void> stopMcpServer(int id) async {
    await _backendClient.stopMcpServer(backendUrl, id);
    await refreshMcp();
  }

  Future<void> deleteMcpServer(int id) async {
    await _backendClient.deleteMcpServer(backendUrl, id);
    await refreshMcp();
  }

  Future<void> requestHealthPermissions() async {
    try {
      deviceHealthStatus = await _healthBridge.requestPermissions();
      await _syncBackgroundHealthConfig();
      notifyListeners();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
    }
  }

  Future<void> syncHealthNow() async {
    isSyncingHealth = true;
    errorMessage = null;
    notifyListeners();

    try {
      final deviceStatus = await _healthBridge.getStatus();
      deviceHealthStatus = deviceStatus;
      if (!deviceStatus.available) {
        throw const HealthBridgeException(
          'Health Connect is not available on this device.',
        );
      }
      if (!deviceStatus.permissionsGranted) {
        throw const HealthBridgeException(
          'Grant Health Connect permissions before syncing.',
        );
      }

      final lastRun = _jsonMap(backendHealthStatus?['lastRun']);
      final lastWindowEndRaw = lastRun['sync_window_end']?.toString();
      final windowEnd = DateTime.now().toUtc();
      final windowStart = lastWindowEndRaw == null
          ? windowEnd.subtract(const Duration(hours: 24))
          : DateTime.parse(
              lastWindowEndRaw,
            ).toUtc().subtract(const Duration(minutes: 5));

      final payload = await _healthBridge.collectBatch(
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      await _backendClient.uploadHealthBatch(backendUrl, payload);
      backendHealthStatus = await _backendClient.fetchHealthStatus(backendUrl);
      await _syncBackgroundHealthConfig();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isSyncingHealth = false;
      notifyListeners();
    }
  }

  String _friendlyErrorMessage(Object error) {
    final text = _normalizeErrorText(error);
    final lower = text.toLowerCase();
    final backendStatusCode = error is BackendException
        ? error.statusCode
        : null;

    if (backendStatusCode == 402) {
      final details = _extractMeaningfulErrorDetails(text);
      if (lower.contains('invalid credentials')) {
        return 'The NeoAgent deployment responded with HTTP 402 instead of the normal 401 for invalid credentials. Check reverse-proxy, auth gateway, or payment-related rules on that server.';
      }
      if (details.isNotEmpty &&
          details.toLowerCase() !=
              'request failed with http $backendStatusCode') {
        return 'The NeoAgent deployment responded with HTTP 402.\n\n$details';
      }
      return 'The NeoAgent deployment responded with HTTP 402. Check reverse-proxy, auth gateway, or payment-related rules on that server.';
    }

    if (lower.contains('invalid credentials')) {
      return 'Your username or password is incorrect.';
    }
    if (lower.contains('registration is closed')) {
      return 'This server is already set up. Sign in with an existing account.';
    }
    if (lower.contains('too many attempts')) {
      return 'Too many sign-in attempts. Please wait and try again.';
    }
    if (lower.contains('qr login request was not found') ||
        lower.contains('qr login request has expired') ||
        lower.contains('this qr login request has expired')) {
      return 'This QR login request expired. Generate a new code and try again.';
    }
    if (lower.contains('already used')) {
      return 'This QR login request was already used.';
    }
    if (lower.contains('not approved yet')) {
      return 'This QR login request is still waiting for approval.';
    }
    if (lower.contains('valid email')) {
      return 'Enter a valid email address.';
    }
    if (lower.contains('email is already in use')) {
      return 'That email is already linked to another account.';
    }
    if (lower.contains('current password is incorrect')) {
      return 'Your current password is incorrect.';
    }
    if (lower.contains('email confirmation required')) {
      return 'Confirm your email before signing in. Check the service email message from NeoAgent.';
    }
    if (lower.contains('could not send confirmation email') ||
        lower.contains('service email is not configured')) {
      return 'NeoAgent service email is not ready. Ask the server operator to check the email environment settings.';
    }
    if (lower.contains('password min 8')) {
      return 'Use a password with at least 8 characters.';
    }
    if (lower.contains('password is too weak')) {
      return text;
    }
    if (lower.contains('invalid 2fa') || lower.contains('two-factor code')) {
      return 'The two-factor code is not valid.';
    }
    if (lower.contains('two-factor challenge expired')) {
      return 'The two-factor challenge expired. Sign in again.';
    }
    if (lower.contains('session_secret')) {
      return '2FA requires SESSION_SECRET to be configured on this NeoAgent deployment.';
    }
    if (lower.contains('cors') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('failed to fetch') ||
        lower.contains('network request failed') ||
        lower.contains('clientexception') ||
        lower.contains('socketexception')) {
      return 'The app could not reach this NeoAgent deployment. Check your network connection or confirm the service URL is correct.';
    }
    if (lower.contains('origin not allowed')) {
      return 'This build is not allowed to talk to this NeoAgent deployment.';
    }
    if (lower.contains('not authenticated')) {
      return 'Your session expired. Please sign in again.';
    }
    if (lower.contains('no neoagent account is linked to this provider')) {
      return 'This Google account is not linked yet. Use provider registration first, or sign in normally and link it from account settings.';
    }
    if (lower.contains('already belongs to an existing account')) {
      return 'That email already belongs to an existing account. Sign in first, then link Google from account settings.';
    }
    if (lower.contains('already linked to another neoagent account') ||
        lower.contains('already linked to another account')) {
      return 'That Google account is already linked to a different NeoAgent account.';
    }
    if (lower.contains(
      'create a password or link another provider before removing this sign-in method',
    )) {
      return 'Add another sign-in method before removing this one.';
    }
    if (lower.contains('unable to locate a java runtime') ||
        lower.contains('java runtime')) {
      final details = _extractMeaningfulErrorDetails(text);
      if (details.isNotEmpty) {
        return 'Mobile setup failed because Java is not available on the machine running NeoAgent.\n\n$details';
      }
      return 'Mobile setup failed because Java is not available on the machine running NeoAgent. Install a JDK and try again.';
    }
    if (lower.contains('android sdk') ||
        lower.contains('sdkmanager') ||
        lower.contains('adb') ||
        lower.contains('emulator') ||
        lower.contains('gradle')) {
      final details = _extractMeaningfulErrorDetails(text);
      if (details.isNotEmpty) {
        return 'Mobile setup failed.\n\n$details';
      }
      return 'Mobile setup failed. Check that Android tooling is installed correctly and try again.';
    }
    if (lower.contains('health connect')) {
      return text;
    }
    if (lower.contains('xmlhttprequest error') ||
        lower.contains('failed to fetch') ||
        lower.contains('networkerror') ||
        lower.contains('load failed')) {
      final details = _extractMeaningfulErrorDetails(text);
      return details.isNotEmpty
          ? 'The web app could not reach the NeoAgent backend.\n\n$details'
          : 'The web app could not reach the NeoAgent backend.';
    }
    if (lower.contains('content security policy') ||
        lower.contains('connect-src')) {
      final details = _extractMeaningfulErrorDetails(text);
      return details.isNotEmpty
          ? 'The browser blocked a required request because of Content Security Policy.\n\n$details'
          : 'The browser blocked a required request because of Content Security Policy.';
    }
    if (_shouldExposeErrorText(text)) {
      return _extractMeaningfulErrorDetails(text);
    }

    return 'Something went wrong. Please try again.';
  }

  String _normalizeErrorText(Object error) {
    var text = error.toString().trim();
    const prefixes = <String>[
      'BackendException: ',
      'HealthBridgeException: ',
      'Exception: ',
    ];
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
      }
    }
    if (text.startsWith('PlatformException(') && text.endsWith(')')) {
      final inner = text.substring(
        'PlatformException('.length,
        text.length - 1,
      );
      final parts = inner.split(', ');
      if (parts.length >= 2) {
        text = parts[1].trim();
      }
    }
    return text;
  }

  String _extractMeaningfulErrorDetails(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('{') && !line.startsWith('"error"'))
        .toList();
    if (lines.isEmpty) {
      return text.trim();
    }
    return lines.join('\n');
  }

  bool _shouldExposeErrorText(String text) {
    if (text.isEmpty) {
      return false;
    }

    final lower = text.toLowerCase();
    if (lower.contains('stack trace') ||
        lower.contains('typeerror:') ||
        lower.contains('referenceerror:') ||
        lower.contains('syntaxerror:') ||
        lower.contains(' at ') ||
        lower.contains('/users/') ||
        lower.contains('/var/') ||
        lower.contains('/tmp/')) {
      return false;
    }

    final details = _extractMeaningfulErrorDetails(text);
    return details.isNotEmpty &&
        details != 'Something went wrong. Please try again.' &&
        details.length <= 800;
  }

  bool get headlessBrowser =>
      settings['headless_browser'] != false &&
      settings['headless_browser'] != 'false';

  String get browserBackend =>
      settings['browser_backend']?.toString().trim().toLowerCase() ?? 'host';

  String get cloudBrowserBackend {
    final browser = browserBackend;
    final profile = settings['runtime_profile']
        ?.toString()
        .trim()
        .toLowerCase();
    final runtime = settings['runtime_backend']
        ?.toString()
        .trim()
        .toLowerCase();
    if (updateStatus.deploymentProfile.toLowerCase() == 'prod' ||
        profile == 'secure-vm') {
      return 'vm';
    }
    if (browser == 'host' || browser == 'vm') {
      return browser;
    }
    if (runtime == 'vm') return 'vm';
    return 'host';
  }

  bool get browserExtensionConnected =>
      browserExtensionStatus['connected'] == true;

  bool get smarterSelector => settings['smarter_model_selector'] != false;

  Map<String, AiProviderConfig> get aiProviderConfigs {
    final raw = settings['ai_provider_configs'];
    final decoded = raw is Map
        ? raw.map(
            (key, value) => MapEntry(
              key.toString(),
              AiProviderConfig.fromJson(key.toString(), value),
            ),
          )
        : const <String, AiProviderConfig>{};

    if (aiProviders.isEmpty) {
      return decoded;
    }

    return <String, AiProviderConfig>{
      for (final provider in aiProviders)
        provider.id:
            decoded[provider.id] ?? AiProviderConfig.empty(provider.id),
    };
  }

  List<String> get enabledModelIds {
    final raw = settings['enabled_models'];
    if (raw is List) {
      final knownIds = supportedModels.map((model) => model.id).toSet();
      final filtered = raw
          .map((item) => item.toString())
          .where((id) => knownIds.contains(id))
          .toList();
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }
    return supportedModels
        .where((model) => model.available)
        .map((model) => model.id)
        .toList();
  }

  String get defaultChatModel =>
      settings['default_chat_model']?.toString() ?? 'auto';

  String get defaultSubagentModel =>
      settings['default_subagent_model']?.toString() ?? 'auto';

  String get defaultSpeechModel =>
      settings['default_speech_model']?.toString() ?? 'auto';

  String get defaultRecordingTranscriptionModel =>
      settings['default_recording_transcription_model']?.toString() ?? 'nova-3';

  String get defaultRecordingTranscriptionProvider => _settingString(
    'default_recording_transcription_provider',
    'deepgram',
    lowercase: true,
  );

  String get defaultRecordingSummaryModel =>
      settings['default_recording_summary_model']?.toString() ?? 'auto';

  String get defaultRecordingSummaryProvider => _settingString(
    'default_recording_summary_provider',
    'auto',
    lowercase: true,
  );

  String get fallbackModel =>
      settings['fallback_model_id']?.toString() ??
      _firstAvailableModelId(supportedModels);

  String get voiceSttProvider =>
      _settingString('voice_stt_provider', 'openai', lowercase: true);

  String get voiceSttModel =>
      _settingString('voice_stt_model', 'gpt-4o-transcribe');

  String get voiceTtsProvider =>
      _settingString('voice_tts_provider', 'openai', lowercase: true);

  String get voiceTtsModel =>
      _settingString('voice_tts_model', 'gpt-4o-mini-tts');

  String get voiceTtsVoice => _settingString('voice_tts_voice', 'alloy');

  String get voiceRuntimeMode => 'live';

  String get voiceLiveProvider =>
      _settingString('voice_live_provider', 'openai', lowercase: true);

  String get voiceLiveModel => _settingString(
    'voice_live_model',
    (_voiceLiveModelsByProvider[voiceLiveProvider] ??
            _voiceLiveModelsByProvider['openai']!)
        .first,
  );

  String get voiceLiveVoice => _settingString(
    'voice_live_voice',
    (_voiceLiveVoicesByProvider[voiceLiveProvider] ??
            _voiceLiveVoicesByProvider['openai']!)
        .first,
  );

  bool get isLiveVoiceCaptureStarting => _isStartingLiveVoice;

  bool get isLiveVoiceCaptureActive => _liveVoiceCaptureActive;

  DateTime? get liveVoiceCaptureStartedAt => _liveVoiceCaptureStartedAt;

  String get accountLabel =>
      user?['username']?.toString() ?? username.ifEmpty('NeoAgent User');

  String get modelIndicator {
    if (defaultChatModel != 'auto') {
      final selected = _modelById(defaultChatModel);
      return selected?.label ?? defaultChatModel;
    }
    return smarterSelector ? 'Smart selector active' : 'Manual routing';
  }

  bool get showHealthSection =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _syncBackgroundHealthConfig() async {
    final cookie = _backendClient.sessionCookie ?? '';
    await _prefs?.setString('health_sync_backend_url', backendUrl);
    await _prefs?.remove('health_sync_session_cookie');
    final enabled =
        isAuthenticated &&
        showHealthSection &&
        (deviceHealthStatus?.permissionsGranted ?? false);
    await _prefs?.setBool('health_sync_enabled', enabled);
    await _healthBridge.configureBackgroundSync(
      enabled: enabled,
      backendUrl: backendUrl,
      sessionCookie: cookie,
    );
  }

  Future<void> _syncHomeWidgetConfig() async {
    final cookie = _backendClient.sessionCookie ?? '';
    final enabled =
        isAuthenticated &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android;
    await _widgetBridge.configureHomeWidgets(
      enabled: enabled,
      backendUrl: backendUrl,
      sessionCookie: cookie,
    );
    if (enabled) {
      await _maybeSyncHomeWidgets();
    }
  }

  Future<void> _maybeSyncHomeWidgets({bool force = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (!isAuthenticated) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastHomeWidgetSyncAt != null &&
        now.difference(_lastHomeWidgetSyncAt!) < _homeWidgetSyncCooldown) {
      return;
    }
    _lastHomeWidgetSyncAt = now;
    await _widgetBridge.syncNow();
  }

  Stream<String> get widgetOpenRequests => _widgetBridge.openWidgetRequests;

  List<ChatEntry> get visibleChatMessages {
    final entries = <ChatEntry>[...chatMessages];
    if (streamingAssistant.trim().isNotEmpty) {
      entries.add(
        ChatEntry(
          id: '',
          role: 'assistant',
          content: streamingAssistant,
          platform: 'live',
          createdAt: DateTime.now(),
          transient: true,
        ),
      );
    }
    return entries;
  }

  ModelMeta? _modelById(String id) {
    for (final model in supportedModels) {
      if (model.id == id) {
        return model;
      }
    }
    return null;
  }

  void _ensureUpdatePolling() {
    _updatePollTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (isAuthenticated) {
        refreshUpdateStatus();
      }
    });
  }

  void _disconnectSocket() {
    socketConnected = false;
    if (_liveVoiceSessionOpenCompleter != null &&
        !_liveVoiceSessionOpenCompleter!.isCompleted) {
      _liveVoiceSessionOpenCompleter!.completeError(
        StateError('Live voice connection was closed.'),
      );
    }
    _liveVoiceSessionOpenCompleter = null;
    _socket?.dispose();
    _socket = null;
  }

  void _ensureSocketConnected() {
    final origin = _socketOrigin();
    final existing = _socket?.io.uri;
    if (_socket != null && socketConnected && existing == origin) {
      return;
    }

    _disconnectSocket();

    final options = <String, dynamic>{
      'transports': <String>['websocket', 'polling'],
      'autoConnect': false,
      'withCredentials': true,
    };

    final cookie = _backendClient.sessionCookie;
    if (!kIsWeb && cookie != null && cookie.isNotEmpty) {
      options['extraHeaders'] = <String, String>{'Cookie': cookie};
    }

    final socket = io.io(origin, options);
    socket.onConnect((_) {
      socketConnected = true;
      socket.emit('client:request_logs');
      socket.emit('integrations:status');
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        transportState: 'connected',
        clearError: _hasRecoverableLiveVoiceTurn(),
      );
      if (_hasRecoverableLiveVoiceTurn()) {
        unawaited(
          ensureLiveVoiceSession().catchError((Object error) {
            voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
              transportState: 'disconnected',
              state: 'error',
              error: _friendlyErrorMessage(error),
            );
            notifyListeners();
          }),
        );
      }
      notifyListeners();
    });
    socket.onDisconnect((_) {
      socketConnected = false;
      if (_hasRecoverableLiveVoiceTurn()) {
        _setLiveVoiceRecoveryWindow();
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          sessionId: '',
          transportState: hasNetworkConnection
              ? 'reconnecting'
              : 'disconnected',
          state: _liveVoiceCaptureActive
              ? 'listening'
              : voiceAssistantLiveState.state,
        );
      } else {
        _liveVoiceCaptureActive = false;
        _pendingLiveVoiceStop = false;
        voiceAssistantLiveState = VoiceAssistantLiveState(
          transportState: hasNetworkConnection
              ? 'disconnected'
              : 'disconnected',
        );
      }
      notifyListeners();
    });
    socket.onConnectError((dynamic _) {
      socketConnected = false;
      if (_hasRecoverableLiveVoiceTurn()) {
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          transportState: 'reconnecting',
        );
      }
      notifyListeners();
    });
    socket.on('server:log_history', (dynamic data) {
      final next = <LogEntry>[];
      if (data is List) {
        for (final item in data) {
          next.add(LogEntry.fromJson(_jsonMap(item)));
        }
      }
      _setServerLogs(next);
      notifyListeners();
    });
    socket.on('server:log', (dynamic data) {
      _appendServerLog(LogEntry.fromJson(_jsonMap(data)));
      notifyListeners();
    });
    socket.on('messaging:qr', (dynamic data) {
      final payload = _jsonMap(data);
      pendingMessagingQr = MessagingQrState(
        platform: payload['platform']?.toString() ?? 'whatsapp',
        qr: payload['qr']?.toString() ?? '',
      );
      notifyListeners();
    });
    socket.on('messaging:connected', (dynamic _) {
      pendingMessagingQr = null;
      unawaited(refreshMessaging());
    });
    socket.on('messaging:disconnected', (dynamic _) {
      pendingMessagingQr = null;
      unawaited(refreshMessaging());
    });
    socket.on('messaging:logged_out', (dynamic _) {
      pendingMessagingQr = null;
      unawaited(refreshMessaging());
    });
    socket.on('integrations:status', (dynamic data) {
      officialIntegrations = _decodeModelList(
        'official_integrations.socket',
        data,
        OfficialIntegrationItem.fromJson,
      );
      notifyListeners();
    });
    socket.on('messaging:sent', (dynamic data) {
      final payload = _jsonMap(data);
      messagingMessages = <MessagingMessage>[
        MessagingMessage.fromSocket(payload, outgoing: true),
        ...messagingMessages,
      ];
      _appendAssistantChatMessage(
        payload['content']?.toString() ?? '',
        platform:
            payload['platform']?.toString().ifEmpty('webchat') ?? 'webchat',
      );
      notifyListeners();
    });
    socket.on('messaging:message', (dynamic data) {
      final payload = _jsonMap(data);
      messagingMessages = <MessagingMessage>[
        MessagingMessage.fromSocket(payload, outgoing: false),
        ...messagingMessages,
      ];
      _appendUserChatMessage(
        payload['content']?.toString() ?? '',
        platform:
            payload['platform']?.toString().ifEmpty('webchat') ?? 'webchat',
      );
      notifyListeners();
    });
    socket.on('messaging:blocked_sender', (dynamic data) {
      final blockedNotice = BlockedSenderNotice.fromSocket(_jsonMap(data));
      final blocked = MessagingMessage.fromBlockedNotice(blockedNotice);
      messagingMessages = <MessagingMessage>[blocked, ...messagingMessages];
      _enqueueBlockedSenderNotice(blockedNotice);
      errorMessage =
          '${blocked.senderLabel} is blocked on ${blocked.platform.toUpperCase()}. Update the access list to allow replies.';
      notifyListeners();
    });
    socket.on('messaging:error', (dynamic data) {
      final payload = _jsonMap(data);
      errorMessage =
          payload['error']?.toString() ?? 'Messaging error. Please try again.';
      notifyListeners();
    });
    socket.on('recordings:updated', (dynamic data) {
      final payload = _jsonMap(data);
      final sessionId = payload['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) {
        unawaited(refreshRecordings());
        return;
      }
      unawaited(_refreshRecordingSessionById(sessionId));
    });
    socket.on('voice:session_ready', (dynamic data) {
      final payload = _jsonMap(data);
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        sessionId: payload['sessionId']?.toString() ?? '',
        runtimeMode:
            payload['runtimeMode']?.toString().ifEmpty('live') ?? 'live',
        provider:
            payload['provider']?.toString().ifEmpty(voiceLiveProvider) ??
            voiceLiveProvider,
        model:
            payload['model']?.toString().ifEmpty(voiceLiveModel) ??
            voiceLiveModel,
        voice:
            payload['voice']?.toString().ifEmpty(voiceLiveVoice) ??
            voiceLiveVoice,
        transportState: 'connected',
        state: 'idle',
        clearError: true,
      );
      if (_liveVoiceSessionOpenCompleter != null &&
          !_liveVoiceSessionOpenCompleter!.isCompleted) {
        _liveVoiceSessionOpenCompleter!.complete();
      }
      if (_hasRecoverableLiveVoiceTurn()) {
        unawaited(_restoreBufferedLiveVoiceTurnToActiveSession());
      }
      notifyListeners();
    });
    socket.on('voice:assistant_state', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        state: payload['state']?.toString().ifEmpty('idle') ?? 'idle',
      );
      notifyListeners();
    });
    socket.on('voice:chunk_ack', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final ackTurnId = payload['turnId']?.toString().trim() ?? '';
      if (ackTurnId.isEmpty || ackTurnId != (_liveVoiceTurnId ?? '').trim()) {
        return;
      }
      _liveVoiceAckThrough = math.max(
        _liveVoiceAckThrough,
        _asInt(payload['receivedThrough']),
      );
      for (final chunk in _liveVoiceBufferedChunks) {
        if (chunk.sequence <= _liveVoiceAckThrough) {
          chunk.sent = true;
        }
      }
      unawaited(_emitPendingLiveVoiceCommitIfReady());
    });
    socket.on('voice:transcript_partial', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        partialTranscript: payload['content']?.toString() ?? '',
      );
      notifyListeners();
    });
    socket.on('voice:transcript_final', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final content = payload['content']?.toString() ?? '';
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        partialTranscript: content,
        finalTranscript: content,
      );
      if (content.trim().isNotEmpty) {
        _appendUserChatMessage(content, platform: 'voice_live');
      }
      notifyListeners();
    });
    socket.on('voice:assistant_text', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final content = payload['content']?.toString() ?? '';
      final kind = payload['kind']?.toString() ?? 'final';
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        interimAssistantText: kind == 'final'
            ? voiceAssistantLiveState.interimAssistantText
            : content,
        finalAssistantText: kind == 'final'
            ? content
            : voiceAssistantLiveState.finalAssistantText,
        assistantText: content,
      );
      if (kind == 'final' && content.trim().isNotEmpty) {
        _resetLiveVoiceTurnBuffer();
        _appendAssistantChatMessage(content, platform: 'voice_live');
      }
      notifyListeners();
    });
    socket.on('voice:audio_chunk', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      final audioBase64 = payload['audioBase64']?.toString() ?? '';
      if (audioBase64.trim().isEmpty) return;
      final chunk = base64Decode(audioBase64);
      if (chunk.isEmpty) return;
      final mimeType = payload['mimeType']?.toString() ?? 'audio/mpeg';
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        audioMimeType: mimeType,
        audioQueue: <Uint8List>[...voiceAssistantLiveState.audioQueue, chunk],
        audioStreamDone: false,
      );
      notifyListeners();
    });
    socket.on('voice:audio_done', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        audioStreamDone: true,
      );
      notifyListeners();
    });
    socket.on('voice:error', (dynamic data) {
      final payload = _jsonMap(data);
      if (!_matchesLiveVoiceSessionPayload(payload)) {
        return;
      }
      _resetLiveVoiceTurnBuffer();
      final message = payload['error']?.toString() ?? 'Live voice failed.';
      if (_liveVoiceSessionOpenCompleter != null &&
          !_liveVoiceSessionOpenCompleter!.isCompleted) {
        _liveVoiceSessionOpenCompleter!.completeError(StateError(message));
      }
      _liveVoiceSessionOpenCompleter = null;
      voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
        error: message,
        state: payload['phase']?.toString() == 'tts' ? 'degraded' : 'idle',
        clearAudio: true,
        clearRecoverableUntil: true,
      );
      _liveVoiceCaptureActive = false;
      _pendingLiveVoiceStop = false;
      errorMessage = message;
      notifyListeners();
    });
    socket.on('run:start', (dynamic data) {
      final payload = _jsonMap(data);
      final triggerSource = payload['triggerSource']?.toString() ?? '';
      final runId = payload['runId']?.toString() ?? '';
      if (triggerSource == 'voice_live') {
        _voiceRunIds.add(runId);
        return;
      }
      final pendingSteeringCount = activeRun?.pendingSteeringCount ?? 0;
      if (_isBackgroundRun(triggerSource)) {
        _backgroundRunIds.add(runId);
        return;
      }
      activeRun = ActiveRunState(
        runId: runId,
        title:
            payload['title']?.toString().ifEmpty('Running task') ??
            'Running task',
        model: payload['model']?.toString() ?? '',
        triggerSource: triggerSource,
        phase: 'Starting',
        iteration: 0,
        pendingSteeringCount: pendingSteeringCount,
      );
      toolEvents = const <ToolEventItem>[];
      streamingAssistant = '';
      isSendingMessage = true;
      notifyListeners();
    });
    socket.on('run:thinking', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(
          phase: 'Thinking',
          iteration: _asInt(payload['iteration']),
        );
        notifyListeners();
      }
    });
    socket.on('run:analysis', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final summary = [
        'mode: ${payload['mode']?.toString() ?? 'execute'}',
        'verification: ${payload['verification_need']?.toString() ?? 'none'}',
        'freshness: ${payload['freshness_risk']?.toString() ?? 'none'}',
      ].join(' | ');
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'analysis-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'analysis',
          type: 'analysis',
          status: 'completed',
          summary: summary,
        ),
      ];
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Analyzing');
      }
      notifyListeners();
    });
    socket.on('run:plan', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final steps = _jsonList(payload['steps'], fallbackToMapValues: true)
          .map((item) {
            if (item is Map) {
              return item['title']?.toString() ?? '';
            }
            return item.toString();
          })
          .where((item) => item.trim().isNotEmpty)
          .take(4)
          .join(' | ');
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'plan-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'plan',
          type: 'planning',
          status: 'completed',
          summary: steps.ifEmpty('Execution plan created.'),
        ),
      ];
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Planning');
      }
      notifyListeners();
    });
    socket.on('run:stopping', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Stopping');
        notifyListeners();
      }
    });
    socket.on('run:tool_start', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final item = ToolEventItem(
        id:
            payload['stepId']?.toString().ifEmpty(
              DateTime.now().microsecondsSinceEpoch.toString(),
            ) ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        toolName: payload['toolName']?.toString() ?? 'tool',
        type: payload['type']?.toString() ?? '',
        status: 'running',
        summary: _summarizeToolArgs(payload['toolArgs']),
      );
      toolEvents = <ToolEventItem>[
        ...toolEvents.where((event) => event.id != item.id),
        item,
      ];
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Running tool');
      }
      notifyListeners();
    });
    socket.on('run:verification', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'verification-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'verification',
          type: 'verification',
          status: payload['status']?.toString() == 'verified'
              ? 'completed'
              : 'failed',
          summary:
              payload['notes']?.toString().ifEmpty(
                'Verification status: ${payload['status']?.toString() ?? 'unknown'}',
              ) ??
              'Verification completed.',
        ),
      ];
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Verifying');
      }
      notifyListeners();
    });
    socket.on('run:subagent', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final newId =
          'subagent-${payload['handle']?.toString() ?? DateTime.now().microsecondsSinceEpoch}';
      final nextEvents = toolEvents
          .where((event) => event.id != newId)
          .toList(growable: true);
      nextEvents.insert(
        0,
        ToolEventItem(
          id: newId,
          toolName: 'subagent',
          type: 'subagent',
          status: payload['status']?.toString() == 'failed'
              ? 'failed'
              : (payload['status']?.toString() == 'running'
                    ? 'running'
                    : 'completed'),
          summary:
              payload['task']?.toString().ifEmpty(
                payload['error']?.toString() ??
                    payload['result']?.toString() ??
                    'Subagent update.',
              ) ??
              'Subagent update.',
        ),
      );
      toolEvents = nextEvents;
      notifyListeners();
    });
    socket.on('run:tool_end', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      final stepId = payload['stepId']?.toString() ?? '';
      final updated = ToolEventItem(
        id: stepId,
        toolName: payload['toolName']?.toString() ?? 'tool',
        type: payload['type']?.toString() ?? '',
        status: payload['status']?.toString() ?? 'completed',
        summary:
            payload['error']?.toString() ??
            _summarizeToolResult(payload['result']),
      );
      var replaced = false;
      final next = toolEvents.map((event) {
        if (event.id == stepId) {
          replaced = true;
          return updated;
        }
        return event;
      }).toList();
      if (!replaced) {
        next.add(updated);
      }
      toolEvents = next;
      final toolName = payload['toolName']?.toString() ?? '';
      final screenshotPath =
          payload['screenshotPath']?.toString() ??
          (payload['result'] is Map
              ? (payload['result'] as Map)['screenshotPath']?.toString()
              : null);
      if (screenshotPath != null && screenshotPath.isNotEmpty) {
        if (toolName.startsWith('browser_')) {
          browserScreenshotPath = screenshotPath;
        } else if (toolName.startsWith('android_')) {
          androidScreenshotPath = screenshotPath;
        }
      }
      if (toolName.startsWith('browser_')) {
        unawaited(refreshDevices());
      } else if (toolName.startsWith('android_')) {
        unawaited(refreshDevices());
      }
      notifyListeners();
    });
    socket.on('run:steer_queued', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'steer-queued-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'steering',
          type: 'note',
          status: 'completed',
          summary:
              'Queued as steering for the current run: ${payload['content']?.toString() ?? ''}',
        ),
      ];
      if (activeRun?.runId == runId || activeRun?.runId == 'pending') {
        activeRun = activeRun!.copyWith(
          pendingSteeringCount: _asInt(payload['pendingCount']),
        );
      }
      notifyListeners();
    });
    socket.on('run:steer_applied', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      toolEvents = <ToolEventItem>[
        ...toolEvents,
        ToolEventItem(
          id: 'steer-applied-${DateTime.now().microsecondsSinceEpoch}',
          toolName: 'steering',
          type: 'note',
          status: 'completed',
          summary: payload['count'] == 1
              ? 'Applied the latest steering update to the current run.'
              : 'Applied ${_asInt(payload['count'])} queued steering updates to the current run.',
        ),
      ];
      if (activeRun?.runId == runId || activeRun?.runId == 'pending') {
        activeRun = activeRun!.copyWith(
          pendingSteeringCount: _asInt(payload['pendingCount']),
          phase: 'Incorporating steering',
        );
      }
      notifyListeners();
    });
    socket.on('run:interim', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      _appendToolNote(payload['message']?.toString() ?? '');
      if (runId.isNotEmpty && activeRun?.runId == runId) {
        final phase = payload['phase']?.toString().trim() ?? '';
        if (phase.isNotEmpty) {
          activeRun = activeRun!.copyWith(phase: phase);
        }
      }
      notifyListeners();
    });
    socket.on('run:assistant_interim', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      final content = payload['content']?.toString() ?? '';
      final kind =
          payload['kind']?.toString().ifEmpty('progress') ?? 'progress';
      final platform = payload['platform']?.toString().ifEmpty('web') ?? 'web';
      _appendAssistantChatMessage(content, platform: platform);
      _appendToolNote(content, toolName: 'interim_$kind');
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(phase: 'Responding');
      }
      notifyListeners();
    });
    socket.on('run:stream', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.contains(runId)) {
        return;
      }
      if (_backgroundRunIds.contains(runId)) {
        return;
      }
      streamingAssistant = payload['content']?.toString() ?? '';
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(
          phase: toolEvents.any((event) => event.status == 'running')
              ? 'Running tool'
              : 'Streaming',
        );
      }
      notifyListeners();
    });
    socket.on('run:complete', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.remove(runId)) {
        return;
      }
      if (_backgroundRunIds.remove(runId)) {
        unawaited(refreshRunsOnly());
        notifyListeners();
        return;
      }
      final content = payload['content']?.toString().trim() ?? '';
      if (content.isNotEmpty) {
        _appendAssistantChatMessage(content, platform: 'web');
      }
      streamingAssistant = '';
      isSendingMessage = false;
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(
          phase: 'Completed',
          pendingSteeringCount: 0,
        );
      }
      unawaited(refreshRunsOnly());
      notifyListeners();
    });
    socket.on('run:stopped', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString() ?? '';
      if (_voiceRunIds.remove(runId)) {
        return;
      }
      if (_backgroundRunIds.remove(runId)) {
        unawaited(refreshRunsOnly());
        notifyListeners();
        return;
      }
      streamingAssistant = '';
      isSendingMessage = false;
      if (activeRun?.runId == runId) {
        activeRun = activeRun!.copyWith(
          phase: 'Stopped',
          pendingSteeringCount: 0,
        );
      }
      unawaited(refreshRunsOnly());
      notifyListeners();
    });
    socket.on('run:error', (dynamic data) {
      final payload = _jsonMap(data);
      final runId = payload['runId']?.toString();
      if (runId != null && _voiceRunIds.remove(runId)) {
        _resetLiveVoiceTurnBuffer();
        voiceAssistantLiveState = voiceAssistantLiveState.copyWith(
          error:
              payload['error']?.toString() ??
              'I could not complete that voice request.',
          state: 'idle',
          clearRecoverableUntil: true,
        );
        notifyListeners();
        return;
      }
      if (runId != null) {
        if (_backgroundRunIds.remove(runId)) {
          unawaited(refreshRunsOnly());
          notifyListeners();
          return;
        }
      }
      streamingAssistant = '';
      activeRun = null;
      isSendingMessage = false;
      errorMessage =
          'I could not complete that request right now. Please try again in a moment.';
      notifyListeners();
    });
    socket.connect();
    _socket = socket;
  }

  bool _isBackgroundRun(String triggerSource) {
    return triggerSource == 'schedule' ||
        triggerSource == 'tasks' ||
        triggerSource == 'messaging';
  }

  String _socketOrigin() {
    final trimmed = backendUrl.trim();
    if (trimmed.isEmpty) {
      final base = Uri.base;
      final port = base.hasPort ? ':${base.port}' : '';
      return '${base.scheme}://${base.host}$port';
    }
    final uri = Uri.parse(trimmed);
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }
}

class _OptimizedScreenshotPayload {
  const _OptimizedScreenshotPayload({
    required this.bytes,
    required this.mimeType,
    required this.resizedOrReencoded,
  });

  final Uint8List bytes;
  final String mimeType;
  final bool resizedOrReencoded;
}

class DevicesPanel extends StatefulWidget {
  const DevicesPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<DevicesPanel> createState() => _DevicesPanelState();
}

class _DevicesPanelState extends State<DevicesPanel> {
  late final TextEditingController _browserUrlController;
  late final TextEditingController _androidLaunchController;
  late final TextEditingController _desktopLaunchController;
  late final TextEditingController _textEntryController;
  Timer? _surfaceFrameTimer;
  _DeviceSurface _surface = _DeviceSurface.browser;

  @override
  void initState() {
    super.initState();
    _browserUrlController = TextEditingController(text: _browserUrlPlaceholder);
    _androidLaunchController = TextEditingController(
      text: _androidLaunchPlaceholder,
    );
    _desktopLaunchController = TextEditingController();
    _textEntryController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrapSurface());
    });
    _surfaceFrameTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshSurfaceFrame());
    });
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _browserUrlController,
      _androidLaunchController,
      _desktopLaunchController,
      _textEntryController,
    ]) {
      controller.dispose();
    }
    _surfaceFrameTimer?.cancel();
    super.dispose();
  }

  bool get _isBrowser => _surface == _DeviceSurface.browser;
  bool get _isDesktop => _surface == _DeviceSurface.desktop;

  bool get _androidOnline {
    final status = widget.controller.androidRuntime;
    final devices = _jsonMapList(status['devices'], fallbackToMapValues: true);
    return devices.any((device) => device['status']?.toString() == 'device');
  }

  bool get _androidStarting =>
      widget.controller.androidRuntime['starting'] == true;

  List<Map<String, dynamic>> get _onlineDesktopDevices => widget
      .controller
      .desktopDevices
      .where((device) => device['online'] == true)
      .toList(growable: false);

  bool get _desktopOnline => _onlineDesktopDevices.isNotEmpty;

  bool get _desktopRequiresSelection =>
      _isDesktop &&
      _onlineDesktopDevices.length > 1 &&
      (widget.controller.selectedDesktopDeviceId ?? '').isEmpty;

  String? get _activeScreenshotPath {
    if (_isBrowser) {
      return widget.controller.browserScreenshotPath;
    }
    if (_isDesktop) {
      return widget.controller.desktopScreenshotPath;
    }
    return widget.controller.androidScreenshotPath;
  }

  Future<void> _bootstrapSurface() async {
    await widget.controller.refreshDevices();
    await _ensurePreview();
  }

  Future<void> _ensurePreview() async {
    final controller = widget.controller;
    if (_isBrowser) {
      if (controller.browserRuntime['launched'] != true) {
        return;
      }
      if ((controller.browserScreenshotPath ?? '').isEmpty) {
        final currentUrl =
            controller.browserRuntime['pageInfo'] is Map<dynamic, dynamic>
            ? (controller.browserRuntime['pageInfo'] as Map)['url']?.toString()
            : null;
        if (currentUrl != null && currentUrl.isNotEmpty) {
          await controller.navigateBrowserRuntime(url: currentUrl);
        } else {
          await controller.screenshotBrowserRuntime();
        }
      }
      return;
    }

    if (_isDesktop) {
      if (_desktopRequiresSelection || !_desktopOnline) {
        return;
      }
      if ((controller.desktopScreenshotPath ?? '').isEmpty) {
        await controller.screenshotDesktopRuntime();
      }
      return;
    }

    if (_androidOnline && (controller.androidScreenshotPath ?? '').isEmpty) {
      await controller.screenshotAndroidRuntime();
    }
  }

  Future<void> _refreshSurfaceFrame() async {
    if (!mounted ||
        widget.controller.selectedSection != AppSection.devices ||
        widget.controller.isRunningDeviceAction ||
        widget.controller.isRefreshingDevices) {
      return;
    }
    if (_isBrowser) {
      await widget.controller.refreshBrowserFrameRuntime();
      return;
    }
    if (_isDesktop) {
      await widget.controller.refreshDesktopFrameRuntime();
      return;
    }
    if (_androidStarting) {
      await widget.controller.refreshDevices();
      if (_androidOnline &&
          (widget.controller.androidScreenshotPath ?? '').isEmpty) {
        await widget.controller.screenshotAndroidRuntime();
      }
      return;
    }
    await widget.controller.refreshAndroidFrameRuntime();
  }

  Future<void> _switchSurface(int delta) async {
    final surfaces = _DeviceSurface.values;
    final currentIndex = surfaces.indexOf(_surface);
    final nextIndex = (currentIndex + delta) % surfaces.length;
    setState(
      () =>
          _surface = surfaces[nextIndex < 0 ? surfaces.length - 1 : nextIndex],
    );
    await _ensurePreview();
  }

  Future<void> _openPrimary() async {
    final controller = widget.controller;
    if (_isBrowser) {
      await controller.navigateBrowserRuntime(
        url: _browserUrlController.text.trim(),
      );
      return;
    }

    if (_isDesktop) {
      if (_desktopRequiresSelection) {
        final selectedId = widget.controller.selectedDesktopDeviceId;
        if ((selectedId ?? '').isEmpty && _onlineDesktopDevices.length == 1) {
          await controller.selectDesktopDeviceRuntime(
            _onlineDesktopDevices.first['deviceId']?.toString() ?? '',
          );
        } else {
          await controller.openDesktopSelectionRuntime();
        }
        return;
      }
      if (!_desktopOnline) {
        return;
      }
      final selectedId = widget.controller.selectedDesktopDeviceId;
      if ((selectedId ?? '').isEmpty && _onlineDesktopDevices.length == 1) {
        await controller.selectDesktopDeviceRuntime(
          _onlineDesktopDevices.first['deviceId']?.toString() ?? '',
        );
      }
      final raw = _desktopLaunchController.text.trim();
      if (raw.isNotEmpty) {
        await controller.launchDesktopAppRuntime(raw);
        return;
      }
      await controller.observeDesktopRuntime();
      return;
    }

    if (!_androidOnline) {
      await controller.startAndroidRuntime();
      await widget.controller.refreshDevices();
      if (_androidOnline) {
        await controller.screenshotAndroidRuntime();
      }
      return;
    }

    final raw = _androidLaunchController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      await controller.openAndroidIntentRuntime(
        action: 'android.intent.action.VIEW',
        dataUri: raw,
      );
      return;
    }
    await controller.openAndroidAppRuntime(packageName: raw);
  }

  Future<void> _sleepPrimary() async {
    final controller = widget.controller;
    if (_isBrowser) {
      if (controller.browserRuntime['launched'] != true) {
        return;
      }
      await controller.closeBrowserRuntime();
      return;
    }
    if (_isDesktop) {
      final selectedId = widget.controller.selectedDesktopDeviceId;
      if ((selectedId ?? '').isNotEmpty) {
        await controller.pauseDesktopDeviceRuntime(selectedId!);
      }
      return;
    }
    if (!_androidOnline) {
      return;
    }
    await controller.stopAndroidRuntime();
  }

  Future<void> _sendText() async {
    final text = _textEntryController.text;
    if (text.trim().isEmpty) {
      return;
    }
    if (_isBrowser) {
      await widget.controller.typeBrowserTextRuntime(text, pressEnter: true);
    } else if (_isDesktop) {
      await widget.controller.typeDesktopRuntime(text, pressEnter: true);
    } else {
      await widget.controller.typeAndroidRuntime(<String, dynamic>{
        'text': text,
        'pressEnter': true,
      });
    }
  }

  Future<void> _handleTap(Offset point) async {
    if (_isBrowser) {
      await widget.controller.clickBrowserPointRuntime(
        x: point.dx.round(),
        y: point.dy.round(),
      );
      return;
    }
    if (_isDesktop) {
      if (_desktopRequiresSelection) {
        return;
      }
      await widget.controller.clickDesktopRuntime(
        x: point.dx.round(),
        y: point.dy.round(),
      );
      return;
    }
    if (!_androidOnline) {
      await widget.controller.startAndroidRuntime();
      return;
    }
    await widget.controller.tapAndroidRuntime(<String, dynamic>{
      'x': point.dx.round(),
      'y': point.dy.round(),
    });
  }

  Future<void> _handleSwipe(Offset start, Offset end) async {
    if (_isBrowser) {
      await widget.controller.scrollBrowserRuntime(
        deltaY: (start.dy - end.dy).round(),
      );
      return;
    }
    if (_isDesktop) {
      if (_desktopRequiresSelection) {
        return;
      }
      await widget.controller.dragDesktopRuntime(
        x1: start.dx.round(),
        y1: start.dy.round(),
        x2: end.dx.round(),
        y2: end.dy.round(),
      );
      return;
    }
    if (!_androidOnline) {
      return;
    }
    await widget.controller.swipeAndroidRuntime(<String, dynamic>{
      'x1': start.dx.round(),
      'y1': start.dy.round(),
      'x2': end.dx.round(),
      'y2': end.dy.round(),
      'durationMs': 280,
    });
  }

  Future<void> _runQuickAction(String action) async {
    final controller = widget.controller;
    switch (action) {
      case 'browser_refresh':
        await controller.navigateBrowserRuntime(
          url: controller.browserRuntime['pageInfo'] is Map<dynamic, dynamic>
              ? ((controller.browserRuntime['pageInfo'] as Map)['url']
                        ?.toString() ??
                    _browserUrlController.text.trim())
              : _browserUrlController.text.trim(),
        );
        break;
      case 'browser_enter':
        await controller.pressBrowserKeyRuntime('Enter');
        break;
      case 'desktop_enter':
        await controller.pressDesktopKeyRuntime('Return');
        break;
      case 'desktop_escape':
        await controller.pressDesktopKeyRuntime('Escape');
        break;
      case 'android_back':
        await controller.pressAndroidKeyRuntime('back');
        break;
      case 'android_home':
        await controller.pressAndroidKeyRuntime('home');
        break;
      case 'android_recent':
        await controller.pressAndroidKeyRuntime('app_switch');
        break;
      case 'surface_refresh':
        await _ensurePreview();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final browserStatus = controller.browserRuntime;
    final prefersExtension = controller.browserBackend == 'extension';
    final extensionConnected = controller.browserExtensionConnected;
    final usingExtension = prefersExtension && extensionConnected;
    final browserFallbackLabel = controller.cloudBrowserBackend == 'vm'
        ? 'cloud VM'
        : 'local host';
    final browserPageInfo = browserStatus['pageInfo'] is Map<dynamic, dynamic>
        ? Map<String, dynamic>.from(browserStatus['pageInfo'] as Map)
        : const <String, dynamic>{};
    final selectedDesktopDevice = controller.desktopDevices
        .where(
          (device) => device['deviceId'] == controller.selectedDesktopDeviceId,
        )
        .cast<Map<String, dynamic>?>()
        .firstWhere((device) => device != null, orElse: () => null);
    final desktopDeviceOnline = selectedDesktopDevice?['online'] == true;
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Remote Device',
          subtitle:
              'Tap, swipe, and type directly on the live surface. Use the arrows below to switch between browser, phone, and desktop.',
          trailing: OutlinedButton.icon(
            onPressed:
                controller.isRefreshingDevices ||
                    controller.isRunningDeviceAction
                ? null
                : _bootstrapSurface,
            icon: Icon(Icons.sync),
            label: Text('Sync Surface'),
          ),
        ),
        if (controller.errorMessage case final message?)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _InlineError(message: message),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Card(
              color: _bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: _borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    _DeviceSurfaceHeader(
                      surface: _surface,
                      browserStatus: browserStatus,
                      browserPageInfo: browserPageInfo,
                      androidRuntime: controller.androidRuntime,
                      androidOnline: _androidOnline,
                      desktopRuntime: controller.desktopRuntime,
                      desktopDevices: controller.desktopDevices,
                      selectedDesktopDeviceId:
                          controller.selectedDesktopDeviceId,
                      browserExtensionPreferred: prefersExtension,
                      browserExtensionActive: usingExtension,
                      browserFallbackLabel: browserFallbackLabel,
                    ),
                    if (_isDesktop) ...<Widget>[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedDesktopDevice?['deviceId']
                            ?.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Desktop device',
                          prefixIcon: Icon(Icons.computer_outlined),
                        ),
                        hint: const Text('Select a companion desktop'),
                        items: controller.desktopDevices.map((device) {
                          final deviceId = device['deviceId']?.toString() ?? '';
                          final label =
                              device['label']?.toString().trim().isNotEmpty ==
                                  true
                              ? device['label'].toString()
                              : (device['hostname']?.toString() ?? deviceId);
                          final os =
                              device['platform']?.toString() ?? 'desktop';
                          final state = device['online'] == true
                              ? (device['paused'] == true ? 'paused' : 'online')
                              : 'offline';
                          return DropdownMenuItem<String>(
                            value: deviceId,
                            child: Text('$label · $os · $state'),
                          );
                        }).toList(),
                        onChanged: controller.isRunningDeviceAction
                            ? null
                            : (value) {
                                if (value == null || value.isEmpty) {
                                  return;
                                }
                                unawaited(
                                  controller.selectDesktopDeviceRuntime(value),
                                );
                              },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          _DotStatus(
                            label: desktopDeviceOnline
                                ? 'Companion live'
                                : controller.desktopCompanionConnected
                                ? 'Companion live'
                                : controller.desktopCompanionConnecting
                                ? 'Connecting'
                                : 'Companion idle',
                            color: desktopDeviceOnline
                                ? _success
                                : controller.desktopCompanionConnected
                                ? _success
                                : controller.desktopCompanionConnecting
                                ? _accent
                                : _warning,
                          ),
                          if (selectedDesktopDevice != null)
                            _DotStatus(
                              label: selectedDesktopDevice['paused'] == true
                                  ? 'Paused'
                                  : (selectedDesktopDevice['online'] == true
                                        ? 'Ready'
                                        : 'Offline'),
                              color: selectedDesktopDevice['paused'] == true
                                  ? _warning
                                  : (selectedDesktopDevice['online'] == true
                                        ? _success
                                        : _textMuted),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _DeviceLaunchBar(
                      surface: _surface,
                      controller: _isBrowser
                          ? _browserUrlController
                          : (_isDesktop
                                ? _desktopLaunchController
                                : _androidLaunchController),
                      active: _isBrowser
                          ? browserStatus['launched'] == true
                          : (_isDesktop
                                ? _desktopOnline
                                : _androidOnline || _androidStarting),
                      starting: !_isBrowser && !_isDesktop && _androidStarting,
                      busy: controller.isRunningDeviceAction,
                      onSubmit: _openPrimary,
                      onSleep: _sleepPrimary,
                    ),
                    const SizedBox(height: 18),
                    _InteractiveSurfacePreview(
                      surface: _surface,
                      controller: controller,
                      screenshotPath: _activeScreenshotPath,
                      busy: controller.isRunningDeviceAction,
                      wakingUp: !_isBrowser && !_isDesktop && _androidStarting,
                      enabled: _isBrowser || _isDesktop || _androidOnline,
                      connectRequired: _desktopRequiresSelection,
                      onTapPoint: _handleTap,
                      onSwipe: _handleSwipe,
                      onWakeRequested: _openPrimary,
                    ),
                    if (!_isBrowser && !_isDesktop) ...<Widget>[
                      const SizedBox(height: 12),
                      _AndroidNavDock(
                        busy: controller.isRunningDeviceAction,
                        androidOnline: _androidOnline,
                        onAction: _runQuickAction,
                      ),
                      if (kIsWeb) ...<Widget>[
                        const SizedBox(height: 14),
                        AndroidApkDropZone(
                          enabled: _androidOnline,
                          busy: controller.isRunningDeviceAction,
                          onInstall: ({required filename, required bytes}) {
                            return controller.installAndroidApkRuntime(
                              filename: filename,
                              bytes: bytes,
                            );
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),
                    _DeviceTypeDock(
                      controller: _textEntryController,
                      busy: controller.isRunningDeviceAction,
                      surface: _surface,
                      onSubmit: _sendText,
                    ),
                    if (_isBrowser || _isDesktop) ...<Widget>[
                      const SizedBox(height: 14),
                      _DeviceQuickActions(
                        surface: _surface,
                        androidOnline: _androidOnline,
                        busy: controller.isRunningDeviceAction,
                        onAction: _runQuickAction,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _SurfaceSwitcher(
                      surface: _surface,
                      onPrevious: () => _switchSurface(-1),
                      onNext: () => _switchSurface(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _DeviceSurface { browser, android, desktop }

extension _DeviceSurfaceX on _DeviceSurface {
  String get label => switch (this) {
    _DeviceSurface.browser => 'Browser',
    _DeviceSurface.android => 'Phone',
    _DeviceSurface.desktop => 'Desktop',
  };

  String get helper => switch (this) {
    _DeviceSurface.browser => 'Tap to click. Drag to scroll.',
    _DeviceSurface.android => 'Tap to touch. Drag to swipe.',
    _DeviceSurface.desktop =>
      'Tap to click. Drag to drag windows or selections.',
  };

  IconData get icon => switch (this) {
    _DeviceSurface.browser => Icons.language_outlined,
    _DeviceSurface.android => Icons.smartphone_outlined,
    _DeviceSurface.desktop => Icons.computer_outlined,
  };
}

class _DeviceSurfaceHeader extends StatelessWidget {
  const _DeviceSurfaceHeader({
    required this.surface,
    required this.browserStatus,
    required this.browserPageInfo,
    required this.androidRuntime,
    required this.androidOnline,
    required this.desktopRuntime,
    required this.desktopDevices,
    required this.selectedDesktopDeviceId,
    required this.browserExtensionPreferred,
    required this.browserExtensionActive,
    required this.browserFallbackLabel,
  });

  final _DeviceSurface surface;
  final Map<String, dynamic> browserStatus;
  final Map<String, dynamic> browserPageInfo;
  final Map<String, dynamic> androidRuntime;
  final bool androidOnline;
  final Map<String, dynamic> desktopRuntime;
  final List<Map<String, dynamic>> desktopDevices;
  final String? selectedDesktopDeviceId;
  final bool browserExtensionPreferred;
  final bool browserExtensionActive;
  final String browserFallbackLabel;

  @override
  Widget build(BuildContext context) {
    final androidStarting = androidRuntime['starting'] == true;
    final androidVersion = _androidRuntimeVersionLabel(androidRuntime);
    final selectedDesktop = desktopDevices
        .where((device) => device['deviceId'] == selectedDesktopDeviceId)
        .cast<Map<String, dynamic>?>()
        .firstWhere((device) => device != null, orElse: () => null);
    final desktopOnlineCount = desktopDevices
        .where((device) => device['online'] == true)
        .length;
    final title = switch (surface) {
      _DeviceSurface.browser =>
        (browserPageInfo['title']?.toString().trim().isNotEmpty ?? false)
            ? browserPageInfo['title'].toString()
            : 'Live Browser',
      _DeviceSurface.android => 'Android Phone',
      _DeviceSurface.desktop =>
        selectedDesktop?['label']?.toString().trim().isNotEmpty == true
            ? selectedDesktop!['label'].toString()
            : 'Desktop Companion',
    };
    final subtitle = switch (surface) {
      _DeviceSurface.browser =>
        browserExtensionPreferred && !browserExtensionActive
            ? 'No extension device is active. Using the $browserFallbackLabel browser fallback.'
            : (browserPageInfo['url']?.toString() ?? 'Ready for navigation'),
      _DeviceSurface.android =>
        androidOnline
            ? androidVersion == null
                  ? 'Tap and swipe directly on the preview.'
                  : '$androidVersion · Tap and swipe directly on the preview.'
            : androidStarting
            ? (androidRuntime['startupPhase']?.toString().trim().isNotEmpty ??
                      false)
                  ? androidRuntime['startupPhase'].toString()
                  : 'Starting the phone. This can take a little while.'
            : (androidRuntime['lastLogLine']?.toString().trim().isNotEmpty ??
                  false)
            ? androidRuntime['lastLogLine'].toString()
            : androidVersion != null
            ? '$androidVersion selected. Phone is offline.'
            : 'Phone is offline. Open or start it from below.',
      _DeviceSurface.desktop =>
        selectedDesktop == null
            ? desktopOnlineCount > 1
                  ? 'Multiple desktop companions are online. Pick the machine you want to control.'
                  : desktopOnlineCount == 1
                  ? 'One desktop companion is online. Open the surface to fetch the latest frame.'
                  : 'No desktop companion is online. Enable Companion Mode on a signed-in desktop app.'
            : '${selectedDesktop['platform'] ?? 'desktop'} · ${selectedDesktop['hostname'] ?? 'unknown host'}',
    };
    final statusLabel = surface == _DeviceSurface.browser
        ? browserExtensionPreferred && !browserExtensionActive
              ? 'Fallback'
              : browserExtensionActive
              ? 'Extension'
              : (browserStatus['launched'] == true ? 'Live' : 'Sleeping')
        : surface == _DeviceSurface.desktop
        ? selectedDesktop == null
              ? (desktopOnlineCount > 0 ? 'Select Device' : 'Offline')
              : (selectedDesktop['paused'] == true
                    ? 'Paused'
                    : (selectedDesktop['online'] == true ? 'Live' : 'Offline'))
        : (androidOnline
              ? 'Live'
              : androidStarting
              ? 'Starting'
              : 'Offline');
    final statusColor = surface == _DeviceSurface.browser
        ? (browserStatus['launched'] == true ? _success : _warning)
        : surface == _DeviceSurface.desktop
        ? (selectedDesktop?['paused'] == true
              ? _warning
              : (selectedDesktop?['online'] == true ? _success : _warning))
        : (androidOnline ? _success : (androidStarting ? _accent : _warning));

    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _accentMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(surface.icon, color: _textPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _DotStatus(label: statusLabel, color: statusColor),
      ],
    );
  }
}

class _DeviceLaunchBar extends StatelessWidget {
  const _DeviceLaunchBar({
    required this.surface,
    required this.controller,
    required this.active,
    required this.starting,
    required this.busy,
    required this.onSubmit,
    required this.onSleep,
  });

  final _DeviceSurface surface;
  final TextEditingController controller;
  final bool active;
  final bool starting;
  final bool busy;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSleep;

  @override
  Widget build(BuildContext context) {
    final hint = switch (surface) {
      _DeviceSurface.browser => _browserUrlPlaceholder,
      _DeviceSurface.android => _packageOrUrlHint,
      _DeviceSurface.desktop =>
        'Launch an app on the selected desktop (optional)',
    };
    final buttonLabel = switch (surface) {
      _DeviceSurface.browser => 'Open',
      _DeviceSurface.android => starting ? 'Starting...' : 'Launch',
      _DeviceSurface.desktop => 'Refresh',
    };
    final sleepLabel = switch (surface) {
      _DeviceSurface.browser => 'Sleep Browser',
      _DeviceSurface.android => 'Sleep Phone',
      _DeviceSurface.desktop => 'Pause Desktop',
    };
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final input = TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          surface == _DeviceSurface.browser
              ? Icons.travel_explore
              : surface == _DeviceSurface.desktop
              ? Icons.apps_outlined
              : Icons.open_in_new,
        ),
      ),
    );

    final button = FilledButton.icon(
      onPressed: busy || starting ? null : onSubmit,
      icon: Icon(
        surface == _DeviceSurface.browser
            ? Icons.arrow_forward
            : surface == _DeviceSurface.desktop
            ? Icons.desktop_windows_outlined
            : Icons.play_arrow,
      ),
      label: Text(buttonLabel),
    );
    final sleepButton = OutlinedButton.icon(
      onPressed: busy || !active ? null : onSleep,
      icon: Icon(Icons.bedtime_outlined),
      label: Text(sleepLabel),
    );

    if (narrow) {
      return Column(
        children: <Widget>[
          input,
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: button),
              const SizedBox(width: 10),
              Expanded(child: sleepButton),
            ],
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: input),
        const SizedBox(width: 10),
        sleepButton,
        const SizedBox(width: 10),
        button,
      ],
    );
  }
}

class _DeviceTypeDock extends StatelessWidget {
  const _DeviceTypeDock({
    required this.controller,
    required this.busy,
    required this.surface,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final _DeviceSurface surface;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final hint = switch (surface) {
      _DeviceSurface.browser => 'Type into the currently focused field',
      _DeviceSurface.android => 'Type into the current phone field',
      _DeviceSurface.desktop => 'Type into the focused desktop field',
    };
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final input = TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.keyboard_outlined),
      ),
    );

    final button = FilledButton.icon(
      onPressed: busy ? null : onSubmit,
      icon: Icon(Icons.send_rounded),
      label: Text('Send'),
    );

    if (narrow) {
      return Column(
        children: <Widget>[
          input,
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: button),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: input),
        const SizedBox(width: 10),
        button,
      ],
    );
  }
}

class _DeviceQuickActions extends StatelessWidget {
  const _DeviceQuickActions({
    required this.surface,
    required this.androidOnline,
    required this.busy,
    required this.onAction,
  });

  final _DeviceSurface surface;
  final bool androidOnline;
  final bool busy;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final actions = switch (surface) {
      _DeviceSurface.browser => const <MapEntry<String, IconData>>[
        MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
        MapEntry<String, IconData>('browser_refresh', Icons.replay_rounded),
        MapEntry<String, IconData>(
          'browser_enter',
          Icons.keyboard_return_rounded,
        ),
      ],
      _DeviceSurface.desktop => const <MapEntry<String, IconData>>[
        MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
        MapEntry<String, IconData>(
          'desktop_enter',
          Icons.keyboard_return_rounded,
        ),
        MapEntry<String, IconData>('desktop_escape', Icons.close_fullscreen),
      ],
      _DeviceSurface.android => const <MapEntry<String, IconData>>[
        MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
      ],
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((entry) {
        final disabled =
            busy ||
            (surface != _DeviceSurface.browser &&
                entry.key.startsWith('browser_')) ||
            (surface != _DeviceSurface.desktop &&
                entry.key.startsWith('desktop_')) ||
            (!androidOnline && entry.key.startsWith('android_'));
        return InkWell(
          onTap: disabled ? null : () => onAction(entry.key),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: disabled ? _bgSecondary : _bgTertiary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderLight),
            ),
            child: Icon(
              entry.value,
              color: disabled ? _textMuted : _textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AndroidNavDock extends StatelessWidget {
  const _AndroidNavDock({
    required this.busy,
    required this.androidOnline,
    required this.onAction,
  });

  final bool busy;
  final bool androidOnline;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    const actions = <MapEntry<String, IconData>>[
      MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
      MapEntry<String, IconData>('android_back', Icons.arrow_back_rounded),
      MapEntry<String, IconData>('android_home', Icons.home_rounded),
      MapEntry<String, IconData>('android_recent', Icons.crop_square_rounded),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((entry) {
          final disabled =
              busy || (!androidOnline && entry.key.startsWith('android_'));
          return IconButton.filledTonal(
            onPressed: disabled ? null : () => onAction(entry.key),
            icon: Icon(entry.value),
          );
        }).toList(),
      ),
    );
  }
}

class _SurfaceSwitcher extends StatelessWidget {
  const _SurfaceSwitcher({
    required this.surface,
    required this.onPrevious,
    required this.onNext,
  });

  final _DeviceSurface surface;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton.filledTonal(
          onPressed: onPrevious,
          icon: Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              surface.label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(surface.helper, style: TextStyle(color: _textSecondary)),
          ],
        ),
        const SizedBox(width: 14),
        IconButton.filledTonal(
          onPressed: onNext,
          icon: Icon(Icons.arrow_forward_ios_rounded),
        ),
      ],
    );
  }
}

class _InteractiveSurfacePreview extends StatefulWidget {
  const _InteractiveSurfacePreview({
    required this.surface,
    required this.controller,
    required this.screenshotPath,
    required this.busy,
    required this.wakingUp,
    required this.enabled,
    required this.connectRequired,
    required this.onTapPoint,
    required this.onSwipe,
    required this.onWakeRequested,
  });

  final _DeviceSurface surface;
  final NeoAgentController controller;
  final String? screenshotPath;
  final bool busy;
  final bool wakingUp;
  final bool enabled;
  final bool connectRequired;
  final Future<void> Function(Offset point) onTapPoint;
  final Future<void> Function(Offset start, Offset end) onSwipe;
  final Future<void> Function() onWakeRequested;

  @override
  State<_InteractiveSurfacePreview> createState() =>
      _InteractiveSurfacePreviewState();
}

class _InteractiveSurfacePreviewState
    extends State<_InteractiveSurfacePreview> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _pixelSize;
  Uint8List? _imageBytes;
  Object? _imageError;
  Offset? _dragStart;
  Offset? _dragEnd;

  @override
  void initState() {
    super.initState();
    unawaited(_loadImage());
  }

  @override
  void didUpdateWidget(covariant _InteractiveSurfacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenshotPath != widget.screenshotPath) {
      unawaited(_loadImage());
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    super.dispose();
  }

  void _detachImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
  }

  Future<void> _loadImage() async {
    _detachImageListener();
    final path = widget.screenshotPath;
    if (path == null || path.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pixelSize = null;
        _imageBytes = null;
        _imageError = null;
      });
      return;
    }
    try {
      final bytes = await widget.controller.fetchRuntimeAssetBytes(path);
      if (!mounted || widget.screenshotPath != path) {
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageError = null;
        _pixelSize = null;
      });
      final provider = MemoryImage(bytes);
      final stream = provider.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((image, _) {
        if (!mounted || widget.screenshotPath != path) {
          return;
        }
        setState(() {
          _pixelSize = Size(
            image.image.width.toDouble(),
            image.image.height.toDouble(),
          );
        });
      });
      _imageStream = stream;
      _imageListener = listener;
      stream.addListener(listener);
    } catch (error) {
      if (!mounted || widget.screenshotPath != path) {
        return;
      }
      setState(() {
        _imageBytes = null;
        _pixelSize = null;
        _imageError = error;
      });
    }
  }

  Offset? _mapToPixels(Offset localPosition, Size boxSize) {
    final pixelSize = _pixelSize;
    if (pixelSize == null) {
      return null;
    }
    final boxAspect = boxSize.width / boxSize.height;
    final imageAspect = pixelSize.width / pixelSize.height;
    late final double renderWidth;
    late final double renderHeight;
    late final double offsetX;
    late final double offsetY;

    if (boxAspect > imageAspect) {
      renderHeight = boxSize.height;
      renderWidth = renderHeight * imageAspect;
      offsetX = (boxSize.width - renderWidth) / 2;
      offsetY = 0;
    } else {
      renderWidth = boxSize.width;
      renderHeight = renderWidth / imageAspect;
      offsetX = 0;
      offsetY = (boxSize.height - renderHeight) / 2;
    }

    if (localPosition.dx < offsetX ||
        localPosition.dx > offsetX + renderWidth ||
        localPosition.dy < offsetY ||
        localPosition.dy > offsetY + renderHeight) {
      return null;
    }

    return Offset(
      ((localPosition.dx - offsetX) / renderWidth) * pixelSize.width,
      ((localPosition.dy - offsetY) / renderHeight) * pixelSize.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.screenshotPath;
    final hasImage = path != null && path.isNotEmpty;
    final aspectRatio = switch (widget.surface) {
      _DeviceSurface.browser => 16 / 10,
      _DeviceSurface.android => 10 / 16,
      _DeviceSurface.desktop => 16 / 10,
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_bgTertiary, _bgSecondary],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.surface == _DeviceSurface.android ? 640 : 560,
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    if (!hasImage) {
                      return _EmptySurfaceState(
                        surface: widget.surface,
                        enabled: widget.enabled,
                        busy: widget.busy,
                        isLoadingPreview: widget.wakingUp,
                        connectRequired: widget.connectRequired,
                        errorMessage: _imageError?.toString(),
                        onPressed: widget.onWakeRequested,
                      );
                    }
                    final imageBytes = _imageBytes;
                    if (imageBytes == null) {
                      return _EmptySurfaceState(
                        surface: widget.surface,
                        enabled: widget.enabled,
                        busy: widget.busy,
                        isLoadingPreview: _imageError == null,
                        connectRequired: widget.connectRequired,
                        errorMessage: _imageError?.toString(),
                        onPressed: widget.onWakeRequested,
                      );
                    }
                    return GestureDetector(
                      onTapUp: widget.busy
                          ? null
                          : (details) async {
                              final point = _mapToPixels(
                                details.localPosition,
                                boxSize,
                              );
                              if (point != null) {
                                await widget.onTapPoint(point);
                              }
                            },
                      onPanStart: widget.busy
                          ? null
                          : (details) {
                              _dragStart = details.localPosition;
                              _dragEnd = details.localPosition;
                            },
                      onPanUpdate: widget.busy
                          ? null
                          : (details) {
                              _dragEnd = details.localPosition;
                            },
                      onPanEnd: widget.busy
                          ? null
                          : (_) async {
                              final start = _dragStart;
                              final end = _dragEnd;
                              _dragStart = null;
                              _dragEnd = null;
                              if (start == null || end == null) {
                                return;
                              }
                              if ((start - end).distance < 12) {
                                return;
                              }
                              final mappedStart = _mapToPixels(start, boxSize);
                              final mappedEnd = _mapToPixels(end, boxSize);
                              if (mappedStart != null && mappedEnd != null) {
                                await widget.onSwipe(mappedStart, mappedEnd);
                              }
                            },
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Container(color: _bgSecondary),
                          Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xB205080D),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _borderLight),
                              ),
                              child: Text(
                                widget.surface.helper,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _textPrimary),
                              ),
                            ),
                          ),
                          if (widget.busy)
                            const Center(child: CircularProgressIndicator()),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySurfaceState extends StatelessWidget {
  const _EmptySurfaceState({
    required this.surface,
    required this.enabled,
    required this.busy,
    required this.isLoadingPreview,
    required this.connectRequired,
    this.errorMessage,
    required this.onPressed,
  });

  final _DeviceSurface surface;
  final bool enabled;
  final bool busy;
  final bool isLoadingPreview;
  final bool connectRequired;
  final String? errorMessage;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (surface) {
      _DeviceSurface.browser =>
        connectRequired
            ? 'Open Settings'
            : (busy ? 'Opening Browser...' : 'Wake Browser'),
      _DeviceSurface.android =>
        busy
            ? 'Starting Phone...'
            : (enabled ? 'Refresh Phone' : 'Start Phone'),
      _DeviceSurface.desktop =>
        connectRequired
            ? 'Select Desktop'
            : (busy ? 'Refreshing Desktop...' : 'Refresh Desktop'),
    };
    final message = switch ((surface, busy, isLoadingPreview)) {
      (_DeviceSurface.browser, true, _) =>
        'Opening the browser and downloading the first preview...',
      (_DeviceSurface.browser, false, true) =>
        'Downloading the latest browser preview...',
      (_DeviceSurface.desktop, true, _) =>
        'Refreshing the selected desktop companion...',
      (_DeviceSurface.desktop, false, true) =>
        'Downloading the latest desktop preview...',
      (_DeviceSurface.android, true, _) =>
        'Waking the phone and downloading the first preview. This can take a little while.',
      (_DeviceSurface.android, false, true) =>
        'Downloading the latest phone preview...',
      _ =>
        surface == _DeviceSurface.browser
            ? connectRequired
                  ? 'Chrome extension is not connected. Use Settings to download, load, and pair the extension on the remote machine.'
                  : 'Browser is sleeping. Press Open to start it.'
            : surface == _DeviceSurface.desktop
            ? connectRequired
                  ? 'Multiple desktop companions are online. Select a machine before sending clicks or keystrokes.'
                  : (errorMessage != null && errorMessage!.trim().isNotEmpty)
                  ? errorMessage!
                  : 'No desktop frame is loaded yet. Refresh the selected machine to capture a frame.'
            : (errorMessage != null && errorMessage!.trim().isNotEmpty)
            ? errorMessage!
            : 'Phone is offline. Press Start Phone to boot it.',
    };
    return Container(
      color: _bgSecondary,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (busy || isLoadingPreview) ...<Widget>[
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
          ] else
            Icon(surface.icon, size: 46, color: _textSecondary),
          if (!(busy || isLoadingPreview)) const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          if (errorMessage != null &&
              surface == _DeviceSurface.browser &&
              errorMessage!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onPressed,
            icon: Icon(Icons.play_arrow_rounded),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _RuntimeControlCard extends StatelessWidget {
  const _RuntimeControlCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(color: _textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                status,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _BrowserControls extends StatelessWidget {
  const _BrowserControls({
    required this.controller,
    required this.browserStatus,
    required this.browserPageInfo,
    required this.urlController,
    required this.waitForController,
    required this.clickSelectorController,
    required this.clickTextController,
    required this.fillSelectorController,
    required this.fillValueController,
  });

  final NeoAgentController controller;
  final Map<String, dynamic> browserStatus;
  final Map<String, dynamic> browserPageInfo;
  final TextEditingController urlController;
  final TextEditingController waitForController;
  final TextEditingController clickSelectorController;
  final TextEditingController clickTextController;
  final TextEditingController fillSelectorController;
  final TextEditingController fillValueController;

  @override
  Widget build(BuildContext context) {
    final launched = browserStatus['launched'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetaPill(
              label: launched ? 'Launched' : 'Idle',
              icon: Icons.language_outlined,
            ),
            _MetaPill(
              label: 'Pages ${browserStatus['pages'] ?? 0}',
              icon: Icons.filter_none_outlined,
            ),
            _MetaPill(
              label: browserStatus['headless'] == false
                  ? 'Visible window'
                  : 'Headless',
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
        if ((browserPageInfo['url']?.toString().isNotEmpty ?? false) ||
            (browserPageInfo['title']?.toString().isNotEmpty ??
                false)) ...<Widget>[
          const SizedBox(height: 14),
          SelectableText(
            '${browserPageInfo['title'] ?? 'Untitled'}\n${browserPageInfo['url'] ?? ''}',
            style: TextStyle(color: _textSecondary, height: 1.5),
          ),
        ],
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'URL',
              child: TextField(controller: urlController),
            ),
            _DeviceField(
              label: 'Wait For Selector',
              child: TextField(controller: waitForController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.launchBrowserRuntime,
              icon: Icon(Icons.rocket_launch_outlined),
              label: Text('Launch'),
            ),
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.navigateBrowserRuntime(
                      url: urlController.text.trim(),
                      waitFor: waitForController.text.trim(),
                    ),
              icon: Icon(Icons.open_in_browser_outlined),
              label: Text('Navigate'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.screenshotBrowserRuntime,
              icon: Icon(Icons.photo_camera_back_outlined),
              label: Text('Screenshot'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.closeBrowserRuntime,
              icon: Icon(Icons.close),
              label: Text('Close'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Click Selector',
              child: TextField(controller: clickSelectorController),
            ),
            _DeviceField(
              label: 'Click Text',
              child: TextField(controller: clickTextController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.clickBrowserRuntime(
                      selector: clickSelectorController.text.trim(),
                    ),
              child: Text('Click Selector'),
            ),
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.clickBrowserRuntime(
                      text: clickTextController.text.trim(),
                    ),
              child: Text('Click Text'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Type Selector',
              child: TextField(controller: fillSelectorController),
            ),
            _DeviceField(
              label: 'Value',
              child: TextField(controller: fillValueController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.fillBrowserRuntime(
                  selector: fillSelectorController.text.trim(),
                  value: fillValueController.text,
                ),
          icon: Icon(Icons.keyboard_outlined),
          label: Text('Type Into Field'),
        ),
        const SizedBox(height: 18),
        _RuntimePreview(
          title: 'Latest Browser Screenshot',
          screenshotPath: controller.browserScreenshotPath,
          controller: controller,
        ),
        if (controller.browserLastResult?.trim().isNotEmpty ??
            false) ...<Widget>[
          const SizedBox(height: 14),
          _ResultBlock(
            label: 'Last browser result',
            value: controller.browserLastResult!,
          ),
        ],
      ],
    );
  }
}

// ignore: unused_element
class _AndroidControls extends StatelessWidget {
  const _AndroidControls({
    required this.controller,
    required this.androidStatus,
    required this.androidDevices,
    required this.packageController,
    required this.activityController,
    required this.intentActionController,
    required this.intentDataController,
    required this.tapTextController,
    required this.tapDescriptionController,
    required this.tapResourceIdController,
    required this.tapXController,
    required this.tapYController,
    required this.typeTextController,
    required this.typeFieldTextController,
    required this.typeFieldDescriptionController,
    required this.waitTextController,
    required this.keyController,
    required this.swipeX1Controller,
    required this.swipeY1Controller,
    required this.swipeX2Controller,
    required this.swipeY2Controller,
    required this.toInt,
  });

  final NeoAgentController controller;
  final Map<String, dynamic> androidStatus;
  final List<Map<String, dynamic>> androidDevices;
  final TextEditingController packageController;
  final TextEditingController activityController;
  final TextEditingController intentActionController;
  final TextEditingController intentDataController;
  final TextEditingController tapTextController;
  final TextEditingController tapDescriptionController;
  final TextEditingController tapResourceIdController;
  final TextEditingController tapXController;
  final TextEditingController tapYController;
  final TextEditingController typeTextController;
  final TextEditingController typeFieldTextController;
  final TextEditingController typeFieldDescriptionController;
  final TextEditingController waitTextController;
  final TextEditingController keyController;
  final TextEditingController swipeX1Controller;
  final TextEditingController swipeY1Controller;
  final TextEditingController swipeX2Controller;
  final TextEditingController swipeY2Controller;
  final int? Function(String text) toInt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetaPill(
              label: androidStatus['bootstrapped'] == true
                  ? 'SDK Ready'
                  : 'Bootstrap Needed',
              icon: Icons.adb_outlined,
            ),
            _MetaPill(
              label: androidStatus['serial']?.toString().isNotEmpty == true
                  ? androidStatus['serial'].toString()
                  : 'No active serial',
              icon: Icons.phone_android_outlined,
            ),
            _MetaPill(
              label: '${androidDevices.length} device(s)',
              icon: Icons.devices_other_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.startAndroidRuntime,
              icon: Icon(Icons.play_arrow_outlined),
              label: Text('Start Emulator'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.stopAndroidRuntime,
              icon: Icon(Icons.stop_circle_outlined),
              label: Text('Stop'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.screenshotAndroidRuntime,
              icon: Icon(Icons.photo_camera_outlined),
              label: Text('Screenshot'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.dumpAndroidUiRuntime,
              icon: Icon(Icons.data_object_outlined),
              label: Text('Dump UI'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.refreshAndroidApps,
              icon: Icon(Icons.apps_outlined),
              label: Text('Load Apps'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Package',
              child: TextField(controller: packageController),
            ),
            _DeviceField(
              label: 'Activity',
              child: TextField(controller: activityController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.openAndroidAppRuntime(
                      packageName: packageController.text.trim(),
                      activity: activityController.text.trim(),
                    ),
              icon: Icon(Icons.apps),
              label: Text('Open App'),
            ),
            if (controller.androidInstalledApps.isNotEmpty)
              SizedBox(width: 1, height: 1, child: Container()),
          ],
        ),
        if (controller.androidInstalledApps.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.androidInstalledApps.take(10).map((appId) {
              return ActionChip(
                label: Text(appId),
                onPressed: () => packageController.text = appId,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Intent Action',
              child: TextField(controller: intentActionController),
            ),
            _DeviceField(
              label: 'Intent Data',
              child: TextField(controller: intentDataController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.openAndroidIntentRuntime(
                  action: intentActionController.text.trim(),
                  dataUri: intentDataController.text.trim(),
                  packageName: packageController.text.trim(),
                ),
          icon: Icon(Icons.route_outlined),
          label: Text('Open Intent'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Wait For Text',
              child: TextField(controller: waitTextController),
            ),
            _DeviceField(
              label: 'Key',
              child: TextField(controller: keyController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.waitForAndroidRuntime(<String, dynamic>{
                      'text': waitTextController.text.trim(),
                      'timeoutMs': 20000,
                      'intervalMs': 1200,
                    }),
              child: Text('Wait For UI'),
            ),
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.pressAndroidKeyRuntime(
                      keyController.text.trim(),
                    ),
              child: Text('Press Key'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Tap Text',
              child: TextField(controller: tapTextController),
            ),
            _DeviceField(
              label: 'Tap Description',
              child: TextField(controller: tapDescriptionController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Tap Resource Id',
              child: TextField(controller: tapResourceIdController),
            ),
            _DeviceField(
              label: 'Tap X / Y',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: tapXController)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: tapYController)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.tapAndroidRuntime(<String, dynamic>{
                  if (tapTextController.text.trim().isNotEmpty)
                    'text': tapTextController.text.trim(),
                  if (tapDescriptionController.text.trim().isNotEmpty)
                    'description': tapDescriptionController.text.trim(),
                  if (tapResourceIdController.text.trim().isNotEmpty)
                    'resourceId': tapResourceIdController.text.trim(),
                  if (toInt(tapXController.text) != null)
                    'x': toInt(tapXController.text),
                  if (toInt(tapYController.text) != null)
                    'y': toInt(tapYController.text),
                }),
          icon: Icon(Icons.touch_app_outlined),
          label: Text('Tap'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Type Text',
              child: TextField(controller: typeTextController),
            ),
            _DeviceField(
              label: 'Focus Field Text / Description',
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(controller: typeFieldTextController),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: typeFieldDescriptionController,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.typeAndroidRuntime(<String, dynamic>{
                  'text': typeTextController.text,
                  if (typeFieldTextController.text.trim().isNotEmpty)
                    'textSelector': typeFieldTextController.text.trim(),
                  if (typeFieldDescriptionController.text.trim().isNotEmpty)
                    'description': typeFieldDescriptionController.text.trim(),
                  'pressEnter': true,
                }),
          icon: Icon(Icons.keyboard_outlined),
          label: Text('Type'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Swipe X1 / Y1',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: swipeX1Controller)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: swipeY1Controller)),
                ],
              ),
            ),
            _DeviceField(
              label: 'Swipe X2 / Y2',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: swipeX2Controller)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: swipeY2Controller)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.swipeAndroidRuntime(<String, dynamic>{
                  'x1': toInt(swipeX1Controller.text),
                  'y1': toInt(swipeY1Controller.text),
                  'x2': toInt(swipeX2Controller.text),
                  'y2': toInt(swipeY2Controller.text),
                }),
          icon: Icon(Icons.swipe_outlined),
          label: Text('Swipe'),
        ),
        const SizedBox(height: 18),
        _RuntimePreview(
          title: 'Latest Android Screenshot',
          screenshotPath: controller.androidScreenshotPath,
          controller: controller,
        ),
        if (controller.androidUiPreview.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            'Latest UI dump preview',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...controller.androidUiPreview.take(6).map((node) {
            final title = node['text']?.toString().trim().isNotEmpty == true
                ? node['text'].toString()
                : node['description']?.toString().trim().isNotEmpty == true
                ? node['description'].toString()
                : node['resourceId']?.toString().trim().isNotEmpty == true
                ? node['resourceId'].toString()
                : node['className']?.toString() ?? 'node';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Text(
                '$title\n${node['packageName'] ?? ''}',
                style: TextStyle(color: _textSecondary, height: 1.5),
              ),
            );
          }),
        ],
        if (controller.androidLastResult?.trim().isNotEmpty ??
            false) ...<Widget>[
          const SizedBox(height: 14),
          _ResultBlock(
            label: 'Last Android result',
            value: controller.androidLastResult!,
          ),
        ],
      ],
    );
  }
}

class _DeviceFieldRow extends StatelessWidget {
  const _DeviceFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final stacked = MediaQuery.sizeOf(context).width < 860;
    if (stacked) {
      return Column(
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: child,
              ),
            )
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < children.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 12),
          Expanded(child: children[index]),
        ],
      ],
    );
  }
}

class _DeviceField extends StatelessWidget {
  const _DeviceField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _RuntimePreview extends StatelessWidget {
  const _RuntimePreview({
    required this.title,
    required this.screenshotPath,
    required this.controller,
  });

  final String title;
  final String? screenshotPath;
  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    if (screenshotPath == null || screenshotPath!.isEmpty) {
      return _EmptyCard(
        title: title,
        subtitle:
            'Run a screenshot-capable action to preview the live runtime.',
      );
    }

    final uri = controller.resolveRuntimeAsset(screenshotPath!);
    return Card(
      color: _bgSecondary,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              screenshotPath!,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                uri.toString(),
                headers: controller.authenticatedImageHeaders,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) {
                  return Container(
                    height: 220,
                    color: _bgCard,
                    alignment: Alignment.center,
                    child: Text(
                      'Could not load preview image',
                      style: TextStyle(color: _textSecondary),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SelectableText(
            value,
            style: TextStyle(
              fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
              fontSize: 12,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class RecordingsPanel extends StatefulWidget {
  const RecordingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RecordingsPanel> createState() => _RecordingsPanelState();
}

class _RecordingsPanelState extends State<RecordingsPanel> {
  Future<void> _deleteSegment(
    BuildContext context,
    RecordingSessionItem session,
    RecordingTranscriptSegment segment,
  ) async {
    await _confirmDelete(
      context,
      title: 'Delete segment?',
      message:
          'Remove the transcript segment at ${segment.timestampLabel} from "${session.title}"?',
      onConfirm: () =>
          widget.controller.deleteRecordingSegment(session.id, segment.id),
    );
  }

  Future<void> _deleteRecording(
    BuildContext context,
    RecordingSessionItem session,
  ) async {
    await _confirmDelete(
      context,
      title: 'Delete recording?',
      message:
          'Remove the full recording "${session.title}", including audio chunks and transcript data?',
      onConfirm: () => widget.controller.deleteRecordingSession(session.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.controller.recordingRuntime;
    final anyRecordingActive = runtime.active;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        const _SectionTitle('Record meetings and conversations'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _DotStatus(
                      label: anyRecordingActive
                          ? (runtime.paused ? 'Paused' : 'Recording')
                          : 'Idle',
                      color: anyRecordingActive
                          ? (runtime.paused ? _warning : _danger)
                          : _success,
                    ),
                    if (runtime.platformLabel != null &&
                        runtime.platformLabel!.isNotEmpty)
                      Text(
                        runtime.platformLabel!,
                        style: TextStyle(color: _textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  runtime.supportsSystemAudio
                      ? 'Desktop studio mode keeps microphone and system audio as separate live sources, supports background runtime, and exposes a floating control bar for long-running captures.'
                      : 'Choose the best capture mode for the current platform. Existing web and Android flows remain available alongside the new desktop runtime.',
                  style: TextStyle(color: _textSecondary, height: 1.5),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    if (runtime.supportsScreenAndMic)
                      FilledButton.icon(
                        onPressed:
                            widget.controller.isStartingRecording ||
                                runtime.active
                            ? null
                            : widget.controller.startWebRecording,
                        icon: Icon(Icons.desktop_windows_outlined),
                        label: Text('Start screen + mic'),
                      ),
                    if (runtime.supportsScreenAndMic)
                      OutlinedButton.icon(
                        onPressed:
                            widget.controller.isStartingRecording ||
                                runtime.active
                            ? null
                            : widget.controller.startWebMicrophoneRecording,
                        icon: Icon(Icons.graphic_eq_outlined),
                        label: Text('Mic only'),
                      ),
                    if (runtime.supportsBackgroundMic)
                      FilledButton.icon(
                        onPressed:
                            widget.controller.isStartingRecording ||
                                runtime.active
                            ? null
                            : widget.controller.startBackgroundRecording,
                        icon: Icon(Icons.mic_none_outlined),
                        label: Text('Start background mic'),
                      ),
                    if (runtime.supportsSystemAudio)
                      FilledButton.icon(
                        onPressed: widget.controller.canStartDesktopRecording
                            ? widget.controller.startDesktopRecording
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accentAlt,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(Icons.surround_sound_outlined),
                        label: Text('Start desktop studio'),
                      ),
                    if (runtime.supportsBackgroundMic && runtime.active)
                      OutlinedButton.icon(
                        onPressed: runtime.paused
                            ? widget.controller.resumeBackgroundRecording
                            : widget.controller.pauseBackgroundRecording,
                        icon: Icon(
                          runtime.paused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(runtime.paused ? 'Resume' : 'Pause'),
                      ),
                    if (runtime.supportsSystemAudio && runtime.active)
                      OutlinedButton.icon(
                        onPressed: runtime.paused
                            ? widget.controller.resumeDesktopRecording
                            : widget.controller.pauseDesktopRecording,
                        icon: Icon(
                          runtime.paused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(runtime.paused ? 'Resume' : 'Pause'),
                      ),
                    if (runtime.active)
                      OutlinedButton.icon(
                        onPressed: widget.controller.isStoppingRecording
                            ? null
                            : widget.controller.stopRecording,
                        icon: Icon(Icons.stop_circle_outlined),
                        label: Text('Stop'),
                      ),
                    if (runtime.supportsFloatingToolbar)
                      OutlinedButton.icon(
                        onPressed: !runtime.active
                            ? null
                            : (runtime.floatingToolbarVisible
                                  ? widget.controller.hideDesktopFloatingToolbar
                                  : widget
                                        .controller
                                        .showDesktopFloatingToolbar),
                        icon: Icon(
                          runtime.floatingToolbarVisible
                              ? Icons.visibility_off_outlined
                              : Icons.open_in_new_rounded,
                        ),
                        label: Text(
                          runtime.floatingToolbarVisible
                              ? 'Hide floating bar'
                              : 'Show floating bar',
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: widget.controller.refreshRecordings,
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh'),
                    ),
                  ],
                ),
                if (runtime.supportsSystemAudio) ...<Widget>[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _bgSecondary.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Desktop runtime diagnostics',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Permissions, live levels, and background runtime state stay visible here while the floating bar handles quick controls.',
                          style: TextStyle(color: _textSecondary, height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _RecordingPermissionBadge(
                              label: 'Microphone',
                              state: runtime.microphonePermission,
                            ),
                            _RecordingPermissionBadge(
                              label: 'System audio',
                              state: runtime.systemAudioPermission,
                            ),
                            _DotStatus(
                              label: runtime.backgroundRuntimeActive
                                  ? 'Background runtime ready'
                                  : 'Foreground only',
                              color: runtime.backgroundRuntimeActive
                                  ? _success
                                  : _warning,
                            ),
                            _DotStatus(
                              label: runtime.supportsGlobalHotkeys
                                  ? 'Hotkey-ready'
                                  : 'No global hotkeys',
                              color: runtime.supportsGlobalHotkeys
                                  ? _success
                                  : _warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 18,
                          runSpacing: 18,
                          children: <Widget>[
                            _AudioLevelBar(
                              label: 'Microphone',
                              valueDb: runtime.microphoneLevelDb,
                              color: _accent,
                            ),
                            _AudioLevelBar(
                              label: 'System audio',
                              valueDb: runtime.systemAudioLevelDb,
                              color: _accentAlt,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            if ((runtime.selectedInputDeviceName ?? '')
                                .trim()
                                .isNotEmpty)
                              _MetaPill(
                                icon: Icons.mic_external_on_outlined,
                                label:
                                    'Input ${runtime.selectedInputDeviceName!}',
                              ),
                            _MetaPill(
                              icon: Icons.tune_outlined,
                              label:
                                  '${runtime.availableInputDevices.length} input device${runtime.availableInputDevices.length == 1 ? '' : 's'}',
                            ),
                            if (runtime.activeSources.isNotEmpty)
                              _MetaPill(
                                icon: Icons.multitrack_audio_outlined,
                                label: runtime.activeSources.join(' + '),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: widget
                                  .controller
                                  .openDesktopMicrophoneSettings,
                              icon: Icon(Icons.settings_voice_outlined),
                              label: Text('Mic settings'),
                            ),
                            OutlinedButton.icon(
                              onPressed: widget
                                  .controller
                                  .openDesktopSystemAudioSettings,
                              icon: Icon(Icons.speaker_group_outlined),
                              label: Text('System audio settings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (runtime.errorMessage != null &&
                    runtime.errorMessage!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _InlineError(message: runtime.errorMessage!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('Transcription history'),
        const SizedBox(height: 12),
        if (widget.controller.recordingSessions.isEmpty)
          const _EmptyCard(
            title: 'No recordings yet',
            subtitle:
                'Start a recording and your persisted transcripts will appear here with timestamps.',
          )
        else
          ...widget.controller.recordingSessions.map(
            (session) => Padding(
              key: ValueKey<String>(session.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecordingSessionCard(
                controller: widget.controller,
                session: session,
                onRetry:
                    (session.status == 'failed' ||
                        (session.status == 'completed' &&
                            session.transcriptText.trim().isEmpty &&
                            session.transcriptSegments.isEmpty &&
                            session.structuredContent.isEmpty))
                    ? () => widget.controller.retryRecording(session.id)
                    : null,
                onDeleteSegment: (segment) =>
                    _deleteSegment(context, session, segment),
                onDeleteRecording: () => _deleteRecording(context, session),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordingSessionCard extends StatelessWidget {
  const _RecordingSessionCard({
    required this.controller,
    required this.session,
    this.onRetry,
    this.onDeleteSegment,
    this.onDeleteRecording,
  });

  final NeoAgentController controller;
  final RecordingSessionItem session;
  final VoidCallback? onRetry;
  final Future<void> Function(RecordingTranscriptSegment segment)?
  onDeleteSegment;
  final Future<void> Function()? onDeleteRecording;

  @override
  Widget build(BuildContext context) {
    final runtime = controller.recordingRuntime;
    final isLiveSession = runtime.active && runtime.sessionId == session.id;
    final canDeleteRecording = onDeleteRecording != null && !isLiveSession;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        session.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${session.startedAtLabel} • ${session.platformLabel} • ${session.durationLabel}',
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: session.statusLabel,
                  color: session.statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: session.sources
                  .map(
                    (source) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        '${source.label} • ${source.durationLabel}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (session.sources.any(
              (source) => source.mediaKind == 'audio',
            )) ...<Widget>[
              const SizedBox(height: 12),
              _RecordingSourceAudioControls(
                controller: controller,
                session: session,
              ),
            ],
            if (session.lastError != null &&
                session.lastError!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  session.lastError!,
                  style: TextStyle(color: _danger),
                ),
              ),
            if (session.structuredContent.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.auto_awesome, size: 16, color: _accent),
                        const SizedBox(width: 8),
                        Text(
                          'Smart Segments',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (session.structuredContent['summary'] !=
                        null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        'Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.structuredContent['summary'].toString(),
                        style: TextStyle(height: 1.45),
                      ),
                    ],
                    if (session.structuredContent['action_items'] != null &&
                        _getStructuredList(
                          session,
                          'action_items',
                        ).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        'Action Items',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._getStructuredList(session, 'action_items').map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.toString(),
                                  style: TextStyle(height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (session.structuredContent['events'] != null &&
                        _getStructuredList(
                          session,
                          'events',
                        ).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        'Events Mentioned',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._getStructuredList(session, 'events').map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.toString(),
                                  style: TextStyle(height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (session.transcriptSegments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              ...session.transcriptSegments.map(
                (segment) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 88,
                        child: Text(
                          segment.timestampLabel,
                          style: TextStyle(color: _textSecondary),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          segment.displayText,
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                      if (onDeleteSegment != null &&
                          segment.id > 0) ...<Widget>[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            await onDeleteSegment!(segment);
                          },
                          icon: Icon(Icons.delete_outline),
                          tooltip: 'Delete segment',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else if (session.transcriptText.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(session.transcriptText, style: TextStyle(height: 1.45)),
            ] else ...<Widget>[
              const SizedBox(height: 16),
              Text(
                session.status == 'processing'
                    ? 'Transcription is being processed.'
                    : session.status == 'failed'
                    ? 'Transcription failed. Check the error above and retry.'
                    : session.status == 'completed'
                    ? 'Transcription completed but no speech text was returned. You can retry transcription.'
                    : 'Transcript is not available yet.',
                style: TextStyle(color: _textSecondary),
              ),
            ],
            if (onRetry != null || canDeleteRecording) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (onRetry != null)
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: Icon(Icons.replay),
                      label: Text('Retry transcription'),
                    ),
                  if (canDeleteRecording)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await onDeleteRecording!();
                      },
                      icon: Icon(Icons.delete_forever_outlined),
                      label: Text('Delete recording'),
                      style: OutlinedButton.styleFrom(foregroundColor: _danger),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<dynamic> _getStructuredList(RecordingSessionItem session, String key) {
    final value = session.structuredContent[key];
    if (value is List) {
      return value;
    }
    return const [];
  }
}

class _RecordingSourceAudioControls extends StatefulWidget {
  const _RecordingSourceAudioControls({
    required this.controller,
    required this.session,
  });

  final NeoAgentController controller;
  final RecordingSessionItem session;

  @override
  State<_RecordingSourceAudioControls> createState() =>
      _RecordingSourceAudioControlsState();
}

class _RecordingSourceAudioControlsState
    extends State<_RecordingSourceAudioControls> {
  late final AudioPlayer _player;
  String? _activeSourceKey;
  bool _isPlaying = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggleSource(RecordingSourceItem source) async {
    final token = ++_loadToken;
    bool isStale() => !mounted || token != _loadToken;
    if (_isPlaying && _activeSourceKey == source.sourceKey) {
      await _player.stop();
      if (isStale()) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
      return;
    }

    try {
      await _player.stop();
      if (isStale()) {
        return;
      }
      final bytes = await widget.controller.fetchRecordingSourceAudioBytes(
        widget.session.id,
        source.sourceKey,
      );
      if (isStale()) {
        return;
      }
      if (bytes.isEmpty) {
        throw StateError('Audio source is empty.');
      }
      final mime = source.mimeType.trim().isNotEmpty
          ? source.mimeType.trim()
          : null;
      await _player.play(BytesSource(bytes, mimeType: mime));
      if (isStale()) {
        await _player.stop();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = true;
        _activeSourceKey = source.sourceKey;
      });
    } catch (e) {
      if (isStale()) {
        return;
      }
      AppDiagnostics.log(
        'recording.playback',
        'source.play.failed',
        data: <String, Object?>{
          'sessionId': widget.session.id,
          'sourceKey': source.sourceKey,
          'mimeType': source.mimeType,
        },
        error: e,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _activeSourceKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioSources = widget.session.sources
        .where((source) => source.mediaKind == 'audio')
        .toList();
    if (audioSources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: audioSources.map((source) {
        final isActive = _isPlaying && _activeSourceKey == source.sourceKey;
        return OutlinedButton.icon(
          onPressed: () => _toggleSource(source),
          icon: Icon(isActive ? Icons.stop_circle_outlined : Icons.play_arrow),
          label: Text(
            isActive ? 'Stop ${source.label}' : 'Play ${source.label}',
          ),
        );
      }).toList(),
    );
  }
}

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  late final TextEditingController _composerController;
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  int _lastToolCount = 0;
  String _lastStream = '';

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    widget.controller.addListener(_consumeQueuedDraft);
    _consumeQueuedDraft();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_consumeQueuedDraft);
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _consumeQueuedDraft() {
    final draft = widget.controller.takePendingChatDraft();
    if (draft == null || draft.isEmpty) {
      return;
    }
    _composerController
      ..text = draft
      ..selection = TextSelection.collapsed(offset: draft.length);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final messages = controller.visibleChatMessages;
    if (_lastMessageCount != messages.length ||
        _lastToolCount != controller.toolEvents.length ||
        _lastStream != controller.streamingAssistant) {
      _lastMessageCount = messages.length;
      _lastToolCount = controller.toolEvents.length;
      _lastStream = controller.streamingAssistant;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: _pagePadding(context),
            children: <Widget>[
              _PageTitle(
                title: 'Chat',
                subtitle: 'Live agent chat with tool and stream status.',
                trailing: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => controller.setSelectedSection(
                        AppSection.voiceAssistant,
                      ),
                      icon: Icon(Icons.call),
                      label: Text('Call'),
                    ),
                    _MetaPill(
                      label: controller.modelIndicator,
                      icon: Icons.memory_outlined,
                    ),
                    _MetaPill(
                      label: 'Agent: ${controller.activeAgentLabel}',
                      icon: Icons.smart_toy_outlined,
                    ),
                  ],
                ),
              ),
              if (controller.errorMessage != null) ...<Widget>[
                _InlineError(message: controller.errorMessage!),
                const SizedBox(height: 16),
              ],
              if (controller.activeRun != null ||
                  controller.toolEvents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RunStatusPanel(
                    run: controller.activeRun,
                    tools: controller.toolEvents,
                  ),
                ),
              if (messages.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(
                    child: _EmptyState(
                      title: 'How can I help?',
                      subtitle:
                          'Runs, tools, memory, scheduling, skills, and MCP are all available here.',
                    ),
                  ),
                )
              else
                ...messages.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _ChatBubble(
                      entry: entry,
                      onLoadRunDetail: controller.fetchRunDetail,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: _bgPrimary,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                decoration: BoxDecoration(
                  color: _bgTertiary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _composerController,
                        minLines: 1,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: controller.chatComposerHint,
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => controller.setSelectedSection(
                        AppSection.voiceAssistant,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(46, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: _success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Icon(Icons.call_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final task = _composerController.text;
                        _composerController.clear();
                        await controller.sendMessage(task);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(46, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Icon(
                        controller.hasLiveRun
                            ? Icons.alt_route_rounded
                            : Icons.north_east_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      controller.chatStatusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      controller.hasLiveRun
                          ? 'Steering mode'
                          : controller.modelIndicator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessagingPanel extends StatefulWidget {
  const MessagingPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<MessagingPanel> createState() => _MessagingPanelState();
}

MessagingPlatformDescriptor? _messagingPlatformById(String id) {
  for (final platform in messagingPlatforms) {
    if (platform.id == id) return platform;
  }
  return null;
}

class _MessagingPanelState extends State<MessagingPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final groups = [
      const (
        'Text & Chat',
        'Personal channels and direct support surfaces.',
        [
          'whatsapp',
          'signal',
          'imessage',
          'bluebubbles',
          'line',
          'zalo_personal',
        ],
      ),
      const (
        'Community & ChatOps',
        'Team spaces, rooms, channels, and live communities.',
        [
          'discord',
          'telegram',
          'slack',
          'google_chat',
          'teams',
          'matrix',
          'mattermost',
          'irc',
          'twitch',
        ],
      ),
      const (
        'Configurable Webhooks',
        'Bridge any provider that can post and receive webhook payloads.',
        [
          'feishu',
          'nextcloud_talk',
          'nostr',
          'synology_chat',
          'tlon',
          'zalo',
          'wechat',
          'webchat',
        ],
      ),
      const ('Voice', 'Telephony integrations.', ['telnyx']),
    ];
    final query = _searchController.text.trim().toLowerCase();
    final counts = _MessagingStatusCounts.from(controller.messagingStatuses);
    final hasMatches = _hasMessagingMatches(controller, groups, query);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _PageTitle(
          title: 'Messaging',
          subtitle:
              'Connect channels, limit who can reach the agent, and monitor activity.',
          trailing: OutlinedButton.icon(
            onPressed: controller.refreshMessaging,
            icon: Icon(Icons.refresh_rounded),
            label: Text('Refresh'),
          ),
        ),
        const SizedBox(height: 18),
        _MessagingOverviewStrip(counts: counts),
        const SizedBox(height: 16),
        _MessagingToolbar(
          controller: _searchController,
          selectedFilter: _statusFilter,
          onFilterChanged: (value) => setState(() => _statusFilter = value),
          counts: counts,
        ),
        if (controller.pendingMessagingQr != null) ...[
          const SizedBox(height: 18),
          _MessagingQrPanel(qrState: controller.pendingMessagingQr!),
        ],
        const SizedBox(height: 18),
        for (final group in groups)
          Builder(
            builder: (context) {
              final platforms = group.$3
                  .map(_messagingPlatformById)
                  .nonNulls
                  .where((platform) {
                    final status =
                        controller.messagingStatuses[platform.id] ??
                        MessagingPlatformStatus.empty(platform.id);
                    final haystack =
                        '${platform.label} ${platform.subtitle} ${group.$1}'
                            .toLowerCase();
                    return _matchesMessagingStatusFilter(status) &&
                        (query.isEmpty || haystack.contains(query));
                  })
                  .toList(growable: false);
              if (platforms.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MessagingGroupHeader(
                      title: group.$1,
                      subtitle: group.$2,
                      count: platforms.length,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width >= 1380
                            ? 4
                            : width >= 1020
                            ? 3
                            : width >= 700
                            ? 2
                            : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: platforms.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 268,
                              ),
                          itemBuilder: (context, index) {
                            final platform = platforms[index];
                            return _MessagingCard(
                              platform: platform,
                              status:
                                  controller.messagingStatuses[platform.id] ??
                                  MessagingPlatformStatus.empty(platform.id),
                              accessCatalog: controller
                                  .currentMessagingAccessCatalog(platform.id),
                              controller: controller,
                              onConnect: () => _openMessagingConfig(platform),
                              onDisconnect: () => controller
                                  .disconnectMessagingPlatform(platform.id),
                              onLogout: () => controller
                                  .logoutMessagingPlatform(platform.id),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        if (!hasMatches) ...[
          const SizedBox(height: 10),
          const _EmptyCard(
            title: 'No platforms match',
            subtitle:
                'Adjust the search or status filter to see more messaging channels.',
          ),
          const SizedBox(height: 22),
        ],
        _MessagingActivityPanel(messages: controller.messagingMessages),
      ],
    );
  }

  bool _hasMessagingMatches(
    NeoAgentController controller,
    List<(String, String, List<String>)> groups,
    String query,
  ) {
    for (final group in groups) {
      for (final key in group.$3) {
        final platform = _messagingPlatformById(key);
        if (platform == null) continue;
        final status =
            controller.messagingStatuses[platform.id] ??
            MessagingPlatformStatus.empty(platform.id);
        final haystack = '${platform.label} ${platform.subtitle} ${group.$1}'
            .toLowerCase();
        if (_matchesMessagingStatusFilter(status) &&
            (query.isEmpty || haystack.contains(query))) {
          return true;
        }
      }
    }
    return false;
  }

  bool _matchesMessagingStatusFilter(MessagingPlatformStatus? status) {
    final effective = status ?? MessagingPlatformStatus.empty('unknown');
    return switch (_statusFilter) {
      'connected' => effective.isConnected,
      'configured' => effective.status != 'not_configured',
      'attention' => const {
        'connecting',
        'awaiting_qr',
        'logged_out',
        'disconnected',
        'error',
      }.contains(effective.status),
      _ => true,
    };
  }

  Future<void> _openMessagingConfig(
    MessagingPlatformDescriptor platform,
  ) async {
    switch (platform.id) {
      case 'whatsapp':
        await _connectMessagingPlatform(
          platform: 'whatsapp',
          platformLabel: platform.label,
        );
        return;
      case 'telnyx':
        return _openTelnyxConfig();
      default:
        return _openGenericMessagingConfig(platform);
    }
  }

  Future<bool> _connectMessagingPlatform({
    required String platform,
    required String platformLabel,
    Map<String, dynamic>? config,
    Map<String, dynamic>? configSnapshot,
  }) async {
    try {
      await widget.controller.connectMessagingPlatform(
        platform: platform,
        config: config,
        configSnapshot: configSnapshot,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to connect $platformLabel: ${widget.controller._friendlyErrorMessage(error)}',
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _openTelnyxConfig() async {
    final saved = _jsonMap(
      _decodeMaybeJson(widget.controller.settings['telnyx_config']),
    );
    final apiKey = TextEditingController(
      text: saved['apiKey']?.toString() ?? '',
    );
    final phoneNumber = TextEditingController(
      text: saved['phoneNumber']?.toString() ?? '',
    );
    final connectionId = TextEditingController(
      text: saved['connectionId']?.toString() ?? '',
    );
    final webhookUrl = TextEditingController(
      text: saved['webhookUrl']?.toString() ?? widget.controller.backendUrl,
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text('Telnyx Voice'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: apiKey,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'API Key'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneNumber,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: connectionId,
                        decoration: const InputDecoration(
                          labelText: 'Connection ID',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: webhookUrl,
                        decoration: const InputDecoration(
                          labelText: 'Webhook Base URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Voice STT/TTS providers and models are configured in global Settings > Voice.',
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final config = <String, dynamic>{
                      'apiKey': apiKey.text.trim(),
                      'phoneNumber': phoneNumber.text.trim(),
                      'connectionId': connectionId.text.trim(),
                      'webhookUrl': webhookUrl.text.trim(),
                    };
                    final connected = await _connectMessagingPlatform(
                      platform: 'telnyx',
                      platformLabel: 'Telnyx Voice',
                      config: config,
                      configSnapshot: <String, dynamic>{
                        'telnyx_config': jsonEncode(config),
                      },
                    );
                    if (connected && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openGenericMessagingConfig(
    MessagingPlatformDescriptor platform,
  ) async {
    final saved = _jsonMap(
      _decodeMaybeJson(widget.controller.settings[platform.settingsKey]),
    );
    final textControllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};
    for (final field in platform.configFields) {
      final savedValue = saved[field.key];
      if (field.kind == MessagingConfigFieldKind.boolean) {
        boolValues[field.key] =
            savedValue == true || savedValue?.toString() == 'true';
      } else {
        textControllers[field.key] = TextEditingController(
          text: savedValue?.toString() ?? field.defaultValue ?? '',
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(platform.label),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (platform.configFields.isEmpty)
                        Text(
                          'No extra settings are required.',
                          style: TextStyle(color: _textSecondary),
                        )
                      else
                        ...platform.configFields.map((field) {
                          if (field.kind == MessagingConfigFieldKind.boolean) {
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(field.label),
                              value: boolValues[field.key] ?? false,
                              onChanged: (value) {
                                setLocalState(() {
                                  boolValues[field.key] = value;
                                });
                              },
                            );
                          }
                          final controller = textControllers[field.key]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: controller,
                              obscureText:
                                  field.obscure ||
                                  field.kind ==
                                      MessagingConfigFieldKind.password,
                              minLines:
                                  field.kind ==
                                      MessagingConfigFieldKind.multiline
                                  ? 4
                                  : 1,
                              maxLines:
                                  field.kind ==
                                      MessagingConfigFieldKind.multiline
                                  ? 8
                                  : 1,
                              decoration: InputDecoration(
                                labelText: field.label,
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      SelectableText(
                        'Inbound webhook: ${widget.controller.backendUrl}/api/messaging/webhook/${platform.id}',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final config = <String, dynamic>{};
                    for (final entry in textControllers.entries) {
                      final value = entry.value.text.trim();
                      if (value.isNotEmpty) config[entry.key] = value;
                    }
                    for (final entry in boolValues.entries) {
                      config[entry.key] = entry.value;
                    }
                    final connected = await _connectMessagingPlatform(
                      platform: platform.id,
                      platformLabel: platform.label,
                      config: config,
                      configSnapshot: <String, dynamic>{
                        platform.settingsKey: jsonEncode(config),
                      },
                    );
                    if (connected && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MessagingStatusCounts {
  const _MessagingStatusCounts({
    required this.total,
    required this.connected,
    required this.configured,
    required this.attention,
  });

  final int total;
  final int connected;
  final int configured;
  final int attention;

  factory _MessagingStatusCounts.from(
    Map<String, MessagingPlatformStatus> statuses,
  ) {
    var connected = 0;
    var configured = 0;
    var attention = 0;
    for (final platform in messagingPlatforms) {
      final status =
          statuses[platform.id] ?? MessagingPlatformStatus.empty(platform.id);
      if (status.isConnected) connected++;
      if (status.status != 'not_configured') configured++;
      if (const {
        'connecting',
        'awaiting_qr',
        'logged_out',
        'disconnected',
        'error',
      }.contains(status.status)) {
        attention++;
      }
    }
    return _MessagingStatusCounts(
      total: messagingPlatforms.length,
      connected: connected,
      configured: configured,
      attention: attention,
    );
  }
}

class _MessagingOverviewStrip extends StatelessWidget {
  const _MessagingOverviewStrip({required this.counts});

  final _MessagingStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MessagingMetricCard(
        icon: Icons.link_rounded,
        label: 'Connected',
        value: '${counts.connected}',
        helper: '${counts.configured} configured',
        color: _success,
      ),
      _MessagingMetricCard(
        icon: Icons.error_outline_rounded,
        label: 'Needs attention',
        value: '${counts.attention}',
        helper: 'Reconnect or finish setup',
        color: counts.attention > 0 ? _warning : _textSecondary,
      ),
      _MessagingMetricCard(
        icon: Icons.apps_rounded,
        label: 'Available',
        value: '${counts.total}',
        helper: 'Native and webhook channels',
        color: _info,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                cards[index],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: cards[index]),
            ],
          ],
        );
      },
    );
  }
}

class _MessagingMetricCard extends StatelessWidget {
  const _MessagingMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helper,
                  style: TextStyle(color: _textMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagingToolbar extends StatelessWidget {
  const _MessagingToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.counts,
  });

  final TextEditingController controller;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final _MessagingStatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, String)>[
      ('all', 'All ${counts.total}'),
      ('connected', 'Connected ${counts.connected}'),
      ('configured', 'Configured ${counts.configured}'),
      ('attention', 'Attention ${counts.attention}'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 780;
          final search = TextField(
            controller: controller,
            style: TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              labelText: 'Find a platform',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: controller.clear,
                      icon: Icon(Icons.close_rounded),
                    ),
            ),
          );
          final chips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in filters)
                ChoiceChip(
                  label: Text(filter.$2),
                  selected: selectedFilter == filter.$1,
                  onSelected: (_) => onFilterChanged(filter.$1),
                  selectedColor: _accent.withValues(alpha: 0.18),
                  backgroundColor: _bgCard,
                  side: BorderSide(
                    color: selectedFilter == filter.$1
                        ? _accent.withValues(alpha: 0.42)
                        : _borderLight,
                  ),
                  labelStyle: TextStyle(
                    color: selectedFilter == filter.$1
                        ? _textPrimary
                        : _textSecondary,
                    fontWeight: selectedFilter == filter.$1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 12), chips],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 14),
              Flexible(child: chips),
            ],
          );
        },
      ),
    );
  }
}

class _MessagingQrPanel extends StatelessWidget {
  const _MessagingQrPanel({required this.qrState});

  final MessagingQrState qrState;

  @override
  Widget build(BuildContext context) {
    final qrImage = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.network(
        'https://api.qrserver.com/v1/create-qr-code/?data=${Uri.encodeComponent(qrState.qr)}&size=280x280',
        width: 168,
        height: 168,
        fit: BoxFit.contain,
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusPill(label: 'Awaiting scan', color: _warning),
        const SizedBox(height: 12),
        Text(
          'Scan to finish ${qrState.platformLabel}',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep this panel open until the platform confirms the connection.',
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _warning.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 16),
                Center(child: qrImage),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              qrImage,
            ],
          );
        },
      ),
    );
  }
}

class _MessagingGroupHeader extends StatelessWidget {
  const _MessagingGroupHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: _textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StatusPill(label: '$count shown', color: _textSecondary),
      ],
    );
  }
}

class _MessagingActivityPanel extends StatelessWidget {
  const _MessagingActivityPanel({required this.messages});

  final List<MessagingMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Channel Activity',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(label: '${messages.length} events', color: _info),
            ],
          ),
          const SizedBox(height: 14),
          if (messages.isEmpty)
            const _EmptyCard(
              title: 'No recent channel activity',
              subtitle:
                  'Incoming and outgoing channel messages will appear here.',
            )
          else
            Column(
              children: [
                for (final message in messages.take(12))
                  _MessagingActivityItem(message: message),
              ],
            ),
        ],
      ),
    );
  }
}

class _MessagingActivityItem extends StatelessWidget {
  const _MessagingActivityItem({required this.message});

  final MessagingMessage message;

  @override
  Widget build(BuildContext context) {
    final isOutbound = message.outgoing;
    final color = isOutbound ? _accent : _success;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOutbound ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(
                      label: message.platform.toUpperCase(),
                      color: _info,
                    ),
                    Text(
                      message.senderLabel,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      message.createdAtLabel,
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message.content.ifEmpty('[empty]'),
                  style: TextStyle(color: _textSecondary, height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RunsPanel extends StatefulWidget {
  const RunsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<RunsPanel> createState() => _RunsPanelState();
}

class _RunsPanelState extends State<RunsPanel> {
  late final TextEditingController _searchController;
  String? _selectedRunId;
  String _statusFilter = 'all';
  RunDetailSnapshot? _detail;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _syncSelection();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RunsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelection();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _syncSelection();
  }

  List<RunSummary> get _filteredRuns {
    final query = _searchController.text.trim().toLowerCase();
    return widget.controller.recentRuns.where((run) {
      final statusMatches =
          _statusFilter == 'all' ||
          (_statusFilter == 'failed'
              ? run.isFailure
              : run.status.toLowerCase() == _statusFilter);
      if (!statusMatches) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        run.title,
        run.status,
        run.model,
        run.triggerSource,
        run.error,
        run.id,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _syncSelection() {
    final runs = _filteredRuns;
    if (runs.isEmpty) {
      _selectedRunId = null;
      _detail = null;
      return;
    }
    if (_selectedRunId == null ||
        !runs.any((run) => run.id == _selectedRunId)) {
      _selectRun(runs.first.id);
    }
  }

  Future<void> _selectRun(String runId, {bool force = false}) async {
    setState(() {
      _selectedRunId = runId;
      _loadingDetail = true;
    });
    try {
      final detail = await widget.controller.fetchRunDetail(
        runId,
        force: force,
      );
      if (!mounted || _selectedRunId != runId) {
        return;
      }
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted || _selectedRunId != runId) {
        return;
      }
      setState(() {
        _loadingDetail = false;
      });
    }
  }

  Future<void> _refreshRuns() async {
    await widget.controller.refreshRunsOnly();
    if (!mounted) {
      return;
    }
    final selectedRunId = _selectedRunId;
    if (selectedRunId != null &&
        _filteredRuns.any((run) => run.id == selectedRunId)) {
      await _selectRun(selectedRunId, force: true);
    } else {
      _syncSelection();
    }
    setState(() {});
  }

  void _setStatusFilter(String value) {
    setState(() {
      _statusFilter = value;
    });
    _syncSelection();
  }

  Future<void> _copyResponse(String response) async {
    if (response.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: response));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied final response')));
  }

  Future<void> _deleteSelectedRun() async {
    final run = widget.controller.recentRuns.cast<RunSummary?>().firstWhere(
      (item) => item?.id == _selectedRunId,
      orElse: () => null,
    );
    if (run == null) {
      return;
    }
    await _confirmDelete(
      context,
      title: 'Delete run?',
      message:
          'Remove "${run.title}" and its recorded steps from the run history?',
      onConfirm: () async {
        await widget.controller.deleteRun(run.id);
        if (!mounted) {
          return;
        }
        _syncSelection();
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final filteredRuns = _filteredRuns;
    final selected = filteredRuns.cast<RunSummary?>().firstWhere(
      (run) => run?.id == _selectedRunId,
      orElse: () => null,
    );
    final detail = _detail?.run.id == selected?.id ? _detail : null;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Runs',
          subtitle:
              'Inspect recent runs, failures, tool steps, and final responses.',
          trailing: OutlinedButton.icon(
            onPressed: _refreshRuns,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (controller.activeRun != null ||
            controller.toolEvents.isNotEmpty) ...<Widget>[
          _RunStatusPanel(
            run: controller.activeRun,
            tools: controller.toolEvents,
          ),
          const SizedBox(height: 16),
        ],
        if (controller.recentRuns.isEmpty)
          const _EmptyCard(
            title: 'No runs yet',
            subtitle:
                'Send a task from chat and its execution history will show up here.',
          )
        else ...<Widget>[
          _RunsMetricsStrip(
            runs: filteredRuns,
            totalLoaded: controller.recentRuns.length,
          ),
          const SizedBox(height: 16),
          _RunsFilterBar(
            searchController: _searchController,
            statusFilter: _statusFilter,
            onStatusChanged: _setStatusFilter,
          ),
          const SizedBox(height: 16),
          if (filteredRuns.isEmpty)
            const _EmptyCard(
              title: 'No matching runs',
              subtitle:
                  'Try clearing the search or switching the status filter.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1120;
                final historyPane = _RunsHistoryPane(
                  runs: filteredRuns,
                  selectedRunId: _selectedRunId,
                  onSelect: _selectRun,
                );
                final detailPane = _RunDetailWorkspace(
                  run: selected,
                  detail: detail,
                  loading: _loadingDetail,
                  onDelete: _deleteSelectedRun,
                  onCopyResponse: _copyResponse,
                );
                if (!wide) {
                  return Column(
                    children: <Widget>[
                      detailPane,
                      const SizedBox(height: 16),
                      historyPane,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 360, child: historyPane),
                    const SizedBox(width: 16),
                    Expanded(child: detailPane),
                  ],
                );
              },
            ),
        ],
      ],
    );
  }
}

class _MessagingCard extends StatelessWidget {
  const _MessagingCard({
    required this.platform,
    required this.status,
    required this.accessCatalog,
    required this.controller,
    required this.onConnect,
    required this.onDisconnect,
    required this.onLogout,
  });

  final MessagingPlatformDescriptor platform;
  final MessagingPlatformStatus? status;
  final MessagingAccessCatalog accessCatalog;
  final NeoAgentController controller;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final connected = status?.isConnected ?? false;
    final configured = status != null && status!.status != 'not_configured';
    final accent = platform.accent;
    final actionLabel = connected
        ? 'Connected'
        : configured
        ? 'Reconnect'
        : 'Connect';
    final accessLabel = accessCatalog.summary.ifEmpty('Access policy');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: connected ? accent.withValues(alpha: 0.48) : _borderLight,
        ),
        boxShadow: [
          if (connected)
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(platform.icon, color: accent, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform.label,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status?.authLabel ?? 'Not configured',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                label: connected
                    ? 'Live'
                    : configured
                    ? 'Ready'
                    : 'Setup',
                color: connected
                    ? _success
                    : configured
                    ? _warning
                    : _textMuted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            platform.subtitle,
            style: TextStyle(color: _textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MessagingMiniPill(
                icon: Icons.admin_panel_settings_outlined,
                label: accessLabel,
              ),
              if (configured && !connected)
                const _MessagingMiniPill(
                  icon: Icons.tune_rounded,
                  label: 'Configured',
                ),
              if (platform.configFields.isNotEmpty)
                _MessagingMiniPill(
                  icon: Icons.edit_note_rounded,
                  label: '${platform.configFields.length} fields',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: connected
                    ? OutlinedButton.icon(
                        onPressed: onDisconnect,
                        icon: Icon(Icons.link_off_rounded, size: 18),
                        label: Text(
                          'Disconnect',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onConnect,
                        icon: Icon(Icons.power_settings_new_rounded, size: 18),
                        label: Text(
                          actionLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(backgroundColor: accent),
                      ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Access policy',
                onPressed: () => _editAccessPolicy(context, controller),
                icon: Icon(Icons.group_add_outlined),
              ),
              if (platform.id == 'telnyx') ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Voice PIN',
                  onPressed: () => _editTelnyxSecret(context, controller),
                  icon: Icon(Icons.password_outlined),
                ),
              ],
              if (connected) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Logout',
                  onPressed: onLogout,
                  icon: Icon(Icons.logout_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAccessPolicy(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final catalog = await controller.loadMessagingAccessCatalog(
      platform.id,
      force: true,
    );
    if (!context.mounted) return;
    await _showMessagingAccessPolicyDialog(
      context,
      platform: platform,
      initialCatalog: catalog,
      onRefreshCatalog: () =>
          controller.loadMessagingAccessCatalog(platform.id, force: true),
      onSave: (policy) =>
          controller.saveMessagingAccessPolicy(platform.id, policy),
    );
  }

  Future<void> _editTelnyxSecret(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final initial =
        controller.settings['platform_voice_secret_telnyx']?.toString() ?? '';
    final saved = await _showTextSettingDialog(
      context,
      title: 'Voice PIN',
      subtitle:
          'Set the PIN callers must enter before the voice agent answers.',
      label: 'PIN or passphrase',
      initialValue: initial,
      obscureText: true,
    );
    if (saved != null) {
      await controller.saveTelnyxVoiceSecret(saved);
    }
  }
}

class _MessagingRuleSelection {
  const _MessagingRuleSelection({required this.bucket, required this.rule});

  final String bucket;
  final MessagingAccessRule rule;
}

Future<void> _showMessagingAccessPolicyDialog(
  BuildContext context, {
  required MessagingPlatformDescriptor platform,
  required MessagingAccessCatalog initialCatalog,
  required Future<MessagingAccessCatalog> Function() onRefreshCatalog,
  required Future<void> Function(MessagingAccessPolicy policy) onSave,
}) async {
  var catalog = initialCatalog;
  var policy = initialCatalog.policy;

  List<MessagingAccessRule> dedupeRules(List<MessagingAccessRule> rules) {
    final seen = <String>{};
    final result = <MessagingAccessRule>[];
    for (final rule in rules) {
      if (rule.value.trim().isEmpty) continue;
      if (!seen.add(rule.id)) continue;
      result.add(rule);
    }
    return result;
  }

  void addRule(
    _MessagingRuleSelection selection,
    void Function(void Function()) setLocalState,
  ) {
    setLocalState(() {
      switch (selection.bucket) {
        case 'directRules':
          policy = policy.copyWith(
            directPolicy: policy.directPolicy == 'disabled'
                ? 'allowlist'
                : policy.directPolicy,
            directRules: dedupeRules(<MessagingAccessRule>[
              ...policy.directRules,
              selection.rule,
            ]),
          );
          break;
        case 'sharedActorRules':
          policy = policy.copyWith(
            sharedPolicy: policy.sharedPolicy == 'disabled'
                ? 'allowlist'
                : policy.sharedPolicy,
            sharedActorRules: dedupeRules(<MessagingAccessRule>[
              ...policy.sharedActorRules,
              selection.rule,
            ]),
          );
          break;
        default:
          policy = policy.copyWith(
            sharedPolicy: policy.sharedPolicy == 'disabled'
                ? 'allowlist'
                : policy.sharedPolicy,
            sharedSpaceRules: dedupeRules(<MessagingAccessRule>[
              ...policy.sharedSpaceRules,
              selection.rule,
            ]),
          );
      }
    });
  }

  void removeRule(
    String bucket,
    MessagingAccessRule rule,
    void Function(void Function()) setLocalState,
  ) {
    setLocalState(() {
      switch (bucket) {
        case 'directRules':
          policy = policy.copyWith(
            directRules: policy.directRules
                .where((item) => item.id != rule.id)
                .toList(growable: false),
          );
          break;
        case 'sharedActorRules':
          policy = policy.copyWith(
            sharedActorRules: policy.sharedActorRules
                .where((item) => item.id != rule.id)
                .toList(growable: false),
          );
          break;
        default:
          policy = policy.copyWith(
            sharedSpaceRules: policy.sharedSpaceRules
                .where((item) => item.id != rule.id)
                .toList(growable: false),
          );
      }
    });
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final capabilities = catalog.capabilities;
          final summaryText = [
            'DMs ${policy.directPolicy}',
            if (capabilities.supportsSharedPolicy)
              'shared ${policy.sharedPolicy}',
            if (capabilities.supportsMentionGate)
              policy.requireMentionInShared
                  ? 'mentions required'
                  : 'mentions optional',
            if (policy.totalRuleCount > 0) '${policy.totalRuleCount} rules',
          ].join(' • ');

          return AlertDialog(
            backgroundColor: _bgCard,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            title: Text('${platform.label} Access Policy'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MessagingAccessSummaryCard(
                      accent: platform.accent,
                      summary: summaryText,
                      hint: capabilities.manualEntryHint.ifEmpty(
                        'Choose who can reach this platform and how shared spaces behave.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (capabilities.supportsDirectPolicy)
                      _AccessModeField(
                        label: 'Direct messages',
                        value: policy.directPolicy,
                        onChanged: (value) => setLocalState(() {
                          policy = policy.copyWith(directPolicy: value);
                        }),
                      ),
                    if (capabilities.supportsSharedPolicy) ...<Widget>[
                      const SizedBox(height: 12),
                      _AccessModeField(
                        label: 'Shared spaces',
                        value: policy.sharedPolicy,
                        onChanged: (value) => setLocalState(() {
                          policy = policy.copyWith(sharedPolicy: value);
                        }),
                      ),
                    ],
                    if (capabilities.supportsMentionGate) ...<Widget>[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Require mention in shared spaces'),
                        subtitle: Text(
                          'Keep channels quiet until the bot is directly mentioned.',
                          style: TextStyle(color: _textSecondary),
                        ),
                        value: policy.requireMentionInShared,
                        onChanged: (value) => setLocalState(() {
                          policy = policy.copyWith(
                            requireMentionInShared: value,
                          );
                        }),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () async {
                            final selection =
                                await _showMessagingAccessRulePicker(
                                  context,
                                  platform: platform,
                                  catalog: catalog,
                                );
                            if (selection != null) {
                              addRule(selection, setLocalState);
                            }
                          },
                          icon: Icon(Icons.add_rounded),
                          label: Text('Add Rule'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final refreshed = await onRefreshCatalog();
                            if (!context.mounted) return;
                            setLocalState(() {
                              catalog = refreshed;
                            });
                          },
                          icon: Icon(Icons.travel_explore_rounded),
                          label: Text('Refresh Discovery'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _AccessRuleSection(
                      title: 'Direct senders',
                      subtitle: 'Who can start a one-to-one conversation.',
                      rules: policy.directRules,
                      emptyLabel: 'No direct sender rules yet.',
                      onRemove: (rule) =>
                          removeRule('directRules', rule, setLocalState),
                    ),
                    if (capabilities.supportsSharedPolicy) ...<Widget>[
                      const SizedBox(height: 16),
                      _AccessRuleSection(
                        title: 'Shared spaces',
                        subtitle:
                            'Which channels, groups, rooms, or servers can trigger the agent.',
                        rules: policy.sharedSpaceRules,
                        emptyLabel: 'No shared-space rules yet.',
                        onRemove: (rule) =>
                            removeRule('sharedSpaceRules', rule, setLocalState),
                      ),
                      const SizedBox(height: 16),
                      _AccessRuleSection(
                        title: 'Shared actors',
                        subtitle:
                            'Optional extra filter for who inside allowed shared spaces can trigger the agent.',
                        rules: policy.sharedActorRules,
                        emptyLabel: 'No shared-actor rules yet.',
                        onRemove: (rule) =>
                            removeRule('sharedActorRules', rule, setLocalState),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await onSave(policy);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text('Save Policy'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _AccessModeField extends StatelessWidget {
  const _AccessModeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'allowlist', child: Text('Allowlist only')),
            DropdownMenuItem(value: 'open', child: Text('Open access')),
            DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _AccessRuleSection extends StatelessWidget {
  const _AccessRuleSection({
    required this.title,
    required this.subtitle,
    required this.rules,
    required this.emptyLabel,
    required this.onRemove,
  });

  final String title;
  final String subtitle;
  final List<MessagingAccessRule> rules;
  final String emptyLabel;
  final ValueChanged<MessagingAccessRule> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            Text(emptyLabel, style: TextStyle(color: _textMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rules
                  .map((rule) {
                    return Chip(
                      label: Text('${rule.scopeLabel}: ${rule.displayLabel}'),
                      deleteIcon: Icon(Icons.close_rounded, size: 18),
                      onDeleted: () => onRemove(rule),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

Future<_MessagingRuleSelection?> _showMessagingAccessRulePicker(
  BuildContext context, {
  required MessagingPlatformDescriptor platform,
  required MessagingAccessCatalog catalog,
}) async {
  return showModalBottomSheet<_MessagingRuleSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _bgCard,
    builder: (sheetContext) =>
        _MessagingAccessRulePickerSheet(platform: platform, catalog: catalog),
  );
}

class _MessagingAccessRulePickerSheet extends StatefulWidget {
  const _MessagingAccessRulePickerSheet({
    required this.platform,
    required this.catalog,
  });

  final MessagingPlatformDescriptor platform;
  final MessagingAccessCatalog catalog;

  @override
  State<_MessagingAccessRulePickerSheet> createState() =>
      _MessagingAccessRulePickerSheetState();
}

class _MessagingAccessRulePickerSheetState
    extends State<_MessagingAccessRulePickerSheet> {
  late final TextEditingController _queryController;
  late String _selectedBucket;
  late String _selectedScope;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _selectedBucket = widget.catalog.capabilities.directRuleScopes.isNotEmpty
        ? 'directRules'
        : (widget.catalog.capabilities.sharedSpaceRuleScopes.isNotEmpty
              ? 'sharedSpaceRules'
              : 'sharedActorRules');
    _selectedScope = widget.catalog.capabilities.directRuleScopes.isNotEmpty
        ? widget.catalog.capabilities.directRuleScopes.first
        : (widget.catalog.capabilities.sharedSpaceRuleScopes.isNotEmpty
              ? widget.catalog.capabilities.sharedSpaceRuleScopes.first
              : (widget.catalog.capabilities.sharedActorRuleScopes.isNotEmpty
                    ? widget.catalog.capabilities.sharedActorRuleScopes.first
                    : 'chat'));
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<String> _scopesForBucket() {
    switch (_selectedBucket) {
      case 'directRules':
        return widget.catalog.capabilities.directRuleScopes;
      case 'sharedActorRules':
        return widget.catalog.capabilities.sharedActorRuleScopes;
      default:
        return widget.catalog.capabilities.sharedSpaceRuleScopes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableScopes = _scopesForBucket();
    if (!availableScopes.contains(_selectedScope) &&
        availableScopes.isNotEmpty) {
      _selectedScope = availableScopes.first;
    }
    final query = _queryController.text.trim().toLowerCase();
    final targets =
        <MessagingAccessTarget>[
              ...widget.catalog.suggestedTargets,
              ...widget.catalog.discoveredTargets,
            ]
            .where((target) {
              if (target.bucket != _selectedBucket) return false;
              if (query.isEmpty) return true;
              final haystack =
                  '${target.label} ${target.subtitle} ${target.scope} ${target.value}'
                      .toLowerCase();
              return haystack.contains(query);
            })
            .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Add Access Rule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a preset, a discovered target, or enter an id manually for ${widget.platform.label}.',
              style: TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (widget.catalog.capabilities.directRuleScopes.isNotEmpty)
                  ChoiceChip(
                    label: Text('Direct'),
                    selected: _selectedBucket == 'directRules',
                    onSelected: (_) => setState(() {
                      _selectedBucket = 'directRules';
                    }),
                  ),
                if (widget
                    .catalog
                    .capabilities
                    .sharedSpaceRuleScopes
                    .isNotEmpty)
                  ChoiceChip(
                    label: Text('Shared spaces'),
                    selected: _selectedBucket == 'sharedSpaceRules',
                    onSelected: (_) => setState(() {
                      _selectedBucket = 'sharedSpaceRules';
                    }),
                  ),
                if (widget
                    .catalog
                    .capabilities
                    .sharedActorRuleScopes
                    .isNotEmpty)
                  ChoiceChip(
                    label: Text('Shared actors'),
                    selected: _selectedBucket == 'sharedActorRules',
                    onSelected: (_) => setState(() {
                      _selectedBucket = 'sharedActorRules';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Search discovered targets',
              ),
            ),
            const SizedBox(height: 16),
            if (targets.isNotEmpty) ...<Widget>[
              Text(
                'Suggested & discovered',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...targets.take(10).map((target) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(target.label),
                  subtitle: Text(
                    target.subtitle.ifEmpty(
                      '${target.scope} • ${target.value}',
                    ),
                  ),
                  trailing: Icon(Icons.add_circle_outline_rounded),
                  onTap: () => Navigator.of(context).pop(
                    _MessagingRuleSelection(
                      bucket: target.bucket,
                      rule: target.asRule,
                    ),
                  ),
                );
              }),
              const Divider(height: 24),
            ],
            Text('Manual entry', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (availableScopes.isNotEmpty)
              InputDecorator(
                decoration: InputDecoration(labelText: 'Rule scope'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedScope,
                    isExpanded: true,
                    items: availableScopes
                        .map(
                          (scope) => DropdownMenuItem<String>(
                            value: scope,
                            child: Text(scope.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedScope = value);
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'ID / value',
                helperText: widget.catalog.capabilities.manualEntryHint,
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isEmpty) return;
                Navigator.of(context).pop(
                  _MessagingRuleSelection(
                    bucket: _selectedBucket,
                    rule: MessagingAccessRule(
                      scope: _selectedScope,
                      value: trimmed,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _showTextSettingDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String label,
  required String initialValue,
  bool obscureText = false,
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bgCard,
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(subtitle, style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: obscureText,
                decoration: InputDecoration(labelText: label),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

class _MessagingMiniPill extends StatelessWidget {
  const _MessagingMiniPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunsMetricsStrip extends StatelessWidget {
  const _RunsMetricsStrip({required this.runs, required this.totalLoaded});

  final List<RunSummary> runs;
  final int totalLoaded;

  @override
  Widget build(BuildContext context) {
    final running = runs.where((run) => run.status == 'running').length;
    final failed = runs.where((run) => run.isFailure).length;
    final completed = runs.where((run) => run.status == 'completed').length;
    final tokens = runs.fold<int>(0, (sum, run) => sum + run.totalTokens);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _RunMetricCard(
          title: 'Showing',
          value: '${runs.length}',
          helper: totalLoaded == runs.length
              ? 'Recent runs loaded'
              : 'Filtered from $totalLoaded loaded runs',
          color: _info,
        ),
        _RunMetricCard(
          title: 'Completed',
          value: '$completed',
          helper: 'Finished successfully',
          color: _success,
        ),
        _RunMetricCard(
          title: 'Failed',
          value: '$failed',
          helper: 'Need attention',
          color: _danger,
        ),
        _RunMetricCard(
          title: 'Tokens',
          value: _formatNumber(tokens),
          helper: 'Across visible runs',
          color: _accentHover,
        ),
        if (running > 0)
          _RunMetricCard(
            title: 'Running',
            value: '$running',
            helper: 'Still in progress',
            color: _warning,
          ),
      ],
    );
  }
}

class _RunMetricCard extends StatelessWidget {
  const _RunMetricCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.color,
  });

  final String title;
  final String value;
  final String helper;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(helper, style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }
}

class _RunsFilterBar extends StatelessWidget {
  const _RunsFilterBar({
    required this.searchController,
    required this.statusFilter,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    const filters = <String>['all', 'running', 'completed', 'failed'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Filter Runs'),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title, model, trigger, error, or run id',
                suffixIcon: searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: searchController.clear,
                        icon: Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filters.map((filter) {
                return FilterChip(
                  label: Text(_titleCase(filter)),
                  selected: statusFilter == filter,
                  selectedColor: _accentMuted,
                  checkmarkColor: _accent,
                  backgroundColor: _bgSecondary,
                  side: BorderSide(color: _border),
                  onSelected: (_) => onStatusChanged(filter),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunsHistoryPane extends StatelessWidget {
  const _RunsHistoryPane({
    required this.runs,
    required this.selectedRunId,
    required this.onSelect,
  });

  final List<RunSummary> runs;
  final String? selectedRunId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Run History')),
                Text(
                  '${runs.length} items',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...runs.map((run) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RunHistoryRow(
                  run: run,
                  selected: run.id == selectedRunId,
                  onTap: () => onSelect(run.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RunHistoryRow extends StatelessWidget {
  const _RunHistoryRow({
    required this.run,
    required this.selected,
    required this.onTap,
  });

  final RunSummary run;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _accentMuted : _bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _accent : _border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: run.statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    run.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${run.triggerLabel} • ${run.createdAtLabel}${run.durationLabel == 'In progress' ? '' : ' • ${run.durationLabel}'}',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${run.modelLabel} • ${run.totalTokensLabel} tokens',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  if (run.error.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      run.error,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _danger,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _StatusPill(label: run.statusLabel, color: run.statusColor),
                const SizedBox(height: 12),
                Icon(
                  Icons.chevron_right,
                  color: selected ? _textPrimary : _textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunDetailWorkspace extends StatelessWidget {
  const _RunDetailWorkspace({
    required this.run,
    required this.detail,
    required this.loading,
    required this.onDelete,
    required this.onCopyResponse,
  });

  final RunSummary? run;
  final RunDetailSnapshot? detail;
  final bool loading;
  final Future<void> Function() onDelete;
  final Future<void> Function(String response) onCopyResponse;

  @override
  Widget build(BuildContext context) {
    if (run == null) {
      return const _EmptyCard(
        title: 'Select a run',
        subtitle: 'Pick a run from the history list to inspect its steps.',
      );
    }

    final selectedRun = run!;
    final snapshot = detail;
    return Column(
      children: <Widget>[
        _RunHeroCard(run: selectedRun, onDelete: onDelete),
        const SizedBox(height: 16),
        if (loading && snapshot == null)
          Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading run detail...',
                    style: TextStyle(color: _textSecondary),
                  ),
                ],
              ),
            ),
          )
        else if (snapshot != null) ...<Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _RunMetricCard(
                title: 'Steps',
                value: '${snapshot.steps.length}',
                helper: 'Recorded events',
                color: _info,
              ),
              _RunMetricCard(
                title: 'Completed tools',
                value: '${snapshot.completedTools}',
                helper: 'Successful tool calls',
                color: _success,
              ),
              _RunMetricCard(
                title: 'Failures',
                value: '${snapshot.failedTools}',
                helper: 'Tool errors',
                color: _danger,
              ),
              _RunMetricCard(
                title: 'Helpers',
                value: '${snapshot.helperCount}',
                helper: 'Subagents or helpers',
                color: _accentHover,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RunResponseCard(
            response: snapshot.response,
            onCopy: () => onCopyResponse(snapshot.response),
          ),
          const SizedBox(height: 16),
          _RunTimelineCard(steps: snapshot.steps, loading: loading),
        ] else
          const _EmptyCard(
            title: 'No detail available',
            subtitle: 'This run does not have step detail yet.',
          ),
      ],
    );
  }
}

class _RunHeroCard extends StatelessWidget {
  const _RunHeroCard({required this.run, required this.onDelete});

  final RunSummary run;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            run.statusColor.withValues(alpha: 0.18),
            _bgSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _StatusPill(
                          label: run.statusLabel,
                          color: run.statusColor,
                        ),
                        _MetaPill(
                          label: run.triggerLabel,
                          icon: Icons.bolt_outlined,
                        ),
                        _MetaPill(
                          label: run.modelLabel,
                          icon: Icons.memory_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      run.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _MetaPill(
                          label: 'Started ${run.createdAtLabel}',
                          icon: Icons.schedule_outlined,
                        ),
                        _MetaPill(
                          label: run.durationLabel,
                          icon: Icons.timer_outlined,
                        ),
                        _MetaPill(
                          label: '${run.totalTokensLabel} tokens',
                          icon: Icons.toll_outlined,
                        ),
                        _MetaPill(
                          label: run.id.length <= 12
                              ? run.id
                              : '${run.id.substring(0, 12)}…',
                          icon: Icons.tag_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline),
                label: Text('Delete'),
              ),
            ],
          ),
          if (run.error.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x19EF4444),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x4CEF4444)),
              ),
              child: Text(run.error, style: TextStyle(height: 1.45)),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunResponseCard extends StatelessWidget {
  const _RunResponseCard({required this.response, required this.onCopy});

  final String response;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Final Response')),
                OutlinedButton.icon(
                  onPressed: response.trim().isEmpty ? null : onCopy,
                  icon: Icon(Icons.copy_all_outlined),
                  label: Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (response.trim().isEmpty)
              Text(
                'No final response was captured for this run.',
                style: TextStyle(color: _textSecondary),
              )
            else
              MarkdownBody(
                data: response,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _textPrimary,
                        height: 1.6,
                      ),
                      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                        backgroundColor: _bgSecondary,
                        color: _textPrimary,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _bgSecondary,
                        border: Border.all(color: _border),
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RunTimelineCard extends StatelessWidget {
  const _RunTimelineCard({required this.steps, required this.loading});

  final List<RunStepItem> steps;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _SectionTitle('Step Timeline')),
                if (loading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (steps.isEmpty)
              Text(
                'No run steps recorded yet.',
                style: TextStyle(color: _textSecondary),
              )
            else
              ...steps.map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RunStepCard(step: step),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RunStepCard extends StatelessWidget {
  const _RunStepCard({required this.step});

  final RunStepItem step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded:
              step.status == 'failed' || step.status == 'running',
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: step.statusColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${step.displayIndex}',
                style: TextStyle(
                  color: step.statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(step.label, style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                step.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _StatusPill(label: step.statusLabel, color: step.statusColor),
                  _MetaPill(label: step.typeLabel, icon: Icons.layers_outlined),
                  if (step.startedAt != null)
                    _MetaPill(
                      label: step.startedAtLabel!,
                      icon: Icons.schedule_outlined,
                    ),
                  if (step.durationLabel != null)
                    _MetaPill(
                      label: step.durationLabel!,
                      icon: Icons.timer_outlined,
                    ),
                  if (step.tokensUsed > 0)
                    _MetaPill(
                      label: '${_formatNumber(step.tokensUsed)} tokens',
                      icon: Icons.toll_outlined,
                    ),
                ],
              ),
            ],
          ),
          children: <Widget>[
            if (step.description.trim().isNotEmpty &&
                step.description.trim() != step.summary.trim())
              _RunDetailBlock(label: 'Description', value: step.description),
            if (step.inputSummary.trim().isNotEmpty)
              _RunDetailBlock(label: 'Input summary', value: step.inputSummary),
            if (step.toolInput.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Tool input',
                value: _truncateRunText(step.toolInput),
                monospace: true,
              ),
            if (step.error.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Error',
                value: step.error,
                monospace: true,
              )
            else if (step.result.trim().isNotEmpty)
              _RunDetailBlock(
                label: 'Result',
                value: _truncateRunText(step.result),
                monospace: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _RunDetailBlock extends StatelessWidget {
  const _RunDetailBlock({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: SelectableText(
              value,
              style: TextStyle(
                height: 1.5,
                fontSize: 12.5,
                color: _textPrimary,
                fontFamily: monospace
                    ? GoogleFonts.jetBrainsMono().fontFamily
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordStrengthInfo {
  const _PasswordStrengthInfo({
    required this.score,
    required this.label,
    required this.message,
    required this.color,
  });

  final int score;
  final String label;
  final String message;
  final Color color;
}

_PasswordStrengthInfo _passwordStrengthInfo({
  required String password,
  String username = '',
  String email = '',
}) {
  final value = password.trim();
  if (value.isEmpty) {
    return _PasswordStrengthInfo(
      score: 0,
      label: 'Empty',
      message: 'Use 8+ characters. Longer passphrases work well.',
      color: _borderLight,
    );
  }
  final lower = RegExp(r'[a-z]').hasMatch(value);
  final upper = RegExp(r'[A-Z]').hasMatch(value);
  final digits = RegExp(r'[0-9]').hasMatch(value);
  final symbols = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  final variety = <bool>[
    lower,
    upper,
    digits,
    symbols,
  ].where((item) => item).length;
  final normalized = value.toLowerCase();
  final userHints = <String>{
    username.trim().toLowerCase(),
    email.trim().toLowerCase(),
    email.trim().toLowerCase().split('@').first,
  }.where((item) => item.length >= 3);
  final containsUserInfo = userHints.any(normalized.contains);
  final obviousPattern =
      RegExp(r'(.)\1\1').hasMatch(value) ||
      normalized.contains('password') ||
      normalized.contains('1234') ||
      normalized.contains('qwerty');

  var score = 0;
  if (value.length >= 8) score += 1;
  if (value.length >= 12) score += 1;
  if (variety >= 3) score += 1;
  if (variety == 4 || value.length >= 16) score += 1;
  if (containsUserInfo || obviousPattern) score -= 1;
  score = score.clamp(0, 4);

  if (value.length < 8) {
    return _PasswordStrengthInfo(
      score: 1,
      label: 'Weak',
      message: 'Use at least 8 characters.',
      color: _danger,
    );
  }
  if (containsUserInfo) {
    return _PasswordStrengthInfo(
      score: 2,
      label: 'Fair',
      message: 'Do not include your username or email.',
      color: _warning,
    );
  }
  if (obviousPattern) {
    return _PasswordStrengthInfo(
      score: 2,
      label: 'Fair',
      message: 'Avoid repeated characters and obvious sequences.',
      color: _warning,
    );
  }
  if (score >= 4) {
    return _PasswordStrengthInfo(
      score: 4,
      label: 'Strong',
      message: 'Strong password.',
      color: _success,
    );
  }
  if (score >= 3) {
    return _PasswordStrengthInfo(
      score: 3,
      label: 'Good',
      message: 'Good password. A little more length makes it stronger.',
      color: _success,
    );
  }
  return _PasswordStrengthInfo(
    score: 2,
    label: 'Fair',
    message: 'Add more length or another character type.',
    color: _warning,
  );
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.info});

  final _PasswordStrengthInfo info;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Password strength: ${info.label}',
              style: TextStyle(color: info.color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: info.score / 4,
                  backgroundColor: _borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(info.color),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          info.message,
          style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }
}

enum AccountSettingsTab { account, security }

class AccountSettingsPanel extends StatefulWidget {
  const AccountSettingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<AccountSettingsPanel> createState() => _AccountSettingsPanelState();
}

class _AccountSettingsPanelState extends State<AccountSettingsPanel> {
  AccountSettingsTab _selectedTab = AccountSettingsTab.account;
  late final TextEditingController _emailController;
  late final TextEditingController _emailPasswordController;
  late final TextEditingController _setupPasswordController;
  late final TextEditingController _setupCodeController;
  late final TextEditingController _disablePasswordController;
  late final TextEditingController _disableCodeController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmNewPasswordController;
  Map<String, dynamic>? _pendingSetup;
  List<String> _recoveryCodes = const <String>[];
  String? _emailSuccessMessage;
  String? _emailInlineError;
  String? _passwordSuccessMessage;
  String? _passwordInlineError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.controller.user?['email']?.toString() ?? '',
    );
    _emailPasswordController = TextEditingController();
    _setupPasswordController = TextEditingController();
    _setupCodeController = TextEditingController();
    _disablePasswordController = TextEditingController();
    _disableCodeController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmNewPasswordController = TextEditingController();
    unawaited(widget.controller.refreshAccountSettings());
  }

  @override
  void didUpdateWidget(covariant AccountSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final email = widget.controller.user?['email']?.toString() ?? '';
    if (_emailController.text.isEmpty && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailPasswordController.dispose();
    _setupPasswordController.dispose();
    _setupCodeController.dispose();
    _disablePasswordController.dispose();
    _disableCodeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  bool get _supportsQrLoginApproval =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _startQrLoginApproval() async {
    final scanned = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const _QrLoginScannerDialog(),
    );
    if (!mounted || scanned == null || scanned.trim().isEmpty) {
      return;
    }

    final payload = QrLoginScanPayload.tryParse(scanned);
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That QR code is not a NeoAgent login request.'),
        ),
      );
      return;
    }

    final scannedBackend = widget.controller._normalizeBackendUrl(
      payload.backendUrl,
    );
    final currentBackend = widget.controller._normalizeBackendUrl(
      widget.controller.backendUrl,
    );
    if (scannedBackend != currentBackend) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This code belongs to a different NeoAgent server: ${payload.backendUrl}',
          ),
        ),
      );
      return;
    }

    try {
      final preview = await widget.controller.resolveQrLoginApproval(payload);
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return _QrLoginApprovalDialog(
            preview: preview,
            busy: widget.controller.isApprovingQrLogin,
          );
        },
      );
      if (approved != true || !mounted) {
        return;
      }
      await widget.controller.approveQrLogin(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approved login for ${preview.requestedDevice.label}.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final message =
          widget.controller.errorMessage ?? 'Could not approve QR login.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 860;
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Account settings',
          subtitle:
              'Manage your account email, two-factor authentication, and active sessions.',
          trailing: OutlinedButton.icon(
            onPressed: widget.controller.isLoadingAccountSettings
                ? null
                : widget.controller.refreshAccountSettings,
            icon: widget.controller.isLoadingAccountSettings
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.refresh),
            label: Text('Refresh'),
          ),
        ),
        if (widget.controller.errorMessage != null) ...<Widget>[
          _InlineError(message: widget.controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (compact)
          _AccountSettingsTabs(
            selected: _selectedTab,
            onSelected: (value) => setState(() => _selectedTab = value),
          )
        else
          const SizedBox.shrink(),
        if (compact) const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: compact
                ? _buildSelectedPanel()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 220,
                        child: _AccountSettingsTabs(
                          selected: _selectedTab,
                          onSelected: (value) =>
                              setState(() => _selectedTab = value),
                          vertical: true,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(child: _buildSelectedPanel()),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPanel() {
    switch (_selectedTab) {
      case AccountSettingsTab.account:
        return _buildAccountPanel();
      case AccountSettingsTab.security:
        return _buildSecurityPanel();
    }
  }

  Widget _buildAccountPanel() {
    final controller = widget.controller;
    final username = controller.user?['username']?.toString() ?? 'Account';
    final currentEmail =
        controller.user?['email']?.toString() ?? 'No email linked';
    final hasPassword = controller.user?['hasPassword'] == true;
    final availableProviders = controller.authProviders
        .where((provider) => provider.configured)
        .toList();
    final linkedProviderKeys = controller.linkedAuthProviders
        .map((provider) => provider.provider)
        .toSet();
    final linkableProviders = availableProviders
        .where((provider) => !linkedProviderKeys.contains(provider.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Account'),
        const SizedBox(height: 12),
        _MetaPill(label: username, icon: Icons.person_outline),
        const SizedBox(height: 18),
        Text('Current email: $currentEmail'),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailPasswordController,
          obscureText: true,
          enabled: hasPassword,
          decoration: InputDecoration(
            labelText: 'Current password',
            helperText: hasPassword
                ? 'Required to add or change your account email.'
                : 'Create a password first to change your account email.',
          ),
        ),
        if (_emailInlineError != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineError(message: _emailInlineError!),
        ],
        if (_emailSuccessMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineSuccess(message: _emailSuccessMessage!),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: controller.isSavingAccountSettings || !hasPassword
              ? null
              : () async {
                  setState(() {
                    _emailInlineError = null;
                    _emailSuccessMessage = null;
                  });
                  if (_emailPasswordController.text.trim().isEmpty) {
                    setState(() {
                      _emailInlineError =
                          'Enter your current password to save email changes.';
                    });
                    return;
                  }
                  final saved = await controller.updateAccountEmail(
                    email: _emailController.text,
                    currentPassword: _emailPasswordController.text,
                  );
                  if (saved && mounted) {
                    setState(() {
                      _emailPasswordController.clear();
                      _emailSuccessMessage =
                          'Email saved. If confirmation is required, check the new address for a NeoAgent confirmation link.';
                    });
                  }
                },
          icon: controller.isSavingAccountSettings
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.save_outlined),
          label: Text('Save email'),
        ),
        const SizedBox(height: 28),
        Row(
          children: <Widget>[
            const Expanded(child: _SectionTitle('Linked sign-in providers')),
            if (controller.linkedAuthProviders.isNotEmpty)
              Text(
                '${controller.linkedAuthProviders.length} linked',
                style: TextStyle(color: _textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.linkedAuthProviders.isEmpty)
          Text(
            'No external sign-in providers linked.',
            style: TextStyle(color: _textSecondary),
          )
        else
          ...controller.linkedAuthProviders.map(
            (provider) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: provider.icon == 'google'
                    ? const CircleAvatar(
                        backgroundColor: Color(0x1A4285F4),
                        child: Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const CircleAvatar(child: Icon(Icons.link)),
                title: Text(provider.label),
                subtitle: Text(
                  provider.email.isNotEmpty
                      ? '${provider.email}\nLast used: ${provider.lastUsedLabel}'
                      : 'Last used: ${provider.lastUsedLabel}',
                ),
                isThreeLine: provider.email.isNotEmpty,
                trailing: TextButton(
                  onPressed:
                      controller.isSavingAccountSettings || !provider.canUnlink
                      ? null
                      : () => controller.unlinkAccountProvider(provider.id),
                  child: const Text('Unlink'),
                ),
              ),
            ),
          ),
        if (linkableProviders.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: linkableProviders
                .map(
                  (provider) => OutlinedButton.icon(
                    onPressed: controller.isSavingAccountSettings
                        ? null
                        : () => controller.linkAccountProvider(provider.id),
                    icon: provider.icon == 'google'
                        ? const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4285F4),
                            ),
                          )
                        : const Icon(Icons.link),
                    label: Text('Link ${provider.label}'),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSecurityPanel() {
    final controller = widget.controller;
    final twoFactorEnabled = controller.accountTwoFactor['enabled'] == true;
    final recoveryCount = _asInt(
      controller.accountTwoFactor['recoveryCodesRemaining'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_supportsQrLoginApproval) ...<Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _SectionTitle('Approve QR login')),
              _StatusPill(label: 'Android only', color: _accent),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Scan QR login requests from signed-out devices and approve them from this authenticated mobile session.',
            style: TextStyle(color: _textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _accent.withValues(alpha: 0.16),
                  _success.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderLight),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: controller.isApprovingQrLogin
                      ? null
                      : _startQrLoginApproval,
                  icon: controller.isApprovingQrLogin
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan login QR'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        _buildPasswordPanel(),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(child: _SectionTitle('Two-factor authentication')),
            _StatusPill(
              label: twoFactorEnabled ? 'Enabled' : 'Disabled',
              color: twoFactorEnabled ? _success : _warning,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          twoFactorEnabled
              ? '$recoveryCount recovery codes are still available.'
              : 'Use an authenticator app such as Authy, 1Password, or Google Authenticator.',
          style: TextStyle(color: _textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (!twoFactorEnabled) _buildEnableTwoFactorPanel(),
        if (twoFactorEnabled) _buildDisableTwoFactorPanel(),
        if (_recoveryCodes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _RecoveryCodesCard(codes: _recoveryCodes),
        ],
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(child: _SectionTitle('Active sessions')),
            Text(
              '${controller.accountSessions.length} active',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.accountSessions.isEmpty)
          Text(
            'No active sessions found.',
            style: TextStyle(color: _textSecondary),
          )
        else
          ...controller.accountSessions.map(
            (session) => _AccountSessionCard(
              session: session,
              busy: controller.isRevokingSession,
              onRevoke: session.current
                  ? null
                  : () => controller.revokeAccountSession(session.id),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordPanel() {
    final controller = widget.controller;
    final hasPassword = controller.user?['hasPassword'] == true;
    final strength = _passwordStrengthInfo(
      password: _newPasswordController.text,
      username: controller.user?['username']?.toString() ?? '',
      email: controller.user?['email']?.toString() ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionTitle('Password'),
        const SizedBox(height: 12),
        if (hasPassword) ...<Widget>[
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
        ] else ...<Widget>[
          Text(
            'No local password is set yet. Create one to enable username/password sign-in.',
            style: TextStyle(color: _textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _newPasswordController,
          onChanged: (_) => setState(() {}),
          obscureText: true,
          decoration: InputDecoration(
            labelText: hasPassword ? 'New password' : 'Create password',
          ),
        ),
        const SizedBox(height: 10),
        _PasswordStrengthIndicator(info: strength),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmNewPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: hasPassword
                ? 'Confirm new password'
                : 'Confirm password',
          ),
        ),
        if (_passwordInlineError != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineError(message: _passwordInlineError!),
        ],
        if (_passwordSuccessMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          _InlineSuccess(message: _passwordSuccessMessage!),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: controller.isSavingAccountSettings
              ? null
              : () async {
                  setState(() {
                    _passwordInlineError = null;
                    _passwordSuccessMessage = null;
                  });
                  if (hasPassword && _currentPasswordController.text.isEmpty) {
                    setState(() {
                      _passwordInlineError =
                          'Enter your current password to change it.';
                    });
                    return;
                  }
                  if (_newPasswordController.text.length < 8) {
                    setState(() {
                      _passwordInlineError =
                          'Use a new password with at least 8 characters.';
                    });
                    return;
                  }
                  if (_newPasswordController.text !=
                      _confirmNewPasswordController.text) {
                    setState(() {
                      _passwordInlineError = 'New passwords do not match.';
                    });
                    return;
                  }
                  final saved = await controller.updateAccountPassword(
                    currentPassword: _currentPasswordController.text,
                    newPassword: _newPasswordController.text,
                  );
                  if (saved && mounted) {
                    setState(() {
                      _currentPasswordController.clear();
                      _newPasswordController.clear();
                      _confirmNewPasswordController.clear();
                      _passwordSuccessMessage = hasPassword
                          ? 'Password changed.'
                          : 'Password created.';
                    });
                  }
                },
          icon: controller.isSavingAccountSettings
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.password_outlined),
          label: Text(hasPassword ? 'Change password' : 'Create password'),
        ),
      ],
    );
  }

  Widget _buildEnableTwoFactorPanel() {
    final setupUrl = _pendingSetup?['otpauthUrl']?.toString() ?? '';
    final manualKey = _pendingSetup?['manualKey']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_pendingSetup == null) ...<Widget>[
          TextField(
            controller: _setupPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.controller.isConfiguringTwoFactor
                ? null
                : () async {
                    final setup = await widget.controller.beginTwoFactorSetup(
                      _setupPasswordController.text,
                    );
                    if (setup != null && mounted) {
                      setState(() => _pendingSetup = setup);
                    }
                  },
            icon: Icon(Icons.qr_code_2_outlined),
            label: Text('Start setup'),
          ),
        ] else ...<Widget>[
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: setupUrl,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(manualKey, style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _setupCodeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Authenticator code'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.controller.isConfiguringTwoFactor
                ? null
                : () async {
                    final codes = await widget.controller.enableTwoFactor(
                      _setupCodeController.text,
                    );
                    if (codes.isNotEmpty && mounted) {
                      setState(() {
                        _recoveryCodes = codes;
                        _pendingSetup = null;
                        _setupPasswordController.clear();
                        _setupCodeController.clear();
                      });
                    }
                  },
            icon: Icon(Icons.verified_user_outlined),
            label: Text('Enable 2FA'),
          ),
        ],
      ],
    );
  }

  Widget _buildDisableTwoFactorPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _disablePasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _disableCodeController,
          decoration: const InputDecoration(labelText: '2FA or recovery code'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: widget.controller.isConfiguringTwoFactor
                  ? null
                  : () => widget.controller.disableTwoFactor(
                      currentPassword: _disablePasswordController.text,
                      code: _disableCodeController.text,
                    ),
              icon: Icon(Icons.lock_open_outlined),
              label: Text('Disable 2FA'),
            ),
            OutlinedButton.icon(
              onPressed: widget.controller.isConfiguringTwoFactor
                  ? null
                  : () async {
                      final codes = await widget.controller
                          .regenerateRecoveryCodes(
                            currentPassword: _disablePasswordController.text,
                            code: _disableCodeController.text,
                          );
                      if (codes.isNotEmpty && mounted) {
                        setState(() => _recoveryCodes = codes);
                      }
                    },
              icon: Icon(Icons.password_outlined),
              label: Text('New recovery codes'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountSettingsTabs extends StatelessWidget {
  const _AccountSettingsTabs({
    required this.selected,
    required this.onSelected,
    this.vertical = false,
  });

  final AccountSettingsTab selected;
  final ValueChanged<AccountSettingsTab> onSelected;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      _tabButton(AccountSettingsTab.account, Icons.person_outline, 'Account'),
      _tabButton(
        AccountSettingsTab.security,
        Icons.security_outlined,
        'Security',
      ),
    ];
    return vertical
        ? Column(children: buttons)
        : Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _tabButton(AccountSettingsTab tab, IconData icon, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: vertical ? 8 : 0),
      child: _SidebarButton(
        label: label,
        icon: icon,
        active: selected == tab,
        onTap: () => onSelected(tab),
      ),
    );
  }
}

class _RecoveryCodesCard extends StatelessWidget {
  const _RecoveryCodesCard({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Save these recovery codes now. They will not be shown again.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: codes
                .map(
                  (code) => SelectableText(
                    code,
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: codes.join('\n'))),
            icon: Icon(Icons.copy_outlined),
            label: Text('Copy codes'),
          ),
        ],
      ),
    );
  }
}

class _AccountSessionCard extends StatelessWidget {
  const _AccountSessionCard({
    required this.session,
    required this.busy,
    required this.onRevoke,
  });

  final AccountSessionItem session;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            session.deviceIcon,
            color: session.current ? _success : _textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.current
                      ? '${session.clientLabel} · Current session'
                      : session.clientLabel,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    session.locationSummary,
                    'Last seen ${session.lastSeenLabel}',
                  ].join(' · '),
                  style: TextStyle(color: _textSecondary),
                ),
                if (session.userAgent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${session.clientPlatformLabel} · ${session.clientBrowserLabel} · Created ${session.createdLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (!session.current)
            TextButton(
              onPressed: busy ? null : onRevoke,
              child: Text('Revoke'),
            ),
        ],
      ),
    );
  }
}

class _QrLoginScannerDialog extends StatefulWidget {
  const _QrLoginScannerDialog();

  @override
  State<_QrLoginScannerDialog> createState() => _QrLoginScannerDialogState();
}

class _QrLoginScannerDialogState extends State<_QrLoginScannerDialog> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (_handled) return;
              final raw = capture.barcodes
                  .map((barcode) => barcode.rawValue?.trim() ?? '')
                  .firstWhere((value) => value.isNotEmpty, orElse: () => '');
              if (raw.isEmpty) return;
              _handled = true;
              Navigator.of(context).pop(raw);
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.72),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.78),
                ],
                stops: const <double>[0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Scan a NeoAgent login QR',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Point the camera at the code shown on the signed-out device. Approval stays on this phone.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrLoginApprovalDialog extends StatelessWidget {
  const _QrLoginApprovalDialog({required this.preview, required this.busy});

  final QrLoginApprovalPreview preview;
  final bool busy;

  IconData get _deviceIcon => switch (preview.requestedDevice.deviceClass) {
    'mobile' => Icons.smartphone_rounded,
    'tablet' => Icons.tablet_mac_rounded,
    'desktop' => Icons.laptop_mac_rounded,
    'server' => Icons.dns_outlined,
    _ => Icons.devices_other_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final canApprove =
        preview.canApprove && !preview.isExpired && !preview.isClaimed;
    return AlertDialog(
      backgroundColor: _bgCard,
      title: const Text('Approve QR login'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(_deviceIcon, color: _accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          preview.requestedDevice.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            preview.requestLocation.label,
                            if (preview.requestedAt != null)
                              'Requested ${_formatTimestamp(preview.requestedAt!)}',
                          ].join(' · '),
                          style: TextStyle(color: _textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaPill(
                  label: preview.requestedDevice.platformLabel,
                  icon: Icons.devices_outlined,
                ),
                _MetaPill(
                  label: preview.requestedDevice.browserLabel,
                  icon: Icons.language_outlined,
                ),
                if (preview.expiresAt != null)
                  _MetaPill(
                    label: 'Expires ${_formatTimestamp(preview.expiresAt!)}',
                    icon: Icons.timer_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              preview.isClaimed
                  ? 'This request has already been used.'
                  : preview.isExpired
                  ? 'This request has expired. Ask the other device to generate a new code.'
                  : 'Approve this only if you started the login on that device just now.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: !canApprove || busy
              ? null
              : () => Navigator.of(context).pop(true),
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined),
          label: const Text('Approve login'),
        ),
      ],
    );
  }
}

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

const Map<String, List<String>> _voiceLiveModelsByProvider =
    <String, List<String>>{
      'openai': <String>[
        'gpt-4o-realtime-preview',
        'gpt-4o-mini-realtime-preview',
      ],
      'gemini': <String>['gemini-3.1-flash-live-preview'],
    };

const Map<String, List<String>> _voiceLiveVoicesByProvider =
    <String, List<String>>{
      'openai': <String>[
        'alloy',
        'ash',
        'ballad',
        'coral',
        'echo',
        'fable',
        'nova',
        'onyx',
        'sage',
        'shimmer',
        'verse',
        'marin',
        'cedar',
      ],
      'gemini': <String>[
        'Kore',
        'Puck',
        'Charon',
        'Zephyr',
        'Leda',
        'Aoede',
        'Fenrir',
        'Orus',
        'Achernar',
        'Achird',
        'Algenib',
        'Algieba',
        'Alnilam',
        'Autonoe',
        'Callirrhoe',
        'Despina',
        'Enceladus',
        'Erinome',
        'Gacrux',
        'Iocaste',
        'Isonoe',
        'Laomedeia',
        'Larissa',
        'Lysithea',
        'Megaclite',
        'Mimosa',
        'Pulcherrima',
        'Rasalgethi',
        'Sadachbia',
        'Sulafat',
      ],
    };

class _SettingsPanelState extends State<SettingsPanel> {
  late bool _headlessBrowser;
  late String _browserBackend;
  late bool _smarterSelector;
  late Set<String> _enabledModels;
  late String _defaultChatModel;
  late String _defaultSubagentModel;
  late String _defaultRecordingTranscriptionModel;
  late String _defaultRecordingSummaryModel;
  late String _fallbackModel;
  late String _defaultSpeechModel;
  late String _voiceLiveProvider;
  late String _voiceLiveModel;
  late String _voiceLiveVoice;
  final Map<String, bool> _providerEnabled = <String, bool>{};
  final Map<String, TextEditingController> _providerBaseUrlControllers =
      <String, TextEditingController>{};
  final Set<String> _expandedProviderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    for (final controller in _providerBaseUrlControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.settings != widget.controller.settings ||
        oldWidget.controller.aiProviders != widget.controller.aiProviders ||
        oldWidget.controller.supportedModels !=
            widget.controller.supportedModels) {
      _hydrate();
    }
  }

  void _hydrate() {
    final controller = widget.controller;
    final knownModels = controller.supportedModels
        .map((model) => model.id)
        .toSet();
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .map((model) => model.id)
        .toSet();
    _headlessBrowser = controller.headlessBrowser;
    _browserBackend = _normalizeBrowserBackend(controller.browserBackend);
    _smarterSelector = controller.smarterSelector;
    _enabledModels = controller.enabledModelIds
        .where((id) => knownModels.contains(id))
        .toSet();
    if (_enabledModels.isEmpty && availableModels.isNotEmpty) {
      _enabledModels = availableModels;
    }
    _defaultChatModel = controller.defaultChatModel;
    _defaultSubagentModel = controller.defaultSubagentModel;
    _defaultRecordingTranscriptionModel =
        controller.defaultRecordingTranscriptionModel;
    _defaultRecordingSummaryModel = controller.defaultRecordingSummaryModel;
    _fallbackModel = controller.fallbackModel;
    _defaultSpeechModel = controller.defaultSpeechModel;
    _voiceLiveProvider = controller.voiceLiveProvider;
    _voiceLiveModel = controller.voiceLiveModel;
    _voiceLiveVoice = controller.voiceLiveVoice;
    if (!_voiceLiveModelsByProvider.containsKey(_voiceLiveProvider)) {
      _voiceLiveProvider = 'openai';
    }
    if (!(_voiceLiveModelsByProvider[_voiceLiveProvider]?.contains(
          _voiceLiveModel,
        ) ??
        false)) {
      _voiceLiveModel = _voiceLiveModelsByProvider[_voiceLiveProvider]!.first;
    }
    final liveVoiceOptions =
        _voiceLiveVoicesByProvider[_voiceLiveProvider] ?? const <String>[];
    if (liveVoiceOptions.isNotEmpty &&
        !liveVoiceOptions.contains(_voiceLiveVoice)) {
      _voiceLiveVoice = liveVoiceOptions.first;
    }

    final providerConfigs = controller.aiProviderConfigs;
    final providerIds = <String>{
      ...providerConfigs.keys,
      ...controller.aiProviders.map((provider) => provider.id),
    };

    for (final providerId in providerIds) {
      final config =
          providerConfigs[providerId] ?? AiProviderConfig.empty(providerId);
      _providerEnabled[providerId] = config.enabled;
      _syncTextController(
        _providerBaseUrlControllers,
        providerId,
        config.baseUrl,
      );
    }

    _pruneControllers(_providerBaseUrlControllers, providerIds);
    _providerEnabled.removeWhere((id, _) => !providerIds.contains(id));
  }

  String _normalizeBrowserBackend(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'extension' ? 'extension' : 'cloud';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final availableModels = controller.supportedModels
        .where((model) => model.available)
        .toList();
    final routingModels = availableModels.isEmpty
        ? controller.supportedModels
        : availableModels;
    final modelChoices = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(
        value: 'auto',
        child: Text('Smart Selector (Auto)'),
      ),
      ...routingModels.map(
        (model) =>
            DropdownMenuItem<String>(value: model.id, child: Text(model.label)),
      ),
    ];
    final enabledSmartModels = _enabledModels
        .where((id) => routingModels.any((model) => model.id == id))
        .length;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Settings',
          subtitle:
              'Platform-aware workspace, model, recording, update, and diagnostics controls.',
          trailing: FilledButton.icon(
            onPressed: controller.isSavingSettings
                ? null
                : () => controller.saveSettings(
                    headlessBrowser: _headlessBrowser,
                    browserBackend: _browserBackend == 'extension'
                        ? 'extension'
                        : controller.cloudBrowserBackend,
                    smarterSelector: _smarterSelector,
                    enabledModels: _enabledModels.toList(),
                    defaultChatModel: _defaultChatModel,
                    defaultSubagentModel: _defaultSubagentModel,
                    defaultRecordingTranscriptionProvider: 'deepgram',
                    defaultRecordingTranscriptionModel:
                        _defaultRecordingTranscriptionModel,
                    defaultRecordingSummaryProvider: _providerForSelectedModel(
                      _defaultRecordingSummaryModel,
                      controller.supportedModels,
                    ),
                    defaultRecordingSummaryModel: _defaultRecordingSummaryModel,
                    fallbackModel: _fallbackModel,
                    defaultSpeechModel: _defaultSpeechModel,
                    voiceSttProvider: controller.voiceSttProvider,
                    voiceSttModel: controller.voiceSttModel,
                    voiceTtsProvider: controller.voiceTtsProvider,
                    voiceTtsModel: controller.voiceTtsModel,
                    voiceTtsVoice: controller.voiceTtsVoice,
                    voiceRuntimeMode: 'live',
                    voiceLiveProvider: _voiceLiveProvider,
                    voiceLiveModel: _voiceLiveModel,
                    voiceLiveVoice: _voiceLiveVoice,
                    aiProviderConfigs: _buildProviderPayload(),
                  ),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            icon: controller.isSavingSettings
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.save_outlined),
            label: Text('Save'),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        _buildSettingsOverview(controller, availableModels.length),
        const SizedBox(height: 16),
        _buildWorkspaceSection(controller),
        const SizedBox(height: 16),
        _buildModelsSection(
          controller: controller,
          modelChoices: modelChoices,
          routingModels: routingModels,
          availableModels: availableModels,
          enabledSmartModels: enabledSmartModels,
        ),
        const SizedBox(height: 16),
        _buildVoiceAndRecordingSection(
          controller: controller,
          modelChoices: modelChoices,
          routingModels: routingModels,
        ),
        const SizedBox(height: 16),
        if (_supportsDesktopShell) ...<Widget>[
          _buildDesktopSection(controller),
          const SizedBox(height: 16),
        ],
        _buildUpdatesSection(controller),
        const SizedBox(height: 16),
        _buildDiagnosticsSection(controller),
      ],
    );
  }

  Widget _buildSettingsOverview(
    NeoAgentController controller,
    int availableModelCount,
  ) {
    final platformLabel = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Overview'),
            const SizedBox(height: 10),
            Text(
              'Start with workspace behavior, then configure models, recording defaults, and updates for this platform.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _MetaPill(
                  icon: Icons.devices_outlined,
                  label:
                      'Platform ${platformLabel[0].toUpperCase()}${platformLabel.substring(1)}',
                ),
                _MetaPill(
                  icon: Icons.memory_outlined,
                  label: '$availableModelCount models ready',
                ),
                _MetaPill(
                  icon: Icons.hub_outlined,
                  label: '${controller.aiProviders.length} providers',
                ),
                _MetaPill(
                  icon: Icons.auto_awesome_outlined,
                  label: _smarterSelector
                      ? 'Smart selector on'
                      : 'Manual routing',
                ),
                if (_supportsDesktopShell)
                  _MetaPill(
                    icon: Icons.desktop_windows_outlined,
                    label: controller.desktopCompanionEnabled
                        ? 'Desktop companion enabled'
                        : 'Desktop-only controls available',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Workspace'),
            const SizedBox(height: 10),
            Text(
              'Controls that affect how the app executes work on this device or through the paired browser runtime.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Browser Runtime',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _SettingToggle(
              title: 'Run browser headless',
              subtitle:
                  'Keep browser automation off-screen when visible windows are not needed.',
              value: _headlessBrowser,
              onChanged: (value) => setState(() => _headlessBrowser = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _browserBackend,
              decoration: const InputDecoration(
                labelText: 'Browser backend',
                helperText:
                    'Cloud uses this deployment. Extension uses a paired Chrome browser.',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'cloud',
                  child: Text('Cloud (local)'),
                ),
                DropdownMenuItem<String>(
                  value: 'extension',
                  child: Text('Chrome extension'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _browserBackend = value);
                }
              },
            ),
            const SizedBox(height: 10),
            Text(
              _browserBackend == 'extension'
                  ? (controller.browserExtensionConnected
                        ? 'Chrome extension connected.'
                        : 'Chrome extension selected. Download it here, load it unpacked in Chrome on the remote machine, then pair after login.')
                  : controller.cloudBrowserBackend == 'vm'
                  ? "Cloud uses this deployment's isolated VM browser runtime."
                  : "Cloud uses this deployment's local host browser runtime.",
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: controller.downloadBrowserExtension,
                  icon: Icon(Icons.download_outlined),
                  label: Text('Download extension'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.refreshBrowserExtensionStatus,
                  icon: Icon(Icons.sync),
                  label: Text('Refresh status'),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Routing Behavior',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _SettingToggle(
              title: 'Smart model selection',
              subtitle:
                  'Automatically choose the best enabled model for each task type.',
              value: _smarterSelector,
              onChanged: (value) => setState(() => _smarterSelector = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelsSection({
    required NeoAgentController controller,
    required List<DropdownMenuItem<String>> modelChoices,
    required List<ModelMeta> routingModels,
    required List<ModelMeta> availableModels,
    required int enabledSmartModels,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Models'),
            const SizedBox(height: 10),
            Text(
              'Enable providers first, then pick defaults for chat, agents, fallback behavior, and smart routing.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Providers',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            if (controller.aiProviders.isEmpty)
              Text(
                'Provider metadata is unavailable on this server version.',
                style: TextStyle(color: _textSecondary),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 960;
                  final cardWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 2;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: controller.aiProviders
                        .where(
                          (provider) =>
                              provider.available ||
                              _providerEnabled[provider.id] == true ||
                              controller
                                      .aiProviderConfigs[provider.id]
                                      ?.enabled ==
                                  true,
                        )
                        .map((provider) {
                          return SizedBox(
                            width: cardWidth,
                            child: _AiProviderCard(
                              provider: provider,
                              enabled:
                                  _providerEnabled[provider.id] ??
                                  controller
                                      .aiProviderConfigs[provider.id]
                                      ?.enabled ??
                                  true,
                              models: controller.supportedModels
                                  .where(
                                    (model) => model.provider == provider.id,
                                  )
                                  .toList(),
                              baseUrlController:
                                  _providerBaseUrlControllers[provider.id]!,
                              expanded: _expandedProviderIds.contains(
                                provider.id,
                              ),
                              onEnabledChanged: (value) {
                                setState(() {
                                  _providerEnabled[provider.id] = value;
                                });
                              },
                              onExpandToggle: () {
                                setState(() {
                                  if (_expandedProviderIds.contains(
                                    provider.id,
                                  )) {
                                    _expandedProviderIds.remove(provider.id);
                                  } else {
                                    _expandedProviderIds.add(provider.id);
                                  }
                                });
                              },
                            ),
                          );
                        })
                        .toList(),
                  );
                },
              ),
            const Divider(height: 32),
            Text(
              'Default Routing',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (routingModels.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 940;
                  final cardWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      SizedBox(
                        width: cardWidth,
                        child: _RoutingSelectCard(
                          label: 'Chat',
                          icon: Icons.chat_bubble_outline,
                          value: _ensureModelValue(
                            _defaultChatModel,
                            routingModels,
                            allowAuto: true,
                          ),
                          items: modelChoices,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _defaultChatModel = value);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _RoutingSelectCard(
                          label: 'Sub-agent',
                          icon: Icons.bolt_outlined,
                          value: _ensureModelValue(
                            _defaultSubagentModel,
                            routingModels,
                            allowAuto: true,
                          ),
                          items: modelChoices,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _defaultSubagentModel = value);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _RoutingSelectCard(
                          label: 'Fallback',
                          icon: Icons.shield_outlined,
                          value: _ensureModelValue(
                            _fallbackModel,
                            routingModels,
                            allowAuto: false,
                          ),
                          items: routingModels
                              .map(
                                (model) => DropdownMenuItem<String>(
                                  value: model.id,
                                  child: Text(model.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _fallbackModel = value);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            const Divider(height: 32),
            Text(
              'Smart Selector Pool',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: controller.supportedModels.map((model) {
                final selected = _enabledModels.contains(model.id);
                return FilterChip(
                  label: Text(
                    model.available
                        ? model.label
                        : '${model.label} (${model.providerStatusLabel})',
                  ),
                  selected: selected,
                  selectedColor: _accentMuted,
                  checkmarkColor: _accent,
                  backgroundColor: _bgSecondary,
                  side: BorderSide(
                    color: model.available
                        ? _border
                        : _warning.withValues(alpha: 0.35),
                  ),
                  onSelected: model.available
                      ? (value) {
                          setState(() {
                            if (value) {
                              _enabledModels.add(model.id);
                            } else if (_enabledModels.length > 1) {
                              _enabledModels.remove(model.id);
                            }
                          });
                        }
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text(
              availableModels.isEmpty
                  ? 'Enable a ready provider above to unlock model routing.'
                  : '$enabledSmartModels models are currently eligible for smart routing.',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAndRecordingSection({
    required NeoAgentController controller,
    required List<DropdownMenuItem<String>> modelChoices,
    required List<ModelMeta> routingModels,
  }) {
    final liveVoiceOptions =
        _voiceLiveVoicesByProvider[_voiceLiveProvider] ?? const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Voice & Recording'),
            const SizedBox(height: 10),
            Text(
              'Defaults for transcription, summary generation, and live voice sessions.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Recording Defaults',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 940;
                final cardWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Recording Summary',
                        icon: Icons.summarize_outlined,
                        value: _ensureModelValue(
                          _defaultRecordingSummaryModel,
                          routingModels,
                          allowAuto: true,
                        ),
                        items: modelChoices,
                        onChanged: (value) {
                          if (value != null) {
                            setState(
                              () => _defaultRecordingSummaryModel = value,
                            );
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Recording Transcription',
                        icon: Icons.hearing_outlined,
                        value: _defaultRecordingTranscriptionModel,
                        items: _recordingTranscriptionModelChoices(
                          _defaultRecordingTranscriptionModel,
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _defaultRecordingTranscriptionModel = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 32),
            Text(
              'Speech Processing',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 940;
                final cardWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Speech Model',
                        icon: Icons.record_voice_over_outlined,
                        value: _ensureModelValue(
                          _defaultSpeechModel,
                          routingModels,
                          allowAuto: true,
                        ),
                        items: modelChoices,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _defaultSpeechModel = value);
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Used for the backend LLM that processes voice assistant and other speech-originated turns. This does not change the speech synthesis voice.',
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const Divider(height: 32),
            Text(
              'Live Voice',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 940;
                final cardWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Live Provider',
                        icon: Icons.call_outlined,
                        value: _voiceLiveProvider,
                        items: const <String>['openai', 'gemini']
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _voiceLiveProvider = value;
                            final modelOptions =
                                _voiceLiveModelsByProvider[_voiceLiveProvider] ??
                                const <String>[];
                            if (!modelOptions.contains(_voiceLiveModel) &&
                                modelOptions.isNotEmpty) {
                              _voiceLiveModel = modelOptions.first;
                            }
                            final voiceOptions =
                                _voiceLiveVoicesByProvider[_voiceLiveProvider] ??
                                const <String>[];
                            if (voiceOptions.isNotEmpty &&
                                !voiceOptions.contains(_voiceLiveVoice)) {
                              _voiceLiveVoice = voiceOptions.first;
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _RoutingSelectCard(
                        label: 'Live Model',
                        icon: Icons.speed_outlined,
                        value: _voiceLiveModel,
                        items:
                            (_voiceLiveModelsByProvider[_voiceLiveProvider] ??
                                    const <String>[])
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _voiceLiveModel = value);
                          }
                        },
                      ),
                    ),
                    if (liveVoiceOptions.isNotEmpty)
                      SizedBox(
                        width: cardWidth,
                        child: _RoutingSelectCard(
                          label: 'Live Voice',
                          icon: Icons.graphic_eq_outlined,
                          value: _voiceLiveVoice,
                          items: liveVoiceOptions
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _voiceLiveVoice = value);
                            }
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Desktop'),
            const SizedBox(height: 10),
            Text(
              'Controls that only apply to the desktop shell on this computer, including local recording UX and Companion Mode.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Local App Behavior',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: controller.desktopAskOnClose,
              contentPadding: EdgeInsets.zero,
              title: Text('Ask before closing to background'),
              subtitle: Text(
                'Prompt for whether NeoAgent should stay resident in the tray when the main window closes.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: (value) => controller.setDesktopClosePreference(
                askOnClose: value,
                keepRunningOnClose: controller.desktopKeepRunningOnClose,
              ),
            ),
            SwitchListTile.adaptive(
              value: controller.desktopAutoShowFloatingToolbar,
              contentPadding: EdgeInsets.zero,
              title: Text('Auto-show floating toolbar'),
              subtitle: Text(
                'Open the compact recording bar automatically whenever a desktop studio session starts.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.setDesktopAutoShowFloatingToolbar,
            ),
            SwitchListTile.adaptive(
              value: controller.desktopAssistantHotkeyEnabled,
              contentPadding: EdgeInsets.zero,
              title: Text('Reserve assistant hotkey'),
              subtitle: Text(
                'Register $_desktopAssistantHotkeyLabel so the desktop shell is ready for the upcoming voice assistant summon flow.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.recordingRuntime.supportsGlobalHotkeys
                  ? controller.setDesktopAssistantHotkeyEnabled
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _RecordingPermissionBadge(
                  label: 'Microphone',
                  state: controller.recordingRuntime.microphonePermission,
                ),
                _RecordingPermissionBadge(
                  label: 'System audio',
                  state: controller.recordingRuntime.systemAudioPermission,
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Companion Mode',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: controller.desktopCompanionEnabled,
              contentPadding: EdgeInsets.zero,
              title: Text('Enable Companion Mode on this computer'),
              subtitle: Text(
                'Expose this signed-in desktop app as a controllable companion device without a separate pairing flow.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.setDesktopCompanionEnabled,
            ),
            SwitchListTile.adaptive(
              value: controller.desktopCompanionPaused,
              contentPadding: EdgeInsets.zero,
              title: Text('Pause Companion Mode'),
              subtitle: Text(
                'Keep the device registered but reject remote control commands locally until resumed.',
                style: TextStyle(color: _textSecondary),
              ),
              onChanged: controller.desktopCompanionEnabled
                  ? controller.setDesktopCompanionPaused
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: controller.desktopCompanionLabel,
              enabled: controller.desktopCompanionEnabled,
              decoration: const InputDecoration(
                labelText: 'Companion device label',
                hintText: 'My workstation',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              onFieldSubmitted: controller.setDesktopCompanionLabel,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _DotStatus(
                  label: controller.desktopCompanionConnected
                      ? 'Connected'
                      : controller.desktopCompanionConnecting
                      ? 'Connecting'
                      : 'Disconnected',
                  color: controller.desktopCompanionConnected
                      ? _success
                      : controller.desktopCompanionConnecting
                      ? _accent
                      : _warning,
                ),
                _DotStatus(
                  label: controller.desktopCompanionPaused ? 'Paused' : 'Ready',
                  color: controller.desktopCompanionPaused
                      ? _warning
                      : _success,
                ),
              ],
            ),
            if (controller.desktopCompanionErrorMessage
                case final message?) ...<Widget>[
              const SizedBox(height: 12),
              _InlineError(message: message),
            ],
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final status = controller.desktopCompanionStatus;
                final permissionsRaw = status['permissions'];
                final permissions = permissionsRaw is Map
                    ? permissionsRaw.map(
                        (key, value) => MapEntry(
                          key.toString(),
                          value?.toString() ?? 'unknown',
                        ),
                      )
                    : const <String, String>{};
                final screenCaptureState =
                    permissions['screenCapture'] ?? 'unknown';
                final inputControlState =
                    permissions['inputControl'] ?? 'unknown';
                final accessibilityState =
                    permissions['accessibility'] ?? 'unknown';
                final grantHelp = switch (defaultTargetPlatform) {
                  TargetPlatform.macOS =>
                    'Grant Screen Recording and Accessibility in System Settings, then press Re-check.',
                  TargetPlatform.windows =>
                    'Grant capture and accessibility/input permissions in Windows Settings, then press Re-check.',
                  TargetPlatform.linux =>
                    'Approve portal capture/input prompts and desktop accessibility access, then press Re-check.',
                  TargetPlatform.android ||
                  TargetPlatform.iOS ||
                  TargetPlatform.fuchsia =>
                    'Desktop companion permission controls are unavailable on this platform.',
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Permissions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      grantHelp,
                      style: TextStyle(color: _textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _CompanionPermissionBadge(
                          label: 'Screen capture',
                          state: screenCaptureState,
                        ),
                        _CompanionPermissionBadge(
                          label: 'Input control',
                          state: inputControlState,
                        ),
                        _CompanionPermissionBadge(
                          label: 'Accessibility',
                          state: accessibilityState,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: controller.desktopCompanionEnabled
                              ? controller.refreshDesktopCompanionStatus
                              : null,
                          icon: Icon(Icons.sync_outlined),
                          label: Text('Re-check permissions'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.desktopCompanionEnabled
                              ? () => controller
                                    .openDesktopCompanionPermissionSettings(
                                      'screenCapture',
                                    )
                              : null,
                          icon: Icon(Icons.monitor_outlined),
                          label: Text('Open capture settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.desktopCompanionEnabled
                              ? () => controller
                                    .openDesktopCompanionPermissionSettings(
                                      'accessibility',
                                    )
                              : null,
                          icon: Icon(Icons.keyboard_command_key_outlined),
                          label: Text('Open input/access settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.desktopCompanionEnabled
                              ? controller.rotateDesktopCompanionIdentity
                              : null,
                          icon: Icon(Icons.refresh_outlined),
                          label: Text('Reset Device Identity'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _SectionTitle('Updates'),
            const SizedBox(height: 10),
            Text(
              'Client and runtime update controls are grouped here so release management lives in one place.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Client App',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      controller.isCheckingAppUpdate ||
                          !controller.appUpdaterConfigured
                      ? null
                      : () => controller.checkForAppUpdates(),
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  icon: controller.isCheckingAppUpdate
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    controller.isCheckingAppUpdate
                        ? 'Checking...'
                        : 'Check now',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!controller.appUpdaterConfigured)
              Text(
                kIsWeb
                    ? 'Client app update checks are disabled in the web app to avoid blocked browser-side GitHub requests.'
                    : 'Client app updates are not configured for this build.',
                style: TextStyle(color: _textSecondary, height: 1.5),
              )
            else ...<Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 780;
                  final channelPicker = DropdownButtonFormField<String>(
                    initialValue: controller.appUpdateChannel,
                    decoration: const InputDecoration(
                      labelText: 'App release channel',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'stable',
                        child: Text('Stable'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'beta',
                        child: Text('Beta'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        unawaited(controller.setAppUpdateChannel(value));
                      }
                    },
                  );
                  final autoCheck = SwitchListTile.adaptive(
                    value: controller.appUpdateAutoCheckEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Check automatically on launch'),
                    subtitle: Text(
                      'This only checks GitHub Releases on startup. Installation still requires your confirmation.',
                      style: TextStyle(color: _textSecondary),
                    ),
                    onChanged: controller.setAppUpdateAutoCheckEnabled,
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        channelPicker,
                        const SizedBox(height: 10),
                        autoCheck,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: channelPicker),
                      const SizedBox(width: 16),
                      Expanded(child: autoCheck),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Installed: ${controller.installedAppVersion ?? 'Unknown'} | Channel: ${controller.appUpdateChannelLabel} | Last checked: ${controller.appUpdateLastCheckedLabel}',
                style: TextStyle(color: _textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Source: ${app_release_updater.appUpdaterGithubOwner}/${app_release_updater.appUpdaterGithubRepo}${app_release_updater.appUpdaterGithubToken.trim().isNotEmpty ? ' (override active)' : ' (default or build override)'}',
                style: TextStyle(color: _textSecondary),
              ),
              if (controller.appUpdateErrorMessage
                  case final message?) ...<Widget>[
                const SizedBox(height: 12),
                _InlineError(message: message),
              ],
              if (controller.availableAppUpdate
                  case final release?) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          _StatusPill(
                            label: 'Update ${release.version}',
                            color: release.channel == 'beta'
                                ? _warning
                                : _accent,
                          ),
                          _StatusPill(
                            label: release.asset.name,
                            color: _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${release.title} · ${release.publishedLabel} · ${release.asset.sizeLabel}',
                        style: TextStyle(color: _textSecondary),
                      ),
                      if (release.body.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            child: MarkdownBody(
                              data: release.body,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  color: _textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: controller.isOpeningAppUpdate
                                ? null
                                : controller.openAppUpdate,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                            ),
                            icon: controller.isOpeningAppUpdate
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.system_update_alt),
                            label: Text(
                              controller.isOpeningAppUpdate
                                  ? 'Opening...'
                                  : 'Download update',
                            ),
                          ),
                          if (release.htmlUrl.trim().isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {
                                unawaited(
                                  widget.controller._oauthLauncher.openExternal(
                                    url: release.htmlUrl,
                                    label: 'release_notes',
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: Text('View release'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  controller.isCheckingAppUpdate
                      ? 'Checking GitHub releases for this platform...'
                      : controller.appUpdateLastCheckedAt == null
                      ? 'Choose a channel and check GitHub releases for this platform.'
                      : 'No newer app release is available for this platform on the selected channel.',
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
              ],
            ],
            const Divider(height: 32),
            if (controller.updateStatus.allowSelfUpdate) ...<Widget>[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 780;
                  final channelPicker = DropdownButtonFormField<String>(
                    initialValue: controller.updateStatus.releaseChannel,
                    decoration: const InputDecoration(
                      labelText: 'Runtime release channel',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'stable',
                        child: Text('Stable'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'beta',
                        child: Text('Beta'),
                      ),
                    ],
                    onChanged:
                        controller.isSavingReleaseChannel ||
                            controller.isTriggeringUpdate ||
                            controller.updateStatus.state == 'running'
                        ? null
                        : (value) {
                            if (value != null) {
                              unawaited(controller.setReleaseChannel(value));
                            }
                          },
                  );

                  final channelHelper = Text(
                    controller.updateStatus.releaseChannel == 'beta'
                        ? 'Beta follows the preview release stream.'
                        : 'Stable follows the production release stream.',
                    style: TextStyle(color: _textSecondary),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        channelPicker,
                        const SizedBox(height: 8),
                        channelHelper,
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: channelPicker),
                        const SizedBox(width: 12),
                        Expanded(child: channelHelper),
                      ],
                    ),
                  );
                },
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Runtime',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        controller.isSavingReleaseChannel ||
                            controller.isTriggeringUpdate ||
                            controller.updateStatus.state == 'running'
                        ? null
                        : controller.triggerUpdate,
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    icon: controller.isTriggeringUpdate
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.system_update),
                    label: Text('Update'),
                  ),
                ],
              ),
            ] else ...<Widget>[
              Text(
                'Runtime',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Updates and release tracks are managed for this deployment.',
                style: TextStyle(color: _textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _StatusPill(
                  label: controller.updateStatus.badgeLabel,
                  color: controller.updateStatus.badgeColor,
                ),
                const SizedBox(width: 10),
                _StatusPill(
                  label: controller.updateStatus.releaseChannelLabel,
                  color: controller.updateStatus.releaseChannel == 'beta'
                      ? _warning
                      : _accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.updateStatus.message,
                    style: TextStyle(color: _textSecondary),
                  ),
                ),
                Text('${controller.updateStatus.progress}%'),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: controller.updateStatus.progress / 100,
                backgroundColor: _bgSecondary,
                color: _accent,
              ),
            ),
            const SizedBox(height: 12),
            Text(controller.updateStatus.versionLine),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsSection(NeoAgentController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const _SectionTitle('Diagnostics'),
                const SizedBox(width: 8),
                Icon(Icons.info_outline, size: 16, color: _textSecondary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Usage and health signals that help explain current runtime behavior without digging through logs first.',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            if (controller.tokenUsage == null)
              Text(
                'Token usage unavailable on this server version.',
                style: TextStyle(color: _textSecondary),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Total: ${controller.tokenUsage!.totalTokensLabel} tokens across ${controller.tokenUsage!.totalRunsLabel} runs',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last 7 days: ${controller.tokenUsage!.last7DaysTokensLabel} tokens in ${controller.tokenUsage!.last7DaysRunsLabel} runs',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Avg/run: ${controller.tokenUsage!.avgTokensPerRunLabel} tokens',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _providerForSelectedModel(String modelId, List<ModelMeta> models) {
    if (modelId.trim().isEmpty || modelId == 'auto') {
      return 'auto';
    }
    for (final model in models) {
      if (model.id == modelId) {
        return model.provider.trim().isEmpty ? 'auto' : model.provider;
      }
    }
    return 'auto';
  }

  Map<String, dynamic> _buildProviderPayload() {
    final providerIds = <String>{
      ...widget.controller.aiProviders.map((provider) => provider.id),
      ...widget.controller.aiProviderConfigs.keys,
    };

    return <String, dynamic>{
      for (final providerId in providerIds)
        providerId: <String, dynamic>{
          'enabled':
              _providerEnabled[providerId] ??
              widget.controller.aiProviderConfigs[providerId]?.enabled ??
              true,
          'baseUrl': _providerBaseUrlControllers[providerId]?.text.trim() ?? '',
        },
    };
  }

  void _syncTextController(
    Map<String, TextEditingController> controllers,
    String id,
    String value,
  ) {
    final controller = controllers.putIfAbsent(
      id,
      () => TextEditingController(text: value),
    );
    if (controller.text != value) {
      controller.text = value;
    }
  }

  void _pruneControllers(
    Map<String, TextEditingController> controllers,
    Set<String> activeIds,
  ) {
    final staleIds = controllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleIds) {
      controllers.remove(id)?.dispose();
    }
  }

  List<DropdownMenuItem<String>> _recordingTranscriptionModelChoices(
    String current,
  ) {
    const defaults = <String>['nova-3', 'nova-2-general'];
    final normalizedCurrent = current.trim();
    final values = <String>{...defaults};
    if (normalizedCurrent.isNotEmpty) {
      values.add(normalizedCurrent);
    }
    return values
        .map(
          (value) => DropdownMenuItem<String>(value: value, child: Text(value)),
        )
        .toList();
  }
}

class _AiProviderCard extends StatelessWidget {
  const _AiProviderCard({
    required this.provider,
    required this.enabled,
    required this.expanded,
    required this.models,
    required this.baseUrlController,
    required this.onEnabledChanged,
    required this.onExpandToggle,
  });

  final AiProviderMeta provider;
  final bool enabled;
  final bool expanded;
  final List<ModelMeta> models;
  final TextEditingController baseUrlController;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onExpandToggle;

  @override
  Widget build(BuildContext context) {
    final availableCount = models.where((model) => model.available).length;
    final hasAdvancedFields = provider.supportsBaseUrl || models.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(provider.icon, color: _accentHover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      provider.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _StatusPill(
                    label: enabled ? provider.statusLabel : 'Disabled',
                    color: enabled ? provider.statusColor : _textSecondary,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: hasAdvancedFields || models.isNotEmpty
                        ? onExpandToggle
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _bgCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            expanded ? 'Hide' : 'Setup',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: _textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetaPill(
                label: '$availableCount of ${models.length} models ready',
                icon: Icons.memory_outlined,
              ),
              if (provider.supportsApiKey && provider.credentialConfigured)
                const _MetaPill(
                  label: 'Credentials ready',
                  icon: Icons.lock_outline,
                ),
              if (provider.supportsApiKey && !provider.credentialConfigured)
                const _MetaPill(
                  label: 'Credentials needed',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              if (provider.supportsBaseUrl &&
                  baseUrlController.text.trim().isNotEmpty)
                _MetaPill(
                  label: _friendlyBaseUrlLabel(baseUrlController.text.trim()),
                  icon: Icons.link_outlined,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    provider.availabilityReason,
                    style: TextStyle(color: _textSecondary, height: 1.35),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            ),
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: 14),
            if (provider.supportsApiKey)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  provider.credentialConfigured
                      ? 'Credentials for this provider are already available to the runtime.'
                      : 'Credentials for this provider are managed outside this workspace UI. Finish the server or admin setup, then return here to enable routing.',
                  style: TextStyle(color: _textSecondary, height: 1.35),
                ),
              ),
            if (provider.supportsBaseUrl) ...<Widget>[
              TextField(
                controller: baseUrlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: provider.id == 'ollama'
                      ? 'Server URL'
                      : 'Base URL',
                  helperText: provider.defaultBaseUrl.trim().isEmpty
                      ? 'Optional override.'
                      : 'Default: ${provider.defaultBaseUrl}',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (models.isNotEmpty) ...<Widget>[
              Text('Models', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: models
                    .map(
                      (model) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: model.available ? _bgCard : _bgPrimary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: model.available ? _border : _borderLight,
                          ),
                        ),
                        child: Text(
                          model.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: model.available
                                ? _textPrimary
                                : _textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RoutingSelectCard extends StatelessWidget {
  const _RoutingSelectCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: _accentHover),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: value,
            items: items,
            decoration: const InputDecoration(isDense: true),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class LogsPanel extends StatefulWidget {
  const LogsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends State<LogsPanel> {
  static const JsonEncoder _debugJsonEncoder = JsonEncoder.withIndent('  ');
  bool _isExportingRecentMessages = false;

  String _recentLogsText() =>
      widget.controller.logs.map((log) => log.clipboardLine).join('\n');

  String _prettyJson(Object? value) => _debugJsonEncoder.convert(value);

  Future<Map<String, dynamic>?> _buildRunExport(
    String runId,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    if (runId.trim().isEmpty) {
      return null;
    }
    if (cache.containsKey(runId)) {
      return cache[runId];
    }
    try {
      final detail = await widget.controller.fetchRunDetail(runId);
      final payload = <String, dynamic>{
        'run': <String, dynamic>{
          'id': detail.run.id,
          'title': detail.run.title,
          'status': detail.run.status,
          'statusLabel': detail.run.statusLabel,
          'triggerSource': detail.run.triggerSource,
          'triggerLabel': detail.run.triggerLabel,
          'model': detail.run.model,
          'createdAt': detail.run.createdAt.toIso8601String(),
          'completedAt': detail.run.completedAt?.toIso8601String(),
          'durationLabel': detail.run.durationLabel,
          'totalTokens': detail.run.totalTokens,
          'error': detail.run.error,
        },
        'response': detail.response,
        'steps': detail.steps
            .map(
              (step) => <String, dynamic>{
                'id': step.id,
                'index': step.index,
                'displayIndex': step.displayIndex,
                'type': step.type,
                'status': step.status,
                'description': step.description,
                'toolName': step.toolName,
                'toolInput': step.toolInput,
                'result': step.result,
                'error': step.error,
                'tokensUsed': step.tokensUsed,
                'startedAt': step.startedAt?.toIso8601String(),
                'completedAt': step.completedAt?.toIso8601String(),
              },
            )
            .toList(),
      };
      cache[runId] = payload;
      return payload;
    } catch (error) {
      final payload = <String, dynamic>{
        'runId': runId,
        'error': error.toString(),
      };
      cache[runId] = payload;
      return payload;
    }
  }

  Future<String> _buildRecentMessagesExport() async {
    final controller = widget.controller;
    final recentMessages = controller.visibleChatMessages.reversed
        .take(5)
        .toList()
        .reversed
        .toList();
    final runCache = <String, Map<String, dynamic>>{};

    final messages = <Map<String, dynamic>>[];
    for (final entry in recentMessages) {
      final runId = entry.runId?.trim() ?? '';
      messages.add(<String, dynamic>{
        'id': entry.id,
        'role': entry.role,
        'content': entry.content,
        'platform': entry.platform,
        'senderName': entry.senderName,
        'createdAt': entry.createdAt.toIso8601String(),
        'transient': entry.transient,
        'runId': runId.isEmpty ? null : runId,
        'metadata': entry.metadata,
        'toolCalls': entry.toolCalls,
        if (runId.isNotEmpty)
          'runDetail': await _buildRunExport(runId, runCache),
      });
    }

    final export = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'kind': 'recent_chat_export',
      'messageCount': messages.length,
      'agent': <String, dynamic>{
        'id': controller.selectedAgentId,
        'label': controller.activeAgentLabel,
      },
      'liveRun': controller.activeRun == null
          ? null
          : <String, dynamic>{
              'runId': controller.activeRun!.runId,
              'title': controller.activeRun!.title,
              'model': controller.activeRun!.model,
              'phase': controller.activeRun!.phase,
              'iteration': controller.activeRun!.iteration,
              'pendingSteeringCount':
                  controller.activeRun!.pendingSteeringCount,
              'triggerSource': controller.activeRun!.triggerSource,
            },
      'liveToolEvents': controller.toolEvents
          .map(
            (event) => <String, dynamic>{
              'id': event.id,
              'toolName': event.toolName,
              'type': event.type,
              'status': event.status,
              'summary': event.summary,
            },
          )
          .toList(),
      'messages': messages,
    };
    return _prettyJson(export);
  }

  String _buildDebugInfo() {
    final controller = widget.controller;
    final now = DateTime.now().toIso8601String();
    final versionInfo = controller.versionInfo;
    final backendStatus = controller.backendHealthStatus;
    final lastRun = _jsonMap(backendStatus?['lastRun']);
    final lastNonEmptyRun = _jsonMap(backendStatus?['lastNonEmptyRun']);

    final snapshot = <String, dynamic>{
      'generatedAt': now,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'session': <String, dynamic>{
        'backendUrl': controller.backendUrl,
        'authenticated': controller.isAuthenticated,
        'socketConnected': controller.socketConnected,
        'selectedSection': controller.selectedSection.label,
        'account': controller.accountLabel,
      },
      'version': <String, dynamic>{
        'name': versionInfo?['name'],
        'version': versionInfo?['version'],
        'packageVersion': versionInfo?['packageVersion'],
        'gitVersion': versionInfo?['gitVersion'],
        'gitBranch': versionInfo?['gitBranch'],
        'gitSha': versionInfo?['gitSha'],
        'deploymentMode':
            versionInfo?['deploymentMode'] ??
            controller.updateStatus.deploymentMode,
        'deploymentProfile':
            versionInfo?['deploymentProfile'] ??
            controller.updateStatus.deploymentProfile,
        'allowSelfUpdate':
            versionInfo?['allowSelfUpdate'] ??
            controller.updateStatus.allowSelfUpdate,
        'releaseChannel':
            versionInfo?['releaseChannel'] ??
            controller.updateStatus.releaseChannel,
        'targetBranch':
            versionInfo?['targetBranch'] ??
            controller.updateStatus.targetBranch,
        'npmDistTag':
            versionInfo?['npmDistTag'] ?? controller.updateStatus.npmDistTag,
      },
      'ai': <String, dynamic>{
        'defaultChatModel': controller.defaultChatModel,
        'defaultSubagentModel': controller.defaultSubagentModel,
        'fallbackModel': controller.fallbackModel,
        'smarterSelector': controller.smarterSelector,
        'enabledModelCount': controller.enabledModelIds.length,
        'availableModelCount': controller.supportedModels
            .where((model) => model.available)
            .length,
        'providerStatus': controller.aiProviders
            .map(
              (provider) => <String, dynamic>{
                'id': provider.id,
                'enabled': provider.enabled,
                'available': provider.available,
                'status': provider.status,
                'statusLabel': provider.statusLabel,
                'modelCount': provider.modelCount,
                'availableModelCount': provider.availableModelCount,
                'baseUrl': provider.supportsBaseUrl ? provider.baseUrl : null,
                'credentialConfigured': provider.credentialConfigured,
              },
            )
            .toList(),
      },
      'runtime': <String, dynamic>{
        'headlessBrowser': controller.headlessBrowser,
        'browserBackend': controller.browserBackend,
        'browserExtensionConnected': controller.browserExtensionConnected,
        'hasLiveRun': controller.hasLiveRun,
        'activeRun': controller.activeRun == null
            ? null
            : <String, dynamic>{
                'runId': controller.activeRun!.runId,
                'title': controller.activeRun!.title,
                'model': controller.activeRun!.model,
                'phase': controller.activeRun!.phase,
                'iteration': controller.activeRun!.iteration,
                'pendingSteeringCount':
                    controller.activeRun!.pendingSteeringCount,
                'triggerSource': controller.activeRun!.triggerSource,
              },
      },
      'updateStatus': <String, dynamic>{
        'state': controller.updateStatus.state,
        'progress': controller.updateStatus.progress,
        'message': controller.updateStatus.message,
        'deploymentProfile': controller.updateStatus.deploymentProfile,
        'versionBefore': controller.updateStatus.versionBefore,
        'versionAfter': controller.updateStatus.versionAfter,
        'installedVersion': controller.updateStatus.installedVersion,
        'backendVersion': controller.updateStatus.backendVersion,
        'runtimeValidationReady':
            controller.updateStatus.runtimeValidationReady,
        'runtimeValidationIssues':
            controller.updateStatus.runtimeValidationIssues,
        'releaseChannel': controller.updateStatus.releaseChannel,
        'targetBranch': controller.updateStatus.targetBranch,
        'npmDistTag': controller.updateStatus.npmDistTag,
        'changelog': controller.updateStatus.changelog,
        'updateLogs': controller.updateStatus.logs,
      },
      'health': <String, dynamic>{
        'status': backendStatus?['status'],
        'timestamp': backendStatus?['timestamp'],
        'metricsCount': _jsonList(
          backendStatus?['metrics'],
          fallbackToMapValues: true,
        ).length,
        'lastRun': lastRun.isEmpty
            ? null
            : <String, dynamic>{
                'startedAt': lastRun['started_at'],
                'completedAt': lastRun['completed_at'],
                'recordCount': lastRun['record_count'],
                'syncWindowEnd': lastRun['sync_window_end'],
                'summary': _jsonMap(lastRun['summary']),
              },
        'lastNonEmptyRun': lastNonEmptyRun.isEmpty
            ? null
            : <String, dynamic>{
                'startedAt': lastNonEmptyRun['started_at'],
                'completedAt': lastNonEmptyRun['completed_at'],
                'recordCount': lastNonEmptyRun['record_count'],
                'syncWindowEnd': lastNonEmptyRun['sync_window_end'],
                'summary': _jsonMap(lastNonEmptyRun['summary']),
              },
      },
      'recentLogs': controller.logs
          .map(
            (log) => <String, dynamic>{
              'time': log.timeLabel,
              'type': log.type,
              'source': log.source,
              'message': log.message,
            },
          )
          .toList(),
    };

    return ['NeoAgent debug info', _prettyJson(snapshot)].join('\n\n');
  }

  Future<void> _copyLogs() async {
    final logsText = _recentLogsText();
    if (logsText.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: logsText));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied logs')));
  }

  Future<void> _copyDebugInfo() async {
    await Clipboard.setData(ClipboardData(text: _buildDebugInfo()));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied debug info')));
  }

  Future<void> _exportRecentMessages() async {
    if (_isExportingRecentMessages) {
      return;
    }
    setState(() => _isExportingRecentMessages = true);
    try {
      final exportText = await _buildRecentMessagesExport();
      await Clipboard.setData(ClipboardData(text: exportText));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied export for the last 5 messages')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export failed: ${widget.controller._friendlyErrorMessage(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingRecentMessages = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Logs',
          subtitle:
              'Merged server and Flutter runtime logs for this app session.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _isExportingRecentMessages
                    ? null
                    : _exportRecentMessages,
                icon: _isExportingRecentMessages
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.ios_share_outlined),
                label: Text('Export last 5 messages'),
              ),
              OutlinedButton.icon(
                onPressed: _copyDebugInfo,
                icon: Icon(Icons.bug_report_outlined),
                label: Text('Copy debug info'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.logs.isEmpty ? null : _copyLogs,
                icon: Icon(Icons.copy_all_outlined),
                label: Text('Copy logs'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.clearLogs,
                icon: Icon(Icons.clear_all),
                label: Text('Clear'),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.controller.logs.isEmpty
                ? Text(
                    'Waiting for server or Flutter log output…',
                    style: TextStyle(color: _textSecondary),
                  )
                : Column(
                    children: widget.controller.logs.map((log) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: _border)),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '[${log.timeLabel}] ',
                                style: TextStyle(color: _textMuted),
                              ),
                              TextSpan(
                                text: '[${log.sourceLabel}] ',
                                style: TextStyle(color: _textSecondary),
                              ),
                              TextSpan(
                                text: log.message,
                                style: TextStyle(color: log.color),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class SkillsPanel extends StatefulWidget {
  const SkillsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<SkillsPanel> createState() => _SkillsPanelState();
}

class _SkillsPanelState extends State<SkillsPanel>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TabController _tabController;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _searchController.text.trim().toLowerCase();
    final categories = <String>{
      'all',
      ...controller.storeSkills.map((item) => item.category),
    }.toList();
    final filteredStore =
        controller.storeSkills.where((item) {
          final matchesQuery =
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query);
          final matchesCategory =
              _selectedCategory == 'all' || item.category == _selectedCategory;
          return matchesQuery && matchesCategory;
        }).toList()..sort((a, b) {
          if (a.installed != b.installed) {
            return a.installed ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

    return Padding(
      padding: _pagePadding(context),
      child: Column(
        children: <Widget>[
          _PageTitle(
            title: 'Skills',
            subtitle:
                'Manage installed skills and browse the store. Official integrations live in their own section.',
            trailing: FilledButton.icon(
              onPressed: () => _openCreateSkill(context),
              icon: Icon(Icons.add),
              label: Text('New Skill'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: TextStyle(fontWeight: FontWeight.w700),
              tabs: <Widget>[
                Tab(text: 'Installed Skills (${controller.skills.length})'),
                Tab(text: 'Store (${filteredStore.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildInstalledTab(controller),
                _buildStoreTab(controller, categories, filteredStore),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledTab(NeoAgentController controller) {
    if (controller.skills.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.extension_off_outlined,
                size: 34,
                color: _textSecondary,
              ),
              SizedBox(height: 12),
              Text(
                'No current skills yet. Install from Store or create a new one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: controller.skills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final skill = controller.skills[index];
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  skill.name,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Switch(
                                value: skill.enabled,
                                onChanged: (value) => controller
                                    .setSkillEnabled(skill.name, value),
                              ),
                            ],
                          ),
                          Text(
                            skill.description.ifEmpty('No description'),
                            style: TextStyle(color: _textSecondary),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _MetaPill(
                                label: skill.category,
                                icon: Icons.folder_outlined,
                              ),
                              _MetaPill(
                                label: skill.source,
                                icon: Icons.source_outlined,
                              ),
                              if (skill.draft)
                                const _MetaPill(
                                  label: 'Draft',
                                  icon: Icons.edit_note_outlined,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              const Spacer(),
                              OutlinedButton(
                                onPressed: () =>
                                    _openSkillEditor(context, skill.name),
                                child: Text('Open'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmDeleteSkill(context, skill.name),
                                icon: Icon(Icons.delete_outline),
                                style: TextButton.styleFrom(
                                  foregroundColor: _danger,
                                ),
                                label: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  skill.name,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  skill.description.ifEmpty('No description'),
                                  style: TextStyle(color: _textSecondary),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    _MetaPill(
                                      label: skill.category,
                                      icon: Icons.folder_outlined,
                                    ),
                                    _MetaPill(
                                      label: skill.source,
                                      icon: Icons.source_outlined,
                                    ),
                                    if (skill.draft)
                                      const _MetaPill(
                                        label: 'Draft',
                                        icon: Icons.edit_note_outlined,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: <Widget>[
                              Switch(
                                value: skill.enabled,
                                onChanged: (value) => controller
                                    .setSkillEnabled(skill.name, value),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _openSkillEditor(context, skill.name),
                                child: Text('Open'),
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmDeleteSkill(context, skill.name),
                                icon: Icon(Icons.delete_outline),
                                style: TextButton.styleFrom(
                                  foregroundColor: _danger,
                                ),
                                label: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStoreTab(
    NeoAgentController controller,
    List<String> categories,
    List<StoreSkillItem> filteredStore,
  ) {
    final featured = filteredStore.take(6).toList();
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[_bgSecondary, _accentMuted],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Skill Store',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Discover, install, and manage skills in a compact catalog.',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search skills',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category == _selectedCategory;
                return FilterChip(
                  selected: selected,
                  label: Text(category == 'all' ? 'All' : category),
                  selectedColor: _accentMuted,
                  checkmarkColor: _accent,
                  backgroundColor: _bgSecondary,
                  side: BorderSide(color: _border),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          if (featured.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const _SectionTitle('Featured'),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = featured[index];
                  return Container(
                    width: 280,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bgSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.installed ? _accentMuted : _border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(item.icon, style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            item.installed
                                ? _StatusPill(
                                    label: 'Installed',
                                    color: _success,
                                  )
                                : _StatusPill(label: 'Get', color: _info),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _textSecondary, height: 1.35),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: item.installed
                              ? OutlinedButton(
                                  onPressed: () =>
                                      controller.uninstallStoreSkill(item.id),
                                  child: Text('Uninstall'),
                                )
                              : FilledButton(
                                  onPressed: () =>
                                      controller.installStoreSkill(item.id),
                                  child: Text('Install'),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const _SectionTitle('All Skills'),
              const Spacer(),
              Text(
                '${filteredStore.length} results',
                style: TextStyle(color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredStore.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No store skills match the current filter.',
                style: TextStyle(color: _textSecondary),
              ),
            )
          else
            ...filteredStore.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 740;
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(item.icon, style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _StatusPill(
                                  label: item.installed ? 'Installed' : 'Get',
                                  color: item.installed ? _success : _info,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.description,
                              style: TextStyle(color: _textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                _MetaPill(
                                  label: item.category,
                                  icon: Icons.grid_view_rounded,
                                ),
                                const Spacer(),
                                item.installed
                                    ? OutlinedButton(
                                        onPressed: () => controller
                                            .uninstallStoreSkill(item.id),
                                        child: Text('Uninstall'),
                                      )
                                    : FilledButton(
                                        onPressed: () => controller
                                            .installStoreSkill(item.id),
                                        child: Text('Install'),
                                      ),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: <Widget>[
                          Text(item.icon, style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _MetaPill(
                                  label: item.category,
                                  icon: Icons.grid_view_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          item.installed
                              ? OutlinedButton(
                                  onPressed: () =>
                                      controller.uninstallStoreSkill(item.id),
                                  child: Text('Uninstall'),
                                )
                              : FilledButton(
                                  onPressed: () =>
                                      controller.installStoreSkill(item.id),
                                  child: Text('Install'),
                                ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSkillEditor(BuildContext context, String name) async {
    final document = await widget.controller.fetchSkillDocument(name);
    final contentController = TextEditingController(text: document.content);
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text(name),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: contentController,
              minLines: 16,
              maxLines: 24,
              decoration: const InputDecoration(labelText: 'Skill Content'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.controller.saveSkillContent(
                  name: name,
                  content: contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateSkill(BuildContext context) async {
    final nameController = TextEditingController();
    final contentController = TextEditingController(
      text: '''---
name: New Skill
description: Describe what this skill does
---
Write the instructions for this skill here.
''',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('New Skill'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Filename'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 16,
                    maxLines: 24,
                    decoration: const InputDecoration(labelText: 'Content'),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.controller.createSkill(
                  filename: nameController.text.trim(),
                  content: contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteSkill(BuildContext context, String name) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Delete skill?'),
          content: Text('"$name" will be removed permanently.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _danger),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.controller.deleteSkill(name);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted "$name".')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete "$name": $error')),
      );
    }
  }
}

class MemoryPanel extends StatefulWidget {
  const MemoryPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<MemoryPanel> createState() => _MemoryPanelState();
}

class _MemoryPanelState extends State<MemoryPanel> {
  late final TextEditingController _searchController;
  final Set<String> _selectedMemoryIds = <String>{};
  bool _bulkActionInFlight = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MemoryItem> get _visibleMemories {
    final controller = widget.controller;
    return controller.memoryRecallResults.isNotEmpty
        ? controller.memoryRecallResults
        : controller.memories;
  }

  List<String> get _selectedVisibleMemoryIds {
    final visibleIds = _visibleMemories.map((memory) => memory.id).toSet();
    return _selectedMemoryIds
        .where(visibleIds.contains)
        .toList(growable: false);
  }

  void _toggleMemorySelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedMemoryIds.add(id);
      } else {
        _selectedMemoryIds.remove(id);
      }
    });
  }

  void _clearMemorySelection() {
    if (_selectedMemoryIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedMemoryIds.clear();
    });
  }

  void _selectAllVisibleMemories(List<MemoryItem> memories) {
    if (memories.isEmpty) {
      return;
    }
    setState(() {
      _selectedMemoryIds.addAll(memories.map((memory) => memory.id));
    });
  }

  Future<void> _runMemorySearch(NeoAgentController controller) async {
    _clearMemorySelection();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      controller.clearMemorySearch();
    } else {
      await controller.searchMemories(query);
    }
  }

  void _resetMemorySearch(NeoAgentController controller) {
    _searchController.clear();
    _clearMemorySelection();
    controller.clearMemorySearch();
  }

  Future<void> _deleteSingleMemory(
    NeoAgentController controller,
    String id,
  ) async {
    await controller.deleteMemory(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedMemoryIds.remove(id);
    });
  }

  Future<void> _runBulkMemoryAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function(List<String> ids) onConfirm,
  }) async {
    final ids = _selectedVisibleMemoryIds;
    if (ids.isEmpty || _bulkActionInFlight) {
      return;
    }
    await _confirmDelete(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirm: () async {
        setState(() {
          _bulkActionInFlight = true;
        });
        try {
          await onConfirm(ids);
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedMemoryIds.removeAll(ids);
          });
        } finally {
          if (mounted) {
            setState(() {
              _bulkActionInFlight = false;
            });
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final memoriesToShow = _visibleMemories;
    final selectedMemoryIds = _selectedVisibleMemoryIds.toSet();
    final selectedCount = selectedMemoryIds.length;
    final allVisibleSelected =
        memoriesToShow.isNotEmpty &&
        memoriesToShow.every((memory) => selectedMemoryIds.contains(memory.id));
    final showingSearchResults = controller.memoryRecallResults.isNotEmpty;

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Memory',
          subtitle:
              'Core memory, thread context, long-term recall, daily logs, and behavior notes.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _openBehaviorNotesEditor(context, controller),
                icon: Icon(Icons.edit_outlined),
                label: Text('Behavior Notes'),
              ),
              FilledButton.icon(
                onPressed: () => _openMemoryCreator(context, controller),
                icon: Icon(Icons.add),
                label: Text('Add Memory'),
              ),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewCard(
                title: 'Behavior Notes',
                value: '${controller.memoryOverview.behaviorNotesLength} chars',
                helper: 'Durable assistant style guidance',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Core Memory',
                value: '${controller.memoryOverview.coreCount}',
                helper: 'Pinned key/value entries',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Daily Logs',
                value: '${controller.memoryOverview.dailyLogCount}',
                helper: 'Recent captured log files',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'API Keys',
                value: '${controller.memoryOverview.apiKeyCount}',
                helper: 'Masked agent-managed credentials',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Recall Search'),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search memory',
                        ),
                        onSubmitted: (_) => _runMemorySearch(controller),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => _runMemorySearch(controller),
                      child: Text('Search'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _resetMemorySearch(controller),
                      child: Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _SectionTitle('Core Memory')),
                    TextButton.icon(
                      onPressed: () =>
                          _openCoreMemoryEditor(context, controller),
                      icon: Icon(Icons.add),
                      label: Text('Add Entry'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (controller.memoryOverview.coreEntries.isEmpty)
                  Text(
                    'No core memory entries yet.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.memoryOverview.coreEntries.entries.map((entry) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.key,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(entry.value.toString()),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openCoreMemoryEditor(
                              context,
                              controller,
                              keyValue: entry,
                            ),
                            icon: Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete core memory entry?',
                              message:
                                  'Remove "${entry.key}" from core memory.',
                              onConfirm: () =>
                                  controller.deleteCoreMemory(entry.key),
                            ),
                            icon: Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Memories'),
                const SizedBox(height: 6),
                Text(
                  showingSearchResults
                      ? 'Showing search results. Select memories to archive or delete them together.'
                      : 'Select one or more memories to archive or delete them together.',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 10),
                if (memoriesToShow.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: allVisibleSelected || _bulkActionInFlight
                            ? null
                            : () => _selectAllVisibleMemories(memoriesToShow),
                        icon: Icon(Icons.done_all_outlined),
                        label: Text(
                          allVisibleSelected ? 'All Selected' : 'Select All',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: selectedCount == 0 || _bulkActionInFlight
                            ? null
                            : _clearMemorySelection,
                        icon: Icon(Icons.deselect_outlined),
                        label: Text('Clear Selection'),
                      ),
                      if (selectedCount > 0)
                        FilledButton.icon(
                          onPressed: _bulkActionInFlight
                              ? null
                              : () => _runBulkMemoryAction(
                                  title: 'Archive selected memories?',
                                  message:
                                      'Archive $selectedCount selected ${selectedCount == 1 ? 'memory' : 'memories'}? Archived memories are removed from the main list.',
                                  confirmLabel: 'Archive',
                                  onConfirm: controller.archiveMemories,
                                ),
                          icon: Icon(Icons.archive_outlined),
                          label: Text('Archive ($selectedCount)'),
                        ),
                      if (selectedCount > 0)
                        OutlinedButton.icon(
                          onPressed: _bulkActionInFlight
                              ? null
                              : () => _runBulkMemoryAction(
                                  title: 'Delete selected memories?',
                                  message:
                                      'Delete $selectedCount selected ${selectedCount == 1 ? 'memory' : 'memories'} permanently?',
                                  confirmLabel: 'Delete',
                                  onConfirm: controller.deleteMemories,
                                ),
                          icon: Icon(Icons.delete_sweep_outlined),
                          label: Text('Delete ($selectedCount)'),
                        ),
                    ],
                  ),
                if (selectedCount > 0) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    '$selectedCount selected',
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (memoriesToShow.isNotEmpty) const SizedBox(height: 10),
                if (memoriesToShow.isEmpty)
                  Text(
                    'No memory entries found.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...memoriesToShow.map((memory) {
                    final isSelected = selectedMemoryIds.contains(memory.id);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _accentMuted : _bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _accent : _border,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              _toggleMemorySelection(memory.id, !isSelected),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) => _toggleMemorySelection(
                                    memory.id,
                                    value ?? false,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: <Widget>[
                                                _MetaPill(
                                                  label: memory.category,
                                                  icon: Icons.label_outline,
                                                ),
                                                _MetaPill(
                                                  label:
                                                      'Importance ${memory.importance}',
                                                  icon: Icons
                                                      .priority_high_outlined,
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _bulkActionInFlight
                                                ? null
                                                : () => _confirmDelete(
                                                    context,
                                                    title: 'Delete memory?',
                                                    message:
                                                        'This memory entry will be removed permanently.',
                                                    onConfirm: () =>
                                                        _deleteSingleMemory(
                                                          controller,
                                                          memory.id,
                                                        ),
                                                  ),
                                            icon: Icon(Icons.delete_outline),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(memory.content),
                                      const SizedBox(height: 8),
                                      Text(
                                        memory.createdAtLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Recent Conversations'),
                const SizedBox(height: 10),
                if (controller.memoryConversations.isEmpty)
                  Text(
                    'No recent conversations found.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...controller.memoryConversations.map(
                    (conversation) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              conversation.title,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              conversation.preview,
                              style: TextStyle(color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openMemoryCreator(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final contentController = TextEditingController();
    final importanceController = TextEditingController(text: '5');
    String category = 'episodic';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Add Memory'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'episodic',
                      child: Text('episodic'),
                    ),
                    DropdownMenuItem(
                      value: 'user_fact',
                      child: Text('user_fact'),
                    ),
                    DropdownMenuItem(
                      value: 'preference',
                      child: Text('preference'),
                    ),
                    DropdownMenuItem(
                      value: 'personality',
                      child: Text('personality'),
                    ),
                  ],
                  decoration: const InputDecoration(labelText: 'Category'),
                  onChanged: (value) {
                    if (value != null) {
                      category = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: importanceController,
                  decoration: const InputDecoration(labelText: 'Importance'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Content'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.createMemory(
                  content: contentController.text.trim(),
                  category: category,
                  importance:
                      int.tryParse(importanceController.text.trim()) ?? 5,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBehaviorNotesEditor(
    BuildContext context,
    NeoAgentController controller,
  ) async {
    final contentController = TextEditingController(
      text: controller.memoryOverview.assistantBehaviorNotes,
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text('Edit Assistant Behavior Notes'),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: contentController,
              minLines: 16,
              maxLines: 24,
              decoration: const InputDecoration(
                labelText: 'assistant_behavior_notes',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.updateAssistantBehaviorNotes(
                  contentController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCoreMemoryEditor(
    BuildContext context,
    NeoAgentController controller, {
    MapEntry<String, dynamic>? keyValue,
  }) async {
    final keyController = TextEditingController(text: keyValue?.key ?? '');
    final valueController = TextEditingController(
      text: keyValue?.value?.toString() ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _bgCard,
          title: Text(
            keyValue == null
                ? 'Add Core Memory Entry'
                : 'Edit Core Memory Entry',
          ),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.updateCoreMemory(
                  keyController.text.trim(),
                  valueController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class WidgetsPanel extends StatelessWidget {
  const WidgetsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Widgets',
          subtitle:
              'Beautiful, glanceable AI widgets that stay in sync across the app, launcher, and Android home screen.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: controller.refreshWidgets,
                icon: Icon(Icons.refresh_rounded),
                label: Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: controller.openWidgetCreateFlow,
                icon: Icon(Icons.auto_awesome_outlined),
                label: Text('Create With AI'),
              ),
            ],
          ),
        ),
        if (controller.widgets.isEmpty)
          const _EmptyCard(
            title: 'No AI widgets yet',
            subtitle:
                'Create a widget through the agent and it will appear here, in launcher mode, and in Android home widgets.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = constraints.maxWidth >= 1100 ? 18.0 : 0.0;
              final columns = constraints.maxWidth >= 1400
                  ? 2
                  : (constraints.maxWidth >= 920 ? 2 : 1);
              final width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
              final cardWidth = columns == 1
                  ? width
                  : (width - (spacing * (columns - 1))) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 18,
                children: controller.widgets.map((item) {
                  final remaining = controller.widgetRunCooldownSeconds(
                    item.id,
                  );
                  return SizedBox(
                    width: cardWidth,
                    child: _AiWidgetCard(
                      item: item,
                      controller: controller,
                      active: controller.selectedWidgetId == item.id,
                      onSelect: () => controller.selectWidget(item.id),
                      footer: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () =>
                                controller.openWidgetEditFlow(item),
                            child: Text('Edit With AI'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                controller.toggleWidgetEnabled(item),
                            child: Text(item.enabled ? 'Pause' : 'Enable'),
                          ),
                          FilledButton(
                            onPressed: remaining > 0
                                ? null
                                : () => controller.refreshWidgetNow(item.id),
                            child: Text(
                              _manualRunButtonLabel('Run Now', remaining),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete widget?',
                              message:
                                  'This removes "${item.name}" and its refresh job.',
                              onConfirm: () => controller.deleteWidget(item.id),
                            ),
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class _AiWidgetCard extends StatefulWidget {
  const _AiWidgetCard({
    required this.item,
    this.controller,
    this.footer,
    this.active = false,
    this.compact = false,
    this.onSelect,
  });

  final AiWidgetItem item;
  final NeoAgentController? controller;
  final Widget? footer;
  final bool active;
  final bool compact;
  final VoidCallback? onSelect;

  @override
  State<_AiWidgetCard> createState() => _AiWidgetCardState();
}

class _AiWidgetCardState extends State<_AiWidgetCard> {
  bool _expandedTasks = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final controller = widget.controller;
    final active = widget.active;
    final compact = widget.compact;
    final onSelect = widget.onSelect;
    final footer = widget.footer;
    final snapshot = item.latestSnapshot;
    final accent = _widgetAccentColor(
      snapshot?.accentToken ?? item.template,
      surfaceColor: snapshot?.surfaceColor ?? '',
    );
    final icon = _widgetIconData(snapshot?.iconToken ?? item.template);
    final displayName = _widgetDisplayName(item.name);
    final title = _widgetPrimaryTitle(item, snapshot);
    final subtitle = _widgetSecondaryTitle(item, snapshot);
    final metric = snapshot?.metric ?? '';
    final rows = snapshot?.rows ?? const <Map<String, dynamic>>[];
    final chips = snapshot?.chips ?? const <String>[];
    final body = _widgetSummaryText(item, snapshot);
    final updatedLabel = snapshot?.generatedAtLabel ?? item.lastSnapshotLabel;
    final cadenceLabel = _widgetCadenceLabel(item.refreshCron);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(
              _bgCard,
              accent,
              compact ? 0.14 : 0.18,
            )!.withValues(alpha: 0.98),
            _bgCard.withValues(alpha: 0.98),
            _bgSecondary.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(
          color: active ? accent.withValues(alpha: 0.42) : _border,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: compact ? 0.1 : 0.14),
            blurRadius: compact ? 22 : 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 28 : 32),
          onTap: onSelect,
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 22),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _AiWidgetAndroidPreview(
                        item: item,
                        accent: accent,
                        icon: icon,
                        snapshot: snapshot,
                        compact: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.26),
                              ),
                            ),
                            child: Icon(icon, color: accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 24,
                                    height: 1.06,
                                    letterSpacing: -0.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StatusPill(
                            label: item.enabled ? 'Live' : 'Paused',
                            color: item.enabled ? _success : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 860;
                          final infoPane = _AiWidgetInfoPane(
                            item: item,
                            snapshot: snapshot,
                            accent: accent,
                            title: title,
                            subtitle: subtitle,
                            body: body,
                            metric: metric,
                            rows: rows,
                            chips: chips,
                            cadenceLabel: cadenceLabel,
                            updatedLabel: updatedLabel,
                          );
                          final previewPane = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Preview',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _AiWidgetAndroidPreview(
                                item: item,
                                accent: accent,
                                icon: icon,
                                snapshot: snapshot,
                              ),
                            ],
                          );
                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                infoPane,
                                const SizedBox(height: 20),
                                previewPane,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 11, child: infoPane),
                              const SizedBox(width: 20),
                              Expanded(flex: 10, child: previewPane),
                            ],
                          );
                        },
                      ),
                      if (item.hasError) ...<Widget>[
                        const SizedBox(height: 16),
                        _InlineError(message: item.lastError!),
                      ],
                      if (item.tasks.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _expandedTasks = !_expandedTasks;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Tasks (${item.tasks.length})',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _expandedTasks
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: accent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_expandedTasks)
                          ...item.tasks.map((task) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.name,
                                            style: TextStyle(
                                              color: _textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (task
                                              .scheduleLabel
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              task.scheduleLabel,
                                              style: TextStyle(
                                                color: _textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      onPressed: controller != null
                                          ? () => controller.runTaskNow(task.id)
                                          : null,
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('Run now'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                      if (footer != null) ...<Widget>[
                        const SizedBox(height: 18),
                        footer!,
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AiWidgetInfoPane extends StatelessWidget {
  const _AiWidgetInfoPane({
    required this.item,
    required this.snapshot,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.metric,
    required this.rows,
    required this.chips,
    required this.cadenceLabel,
    required this.updatedLabel,
  });

  final AiWidgetItem item;
  final WidgetSnapshotItem? snapshot;
  final Color accent;
  final String title;
  final String subtitle;
  final String body;
  final String metric;
  final List<Map<String, dynamic>> rows;
  final List<String> chips;
  final String cadenceLabel;
  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    final kicker = _widgetSanitizedText(snapshot?.kicker ?? '');
    final metricLabel = _widgetSanitizedText(snapshot?.metricLabel ?? '');
    final secondaryMetric = _widgetSanitizedText(
      snapshot?.secondaryMetric ?? '',
    );
    final secondaryLabel = _widgetSanitizedText(snapshot?.secondaryLabel ?? '');
    final tertiaryMetric = _widgetSanitizedText(snapshot?.tertiaryMetric ?? '');
    final tertiaryLabel = _widgetSanitizedText(snapshot?.tertiaryLabel ?? '');
    final progress = snapshot?.progress;
    final progressValue = _widgetProgressFraction(progress);
    final hasUsefulRows = rows.any(
      (row) =>
          (row['label']?.toString() ?? '').trim().isNotEmpty ||
          (row['value']?.toString() ?? '').trim().isNotEmpty,
    );
    final hasSnapshotData =
        metric.trim().isNotEmpty ||
        secondaryMetric.isNotEmpty ||
        tertiaryMetric.isNotEmpty ||
        hasUsefulRows ||
        chips.isNotEmpty ||
        body.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (kicker.isNotEmpty) ...<Widget>[
          Text(
            kicker.toUpperCase(),
            style: TextStyle(
              color: accent.withValues(alpha: 0.94),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.08,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.4,
          ),
        ),
        if (subtitle.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 15, color: _textSecondary, height: 1.35),
          ),
        ],
        const SizedBox(height: 18),
        if (metric.trim().isNotEmpty) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  metric,
                  style: _displayTitleStyle(
                    42,
                  ).copyWith(color: accent, letterSpacing: -1.35),
                ),
                if (metricLabel.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    metricLabel,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (progress != null && progressValue != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _WidgetProgressBar(
                    accent: accent,
                    value: progressValue,
                    label: _widgetProgressLabel(progress),
                  ),
                ],
                if (secondaryMetric.isNotEmpty ||
                    tertiaryMetric.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      if (secondaryMetric.isNotEmpty)
                        _WidgetSupportingMetricCard(
                          label: secondaryLabel.ifEmpty('Secondary'),
                          value: secondaryMetric,
                          accent: accent,
                        ),
                      if (tertiaryMetric.isNotEmpty)
                        _WidgetSupportingMetricCard(
                          label: tertiaryLabel.ifEmpty('Detail'),
                          value: tertiaryMetric,
                          accent: accent,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ] else if (!hasSnapshotData) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              'Waiting for the first refresh. Once live data arrives, this widget will lead with the key number and keep the rest compact.',
              style: TextStyle(
                color: _textSecondary,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
        ],
        if (body.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _textPrimary, height: 1.5, fontSize: 15),
          ),
        ],
        if (hasUsefulRows) ...<Widget>[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: rows.take(3).map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _widgetSanitizedText(
                            row['label']?.toString() ?? '',
                            fallback: 'Detail',
                          ),
                          style: TextStyle(color: _textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _widgetSanitizedText(row['value']?.toString() ?? ''),
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (chips.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.take(3).map((chip) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            _WidgetMetricBlock(label: 'Refreshes', value: cadenceLabel),
            _WidgetMetricBlock(label: 'Last update', value: updatedLabel),
            _WidgetMetricBlock(
              label: 'Status',
              value: item.enabled ? 'Live' : 'Paused',
              accent: item.enabled ? _success : _textSecondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _AiWidgetAndroidPreview extends StatelessWidget {
  const _AiWidgetAndroidPreview({
    required this.item,
    required this.accent,
    required this.icon,
    this.snapshot,
    this.compact = false,
  });

  final AiWidgetItem item;
  final Color accent;
  final IconData icon;
  final WidgetSnapshotItem? snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final activeSnapshot = snapshot ?? item.latestSnapshot;
    final displayName = _widgetDisplayName(item.name);
    final title = _widgetPrimaryTitle(item, activeSnapshot);
    final subtitle = _widgetSecondaryTitle(item, activeSnapshot);
    final body = _widgetSummaryText(item, activeSnapshot);
    final metric = _widgetSanitizedText(activeSnapshot?.metric ?? '');
    final metricLabel = _widgetSanitizedText(activeSnapshot?.metricLabel ?? '');
    final secondaryMetric = _widgetSanitizedText(
      activeSnapshot?.secondaryMetric ?? '',
    );
    final secondaryLabel = _widgetSanitizedText(
      activeSnapshot?.secondaryLabel ?? '',
    );
    final tertiaryMetric = _widgetSanitizedText(
      activeSnapshot?.tertiaryMetric ?? '',
    );
    final tertiaryLabel = _widgetSanitizedText(
      activeSnapshot?.tertiaryLabel ?? '',
    );
    final rows = activeSnapshot?.rows ?? const <Map<String, dynamic>>[];
    final chips = activeSnapshot?.chips ?? const <String>[];
    final progress = activeSnapshot?.progress;
    final previewRatio = _widgetPreviewAspectRatio(item.template);
    final palette = _widgetPreviewPalette(
      item.template,
      accent,
      backgroundToken: activeSnapshot?.backgroundToken ?? '',
      surfaceColor: activeSnapshot?.surfaceColor ?? '',
    );
    return AspectRatio(
      aspectRatio: previewRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 30 : 34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.colors,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.glow,
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: compact ? 26 : 28,
                    height: compact ? 26 : 28,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: compact ? 16 : 17,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.foreground.withValues(alpha: 0.96),
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: compact ? 18 : 20,
                    color: palette.foreground.withValues(alpha: 0.8),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: compact ? 18 : 20,
                    color: palette.foreground.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (item.template) {
                  'list' => _AiWidgetPreviewList(
                    title: title,
                    subtitle: subtitle,
                    rows: rows,
                    chips: chips,
                    accent: palette.accent,
                    palette: palette,
                    compact: compact,
                  ),
                  'summary' => _AiWidgetPreviewSummary(
                    title: title,
                    subtitle: subtitle,
                    body: body,
                    metric: metric,
                    metricLabel: metricLabel,
                    chips: chips,
                    palette: palette,
                    compact: compact,
                  ),
                  _ => _AiWidgetPreviewStat(
                    title: title,
                    subtitle: subtitle,
                    metric: metric,
                    metricLabel: metricLabel,
                    secondaryMetric: secondaryMetric,
                    secondaryLabel: secondaryLabel,
                    tertiaryMetric: tertiaryMetric,
                    tertiaryLabel: tertiaryLabel,
                    progress: progress,
                    rows: rows,
                    accent: palette.accent,
                    palette: palette,
                    compact: compact,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiWidgetPreviewStat extends StatelessWidget {
  const _AiWidgetPreviewStat({
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.metricLabel,
    required this.secondaryMetric,
    required this.secondaryLabel,
    required this.tertiaryMetric,
    required this.tertiaryLabel,
    required this.progress,
    required this.rows,
    required this.accent,
    required this.palette,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final String metric;
  final String metricLabel;
  final String secondaryMetric;
  final String secondaryLabel;
  final String tertiaryMetric;
  final String tertiaryLabel;
  final Map<String, dynamic>? progress;
  final List<Map<String, dynamic>> rows;
  final Color accent;
  final _WidgetPreviewPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final values = rows
        .where(
          (row) =>
              _widgetSanitizedText(row['label']?.toString() ?? '').isNotEmpty ||
              _widgetSanitizedText(row['value']?.toString() ?? '').isNotEmpty,
        )
        .take(3)
        .toList(growable: false);
    final hasMetric = metric.trim().isNotEmpty;
    final progressValue = _widgetProgressFraction(progress);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = compact || constraints.maxHeight < 190;
        final showSupportingPills =
            !dense && (secondaryMetric.isNotEmpty || tertiaryMetric.isNotEmpty);
        final showProgressValue = !dense ? progressValue : null;
        final visibleRows = values.take(dense ? 1 : 3).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (subtitle.trim().isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: dense ? 11 : (compact ? 12 : 13),
                ),
              ),
            SizedBox(height: dense ? 6 : 8),
            Text(
              title.trim().isNotEmpty ? title : 'Waiting for first update',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.foreground,
                fontSize: dense ? 15 : (compact ? 16 : 18),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.35,
              ),
            ),
            SizedBox(height: dense ? 8 : 10),
            Text(
              hasMetric ? metric : 'Waiting for first update',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.foreground,
                fontSize: dense ? 25 : (compact ? 30 : 34),
                height: 0.96,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.1,
              ),
            ),
            if (metricLabel.trim().isNotEmpty) ...<Widget>[
              SizedBox(height: dense ? 4 : 6),
              Text(
                metricLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: dense ? 10 : (compact ? 11 : 12),
                ),
              ),
            ],
            if (showSupportingPills) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (secondaryMetric.isNotEmpty)
                    _WidgetPreviewDataPill(
                      label: secondaryLabel.ifEmpty('Secondary'),
                      value: secondaryMetric,
                      palette: palette,
                    ),
                  if (tertiaryMetric.isNotEmpty)
                    _WidgetPreviewDataPill(
                      label: tertiaryLabel.ifEmpty('Detail'),
                      value: tertiaryMetric,
                      palette: palette,
                    ),
                ],
              ),
            ],
            if (showProgressValue != null) ...<Widget>[
              const SizedBox(height: 12),
              _WidgetPreviewProgress(
                value: showProgressValue,
                label: _widgetProgressLabel(progress),
                palette: palette,
              ),
            ],
            if (visibleRows.isNotEmpty) ...<Widget>[
              SizedBox(height: dense ? 10 : 14),
              ...visibleRows.map(
                (row) => Padding(
                  padding: EdgeInsets.only(bottom: dense ? 6 : 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _widgetSanitizedText(row['label']?.toString() ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: dense ? 10 : (compact ? 11 : 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _widgetSanitizedText(row['value']?.toString() ?? ''),
                        style: TextStyle(
                          color: palette.foreground,
                          fontSize: dense ? 11 : (compact ? 12 : 13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...<Widget>[
              const Spacer(),
              Text(
                'Waiting for first update',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: dense ? 11 : (compact ? 12 : 13),
                ),
              ),
              SizedBox(height: dense ? 8 : 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List<Widget>.generate(dense ? 6 : 8, (index) {
                  final count = dense ? 6 : 8;
                  final factor = (count - index) / count;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: dense ? 7 : (compact ? 8 : 10),
                      height: (dense ? 16 : (compact ? 20 : 26)) * factor + 8,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.62 - (index * 0.05)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AiWidgetPreviewSummary extends StatelessWidget {
  const _AiWidgetPreviewSummary({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.metric,
    required this.metricLabel,
    required this.chips,
    required this.palette,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final String body;
  final String metric;
  final String metricLabel;
  final List<String> chips;
  final _WidgetPreviewPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final topLabel = subtitle.trim().isNotEmpty ? subtitle : 'Summary';
    final headline = title.trim().isNotEmpty
        ? title
        : 'Waiting for first update';
    final copy = body.trim().isNotEmpty ? body : headline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          topLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.muted, fontSize: compact ? 11 : 12),
        ),
        const SizedBox(height: 10),
        Text(
          headline,
          maxLines: compact ? 3 : 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.foreground,
            fontSize: compact ? 20 : 24,
            height: 1.12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
          ),
        ),
        if (copy != headline) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            copy,
            maxLines: compact ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.foreground.withValues(alpha: 0.86),
              fontSize: compact ? 13 : 14,
              height: 1.34,
            ),
          ),
        ],
        if (metric.isNotEmpty) ...<Widget>[
          const Spacer(),
          _WidgetPreviewDataPill(
            label: metricLabel.ifEmpty('Now'),
            value: metric,
            palette: palette,
          ),
          const SizedBox(height: 10),
        ] else if (chips.isNotEmpty) ...<Widget>[const Spacer()],
        if (chips.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.take(2).map((chip) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.chip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    color: palette.foreground.withValues(alpha: 0.94),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _AiWidgetPreviewList extends StatelessWidget {
  const _AiWidgetPreviewList({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.chips,
    required this.accent,
    required this.palette,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> rows;
  final List<String> chips;
  final Color accent;
  final _WidgetPreviewPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final entries = rows.isEmpty
        ? chips
              .map((chip) => <String, dynamic>{'label': chip, 'value': ''})
              .toList(growable: false)
        : rows.take(4).toList(growable: false);
    if (entries.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Waiting for items',
          style: TextStyle(color: palette.muted, fontSize: compact ? 13 : 14),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (subtitle.trim().isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.muted, fontSize: compact ? 11 : 12),
          ),
        if (title.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.foreground,
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...entries.map((row) {
          final label = _widgetSanitizedText(
            row['label']?.toString() ?? '',
            fallback: 'Item',
          );
          final value = _widgetSanitizedText(row['value']?.toString() ?? '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: compact ? 18 : 20,
                  height: compact ? 18 : 20,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: compact ? 12 : 14,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.foreground,
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (value.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _WidgetSupportingMetricCard extends StatelessWidget {
  const _WidgetSupportingMetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetProgressBar extends StatelessWidget {
  const _WidgetProgressBar({
    required this.accent,
    required this.value,
    required this.label,
  });

  final Color accent;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        if (label.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _WidgetPreviewDataPill extends StatelessWidget {
  const _WidgetPreviewDataPill({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final _WidgetPreviewPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.foreground.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: palette.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreviewProgress extends StatelessWidget {
  const _WidgetPreviewProgress({
    required this.value,
    required this.label,
    required this.palette,
  });

  final double value;
  final String label;
  final _WidgetPreviewPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
          ),
        ),
        if (label.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _WidgetMetricBlock extends StatelessWidget {
  const _WidgetMetricBlock({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent ?? _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreviewPalette {
  const _WidgetPreviewPalette({
    required this.colors,
    required this.accent,
    required this.foreground,
    required this.muted,
    required this.chip,
    required this.glow,
  });

  final List<Color> colors;
  final Color accent;
  final Color foreground;
  final Color muted;
  final Color chip;
  final Color glow;
}

Color _widgetAccentColor(String token, {String surfaceColor = ''}) {
  final surfaceOverride = _widgetColorFromHex(surfaceColor);
  if (surfaceOverride != null) {
    return Color.lerp(surfaceOverride, Colors.white, 0.16)!;
  }
  switch (token.trim().toLowerCase()) {
    case 'warning':
    case 'sun':
    case 'sunny':
    case 'weather':
      return _warning;
    case 'success':
    case 'health':
    case 'growth':
    case 'battery':
    case 'electric':
      return _success;
    case 'alert':
    case 'error':
    case 'storm':
      return _danger;
    case 'sky':
    case 'ocean':
    case 'summary':
    case 'rain':
    case 'cloud':
      return _accentAlt;
    case 'night':
      return const Color(0xFFB7C9FF);
    default:
      return _accent;
  }
}

IconData _widgetIconData(String token) {
  switch (token.trim().toLowerCase()) {
    case 'weather':
    case 'sun':
    case 'sunny':
      return Icons.wb_sunny_outlined;
    case 'rain':
    case 'storm':
      return Icons.thunderstorm_outlined;
    case 'cloud':
      return Icons.cloud_outlined;
    case 'vehicle':
    case 'car':
      return Icons.directions_car_outlined;
    case 'battery':
    case 'electric':
      return Icons.battery_charging_full_rounded;
    case 'list':
    case 'agenda':
      return Icons.view_list_outlined;
    case 'health':
      return Icons.favorite_outline;
    case 'summary':
      return Icons.notes_outlined;
    default:
      return Icons.dashboard_customize_outlined;
  }
}

String _manualRunButtonLabel(String label, int remainingSeconds) {
  if (remainingSeconds <= 0) {
    return label;
  }
  return '$label (${remainingSeconds}s)';
}

String _widgetSanitizedText(String value, {String fallback = ''}) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
    return fallback;
  }
  return normalized;
}

String _widgetDisplayName(String raw) {
  final normalized = raw
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return 'AI Widget';
  }
  return normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.length <= 2 && part.toUpperCase() == part) {
          return part;
        }
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String _widgetPrimaryTitle(AiWidgetItem item, WidgetSnapshotItem? snapshot) {
  final snapshotTitle = _widgetSanitizedText(snapshot?.title ?? '');
  if (snapshotTitle.isNotEmpty) {
    return snapshotTitle;
  }
  return _widgetDisplayName(item.name);
}

String _widgetSecondaryTitle(AiWidgetItem item, WidgetSnapshotItem? snapshot) {
  final kicker = _widgetSanitizedText(snapshot?.kicker ?? '');
  if (kicker.isNotEmpty) {
    return kicker;
  }
  final subtitle = _widgetSanitizedText(snapshot?.subtitle ?? '');
  if (subtitle.isNotEmpty) {
    return subtitle;
  }
  final metricLabel = _widgetSanitizedText(snapshot?.metricLabel ?? '');
  if (metricLabel.isNotEmpty) {
    return metricLabel;
  }
  if (snapshot != null) {
    return _widgetDisplayName(item.name);
  }
  return 'Waiting for the first update';
}

String _widgetSummaryText(AiWidgetItem item, WidgetSnapshotItem? snapshot) {
  final body = _widgetSanitizedText(snapshot?.body ?? '');
  if (body.isNotEmpty) {
    return body;
  }
  final supportingFacts = <String>[
    _widgetLabeledValue(
      snapshot?.secondaryLabel ?? '',
      snapshot?.secondaryMetric ?? '',
    ),
    _widgetLabeledValue(
      snapshot?.tertiaryLabel ?? '',
      snapshot?.tertiaryMetric ?? '',
    ),
  ].where((entry) => entry.isNotEmpty).toList(growable: false);
  if (supportingFacts.isNotEmpty) {
    return supportingFacts.join(' • ');
  }
  final rowSummary = snapshot?.rows
      .map(
        (row) => _widgetLabeledValue(
          row['label']?.toString() ?? '',
          row['value']?.toString() ?? '',
        ),
      )
      .where((entry) => entry.isNotEmpty)
      .take(2)
      .join(' • ');
  if (rowSummary != null && rowSummary.isNotEmpty) {
    return rowSummary;
  }
  final description = _widgetSanitizedText(
    item.definition['description']?.toString() ?? '',
  );
  if (description.isNotEmpty) {
    return description;
  }
  final prompt = _widgetSanitizedText(item.prompt);
  if (prompt.isNotEmpty) {
    return prompt;
  }
  return snapshot == null
      ? 'Waiting for the first update.'
      : 'Opens the latest widget snapshot everywhere you use NeoAgent.';
}

String _widgetCadenceLabel(String cron) {
  final normalized = cron.trim();
  final parts = normalized.split(RegExp(r'\s+'));
  if (parts.length != 5) {
    return normalized.isEmpty ? 'Refreshes on schedule' : normalized;
  }
  final minute = parts[0];
  final hour = parts[1];
  final dayOfWeek = parts[4];
  if (minute == '0' && hour == '*' && parts[2] == '*' && parts[3] == '*') {
    return 'Hourly';
  }
  if (minute == '0' &&
      hour.startsWith('*/') &&
      parts[2] == '*' &&
      parts[3] == '*') {
    final interval = int.tryParse(hour.substring(2));
    if (interval != null && interval > 1) {
      return 'Every $interval hours';
    }
  }
  if (minute != '*' &&
      hour != '*' &&
      parts[2] == '*' &&
      parts[3] == '*' &&
      dayOfWeek == '*') {
    final minuteValue = int.tryParse(minute);
    final hourValue = int.tryParse(hour);
    if (minuteValue != null && hourValue != null) {
      final localizations = WidgetsBinding.instance.platformDispatcher.locale;
      final formattedMinute = minuteValue.toString().padLeft(2, '0');
      final formattedHour = hourValue.toString().padLeft(2, '0');
      if (localizations.languageCode.toLowerCase() == 'en') {
        return 'Daily at $formattedHour:$formattedMinute';
      }
      return 'Daily at $formattedHour:$formattedMinute';
    }
  }
  return normalized;
}

double _widgetPreviewAspectRatio(String template) {
  switch (template.trim().toLowerCase()) {
    case 'summary':
      return 1.9;
    case 'list':
      return 1.08;
    default:
      return 1.18;
  }
}

String _widgetLabeledValue(String label, String value) {
  final safeLabel = _widgetSanitizedText(label);
  final safeValue = _widgetSanitizedText(value);
  if (safeLabel.isEmpty) return safeValue;
  if (safeValue.isEmpty) return safeLabel;
  return '$safeLabel $safeValue';
}

Color? _widgetColorFromHex(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final hex = normalized.startsWith('#') ? normalized.substring(1) : normalized;
  if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) {
    return null;
  }
  final value = int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return Color(value);
}

Color _widgetBackgroundSeed(String token, Color accent) {
  switch (token.trim().toLowerCase()) {
    case 'sun':
    case 'sunny':
      return const Color(0xFFD59B4E);
    case 'rain':
      return const Color(0xFF5274A7);
    case 'storm':
      return const Color(0xFF50597A);
    case 'cloud':
      return const Color(0xFF71809A);
    case 'night':
      return const Color(0xFF42507B);
    case 'electric':
    case 'battery':
      return const Color(0xFF37C990);
    case 'vehicle':
      return const Color(0xFF5B6E88);
    default:
      return accent;
  }
}

double? _widgetProgressFraction(Map<String, dynamic>? progress) {
  if (progress == null) {
    return null;
  }
  final value = double.tryParse(progress['value']?.toString() ?? '');
  final max = double.tryParse(progress['max']?.toString() ?? '');
  if (value == null || max == null || max <= 0) {
    return null;
  }
  return (value / max).clamp(0.0, 1.0);
}

String _widgetProgressLabel(Map<String, dynamic>? progress) {
  if (progress == null) {
    return '';
  }
  final explicit = _widgetSanitizedText(progress['label']?.toString() ?? '');
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final value = progress['value']?.toString() ?? '';
  final max = progress['max']?.toString() ?? '';
  if (value.isNotEmpty && max.isNotEmpty) {
    return '$value / $max';
  }
  return '';
}

_WidgetPreviewPalette _widgetPreviewPalette(
  String template,
  Color accent, {
  String backgroundToken = '',
  String surfaceColor = '',
}) {
  final surfaceOverride = _widgetColorFromHex(surfaceColor);
  final seed =
      surfaceOverride ?? _widgetBackgroundSeed(backgroundToken, accent);
  final accentColor = Color.lerp(seed, Colors.white, 0.18)!;
  final start = switch (template.trim().toLowerCase()) {
    'summary' => Color.lerp(seed, const Color(0xFF101B28), 0.28)!,
    'list' => Color.lerp(seed, const Color(0xFF162130), 0.44)!,
    _ => Color.lerp(seed, const Color(0xFF121A25), 0.34)!,
  };
  final end = switch (template.trim().toLowerCase()) {
    'summary' => Color.lerp(seed, const Color(0xFF081018), 0.74)!,
    'list' => Color.lerp(seed, const Color(0xFF0D141F), 0.78)!,
    _ => Color.lerp(seed, const Color(0xFF0B121C), 0.8)!,
  };
  return _WidgetPreviewPalette(
    colors: <Color>[start, end],
    accent: accentColor,
    foreground: Colors.white,
    muted: Colors.white.withValues(alpha: 0.72),
    chip: Colors.white.withValues(alpha: 0.11),
    glow: accentColor.withValues(alpha: 0.18),
  );
}

class _TaskTriggerOption {
  const _TaskTriggerOption({
    required this.type,
    required this.section,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String type;
  final String section;
  final String label;
  final String description;
  final IconData icon;
}

const List<_TaskTriggerOption> _taskTriggerOptions = <_TaskTriggerOption>[
  _TaskTriggerOption(
    type: 'manual',
    section: 'On Demand',
    label: 'Manual Trigger',
    description: 'Runs only when you press Run Now.',
    icon: Icons.play_circle_outline_rounded,
  ),
  _TaskTriggerOption(
    type: 'schedule',
    section: 'Time',
    label: 'Schedule',
    description: 'Cron-based recurring runs and one-time timed execution.',
    icon: Icons.schedule_rounded,
  ),
  _TaskTriggerOption(
    type: 'gmail_message_received',
    section: 'Email',
    label: 'Gmail Message Received',
    description: 'Run when a matching Gmail message arrives.',
    icon: Icons.mail_rounded,
  ),
  _TaskTriggerOption(
    type: 'outlook_email_received',
    section: 'Email',
    label: 'Outlook Email Received',
    description: 'Run when a matching Outlook email arrives.',
    icon: Icons.markunread_rounded,
  ),
  _TaskTriggerOption(
    type: 'slack_message_received',
    section: 'Messaging',
    label: 'Slack Message Received',
    description: 'Run when a Slack message matches the selected scope.',
    icon: Icons.forum_rounded,
  ),
  _TaskTriggerOption(
    type: 'teams_message_received',
    section: 'Messaging',
    label: 'Teams Message Received',
    description: 'Run when a Teams chat message matches the selected scope.',
    icon: Icons.groups_rounded,
  ),
  _TaskTriggerOption(
    type: 'weather_event',
    section: 'Environment',
    label: 'Weather Event',
    description:
        'Run when configured weather events are forecast for a location.',
    icon: Icons.cloudy_snowing,
  ),
  _TaskTriggerOption(
    type: 'whatsapp_personal_message_received',
    section: 'Messaging',
    label: 'WhatsApp Personal Message Received',
    description: 'Run on inbound personal WhatsApp messages.',
    icon: Icons.chat_bubble_rounded,
  ),
];

_TaskTriggerOption _taskTriggerOptionForType(String type) {
  return _taskTriggerOptions.firstWhere(
    (option) => option.type == type,
    orElse: () => _taskTriggerOptions.first,
  );
}

Future<String?> _pickTaskTriggerType(
  BuildContext context,
  String selectedType,
) {
  final optionsBySection = <String, List<_TaskTriggerOption>>{};
  for (final option in _taskTriggerOptions) {
    optionsBySection
        .putIfAbsent(option.section, () => <_TaskTriggerOption>[])
        .add(option);
  }

  return showDialog<String>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: _bgCard,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Select Trigger',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how this task should start. Manual runs only on Run Now. Schedule is time-based. Integration triggers fire from connected official apps.',
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: optionsBySection.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              entry.key.toUpperCase(),
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...entry.value.map((option) {
                              final isSelected = option.type == selectedType;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () =>
                                      Navigator.of(context).pop(option.type),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected ? _accent : _border,
                                        width: isSelected ? 1.6 : 1,
                                      ),
                                      gradient: isSelected
                                          ? LinearGradient(
                                              colors: <Color>[
                                                _accent.withValues(alpha: 0.18),
                                                _accent.withValues(alpha: 0.05),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isSelected
                                          ? null
                                          : _bgCard.withValues(alpha: 0.72),
                                      boxShadow: isSelected
                                          ? <BoxShadow>[
                                              BoxShadow(
                                                color: _accent.withValues(
                                                  alpha: 0.12,
                                                ),
                                                blurRadius: 24,
                                                offset: const Offset(0, 10),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _accent.withValues(
                                                    alpha: 0.16,
                                                  )
                                                : _bgCard,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            option.icon,
                                            color: isSelected
                                                ? _accent
                                                : _textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                option.label,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                option.description,
                                                style: TextStyle(
                                                  color: _textSecondary,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.arrow_forward_rounded,
                                          color: isSelected
                                              ? _accent
                                              : _textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class TasksPanel extends StatefulWidget {
  const TasksPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> {
  String? _agentFilterId;

  NeoAgentController get controller => widget.controller;

  @override
  void didUpdateWidget(covariant TasksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_agentFilterId == null) return;
    final stillExists = controller.agentProfiles.any(
      (agent) => agent.id == _agentFilterId,
    );
    if (!stillExists) {
      _agentFilterId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _agentFilterId == null
        ? controller.taskItems
        : controller.taskItems
              .where((task) => task.agentId == _agentFilterId)
              .toList();
    final automationTasks = filteredTasks
        .where((task) => !task.isWidgetRefresh)
        .toList();
    final widgetTasks = filteredTasks
        .where((task) => task.isWidgetRefresh)
        .toList();
    final selectedAgentLabel = controller.agentLabelFor(_agentFilterId);
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Tasks',
          subtitle:
              'Premium automation with schedule and integration triggers.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: controller.openWidgetCreateFlow,
                icon: Icon(Icons.dashboard_customize_outlined),
                label: Text('Create Widget'),
              ),
              FilledButton.icon(
                onPressed: () => _openTaskEditor(
                  context,
                  defaultAgentId: _agentFilterId ?? controller.selectedAgentId,
                ),
                icon: Icon(Icons.add),
                label: Text('Add Task'),
              ),
            ],
          ),
        ),
        if (controller.agentProfiles.isNotEmpty) ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Assigned agent',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(
                          'All agents (${controller.taskItems.length})',
                        ),
                        selected: _agentFilterId == null,
                        onSelected: (_) =>
                            setState(() => _agentFilterId = null),
                      ),
                      ...controller.agentProfiles.map((agent) {
                        final count = controller.taskItems
                            .where((task) => task.agentId == agent.id)
                            .length;
                        return ChoiceChip(
                          label: Text('${agent.displayName} ($count)'),
                          selected: _agentFilterId == agent.id,
                          onSelected: (_) =>
                              setState(() => _agentFilterId = agent.id),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (controller.taskItems.isEmpty)
          const _EmptyCard(
            title: 'No tasks yet',
            subtitle: 'Create a task with a trigger to automate regular work.',
          )
        else if (filteredTasks.isEmpty)
          _EmptyCard(
            title: 'No tasks for $selectedAgentLabel',
            subtitle: 'Create a task while this agent is selected.',
          )
        else ...<Widget>[
          if (automationTasks.isNotEmpty) ...<Widget>[
            Text('Tasks', style: _sectionEyebrowStyle()),
            const SizedBox(height: 10),
            ...automationTasks.map(_buildTaskCard),
          ],
          if (widgetTasks.isNotEmpty) ...<Widget>[
            if (automationTasks.isNotEmpty) const SizedBox(height: 18),
            Text('Managed Widget Tasks', style: _sectionEyebrowStyle()),
            const SizedBox(height: 10),
            ...widgetTasks.map(_buildWidgetTaskCard),
          ],
        ],
      ],
    );
  }

  Widget _buildTaskCard(TaskItem task) {
    final remaining = controller.taskRunCooldownSeconds(task.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      task.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusPill(
                    label: task.enabled ? 'Active' : 'Paused',
                    color: task.enabled ? _success : _textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task.scheduleLabel,
                style: TextStyle(
                  color: _textSecondary,
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                ),
              ),
              if (task.hasModelOverride) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Model: ${_modelLabelForValue(task.model, controller.supportedModels)}',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Assigned agent: ${controller.agentLabelFor(task.agentId)}',
                style: TextStyle(color: _textSecondary),
              ),
              const SizedBox(height: 8),
              Text(task.prompt, style: TextStyle(color: _textPrimary)),
              if (task.lastRunLabel.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Last run: ${task.lastRunLabel}',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () => _openTaskEditor(context, task: task),
                    child: Text('Edit'),
                  ),
                  OutlinedButton(
                    onPressed: () => controller.toggleTask(task),
                    child: Text(task.enabled ? 'Pause' : 'Enable'),
                  ),
                  FilledButton(
                    onPressed: remaining > 0
                        ? null
                        : () => controller.runTaskNow(task.id),
                    child: Text(_manualRunButtonLabel('Run Now', remaining)),
                  ),
                  OutlinedButton(
                    onPressed: () => _confirmDelete(
                      context,
                      title: 'Delete task?',
                      message: 'This will remove "${task.name}".',
                      onConfirm: () => controller.deleteTask(task.id),
                    ),
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetTaskCard(TaskItem task) {
    AiWidgetItem? linkedWidget;
    for (final item in controller.widgets) {
      if (item.id == task.widgetId) {
        linkedWidget = item;
        break;
      }
    }
    final remaining = linkedWidget == null
        ? controller.taskRunCooldownSeconds(task.id)
        : controller.widgetRunCooldownSeconds(linkedWidget.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      linkedWidget?.name ?? task.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusPill(
                    label: task.enabled ? 'Active' : 'Paused',
                    color: task.enabled ? _success : _textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task.scheduleLabel,
                style: TextStyle(
                  color: _textSecondary,
                  fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assigned agent: ${controller.agentLabelFor(task.agentId)}',
                style: TextStyle(color: _textSecondary),
              ),
              if (linkedWidget != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '${linkedWidget.template} · ${linkedWidget.layoutVariant}',
                  style: TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  linkedWidget.prompt,
                  style: TextStyle(color: _textPrimary),
                ),
              ],
              if (task.lastRunLabel.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Last run: ${task.lastRunLabel}',
                  style: TextStyle(color: _textSecondary),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: linkedWidget == null
                        ? null
                        : () => controller.openWidgetEditFlow(linkedWidget!),
                    child: Text('Edit With AI'),
                  ),
                  OutlinedButton(
                    onPressed: linkedWidget == null
                        ? null
                        : () => controller.toggleWidgetEnabled(linkedWidget!),
                    child: Text(task.enabled ? 'Pause' : 'Enable'),
                  ),
                  FilledButton(
                    onPressed: remaining > 0
                        ? null
                        : (linkedWidget == null
                              ? () => controller.runTaskNow(task.id)
                              : () => controller.refreshWidgetNow(
                                  linkedWidget!.id,
                                )),
                    child: Text(
                      _manualRunButtonLabel('Refresh Now', remaining),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: linkedWidget == null
                        ? null
                        : () => _confirmDelete(
                            context,
                            title: 'Delete widget?',
                            message:
                                'This will remove "${linkedWidget!.name}" and its refresh job.',
                            onConfirm: () =>
                                controller.deleteWidget(linkedWidget!.id),
                          ),
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTaskEditor(
    BuildContext context, {
    TaskItem? task,
    String? defaultAgentId,
  }) async {
    final nameController = TextEditingController(text: task?.name ?? '');
    final triggerType = ValueNotifier<String>(task?.triggerType ?? 'schedule');
    final cronController = TextEditingController(
      text: task?.triggerConfig['cronExpression']?.toString() ?? '*/30 * * * *',
    );
    final runAtController = TextEditingController(
      text: task?.triggerConfig['runAt']?.toString() ?? '',
    );
    final connectionIdController = TextEditingController(
      text: task?.triggerConfig['connectionId']?.toString() ?? '',
    );
    final queryController = TextEditingController(
      text:
          task?.triggerConfig['query']?.toString() ??
          task?.triggerConfig['location']?.toString() ??
          '',
    );
    final weatherEventTypesController = TextEditingController(
      text: (() {
        final raw = task?.triggerConfig['eventTypes'];
        if (raw is List) {
          return raw.map((entry) => entry.toString()).join(', ');
        }
        return task?.triggerConfig['eventTypes']?.toString() ??
            'rain_start, wind_alert';
      })(),
    );
    final channelController = TextEditingController(
      text:
          task?.triggerConfig['channel']?.toString() ??
          task?.triggerConfig['chatId']?.toString() ??
          '',
    );
    final senderController = TextEditingController(
      text: task?.triggerConfig['sender']?.toString() ?? '',
    );
    final promptController = TextEditingController(text: task?.prompt ?? '');
    var enabled = task?.enabled ?? true;
    var unreadOnly = task?.triggerConfig['unreadOnly'] == true;
    var ignoreGroups = task?.triggerConfig['ignoreGroups'] == true;
    var selectedModel = _ensureModelValue(
      task?.model ?? 'auto',
      controller.supportedModels,
      allowAuto: true,
    );
    var selectedAgentId =
        task?.agentId ?? defaultAgentId ?? controller.selectedAgentId;
    if (selectedAgentId != null &&
        !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
      selectedAgentId = controller.selectedAgentId;
    }
    if (selectedAgentId != null &&
        !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
      selectedAgentId = controller.agentProfiles.isEmpty
          ? null
          : controller.agentProfiles.first.id;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(task == null ? 'Add Task' : 'Edit Task'),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: triggerType,
                        builder: (context, selectedTriggerType, _) {
                          final option = _taskTriggerOptionForType(
                            selectedTriggerType,
                          );
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              final nextType = await _pickTaskTriggerType(
                                context,
                                selectedTriggerType,
                              );
                              if (nextType != null) {
                                triggerType.value = nextType;
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Trigger Type',
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(option.icon, color: _accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          option.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          option.description,
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _bgCard.withValues(
                                            alpha: 0.72,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          option.section,
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Icon(
                                        Icons.unfold_more_rounded,
                                        color: _textSecondary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<String>(
                        valueListenable: triggerType,
                        builder: (context, selectedTriggerType, _) {
                          if (selectedTriggerType == 'manual') {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'This task will only run when you press Run Now.',
                                style: TextStyle(color: _textSecondary),
                              ),
                            );
                          }
                          if (selectedTriggerType == 'schedule') {
                            return Column(
                              children: <Widget>[
                                TextField(
                                  controller: cronController,
                                  decoration: const InputDecoration(
                                    labelText: 'Cron Expression',
                                    helperText:
                                        'Use cron for recurring tasks. Leave Run At empty for recurring schedules.',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: runAtController,
                                  decoration: const InputDecoration(
                                    labelText: 'Run At (optional ISO datetime)',
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: <Widget>[
                              TextField(
                                controller: connectionIdController,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Official Integration Connection ID',
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (selectedTriggerType ==
                                  'weather_event') ...<Widget>[
                                TextField(
                                  controller: queryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Location (city or place)',
                                    helperText: 'Required. Example: Berlin, DE',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: weatherEventTypesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Event Types (comma separated)',
                                    helperText:
                                        'Supported: rain_start, snow_start, wind_alert, temperature_above, temperature_below',
                                  ),
                                ),
                              ],
                              if (selectedTriggerType ==
                                      'gmail_message_received' ||
                                  selectedTriggerType ==
                                      'outlook_email_received') ...<Widget>[
                                TextField(
                                  controller: queryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Query / Filter',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SwitchListTile(
                                  value: unreadOnly,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Unread Only'),
                                  onChanged: (value) =>
                                      setLocalState(() => unreadOnly = value),
                                ),
                              ],
                              if (selectedTriggerType ==
                                  'outlook_email_received') ...<Widget>[
                                TextField(
                                  controller: channelController,
                                  decoration: const InputDecoration(
                                    labelText: 'Folder ID (optional)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (selectedTriggerType ==
                                      'slack_message_received' ||
                                  selectedTriggerType ==
                                      'teams_message_received' ||
                                  selectedTriggerType ==
                                      'whatsapp_personal_message_received') ...<
                                Widget
                              >[
                                TextField(
                                  controller: channelController,
                                  decoration: InputDecoration(
                                    labelText:
                                        selectedTriggerType ==
                                            'slack_message_received'
                                        ? 'Channel ID'
                                        : 'Chat ID',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: senderController,
                                  decoration: const InputDecoration(
                                    labelText: 'Sender Filter (optional)',
                                  ),
                                ),
                              ],
                              if (selectedTriggerType ==
                                  'whatsapp_personal_message_received') ...<
                                Widget
                              >[
                                const SizedBox(height: 12),
                                SwitchListTile(
                                  value: ignoreGroups,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Ignore Groups'),
                                  onChanged: (value) =>
                                      setLocalState(() => ignoreGroups = value),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: promptController,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(labelText: 'Prompt'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Model Override',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'auto',
                            child: Text('Auto (default routing)'),
                          ),
                          ...controller.supportedModels.map(
                            (model) => DropdownMenuItem<String>(
                              value: model.id,
                              child: Text(model.label),
                            ),
                          ),
                        ],
                        onChanged: (value) => setLocalState(
                          () => selectedModel = value ?? 'auto',
                        ),
                      ),
                      if (controller.agentProfiles.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedAgentId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Agent',
                          ),
                          items: controller.agentProfiles
                              .map(
                                (agent) => DropdownMenuItem<String>(
                                  value: agent.id,
                                  child: Text(agent.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setLocalState(() => selectedAgentId = value),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Enabled'),
                        onChanged: (value) =>
                            setLocalState(() => enabled = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final selectedTriggerType = triggerType.value;
                    final triggerConfig = <String, dynamic>{};
                    if (selectedTriggerType == 'manual') {
                      // Manual trigger uses no trigger-specific config.
                    } else if (selectedTriggerType == 'schedule') {
                      final runAt = runAtController.text.trim();
                      triggerConfig['mode'] = runAt.isEmpty
                          ? 'recurring'
                          : 'one_time';
                      if (runAt.isEmpty) {
                        triggerConfig['cronExpression'] = cronController.text
                            .trim();
                      } else {
                        triggerConfig['runAt'] = runAt;
                      }
                    } else {
                      triggerConfig['connectionId'] =
                          int.tryParse(connectionIdController.text.trim()) ?? 0;
                      if (selectedTriggerType == 'weather_event') {
                        if (queryController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Location is required for weather event triggers',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        triggerConfig['location'] = queryController.text.trim();
                        final eventTypes = weatherEventTypesController.text
                            .split(',')
                            .map((entry) => entry.trim())
                            .where((entry) => entry.isNotEmpty)
                            .toList();
                        triggerConfig['eventTypes'] = eventTypes;
                      }
                      if (selectedTriggerType == 'gmail_message_received' ||
                          selectedTriggerType == 'outlook_email_received') {
                        if (queryController.text.trim().isNotEmpty) {
                          triggerConfig['query'] = queryController.text.trim();
                        }
                        triggerConfig['unreadOnly'] = unreadOnly;
                        if (selectedTriggerType == 'outlook_email_received' &&
                            channelController.text.trim().isNotEmpty) {
                          triggerConfig['folderId'] = channelController.text
                              .trim();
                        }
                      }
                      if (selectedTriggerType == 'slack_message_received') {
                        triggerConfig['channel'] = channelController.text
                            .trim();
                      }
                      if (selectedTriggerType == 'teams_message_received' ||
                          selectedTriggerType ==
                              'whatsapp_personal_message_received') {
                        triggerConfig['chatId'] = channelController.text.trim();
                      }
                      if (senderController.text.trim().isNotEmpty) {
                        triggerConfig['sender'] = senderController.text.trim();
                      }
                      if (selectedTriggerType ==
                          'whatsapp_personal_message_received') {
                        triggerConfig['ignoreGroups'] = ignoreGroups;
                      }
                    }
                    await controller.saveTask(
                      id: task?.id,
                      name: nameController.text.trim(),
                      triggerType: selectedTriggerType,
                      triggerConfig: triggerConfig,
                      prompt: promptController.text.trim(),
                      model: selectedModel == 'auto' ? null : selectedModel,
                      enabled: enabled,
                      agentId: selectedAgentId,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AgentsPanel extends StatelessWidget {
  const AgentsPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Agents',
          subtitle:
              'Create specialist bots with separate memory, settings, tools, and account assignments.',
          trailing: FilledButton.icon(
            onPressed: () => openAgentEditor(context, controller),
            icon: Icon(Icons.add),
            label: Text('Add Agent'),
          ),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        if (controller.agentProfiles.isEmpty)
          const _EmptyCard(
            title: 'No agents yet',
            subtitle: 'The main agent is created automatically when needed.',
          )
        else
          ...controller.agentProfiles.map(
            (agent) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              agent.displayName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (agent.isDefault)
                            _StatusPill(label: 'Default', color: _accentHover),
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: agent.status,
                            color: agent.status == 'active'
                                ? _success
                                : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '@${agent.slug}',
                        style: TextStyle(color: _textSecondary),
                      ),
                      if (agent.description.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(agent.description),
                      ],
                      if (agent.responsibilities.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          agent.responsibilities,
                          style: TextStyle(color: _textSecondary),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        _communicationSummary(controller, agent),
                        style: TextStyle(color: _textSecondary),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () => controller.switchAgent(agent.id),
                            child: Text(
                              controller.selectedAgentId == agent.id
                                  ? 'Selected'
                                  : 'Switch',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => openAgentEditor(
                              context,
                              controller,
                              agent: agent,
                            ),
                            child: Text('Edit'),
                          ),
                          if (!agent.isDefault)
                            OutlinedButton(
                              onPressed: () =>
                                  controller.makeAgentDefault(agent.id),
                              child: Text('Make default'),
                            ),
                          if (!agent.isMain && !agent.isDefault)
                            TextButton(
                              onPressed: () => _confirmDelete(
                                context,
                                title: 'Archive agent?',
                                message:
                                    'This hides "${agent.displayName}" from routing and selection.',
                                onConfirm: () =>
                                    controller.archiveAgent(agent.id),
                              ),
                              child: Text('Archive'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Future<void> openAgentEditor(
    BuildContext context,
    NeoAgentController controller, {
    AgentProfile? agent,
  }) async {
    final nameController = TextEditingController(
      text: agent?.displayName ?? '',
    );
    final slugController = TextEditingController(text: agent?.slug ?? '');
    final descriptionController = TextEditingController(
      text: agent?.description ?? '',
    );
    final responsibilitiesController = TextEditingController(
      text: agent?.responsibilities ?? '',
    );
    final instructionsController = TextEditingController(
      text: agent?.instructions ?? '',
    );
    var status = agent?.status ?? 'active';
    var canDelegate = agent?.canDelegate ?? false;
    var canBeDelegatedTo = agent?.canBeDelegatedTo ?? true;
    var restrictDelegateTargets =
        agent != null && agent.delegateTargets.isNotEmpty;
    final delegateTargets = <String>{...?agent?.delegateTargets};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(agent == null ? 'Add Agent' : 'Edit Agent'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        onChanged: (value) {
                          if (agent == null && slugController.text.isEmpty) {
                            slugController.text = value
                                .trim()
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
                                .replaceAll(RegExp(r'^-+|-+$'), '');
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: responsibilitiesController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Responsibilities',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructionsController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'paused',
                            child: Text('Paused'),
                          ),
                        ],
                        onChanged: (value) =>
                            setLocalState(() => status = value ?? 'active'),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Agent communication',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canDelegate,
                        title: Text('Can delegate tasks to other agents'),
                        subtitle: Text(
                          'Use this for orchestrator agents. Leave off for isolated work bots that should finish direct messages themselves.',
                        ),
                        onChanged: (value) =>
                            setLocalState(() => canDelegate = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: canBeDelegatedTo,
                        title: Text('Can receive delegated tasks'),
                        subtitle: Text(
                          'Turn this off to keep this agent fully separate from other agents.',
                        ),
                        onChanged: (value) =>
                            setLocalState(() => canBeDelegatedTo = value),
                      ),
                      if (canDelegate) ...<Widget>[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: restrictDelegateTargets,
                          title: Text('Restrict delegation targets'),
                          subtitle: Text(
                            restrictDelegateTargets
                                ? 'Only selected agents can receive tasks from this agent.'
                                : 'This agent can delegate to any eligible receiving agent.',
                          ),
                          onChanged: (value) => setLocalState(() {
                            restrictDelegateTargets = value;
                            if (!value) delegateTargets.clear();
                          }),
                        ),
                        if (restrictDelegateTargets) ...<Widget>[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: controller.agentProfiles
                                  .where((target) => target.id != agent?.id)
                                  .map((target) {
                                    final selected = delegateTargets.contains(
                                      target.id,
                                    );
                                    return FilterChip(
                                      label: Text(target.displayName),
                                      selected: selected,
                                      onSelected: (value) => setLocalState(() {
                                        if (value) {
                                          delegateTargets.add(target.id);
                                        } else {
                                          delegateTargets.remove(target.id);
                                        }
                                      }),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final saved = await controller.saveAgentProfile(
                      id: agent?.id,
                      displayName: nameController.text.trim(),
                      slug: slugController.text.trim(),
                      description: descriptionController.text.trim(),
                      responsibilities: responsibilitiesController.text.trim(),
                      instructions: instructionsController.text.trim(),
                      status: status,
                      canDelegate: canDelegate,
                      canBeDelegatedTo: canBeDelegatedTo,
                      delegateTargets: restrictDelegateTargets
                          ? delegateTargets.toList(growable: false)
                          : const <String>[],
                    );
                    if (saved && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _communicationSummary(
    NeoAgentController controller,
    AgentProfile agent,
  ) {
    final parts = <String>[];
    parts.add(
      agent.canDelegate
          ? (agent.delegatesToAnyEligibleAgent
                ? 'Can delegate to any receiving agent'
                : 'Can delegate to ${agent.delegateTargets.map(controller.agentLabelFor).join(', ')}')
          : 'Handles direct tasks itself',
    );
    parts.add(
      agent.canBeDelegatedTo
          ? 'can receive delegated tasks'
          : 'cannot receive delegated tasks',
    );
    return 'Agent communication: ${parts.join('; ')}.';
  }
}

class McpPanel extends StatelessWidget {
  const McpPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'MCP',
          subtitle: 'Configured MCP servers and live server status.',
          trailing: FilledButton.icon(
            onPressed: () => _openMcpEditor(context),
            icon: Icon(Icons.add),
            label: Text('Add Server'),
          ),
        ),
        if (controller.mcpServers.isEmpty)
          const _EmptyCard(
            title: 'No MCP servers configured',
            subtitle: 'Add an MCP server URL and choose an auth method.',
          )
        else
          ...controller.mcpServers.map(
            (server) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              server.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusPill(
                            label: server.status,
                            color: server.status == 'running'
                                ? _success
                                : _textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        server.command,
                        style: TextStyle(
                          fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          _MetaPill(
                            label: server.enabled ? 'Enabled' : 'Disabled',
                            icon: Icons.toggle_on_outlined,
                          ),
                          _MetaPill(
                            label: '${server.toolCount} tools',
                            icon: Icons.build_outlined,
                          ),
                          _MetaPill(
                            label: server.authMethodLabel,
                            icon: Icons.lock_outline,
                          ),
                          _MetaPill(
                            label:
                                'Agent: ${controller.agentLabelFor(server.agentId)}',
                            icon: Icons.smart_toy_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () =>
                                _openMcpEditor(context, server: server),
                            child: Text('Edit'),
                          ),
                          if (server.status == 'running')
                            FilledButton(
                              onPressed: () =>
                                  controller.stopMcpServer(server.id),
                              child: Text('Stop'),
                            )
                          else
                            FilledButton(
                              onPressed: () =>
                                  controller.startMcpServer(server.id),
                              child: Text('Start'),
                            ),
                          OutlinedButton(
                            onPressed: () => _confirmDelete(
                              context,
                              title: 'Delete MCP server?',
                              message:
                                  'This will remove "${server.name}" from the server list.',
                              onConfirm: () =>
                                  controller.deleteMcpServer(server.id),
                            ),
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openMcpEditor(
    BuildContext context, {
    McpServerItem? server,
  }) async {
    final nameController = TextEditingController(text: server?.name ?? '');
    final urlController = TextEditingController(text: server?.command ?? '');
    final auth = _jsonMap(server?.config['auth']);
    String authType = auth['type']?.toString().ifEmpty('none') ?? 'none';
    final tokenController = TextEditingController(
      text: auth['token']?.toString() ?? '',
    );
    final clientIdController = TextEditingController(
      text: auth['clientId']?.toString() ?? '',
    );
    final authServerUrlController = TextEditingController(
      text: auth['authServerUrl']?.toString() ?? '',
    );
    var enabled = server?.enabled ?? true;
    var selectedAgentId = server?.agentId ?? controller.selectedAgentId;
    if (selectedAgentId != null &&
        !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
      selectedAgentId = controller.selectedAgentId;
    }
    if (selectedAgentId != null &&
        !controller.agentProfiles.any((agent) => agent.id == selectedAgentId)) {
      selectedAgentId = controller.agentProfiles.isEmpty
          ? null
          : controller.agentProfiles.first.id;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: _bgCard,
              title: Text(
                server == null ? 'Add MCP Server' : 'Edit MCP Server',
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'MCP Server URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: authType,
                        decoration: const InputDecoration(
                          labelText: 'Auth Method',
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(
                            value: 'bearer',
                            child: Text('Bearer Token'),
                          ),
                          DropdownMenuItem(
                            value: 'oauth',
                            child: Text('OAuth'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setLocalState(() => authType = value);
                          }
                        },
                      ),
                      if (authType == 'bearer') ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: tokenController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Bearer Token',
                          ),
                        ),
                      ],
                      if (authType == 'oauth') ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: clientIdController,
                          decoration: const InputDecoration(
                            labelText: 'OAuth Client ID',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: authServerUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Auth Server URL',
                          ),
                        ),
                      ],
                      if (controller.agentProfiles.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedAgentId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Agent',
                          ),
                          items: controller.agentProfiles
                              .map(
                                (agent) => DropdownMenuItem<String>(
                                  value: agent.id,
                                  child: Text(agent.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setLocalState(() => selectedAgentId = value),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Matches the old NeoAgent MCP flow: URL plus auth method.',
                          style: TextStyle(color: _textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: enabled,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Enabled'),
                        onChanged: (value) =>
                            setLocalState(() => enabled = value),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Start the server later from the list once the config is saved.',
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final config = <String, dynamic>{
                      'auth': <String, dynamic>{
                        'type': authType,
                        if (authType == 'bearer' &&
                            tokenController.text.trim().isNotEmpty)
                          'token': tokenController.text.trim(),
                        if (authType == 'oauth' &&
                            clientIdController.text.trim().isNotEmpty)
                          'clientId': clientIdController.text.trim(),
                        if (authType == 'oauth' &&
                            authServerUrlController.text.trim().isNotEmpty)
                          'authServerUrl': authServerUrlController.text.trim(),
                      },
                    };
                    await controller.saveMcpServer(
                      id: server?.id,
                      name: nameController.text.trim(),
                      command: urlController.text.trim(),
                      config: config,
                      enabled: enabled,
                      agentId: selectedAgentId,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class HealthPanel extends StatelessWidget {
  const HealthPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final deviceStatus = controller.deviceHealthStatus;
    final backendStatus = controller.backendHealthStatus;
    final metrics = _jsonList(
      backendStatus?['metrics'],
      fallbackToMapValues: true,
    );
    final lastRun = _jsonMap(backendStatus?['lastRun']);
    final lastNonEmptyRun = _jsonMap(backendStatus?['lastNonEmptyRun']);
    final lastSummary = _jsonMap(lastRun['summary']);
    final lastNonEmptySummary = _jsonMap(lastNonEmptyRun['summary']);
    final lastRunRecordCount = _asInt(lastRun['record_count']);
    final lastSyncEmpty = lastRun.isNotEmpty && lastRunRecordCount == 0;
    final lastWindowEnd = _parseOptionalTimestamp(
      lastRun['sync_window_end']?.toString(),
    );
    final lastNonEmptyWindowEnd = _parseOptionalTimestamp(
      lastNonEmptyRun['sync_window_end']?.toString(),
    );

    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        const _PageTitle(
          title: 'Health',
          subtitle: 'Health Connect sync status and stored backend metrics.',
        ),
        if (controller.errorMessage != null) ...<Widget>[
          _InlineError(message: controller.errorMessage!),
          const SizedBox(height: 16),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewCard(
                title: 'Device access',
                value: deviceStatus == null
                    ? 'Checking...'
                    : !deviceStatus.available
                    ? 'Unavailable'
                    : deviceStatus.permissionsGranted
                    ? 'Ready'
                    : 'Permissions needed',
                helper:
                    deviceStatus?.message ??
                    'Reads steps, heart rate, sleep, exercise, and weight.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: 'Backend sync',
                value: lastRun.isEmpty
                    ? 'No sync yet'
                    : lastSyncEmpty
                    ? 'No new data'
                    : '$lastRunRecordCount records',
                helper: lastRun.isEmpty
                    ? 'Sync once to seed your backend.'
                    : lastWindowEnd == null
                    ? 'Last window end is unknown.'
                    : 'Last window ended ${_formatTimestamp(lastWindowEnd)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: controller.requestHealthPermissions,
                  icon: Icon(Icons.health_and_safety_outlined),
                  label: Text('Request permissions'),
                ),
                FilledButton.icon(
                  onPressed: controller.isSyncingHealth
                      ? null
                      : controller.syncHealthNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentHover,
                    foregroundColor: _bgPrimary,
                  ),
                  icon: controller.isSyncingHealth
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.sync),
                  label: Text('Sync now'),
                ),
                _MetaPill(
                  label: 'Background sync stays scheduled on Android',
                  icon: Icons.sync_lock_outlined,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionTitle('Last Sync Summary'),
                const SizedBox(height: 12),
                if (lastSummary.isEmpty)
                  Text(
                    'No detailed sync summary yet.',
                    style: TextStyle(color: _textSecondary),
                  )
                else ...<Widget>[
                  if (lastSyncEmpty && metrics.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        lastWindowEnd == null
                            ? 'The latest sync completed successfully but did not find any new Health Connect records. Stored metrics below came from earlier syncs.'
                            : 'The latest sync window ended ${_formatTimestamp(lastWindowEnd)} and did not find any new Health Connect records. Stored metrics below came from earlier syncs.',
                        style: TextStyle(color: _textSecondary),
                      ),
                    ),
                  _buildHealthSummaryPills(lastSummary),
                ],
                if (lastSyncEmpty &&
                    lastNonEmptySummary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(
                    lastNonEmptyWindowEnd == null
                        ? 'Last non-empty sync'
                        : 'Last non-empty sync · ${_formatTimestamp(lastNonEmptyWindowEnd)}',
                    style: TextStyle(
                      color: _textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHealthSummaryPills(lastNonEmptySummary),
                ],
                const SizedBox(height: 18),
                const _SectionTitle('Stored Metrics'),
                const SizedBox(height: 12),
                if (metrics.isEmpty)
                  Text('No health samples stored yet.')
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: metrics.map((item) {
                      final map = item as Map<dynamic, dynamic>;
                      return _MetaPill(
                        icon: Icons.favorite_border,
                        label:
                            '${map['metricType']} · ${map['sampleCount']} samples',
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
