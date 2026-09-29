part of 'main.dart';

enum _LauncherPage { assistant, settings }

class LauncherHomeView extends StatefulWidget {
  const LauncherHomeView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<LauncherHomeView> createState() => _LauncherHomeViewState();
}

class _LauncherHomeViewState extends State<LauncherHomeView> {
  static const int _assistantButtonKeyCode = 131;

  final AndroidLauncherBridge _launcherBridge = AndroidLauncherBridge.instance;
  StreamSubscription<LauncherHardwareButtonEvent>? _buttonSubscription;

  _LauncherPage _selectedPage = _LauncherPage.assistant;
  LauncherVolumeState? _volumeState;
  LauncherDeviceStatus? _deviceStatus;
  bool _assistantHardwareCaptureActive = false;
  DateTime _now = DateTime.now();
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshVolumeState(retries: 4));
    unawaited(_refreshDeviceStatus(retries: 4));
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
      unawaited(_refreshDeviceStatus(retries: 1));
    });
    if (_launcherBridge.supported) {
      _buttonSubscription = _launcherBridge.buttonEvents.listen(
        _handleHardwareButtonEvent,
      );
    }
  }

  @override
  void dispose() {
    _buttonSubscription?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _showLauncherActionError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openWifiSettings() async {
    final opened = await _launcherBridge.openWifiSettings();
    if (!opened) {
      _showLauncherActionError(appStrings.unableToOpenWiFiSettings);
    }
  }

  Future<void> _openTimeSettings() async {
    final opened = await _launcherBridge.openTimeSettings();
    if (!opened) {
      _showLauncherActionError(appStrings.unableToOpenTimeSettingsOn);
    }
  }

  bool get _supportsQrLoginApproval =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _startQrLoginApproval() async {
    final controller = widget.controller;
    if (!controller.isAuthenticated) {
      _showLauncherActionError(appStrings.signInToThisNeoagentServer);
      return;
    }

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
      _showLauncherActionError(appStrings.thatQrCodeIsNotA2);
      return;
    }

    final scannedBackend = controller._normalizeBackendUrl(payload.backendUrl);
    final currentBackend = controller._normalizeBackendUrl(
      controller.backendUrl,
    );
    if (scannedBackend != currentBackend) {
      _showLauncherActionError(
        appStrings.thisCodeBelongsToADifferent(payload.backendUrl),
      );
      return;
    }

    try {
      final preview = await controller.resolveQrLoginApproval(payload);
      if (!mounted) {
        return;
      }
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return _QrLoginApprovalDialog(
            preview: preview,
            busy: controller.isApprovingQrLogin,
          );
        },
      );
      if (approved != true || !mounted) {
        return;
      }
      await controller.approveQrLogin(payload);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appStrings.approvedPairingForArg1(preview.requestedDevice.label),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showLauncherActionError(
        controller.errorMessage ?? appStrings.couldNotApproveQrPairing,
      );
    }
  }

  Future<void> _refreshDeviceStatus({int retries = 0}) async {
    final status = await _launcherBridge.fetchDeviceStatus();
    if (!mounted) {
      return;
    }
    if (status == null) {
      if (retries > 0) {
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) {
            return;
          }
          unawaited(_refreshDeviceStatus(retries: retries - 1));
        });
      }
      return;
    }
    setState(() {
      _deviceStatus = status;
    });
  }

  Future<void> _refreshVolumeState({int retries = 0}) async {
    final state = await _launcherBridge.fetchVolumeState();
    if (!mounted) {
      return;
    }
    if (state == null) {
      if (retries > 0) {
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) {
            return;
          }
          unawaited(_refreshVolumeState(retries: retries - 1));
        });
      }
      return;
    }
    setState(() {
      _volumeState = state;
    });
  }

  Future<void> _updateVolume(double normalized) async {
    final state = _volumeState;
    if (state == null) {
      return;
    }
    final nextValue =
        state.min + ((state.max - state.min) * normalized).round();
    final updated = await _launcherBridge.setVolume(nextValue);
    if (!mounted || updated == null) {
      return;
    }
    setState(() {
      _volumeState = updated;
    });
  }

  Future<void> _adjustVolume(int delta) async {
    final updated = await _launcherBridge.adjustVolume(delta);
    if (!mounted || updated == null) {
      return;
    }
    setState(() {
      _volumeState = updated;
    });
  }

  Future<void> _startAssistantFromHardware() async {
    if (_assistantHardwareCaptureActive) {
      return;
    }
    _assistantHardwareCaptureActive = true;
    try {
      await widget.controller.startLiveVoiceCapture();
    } catch (_) {
      _assistantHardwareCaptureActive = false;
    }
  }

  Future<void> _stopAssistantFromHardware() async {
    if (!_assistantHardwareCaptureActive &&
        !widget.controller.isLiveVoiceCaptureActive &&
        !widget.controller.isLiveVoiceCaptureStarting) {
      return;
    }
    _assistantHardwareCaptureActive = false;
    await widget.controller.stopLiveVoiceCapture();
  }

  void _handleHardwareButtonEvent(LauncherHardwareButtonEvent event) {
    if (!mounted) {
      return;
    }
    if (event.keyCode == _assistantButtonKeyCode) {
      if (event.isDown && event.repeatCount == 0) {
        unawaited(_startAssistantFromHardware());
      } else if (event.isUp) {
        unawaited(_stopAssistantFromHardware());
      }
    }
  }

  // The launcher's home is the voice call, with the avatar as its centre.
  Widget _buildAssistantPage() {
    return VoiceAssistantPanel(
      controller: widget.controller,
      phoneCall: true,
      embedded: true,
    );
  }

  Widget _buildSettingsPage() {
    final controller = widget.controller;
    final volumeState = _volumeState;
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: appStrings.deviceSettings,
          subtitle: appStrings.adjustSpeakerVolumeReviewHardwareButton,
        ),
        if (_supportsQrLoginApproval) ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: _SectionTitle(appStrings.qrPairing)),
                      _StatusPill(
                        label: appStrings.androidOnly,
                        color: _accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    appStrings.scanANeoagentPairingQrFrom,
                    style: TextStyle(color: _textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: controller.isApprovingQrLogin
                        ? null
                        : _startQrLoginApproval,
                    icon: controller.isApprovingQrLogin
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.qr_code_scanner_outlined),
                    label: Text(
                      controller.isApprovingQrLogin
                          ? appStrings.openingScanner
                          : appStrings.scanPairingQr,
                    ),
                  ),
                  if (!controller.isAuthenticated) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      appStrings.thisRequiresAnAuthenticatedSessionOn,
                      style: TextStyle(color: _textMuted, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SectionTitle(appStrings.sectionVolume),
                const SizedBox(height: 10),
                Text(
                  appStrings.adjustTheSpeakerVolumeHere,
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: _launcherBridge.supported
                          ? () => _adjustVolume(-1)
                          : null,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.remove_circle_outline),
                    ),
                    Expanded(
                      child: Slider(
                        value: volumeState?.normalized ?? 0,
                        onChanged: volumeState == null ? null : _updateVolume,
                      ),
                    ),
                    IconButton(
                      onPressed: _launcherBridge.supported
                          ? () => _adjustVolume(1)
                          : null,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (volumeState != null)
                  Text(
                    appStrings.levelArg1Arg2Arg3(
                      volumeState.current,
                      volumeState.max,
                      volumeState.muted ? appStrings.muted : '',
                    ),
                    style: TextStyle(color: _textSecondary),
                  ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _launcherBridge.supported
                      ? _openWifiSettings
                      : null,
                  icon: Icon(Icons.wifi_outlined),
                  label: Text(appStrings.openWiFiSettings),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _launcherBridge.supported
                      ? _openTimeSettings
                      : null,
                  icon: Icon(Icons.schedule_outlined),
                  label: Text(appStrings.openTimeSettings),
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
                _SectionTitle(appStrings.extraButtons),
                const SizedBox(height: 10),
                Text(
                  appStrings.holdButton131ForTheAssistant,
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _MetaPill(
                      icon: Icons.keyboard_voice_outlined,
                      label: appStrings.assistantKey131,
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
                _SectionTitle(appStrings.appUpdates),
                const SizedBox(height: 10),
                Text(
                  appStrings.keepThisLauncherUpToDate,
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (!controller.appUpdaterConfigured)
                  Text(
                    appStrings.updatesAreNotConfiguredForThis,
                    style: TextStyle(color: _textSecondary),
                  )
                else ...<Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: controller.appUpdateChannel,
                    decoration: InputDecoration(
                      labelText: appStrings.releaseChannel,
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'stable',
                        child: Text(appStrings.stable),
                      ),
                      DropdownMenuItem<String>(
                        value: 'beta',
                        child: Text(appStrings.beta),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        unawaited(controller.setAppUpdateChannel(value));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: controller.appUpdateAutoCheckEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: Text(appStrings.checkAutomaticallyOnLaunch),
                    onChanged: controller.setAppUpdateAutoCheckEnabled,
                  ),
                  Text(
                    appStrings.installedArg1LastCheckedArg2(
                      controller.installedAppVersion ?? 'Unknown',
                      controller.appUpdateLastCheckedLabel,
                    ),
                    style: TextStyle(color: _textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: controller.isCheckingAppUpdate
                            ? null
                            : () => controller.checkForAppUpdates(),
                        icon: controller.isCheckingAppUpdate
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.sync),
                        label: Text(
                          controller.isCheckingAppUpdate
                              ? 'Checking...'
                              : appStrings.checkNow,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            controller.availableAppUpdate == null ||
                                controller.isOpeningAppUpdate
                            ? null
                            : controller.openAppUpdate,
                        icon: controller.isOpeningAppUpdate
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.system_update_alt),
                        label: Text(
                          controller.isOpeningAppUpdate
                              ? 'Opening...'
                              : appStrings.downloadUpdate,
                        ),
                      ),
                    ],
                  ),
                  if (controller.appUpdateErrorMessage
                      case final message?) ...<Widget>[
                    const SizedBox(height: 14),
                    _InlineError(message: message),
                  ],
                  if (controller.availableAppUpdate
                      case final release?) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _bgSecondary,
                        borderRadius: BorderRadius.circular(16),
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
                                label: appStrings.updateArg1(release.version),
                                color: release.channel == 'beta'
                                    ? _warning
                                    : _accent,
                              ),
                              _StatusPill(
                                label: release.asset.sizeLabel,
                                color: _textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            release.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            release.publishedLabel,
                            style: TextStyle(color: _textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
                _SectionTitle(appStrings.sectionSession),
                const SizedBox(height: 10),
                Text(
                  controller.backendUrl,
                  style: GoogleFonts.geistMono(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: controller.logout,
                  icon: Icon(Icons.logout),
                  label: Text(appStrings.signOut),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final compactNav = MediaQuery.sizeOf(context).width < 340;
    final localizations = MaterialLocalizations.of(context);
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(_now),
      alwaysUse24HourFormat: true,
    );
    final batteryPercent = _deviceStatus?.batteryPercent;
    final batteryLabel = batteryPercent == null ? '--%' : '$batteryPercent%';
    final batteryIcon = _deviceStatus?.charging == true
        ? Icons.battery_charging_full
        : Icons.battery_full;
    return _ControlSurfaceBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(batteryIcon, size: 18, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      batteryLabel,
                      style: TextStyle(
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final pages = <Widget>[
                      _buildAssistantPage(),
                      _buildSettingsPage(),
                    ];
                    return IndexedStack(
                      index: _selectedPage.index,
                      children: pages,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedPage.index,
          labelBehavior: compactNav
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.keyboard_voice_outlined),
              label: appStrings.assistant,
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              label: 'Settings',
            ),
          ],
          onDestinationSelected: (index) {
            setState(() {
              _selectedPage = _LauncherPage.values[index];
            });
          },
        ),
      ),
    );
  }
}
