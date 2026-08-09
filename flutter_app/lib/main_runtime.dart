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
  late final WebAppUpdateMonitor _webAppUpdateMonitor;
  final AppLaunchBridge _appLaunchBridge = AppLaunchBridge();
  StreamSubscription<AppLaunchRequest>? _appLaunchSubscription;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _navigatorScopeSignature;
  Menu? _trayMenu;
  HotKey? _assistantHotKey;
  Timer? _assistantHotKeyHoldTimer;
  bool _desktopShellInitialized = false;
  bool _handlingDesktopClose = false;
  bool _desktopAssistantPopupWindowMode = false;
  bool _assistantHotKeyPressed = false;
  bool _assistantHotKeyHandledAsHold = false;
  bool _assistantPttActive = false;
  bool _desktopAssistantReturnToHidden = false;
  Rect? _desktopNormalWindowBounds;

  static const Size _desktopAssistantPopupWindowSize = Size(460, 112);
  static const Duration _desktopAssistantHoldThreshold = Duration(
    milliseconds: 220,
  );

  @override
  void initState() {
    super.initState();
    final backendClient = BackendClient();
    _controller = NeoAgentController(
      appMode: widget.mode,
      backendClient: backendClient,
      healthBridge: HealthBridge(),
    )..bootstrap();
    _webAppUpdateMonitor = createWebAppUpdateMonitor()..start();
    _controller.addListener(_handleControllerChanged);
    _appLaunchSubscription = _appLaunchBridge.launchRequests.listen(
      _handleAppLaunchRequest,
    );
    if (_supportsDesktopShell) {
      unawaited(_initializeDesktopShell());
    }
  }

  @override
  void dispose() {
    _appLaunchSubscription?.cancel();
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
    _webAppUpdateMonitor.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!_supportsDesktopShell) {
      return;
    }
    unawaited(_syncDesktopShell());
  }

  void _handleAppLaunchRequest(AppLaunchRequest request) {
    final action = request.action;
    if (action == AppLaunchBridge.voiceAssistantAction) {
      _controller.openVoiceAssistantSurface();
      return;
    }
    if (action == AppLaunchBridge.shareToChatAction) {
      _controller.queueSharedChatPayload(
        text: request.text,
        subject: request.subject,
        files: request.files,
      );
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
  }

  Future<void> _syncTrayMenu() async {
    _trayMenu = Menu(
      items: <MenuItem>[
        MenuItem(key: 'open', label: 'Open'),
        MenuItem(key: 'open_voice_assistant', label: 'Open voice assistant'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ],
    );
    await trayManager.setContextMenu(_trayMenu!);
  }

  Future<void> _syncAssistantHotkey() async {
    final shouldRegister = _controller.desktopAssistantHotkeyEnabled;
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
    _assistantHotKeyHandledAsHold = true;
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
    if (_desktopAssistantPopupWindowMode) {
      await _restoreMainWindowPresentation();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _hideMainWindow() async {
    if (_desktopAssistantPopupWindowMode) {
      await _restoreMainWindowPresentation(
        hideAfterRestore: true,
        focusWindow: false,
      );
      return;
    }
    await windowManager.hide();
  }

  Future<void> _restoreMainWindowPresentation({
    bool hideAfterRestore = false,
    bool focusWindow = true,
  }) async {
    if (mounted && _desktopAssistantPopupWindowMode) {
      setState(() {
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
    if (!_desktopAssistantPopupWindowMode) {
      _desktopNormalWindowBounds = await windowManager.getBounds();
    }
    if (mounted && !_desktopAssistantPopupWindowMode) {
      setState(() {
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
      animation: Listenable.merge(<Listenable>[
        _controller,
        _webAppUpdateMonitor,
      ]),
      builder: (context, _) {
        // Do not include isRefreshing here — remounting MaterialApp on every
        // refresh tears down onboarding (and other root surfaces) mid-login.
        final rootStateSignature =
            'boot:${_controller.isBooting}'
            '|backend:${_controller.requiresBackendUrlSetup}'
            '|auth:${_controller.isAuthenticated}'
            '|onboarding:${_controller.showOnboarding}'
            '|section:${_controller.selectedSection.name}'
            '|assistantPopupMode:$_desktopAssistantPopupWindowMode'
            '|assistantPttActive:${_controller.isLiveVoiceCaptureActive}'
            '|assistantPttStarting:${_controller.isLiveVoiceCaptureStarting}';
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
                if (!_desktopAssistantPopupWindowMode &&
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
                if (!_desktopAssistantPopupWindowMode &&
                    _webAppUpdateMonitor.isSupported &&
                    _webAppUpdateMonitor.updateAvailable)
                  Positioned(
                    top: _controller.showOfflineBanner ? 84 : 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: _GlobalWebUpdateBanner(
                              monitor: _webAppUpdateMonitor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          home: _desktopAssistantPopupWindowMode
              ? _DesktopAssistantPopupShell(
                  controller: _controller,
                  onPrimaryAction: _toggleAssistantPopupCaptureFromUi,
                  onCancel: _cancelAssistantPopupFromUi,
                )
              : NeoAgentRoot(controller: _controller),
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
    if (controller.showOnboarding) {
      return OnboardingShell(controller: controller);
    }
    if (controller.isLauncherMode) {
      return LauncherHomeView(controller: controller);
    }
    return HomeView(controller: controller);
  }
}
