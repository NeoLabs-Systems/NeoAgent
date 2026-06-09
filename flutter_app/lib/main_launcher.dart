part of 'main.dart';

enum _LauncherPage { assistant, widgets, recordings, settings }

class LauncherHomeView extends StatefulWidget {
  const LauncherHomeView({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<LauncherHomeView> createState() => _LauncherHomeViewState();
}

class _LauncherHomeViewState extends State<LauncherHomeView> {
  static const int _assistantButtonKeyCode = 131;
  static const int _recordingButtonKeyCode = 132;

  final AndroidLauncherBridge _launcherBridge = AndroidLauncherBridge.instance;
  StreamSubscription<LauncherHardwareButtonEvent>? _buttonSubscription;

  _LauncherPage _selectedPage = _LauncherPage.assistant;
  LauncherVolumeState? _volumeState;
  LauncherDeviceStatus? _deviceStatus;
  bool _assistantHardwareCaptureActive = false;
  bool _recordingConfirmOpen = false;
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
      _showLauncherActionError('Unable to open Wi-Fi settings on this build.');
    }
  }

  Future<void> _openTimeSettings() async {
    final opened = await _launcherBridge.openTimeSettings();
    if (!opened) {
      _showLauncherActionError('Unable to open time settings on this build.');
    }
  }

  bool get _supportsQrLoginApproval =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _startQrLoginApproval() async {
    final controller = widget.controller;
    if (!controller.isAuthenticated) {
      _showLauncherActionError(
        'Sign in to this NeoAgent server before scanning a pairing QR code.',
      );
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
      _showLauncherActionError(
        'That QR code is not a NeoAgent pairing request.',
      );
      return;
    }

    final scannedBackend = controller._normalizeBackendUrl(payload.backendUrl);
    final currentBackend = controller._normalizeBackendUrl(
      controller.backendUrl,
    );
    if (scannedBackend != currentBackend) {
      _showLauncherActionError(
        'This code belongs to a different NeoAgent server: ${payload.backendUrl}',
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
            'Approved pairing for ${preview.requestedDevice.label}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showLauncherActionError(
        controller.errorMessage ?? 'Could not approve QR pairing.',
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

  Future<void> _toggleRecordingFromHardware() async {
    final controller = widget.controller;
    if (controller.recordingRuntime.active) {
      await controller.stopRecording(stopReason: 'hardware_button');
      return;
    }
    if (!await _confirmRecordingStart(sourceLabel: 'hardware button')) {
      return;
    }
    await controller.startBackgroundRecording();
  }

  Future<void> _startRecordingFromUi() async {
    final controller = widget.controller;
    if (controller.recordingRuntime.active || controller.isStartingRecording) {
      return;
    }
    if (!await _confirmRecordingStart(sourceLabel: 'Start button')) {
      return;
    }
    await controller.startBackgroundRecording();
  }

  Future<bool> _confirmRecordingStart({required String sourceLabel}) async {
    if (!mounted || _recordingConfirmOpen) {
      return false;
    }
    _recordingConfirmOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start recording?'),
          content: Text(
            'Recording was requested from $sourceLabel. Start a new background recording session now?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
    _recordingConfirmOpen = false;
    return confirmed == true;
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
      return;
    }

    if (event.keyCode == _recordingButtonKeyCode && event.isUp) {
      unawaited(_toggleRecordingFromHardware());
    }
  }

  Widget _buildAssistantPage() {
    return VoiceAssistantPanel(controller: widget.controller);
  }

  Widget _buildRecordingsPage() {
    final controller = widget.controller;
    final runtime = controller.recordingRuntime;
    final recentSessions = controller.recordingSessions.take(4).toList();
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Recorder',
          subtitle:
              'Record audio and keep it running while you use the device.',
          trailing: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: controller.isStartingRecording || runtime.active
                    ? null
                    : _startRecordingFromUi,
                icon: const Icon(Icons.mic_none_outlined),
                label: const Text('Start'),
              ),
              OutlinedButton.icon(
                onPressed: runtime.active
                    ? (runtime.paused
                          ? controller.resumeBackgroundRecording
                          : controller.pauseBackgroundRecording)
                    : null,
                icon: Icon(
                  runtime.paused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                label: Text(runtime.paused ? 'Resume' : 'Pause'),
              ),
              OutlinedButton.icon(
                onPressed: runtime.active && !controller.isStoppingRecording
                    ? controller.stopRecording
                    : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _DotStatus(
                      label: runtime.active
                          ? (runtime.paused ? 'Paused' : 'Recording')
                          : 'Idle',
                      color: runtime.active
                          ? (runtime.paused ? _warning : _danger)
                          : _success,
                    ),
                    _MetaPill(
                      icon: Icons.mic_outlined,
                      label: runtime.supportsBackgroundMic
                          ? 'Background recording ready'
                          : 'Recording unavailable',
                    ),
                  ],
                ),
                if (runtime.errorMessage != null &&
                    runtime.errorMessage!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _InlineError(message: runtime.errorMessage!),
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
                const _SectionTitle('Recent Sessions'),
                const SizedBox(height: 10),
                if (recentSessions.isEmpty)
                  Text(
                    'No recordings yet.',
                    style: TextStyle(color: _textSecondary),
                  )
                else
                  ...recentSessions.map(
                    (session) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.audio_file_outlined, color: _accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  session.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${session.statusLabel} • ${session.startedAtLabel}',
                                  style: TextStyle(color: _textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: controller.refreshRecordings,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWidgetsPage() {
    final controller = widget.controller;
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Widgets',
          subtitle:
              'Pinned AI widgets refreshed by the server and rendered here at a glance.',
        ),
        if (controller.widgets.isEmpty)
          const _EmptyCard(
            title: 'No widgets yet',
            subtitle: 'Create one in chat and it will show up here.',
          )
        else
          ...controller.widgets.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AiWidgetCard(
                item: item,
                controller: controller,
                compact: true,
                active: controller.selectedWidgetId == item.id,
                onSelect: () => controller.selectWidget(item.id),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    final controller = widget.controller;
    final volumeState = _volumeState;
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Device Settings',
          subtitle:
              'Adjust speaker volume, review hardware button defaults, and manage this launcher session.',
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
                      const Expanded(child: _SectionTitle('QR Pairing')),
                      _StatusPill(label: 'Android only', color: _accent),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Scan a NeoAgent pairing QR from another device and approve it from this launcher session.',
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
                        : const Icon(Icons.qr_code_scanner_outlined),
                    label: Text(
                      controller.isApprovingQrLogin
                          ? 'Opening scanner...'
                          : 'Scan pairing QR',
                    ),
                  ),
                  if (!controller.isAuthenticated) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'This requires an authenticated session on the same NeoAgent server.',
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
                const _SectionTitle('Volume'),
                const SizedBox(height: 10),
                Text(
                  'Adjust the speaker volume here.',
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
                      icon: const Icon(Icons.remove_circle_outline),
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
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (volumeState != null)
                  Text(
                    'Level ${volumeState.current}/${volumeState.max}${volumeState.muted ? ' • muted' : ''}',
                    style: TextStyle(color: _textSecondary),
                  ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _launcherBridge.supported
                      ? _openWifiSettings
                      : null,
                  icon: const Icon(Icons.wifi_outlined),
                  label: const Text('Open Wi-Fi settings'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _launcherBridge.supported
                      ? _openTimeSettings
                      : null,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Open time settings'),
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
                const _SectionTitle('Extra Buttons'),
                const SizedBox(height: 10),
                Text(
                  'Hold button 131 for the assistant. Press button 132 to start or stop recording.',
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    const _MetaPill(
                      icon: Icons.keyboard_voice_outlined,
                      label: 'Assistant key 131',
                    ),
                    const _MetaPill(
                      icon: Icons.fiber_smart_record_outlined,
                      label: 'Recording key 132',
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
                const _SectionTitle('App Updates'),
                const SizedBox(height: 10),
                Text(
                  'Keep this launcher up to date.',
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (!controller.appUpdaterConfigured)
                  Text(
                    'Updates are not configured for this build.',
                    style: TextStyle(color: _textSecondary),
                  )
                else ...<Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: controller.appUpdateChannel,
                    decoration: const InputDecoration(
                      labelText: 'Release channel',
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
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: controller.appUpdateAutoCheckEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Check automatically on launch'),
                    onChanged: controller.setAppUpdateAutoCheckEnabled,
                  ),
                  Text(
                    'Installed: ${controller.installedAppVersion ?? 'Unknown'} • Last checked: ${controller.appUpdateLastCheckedLabel}',
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
                            : const Icon(Icons.sync),
                        label: Text(
                          controller.isCheckingAppUpdate
                              ? 'Checking...'
                              : 'Check now',
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
                            : const Icon(Icons.system_update_alt),
                        label: Text(
                          controller.isOpeningAppUpdate
                              ? 'Opening...'
                              : 'Download update',
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
                                label: 'Update ${release.version}',
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
                const _SectionTitle('Session'),
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
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
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
    return _AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _bgCard.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(batteryIcon, size: 18, color: _textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          batteryLabel,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: _textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final pages = <Widget>[
                      _buildAssistantPage(),
                      _buildWidgetsPage(),
                      _buildRecordingsPage(),
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
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.keyboard_voice_outlined),
              label: 'Assistant',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_customize_outlined),
              label: 'Widgets',
            ),
            NavigationDestination(
              icon: Icon(Icons.fiber_smart_record_outlined),
              label: 'Record',
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
