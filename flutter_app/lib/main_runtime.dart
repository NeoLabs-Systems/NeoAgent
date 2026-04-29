part of 'main.dart';

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
