part of 'main.dart';

enum _DeviceTab { computer, android }

class DevicesPanel extends StatefulWidget {
  const DevicesPanel({
    super.key,
    required this.controller,
    this.deviceTarget,
    this.showProviderPicker = true,
    this.computerOnly = false,
  });

  final NeoAgentController controller;
  final String? deviceTarget;
  final bool showProviderPicker;
  final bool computerOnly;

  @override
  State<DevicesPanel> createState() => _DevicesPanelState();
}

class _DevicesPanelState extends State<DevicesPanel> {
  final TextEditingController _teachGoalController = TextEditingController();
  final TextEditingController _androidAppController = TextEditingController();
  _DeviceTab _device = _DeviceTab.computer;
  bool _teachComposerVisible = false;
  Timer? _androidPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          widget.controller.refreshDevices(deviceTarget: widget.deviceTarget),
        );
      }
    });
    // The emulator boots asynchronously, so the panel has to poll: without this
    // "Start Android" looks like it does nothing until the page is reloaded.
    _androidPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_pollAndroid()),
    );
  }

  @override
  void dispose() {
    _androidPollTimer?.cancel();
    _teachGoalController.dispose();
    _androidAppController.dispose();
    super.dispose();
  }

  Future<void> _pollAndroid() async {
    if (!mounted || widget.computerOnly) return;
    if (_device != _DeviceTab.android) return;
    final controller = widget.controller;
    if (controller.isRunningDeviceAction) return;
    await controller.refreshAndroidRuntime();
    if (!mounted) return;
    await controller.refreshAndroidFrameRuntime();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.computerOnly) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: _buildComputer(context),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(appStrings.devices, style: _displayTitleStyle(26)),
                    const SizedBox(height: 4),
                    Text(
                      appStrings.aPrivateLinuxComputerOrAn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: widget.controller.isRefreshingDevices
                    ? null
                    : () => widget.controller.refreshDevices(
                        deviceTarget: widget.deviceTarget,
                      ),
                icon: widget.controller.isRefreshingDevices
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DeviceSurfaceSwitch(
            value: _device,
            onChanged: (value) => setState(() => _device = value),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _device == _DeviceTab.computer
                ? _buildComputer(context)
                : _buildAndroid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildComputer(BuildContext context) {
    final controller = widget.controller;
    final provider = widget.deviceTarget ?? controller.computerProvider;
    final local = provider == 'local';
    final runtime = controller.computerRuntimeFor(widget.deviceTarget);
    final rawState = runtime['state']?.toString() ?? 'stopped';
    final localHeld = local && controller.localComputerDisplayConnected;
    final state = localHeld &&
            !const <String>{
              'ready',
              'agent_control',
              'user_control',
              'teaching',
              'starting',
            }.contains(rawState)
        ? 'ready'
        : rawState;
    final running = <String>{
          'ready',
          'agent_control',
          'user_control',
          'teaching',
        }.contains(state) ||
        localHeld;
    final starting = state == 'starting' || controller.isRunningDeviceAction;
    final teachStatus = controller.teachRuntime['status']?.toString() ?? 'idle';
    final teaching = <String>{
      'recording',
      'synthesizing',
    }.contains(teachStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ComputerToolbar(
          provider: provider,
          showProviderPicker: widget.showProviderPicker,
          localSupported: controller.localComputerSupported,
          state: state,
          runtime: runtime,
          busy: controller.isRunningDeviceAction,
          onProviderChanged: controller.selectComputerProvider,
          onStart: local || running || starting
              ? null
              : () => controller.startComputerRuntime(
                  deviceTarget: widget.deviceTarget,
                ),
          onStop: !local && running
              ? () => controller.stopComputerRuntime(
                  deviceTarget: widget.deviceTarget,
                )
              : null,
          onInterrupt: state == 'agent_control'
              ? () => controller.interruptComputerAgentRuntime(
                  deviceTarget: widget.deviceTarget,
                )
              : null,
          onTeach: !local && running && !teaching
              ? () => setState(
                  () => _teachComposerVisible = !_teachComposerVisible,
                )
              : null,
        ),
        if (local) ...<Widget>[
          const SizedBox(height: 8),
          _LocalComputerPermissionPanel(controller: controller),
        ],
        if (!local && (_teachComposerVisible || teaching)) ...<Widget>[
          const SizedBox(height: 8),
          _TeachBar(
            controller: _teachGoalController,
            status: teachStatus,
            runtime: controller.teachRuntime,
            enabled: running && !controller.isRunningDeviceAction,
            onGoalChanged: (_) => setState(() {}),
            onStart: () =>
                controller.startTeachRuntime(_teachGoalController.text),
            onStop: teachStatus == 'recording'
                ? controller.stopTeachRuntime
                : null,
            onCancel: teaching ? controller.cancelTeachRuntime : null,
            onClose: teaching
                ? null
                : () => setState(() => _teachComposerVisible = false),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: _ComputerActivityGlow(
            active: state == 'agent_control',
            child: _buildDesktop(
              context,
              running: running,
              state: starting && !running ? 'starting' : state,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktop(
    BuildContext context, {
    required bool running,
    required String state,
  }) {
    final controller = widget.controller;
    if ((widget.deviceTarget ?? controller.computerProvider) == 'local') {
      return _LocalComputerDesktop(
        controller: controller,
        running: running,
        state: state,
      );
    }
    final theme = Theme.of(context);
    final displayUrl = controller.computerDisplayUrl;
    final runtime = controller.computerRuntimeFor(widget.deviceTarget);
    final readiness = _jsonMap(runtime['readiness']);
    final firstSetup = readiness['imageReady'] == false;
    final busy = state == 'starting' || controller.isRunningDeviceAction;
    final errorCode = runtime['errorCode']?.toString() ?? '';
    final desktop = _jsonMap(runtime['desktop']);
    final desktopDown = desktop['available'] == false;

    // The display surface stays hidden until the computer is up, so nobody watches
    // the guest's boot console instead of their desktop.
    if (displayUrl != null && running && !desktopDown) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ComputerDisplay(
          key: ValueKey<String>(displayUrl),
          url: displayUrl,
        ),
      );
    }

    Widget content;
    if (desktopDown) {
      content = _ComputerEmptyState(
        icon: Icons.desktop_access_disabled_rounded,
        title: appStrings.theDesktopDidNotStart,
        message:
            desktop['error']?.toString().ifEmpty(
              appStrings.theLinuxGraphicalSessionIsNot,
            ) ??
            appStrings.theLinuxGraphicalSessionIsNot,
        action: FilledButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.startComputerRuntime(
                  deviceTarget: widget.deviceTarget,
                ),
          icon: Icon(Icons.refresh_rounded),
          label: Text(appStrings.repairDesktop),
        ),
      );
    } else if (running) {
      content = _ComputerEmptyState(
        icon: Icons.desktop_windows_rounded,
        title: appStrings.yourDesktopIsReady,
        message:
            appStrings.chromiumFilesTheTextEditorAnd,
        action: FilledButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.openComputerDisplayRuntime(
                  deviceTarget: widget.deviceTarget,
                ),
          icon: Icon(Icons.desktop_windows_rounded),
          label: Text(appStrings.viewDesktop),
        ),
      );
    } else if (busy) {
      content = _ComputerEmptyState(
        icon: Icons.cloud_sync_rounded,
        title: firstSetup
            ? appStrings.preparingYourComputer
            : appStrings.startingYourComputer,
        message: firstSetup
            ? appStrings.neoagentIsDownloadingAndPreparingTheSecure
            : appStrings.openingYourSavedDesktopNormalStarts,
        action: const SizedBox(width: 220, child: LinearProgressIndicator()),
      );
    } else if (state == 'capacity_wait') {
      content = _ComputerEmptyState(
        icon: Icons.hourglass_top_rounded,
        title: appStrings.allComputerSlotsAreBusy,
        message:
            appStrings.noCloudComputerSlotIsFree,
        action: FilledButton.icon(
          onPressed: () => controller.startComputerRuntime(
            deviceTarget: widget.deviceTarget,
          ),
          icon: Icon(Icons.refresh_rounded),
          label: Text(appStrings.tryAgain),
        ),
      );
    } else if (state == 'error') {
      final storageError = errorCode == 'COMPUTER_STORAGE_CAPACITY';
      final lastError =
          runtime['lastError']?.toString().trim() ?? '';
      content = _ComputerEmptyState(
        icon: storageError ? Icons.storage_rounded : Icons.cloud_off_rounded,
        title: storageError
            ? appStrings.moreFreeSpaceIsNeeded
            : appStrings.theComputerCouldNotStart,
        message: lastError.isNotEmpty
            ? lastError
            : storageError
            ? appStrings.freeSomeDiskSpaceOnTheNeoagent
            : appStrings.tryAgainIfThisKeepsHappening,
        action: FilledButton.icon(
          onPressed: () => controller.startComputerRuntime(
            deviceTarget: widget.deviceTarget,
          ),
          icon: Icon(Icons.refresh_rounded),
          label: Text(appStrings.tryAgain),
        ),
      );
    } else {
      content = _ComputerEmptyState(
        icon: Icons.computer_rounded,
        title: state == 'sleeping'
            ? appStrings.yourComputerIsAsleep
            : appStrings.yourLinuxComputer,
        message:
            appStrings.aPrivateDesktopWithChromiumFiles,
        action: FilledButton.icon(
          onPressed: () => controller.startComputerRuntime(
            deviceTarget: widget.deviceTarget,
          ),
          icon: Icon(Icons.play_arrow_rounded),
          label: Text(state == 'sleeping' ? 'Wake computer' : appStrings.startComputer),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: content,
      ),
    );
  }

  Widget _buildAndroid(BuildContext context) {
    final controller = widget.controller;
    final devices = _jsonMapList(
      controller.androidRuntime['devices'],
      fallbackToMapValues: true,
    );
    final online = devices.any(
      (device) => device['status']?.toString() == 'device',
    );
    final starting = !online && controller.androidRuntime['starting'] == true;
    final startupPhase =
        controller.androidRuntime['startupPhase']?.toString().trim() ?? '';
    final startError =
        controller.androidRuntime['lastStartError']?.toString().trim() ?? '';
    final screenshotPath = controller.androidScreenshotPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                if (starting)
                  const SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: online
                        ? Colors.green
                        : startError.isEmpty
                        ? Colors.grey
                        : Theme.of(context).colorScheme.error,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    online
                        ? appStrings.androidReady
                        : starting
                        ? startupPhase.isEmpty
                              ? appStrings.startingAndroid2
                              : startupPhase
                        : startError.isEmpty
                        ? appStrings.androidStopped
                        : startError,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (online) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: controller.isRunningDeviceAction
                        ? null
                        : controller.screenshotAndroidRuntime,
                    icon: Icon(Icons.refresh_rounded),
                    label: Text(appStrings.refresh),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: controller.isRunningDeviceAction
                        ? null
                        : controller.stopAndroidRuntime,
                    child: Text(appStrings.stop),
                  ),
                ] else if (starting)
                  TextButton(
                    onPressed: controller.isRunningDeviceAction
                        ? null
                        : controller.stopAndroidRuntime,
                    child: Text(appStrings.cancel),
                  )
                else
                  FilledButton.icon(
                    onPressed: controller.isRunningDeviceAction
                        ? null
                        : controller.startAndroidRuntime,
                    icon: Icon(Icons.play_arrow_rounded),
                    label: Text(appStrings.startAndroid),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _androidAppController,
                enabled: online && !controller.isRunningDeviceAction,
                decoration: InputDecoration(
                  labelText: appStrings.packageName,
                  hintText: _androidDefaultLaunchPackage,
                  prefixIcon: Icon(Icons.apps_rounded),
                ),
                onSubmitted: (_) => _openAndroidApp(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: online && !controller.isRunningDeviceAction
                  ? _openAndroidApp
                  : null,
              child: Text(appStrings.open),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            color: Colors.black,
            child: starting
                ? _ComputerEmptyState(
                    icon: Icons.android_rounded,
                    title: appStrings.startingAndroid,
                    message: startupPhase.isEmpty
                        ? appStrings.theFirstStartDownloadsTheAndroidSdk
                        : startupPhase,
                    action: const SizedBox(
                      width: 220,
                      child: LinearProgressIndicator(),
                    ),
                  )
                : !online
                ? _ComputerEmptyState(
                    icon: Icons.android_rounded,
                    title: startError.isEmpty
                        ? appStrings.androidIsStopped
                        : appStrings.androidCouldNotStart,
                    message: startError.isEmpty
                        ? appStrings.startTheManagedAndroidEnvironmentWhenYou
                        : startError,
                  )
                : _AndroidSurface(
                    controller: controller,
                    screenshotPath: screenshotPath,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        _AndroidKeyBar(
          enabled: online && !controller.isRunningDeviceAction,
          onKey: controller.pressAndroidKeyRuntime,
        ),
      ],
    );
  }

  Future<void> _openAndroidApp() async {
    final packageName = _androidAppController.text.trim().isEmpty
        ? _androidDefaultLaunchPackage
        : _androidAppController.text.trim();
    await widget.controller.openAndroidAppRuntime(packageName: packageName);
    await widget.controller.screenshotAndroidRuntime();
  }
}

/// Live Android frame with touch input. Keep the last decoded frame on screen
/// between polls so the surface does not flicker.
class _AndroidSurface extends StatefulWidget {
  const _AndroidSurface({
    required this.controller,
    required this.screenshotPath,
  });

  final NeoAgentController controller;
  final String? screenshotPath;

  @override
  State<_AndroidSurface> createState() => _AndroidSurfaceState();
}

class _AndroidSurfaceState extends State<_AndroidSurface> {
  Uint8List? _bytes;
  Size? _pixelSize;
  Object? _error;
  String? _loadedPath;
  Offset? _dragStart;
  Offset? _dragEnd;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _AndroidSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenshotPath != widget.screenshotPath) unawaited(_load());
  }

  Future<void> _load() async {
    final path = widget.screenshotPath;
    if (path == null || path.isEmpty || path == _loadedPath) return;
    try {
      final bytes = await widget.controller.fetchRuntimeAssetBytes(path);
      if (!mounted || widget.screenshotPath != path) return;
      setState(() {
        _bytes = bytes;
        _error = null;
        _loadedPath = path;
      });
      final image = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(
        () =>
            _pixelSize = Size(image.width.toDouble(), image.height.toDouble()),
      );
    } catch (error) {
      if (!mounted || widget.screenshotPath != path) return;
      // A failed poll keeps the last good frame; only report when nothing is shown.
      setState(() => _error = _bytes == null ? error : null);
    }
  }

  /// Maps a position inside the [BoxFit.contain] letterbox onto device pixels.
  Offset? _mapToDevice(Offset local, Size boxSize) {
    final pixelSize = _pixelSize;
    if (pixelSize == null || boxSize.isEmpty) return null;
    final imageAspect = pixelSize.width / pixelSize.height;
    final double renderWidth;
    final double renderHeight;
    if (boxSize.width / boxSize.height > imageAspect) {
      renderHeight = boxSize.height;
      renderWidth = renderHeight * imageAspect;
    } else {
      renderWidth = boxSize.width;
      renderHeight = renderWidth / imageAspect;
    }
    final offsetX = (boxSize.width - renderWidth) / 2;
    final offsetY = (boxSize.height - renderHeight) / 2;
    if (local.dx < offsetX ||
        local.dx > offsetX + renderWidth ||
        local.dy < offsetY ||
        local.dy > offsetY + renderHeight) {
      return null;
    }
    return Offset(
      ((local.dx - offsetX) / renderWidth) * pixelSize.width,
      ((local.dy - offsetY) / renderHeight) * pixelSize.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      if (_error != null) {
        return _ComputerEmptyState(
          icon: Icons.broken_image_outlined,
          title: appStrings.frameUnavailable,
          message: appStrings.refreshTheAndroidScreenToTry,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          button: true,
          label: appStrings.androidScreenTapToTouchDrag,
          child: GestureDetector(
            onTapUp: (details) {
              final point = _mapToDevice(details.localPosition, boxSize);
              if (point == null) return;
              unawaited(
                widget.controller.tapAndroidRuntime(<String, dynamic>{
                  'x': point.dx.round(),
                  'y': point.dy.round(),
                }),
              );
            },
            onPanStart: (details) {
              _dragStart = details.localPosition;
              _dragEnd = details.localPosition;
            },
            onPanUpdate: (details) => _dragEnd = details.localPosition,
            onPanEnd: (_) {
              final start = _dragStart;
              final end = _dragEnd;
              _dragStart = null;
              _dragEnd = null;
              if (start == null || end == null) return;
              if ((start - end).distance < 12) return;
              final mappedStart = _mapToDevice(start, boxSize);
              final mappedEnd = _mapToDevice(end, boxSize);
              if (mappedStart == null || mappedEnd == null) return;
              unawaited(
                widget.controller.swipeAndroidRuntime(<String, dynamic>{
                  'x1': mappedStart.dx.round(),
                  'y1': mappedStart.dy.round(),
                  'x2': mappedEnd.dx.round(),
                  'y2': mappedEnd.dy.round(),
                  'durationMs': 280,
                }),
              );
            },
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }
}

class _AndroidKeyBar extends StatelessWidget {
  const _AndroidKeyBar({required this.enabled, required this.onKey});

  final bool enabled;
  final Future<void> Function(String key) onKey;

  static List<({String key, IconData icon, String label})> _keys =
      <({String key, IconData icon, String label})>[
        (key: 'back', icon: Icons.arrow_back_rounded, label: 'Back'),
        (key: 'home', icon: Icons.circle_outlined, label: appStrings.home),
        (key: 'app_switch', icon: Icons.crop_square_rounded, label: appStrings.recents),
      ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _keys
          .map(
            (entry) => IconButton(
              tooltip: entry.label,
              onPressed: enabled ? () => unawaited(onKey(entry.key)) : null,
              icon: Icon(entry.icon),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DeviceSurfaceSwitch extends StatelessWidget {
  const _DeviceSurfaceSwitch({required this.value, required this.onChanged});

  final _DeviceTab value;
  final ValueChanged<_DeviceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PanelSurface(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      fillColor: _bgSecondary.withValues(alpha: 0.78),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _DeviceSurfacePill(
              selected: value == _DeviceTab.computer,
              icon: Icons.computer_rounded,
              label: 'Computer',
              onTap: () => onChanged(_DeviceTab.computer),
            ),
          ),
          Expanded(
            child: _DeviceSurfacePill(
              selected: value == _DeviceTab.android,
              icon: Icons.android_rounded,
              label: 'Android',
              onTap: () => onChanged(_DeviceTab.android),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceSurfacePill extends StatelessWidget {
  const _DeviceSurfacePill({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _accent : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 17,
                color: selected ? _bgPrimary : _textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? _bgPrimary : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComputerActivityGlow extends StatefulWidget {
  const _ComputerActivityGlow({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_ComputerActivityGlow> createState() => _ComputerActivityGlowState();
}

class _ComputerActivityGlowState extends State<_ComputerActivityGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulse = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ComputerActivityGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      child: widget.child,
      builder: (context, child) {
        final strength = widget.active ? 0.45 + (_pulse.value * 0.55) : 0.0;
        return Container(
          key: widget.active
              ? const ValueKey<String>('computer-ai-activity-glow')
              : null,
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF7C5CFF).withValues(
                alpha: 0.28 * strength,
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF4F8CFF).withValues(
                  alpha: 0.34 * strength,
                ),
                blurRadius: 16 + (14 * strength),
                spreadRadius: 1 + (2 * strength),
              ),
              BoxShadow(
                color: const Color(0xFFB45CFF).withValues(
                  alpha: 0.2 * strength,
                ),
                blurRadius: 28 + (18 * strength),
                spreadRadius: -2 + (2 * strength),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

class _ComputerToolbar extends StatelessWidget {
  const _ComputerToolbar({
    required this.provider,
    required this.showProviderPicker,
    required this.localSupported,
    required this.state,
    required this.runtime,
    required this.busy,
    required this.onProviderChanged,
    required this.onStart,
    required this.onStop,
    required this.onInterrupt,
    required this.onTeach,
  });

  final String provider;
  final bool showProviderPicker;
  final bool localSupported;
  final String state;
  final Map<String, dynamic> runtime;
  final bool busy;
  final ValueChanged<String> onProviderChanged;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onInterrupt;
  final VoidCallback? onTeach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _computerStatusPresentation(
      theme,
      provider: provider,
      state: state,
      runtime: runtime,
      busy: busy,
    );
    final statusView = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: status.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(status.icon, size: 19, color: status.color),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(status.title, style: theme.textTheme.titleSmall),
              Text(
                status.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final controls = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (showProviderPicker)
          _PanelSurface(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            fillColor: _bgSecondary.withValues(alpha: 0.86),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _DeviceSurfacePill(
                  selected: provider == 'cloud',
                  icon: Icons.cloud_rounded,
                  label: 'Cloud',
                  onTap: busy ? null : () => onProviderChanged('cloud'),
                ),
                Tooltip(
                  message: localSupported
                      ? appStrings.letNeoagentWorkOnThisComputer
                      : appStrings.availableInTheDesktopAppFor,
                  child: Opacity(
                    opacity: localSupported ? 1 : 0.45,
                    child: _DeviceSurfacePill(
                      selected: provider == 'local',
                      icon: Icons.laptop_rounded,
                      label: appStrings.thisDevice,
                      onTap: busy || !localSupported
                          ? null
                          : () => onProviderChanged('local'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (onTeach != null)
          OutlinedButton.icon(
            key: const ValueKey<String>('computer-teach-toggle'),
            onPressed: busy ? null : onTeach,
            icon: Icon(Icons.school_outlined, size: 18),
            label: Text(appStrings.teach),
          ),
        if (onInterrupt != null)
          FilledButton.icon(
            key: const ValueKey<String>('computer-interrupt-ai'),
            onPressed: busy ? null : onInterrupt,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            icon: Icon(Icons.front_hand_rounded, size: 18),
            label: Text(appStrings.interruptAi),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (onStart != null)
          FilledButton.icon(
            onPressed: busy ? null : onStart,
            icon: Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(state == 'sleeping' ? 'Wake' : 'Start'),
          ),
        if (onStop != null)
          IconButton(
            tooltip: appStrings.turnOffComputer,
            onPressed: busy ? null : onStop,
            icon: Icon(Icons.power_settings_new_rounded),
          ),
      ],
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  statusView,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: controls),
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: statusView),
                const SizedBox(width: 12),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }
}

({String title, String subtitle, IconData icon, Color color})
_computerStatusPresentation(
  ThemeData theme, {
  required String provider,
  required String state,
  required Map<String, dynamic> runtime,
  required bool busy,
}) {
  if (busy &&
      !const <String>{
        'ready',
        'agent_control',
        'user_control',
        'teaching',
      }.contains(state) &&
      state != 'starting') {
    return (
      title: appStrings.startingYourComputer,
      subtitle: appStrings.thisMayTakeAMoment,
      icon: Icons.cloud_sync_rounded,
      color: theme.colorScheme.primary,
    );
  }
  final local = provider == 'local';
  switch (state) {
    case 'starting':
      final readiness = _jsonMap(runtime['readiness']);
      final firstSetup = !local && readiness['imageReady'] == false;
      return (
        title: firstSetup
            ? appStrings.preparingYourComputer
            : appStrings.startingYourComputer,
        subtitle: firstSetup
            ? appStrings.firstTimeSetupIsInProgress
            : appStrings.openingYourSavedDesktop,
        icon: Icons.cloud_sync_rounded,
        color: theme.colorScheme.primary,
      );
    case 'ready':
    case 'agent_control':
    case 'user_control':
      final desktop = _jsonMap(runtime['desktop']);
      final desktopDown = !local && desktop['available'] == false;
      if (desktopDown) {
        return (
          title: appStrings.desktopFailedToStart,
          subtitle:
              desktop['error']?.toString().ifEmpty(
                appStrings.theLinuxGraphicalSessionIsNot,
              ) ??
              appStrings.theLinuxGraphicalSessionIsNot,
          icon: Icons.desktop_access_disabled_rounded,
          color: theme.colorScheme.error,
        );
      }
      if (state == 'agent_control') {
        return (
          title: appStrings.neoagentIsWorking,
          subtitle: appStrings.youCanFollowAlongOnThe,
          icon: Icons.auto_awesome_rounded,
          color: theme.colorScheme.primary,
        );
      }
      if (state == 'user_control') {
        return (
          title: appStrings.youAreInControl,
          subtitle: appStrings.neoagentIsWaitingWhileYouUse,
          icon: Icons.touch_app_rounded,
          color: Colors.green,
        );
      }
      return (
        title: local ? 'This device is ready' : appStrings.yourComputerIsReady,
        subtitle: local
            ? appStrings.neoagentCanUseTheAccessYouAllow
            : appStrings.everythingIsAvailableFromTheDesktop,
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      );
    case 'teaching':
      return (
        title: appStrings.teachingInProgress,
        subtitle: appStrings.completeTheWorkflowOnTheDesktop,
        icon: Icons.fiber_manual_record_rounded,
        color: Colors.red,
      );
    case 'sleeping':
      return (
        title: appStrings.yourComputerIsAsleep,
        subtitle: appStrings.yourAppsAndFilesAreSaved,
        icon: Icons.bedtime_rounded,
        color: Colors.amber,
      );
    case 'capacity_wait':
      return (
        title: appStrings.allComputerSlotsAreBusy,
        subtitle: appStrings.tryAgainInAMoment,
        icon: Icons.hourglass_top_rounded,
        color: Colors.amber,
      );
    case 'error':
      final storage = runtime['errorCode'] == 'COMPUTER_STORAGE_CAPACITY';
      return (
        title: storage ? appStrings.moreFreeSpaceIsNeeded : appStrings.couldNotStart,
        subtitle: storage
            ? appStrings.freeSomeHostStorageAndTryAgain
            : appStrings.tryAgainOrRunNeoagentDoctor,
        icon: storage ? Icons.storage_rounded : Icons.error_outline_rounded,
        color: theme.colorScheme.error,
      );
    default:
      return (
        title: local ? 'This device is paused' : appStrings.yourComputerIsOff,
        subtitle: local
            ? appStrings.startWhenYouWantNeoagentToHelp
            : appStrings.yourAppsAndFilesRemainSaved,
        icon: local ? Icons.laptop_rounded : Icons.computer_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      );
  }
}

class _LocalComputerPermissionPanel extends StatelessWidget {
  const _LocalComputerPermissionPanel({required this.controller});

  final NeoAgentController controller;

  static Map<String, ({IconData icon, String label, String detail})>
  _definitions = <String, ({IconData icon, String label, String detail})>{
    'screen': (
      icon: Icons.visibility_rounded,
      label: appStrings.screen,
      detail: appStrings.letNeoagentUnderstandWhatIsVisible,
    ),
    'input': (
      icon: Icons.touch_app_rounded,
      label: appStrings.mouseKeyboard,
      detail: appStrings.letNeoagentClickTypeAndMove,
    ),
    'files': (
      icon: Icons.folder_open_rounded,
      label: appStrings.workspaceFiles,
      detail: appStrings.readAndEditFilesInsideYour,
    ),
    'shell': (
      icon: Icons.terminal_rounded,
      label: appStrings.commandsApps,
      detail: appStrings.runTerminalCommandsAndOpenApps,
    ),
  };

  /// OS-level grants the app permission depends on but cannot give itself.
  /// macOS applies a Screen Recording grant only after the app reopens, so
  /// the hint says so instead of leaving the user re-granting in a loop.
  List<String> _systemPermissionGaps(NeoAgentController controller) {
    final granted = controller.localComputerPermissions;
    final system = _jsonMap(controller.localComputerStatus['permissions']);
    final gaps = <String>[];
    if (granted.contains('screen') && system['screenCapture'] == 'required') {
      gaps.add(
        appStrings.macosScreenRecordingIsNotGranted,
      );
    }
    if (granted.contains('input') && system['inputControl'] == 'required') {
      gaps.add(
        appStrings.macosAccessibilityIsNotGrantedTo,
      );
    }
    return gaps;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = controller.localComputerPendingPermission;
    final permissions = controller.localComputerPermissions;
    final systemGaps = _systemPermissionGaps(controller);
    final permissionControls = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _definitions.entries
          .map((entry) {
            final granted = permissions.contains(entry.key);
            return FilterChip(
              avatar: Icon(entry.value.icon, size: 18),
              label: Text(entry.value.label),
              tooltip: entry.value.detail,
              selected: granted,
              onSelected: (selected) => selected
                  ? controller.grantLocalComputerPermission(
                      entry.key,
                      remember: true,
                    )
                  : controller.revokeLocalComputerPermission(entry.key),
            );
          })
          .toList(growable: false),
    );
    if (pending != null && _definitions.containsKey(pending)) {
      final request = _definitions[pending]!;
      return Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(request.icon, color: theme.colorScheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      appStrings.arg1AccessNeeded(request.label),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(request.detail, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton(
                          onPressed: () =>
                              controller.grantLocalComputerPermission(
                                pending,
                                remember: false,
                              ),
                          child: Text(appStrings.allowOnce),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              controller.grantLocalComputerPermission(
                                pending,
                                remember: true,
                              ),
                          child: Text(appStrings.alwaysAllow),
                        ),
                        TextButton(
                          onPressed: () =>
                              controller.denyLocalComputerPermission(pending),
                          child: Text(appStrings.notNow),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        dense: true,
        leading: Icon(
          controller.localComputerConnected
              ? Icons.shield_outlined
              : Icons.link_off_rounded,
        ),
        title: Text(appStrings.accessPermissions),
        subtitle: Text(
          controller.localComputerConnecting
              ? appStrings.connecting
              : systemGaps.isNotEmpty
              ? appStrings.systemPermissionMissing
              : controller.localComputerConnected
              ? appStrings.arg1Of4Allowed(permissions.length)
              : appStrings.reconnectingThisDevice,
          style: systemGaps.isNotEmpty
              ? TextStyle(color: theme.colorScheme.error)
              : null,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        children: <Widget>[
          Align(alignment: Alignment.centerLeft, child: permissionControls),
          for (final gap in systemGaps) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                gap,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (controller.localComputerError?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                controller.localComputerError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          if (permissions.contains('screen') || permissions.contains('input'))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => controller.openLocalComputerSystemPermission(
                  permissions.contains('screen') ? 'screen' : 'input',
                ),
                icon: Icon(Icons.settings_rounded),
                label: Text(appStrings.systemPrivacySettings),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocalComputerDesktop extends StatefulWidget {
  const _LocalComputerDesktop({
    required this.controller,
    required this.running,
    required this.state,
  });

  final NeoAgentController controller;
  final bool running;
  final String state;

  @override
  State<_LocalComputerDesktop> createState() => _LocalComputerDesktopState();
}

class _LocalComputerDesktopState extends State<_LocalComputerDesktop> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.controller.ensureLocalDeviceConnected());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final running = widget.running;
    final connecting =
        widget.state == 'starting' || controller.localComputerConnecting;
    if (!running) {
      return _ComputerSurface(
        child: _ComputerEmptyState(
          icon: connecting ? Icons.sync_rounded : Icons.laptop_rounded,
          title: connecting
              ? appStrings.connectingThisDevice
              : appStrings.keepingThisDeviceConnected,
          message: connecting
              ? appStrings.theSecureLocalConnectionIsBeingEstablished
              : appStrings.neoagentUsesThisComputerAutomaticallyAnd,
          action: const SizedBox(width: 220, child: LinearProgressIndicator()),
        ),
      );
    }
    final permissions = controller.localComputerPermissions;
    return _ComputerSurface(
      child: _ComputerEmptyState(
        icon: Icons.desktop_windows_rounded,
        title: appStrings.thisDesktopIsConnected,
        message:
            appStrings.keepUsingYourAppsNormallyNeoagent +
            appStrings.arg1Of4PermissionsAllowedFiles(permissions.length),
      ),
    );
  }
}

class _ComputerSurface extends StatelessWidget {
  const _ComputerSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _TeachBar extends StatelessWidget {
  const _TeachBar({
    required this.controller,
    required this.status,
    required this.runtime,
    required this.enabled,
    required this.onGoalChanged,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.onClose,
  });

  final TextEditingController controller;
  final String status;
  final Map<String, dynamic> runtime;
  final bool enabled;
  final ValueChanged<String> onGoalChanged;
  final VoidCallback onStart;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final active = status == 'recording' || status == 'synthesizing';
    final goal = runtime['goal']?.toString() ?? '';
    final startedAt = DateTime.tryParse(runtime['startedAt']?.toString() ?? '');
    final elapsed = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt.toLocal());
    final elapsedLabel = elapsed.isNegative
        ? '0:00'
        : '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: active
            ? Row(
                children: <Widget>[
                  Icon(
                    status == 'recording'
                        ? Icons.fiber_manual_record
                        : Icons.auto_awesome,
                    color: status == 'recording' ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          status == 'recording'
                              ? appStrings.recordingYourDemonstration
                              : appStrings.creatingYourSkill,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (goal.isNotEmpty)
                          Text(
                            goal,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          status == 'recording'
                              ? appStrings.arg1WorkThroughTheTaskAsYou(elapsedLabel)
                              : appStrings.neoagentIsTurningYourDemonstrationInto,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onStop != null)
                    FilledButton.icon(
                      onPressed: onStop,
                      icon: Icon(Icons.stop_rounded),
                      label: Text(appStrings.finish),
                    ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: Text(appStrings.cancel),
                    ),
                ],
              )
            : Row(
                children: <Widget>[
                  Icon(Icons.school_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      maxLength: 1000,
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      decoration: InputDecoration(
                        labelText: appStrings.whatShouldNeoagentLearn,
                        hintText:
                            appStrings.describeTheOutcomeThenDemonstrateIt,
                        isDense: true,
                      ),
                      onChanged: onGoalChanged,
                      onSubmitted: (_) =>
                          enabled && controller.text.trim().isNotEmpty
                          ? onStart()
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    key: const ValueKey<String>('computer-teach-start'),
                    onPressed: enabled && controller.text.trim().isNotEmpty
                        ? onStart
                        : null,
                    icon: Icon(Icons.fiber_manual_record_rounded),
                    label: Text(appStrings.teach),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: appStrings.closeTeachMode,
                      onPressed: onClose,
                      icon: Icon(Icons.close_rounded),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ComputerEmptyState extends StatelessWidget {
  const _ComputerEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scrollable so the block never overflows in a short viewport — a phone in
    // landscape, or a section that carries a chip row above the content.
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: 16),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
