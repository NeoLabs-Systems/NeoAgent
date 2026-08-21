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
  final TextEditingController _androidAppController = TextEditingController(
    text: _androidLaunchPlaceholder,
  );
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
                    Text('DEVICES', style: _sectionEyebrowStyle()),
                    const SizedBox(height: 4),
                    Text('Devices', style: _displayTitleStyle(26)),
                    const SizedBox(height: 4),
                    Text(
                      'A private Linux computer or an Android device.',
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
        title: 'The desktop did not start',
        message:
            desktop['error']?.toString().ifEmpty(
              'The Linux graphical session is not running.',
            ) ??
            'The Linux graphical session is not running.',
        action: FilledButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.startComputerRuntime(
                  deviceTarget: widget.deviceTarget,
                ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Repair desktop'),
        ),
      );
    } else if (running) {
      content = _ComputerEmptyState(
        icon: Icons.desktop_windows_rounded,
        title: 'Your desktop is ready',
        message:
            'Chromium, files, the text editor and terminal are all available from the Linux desktop.',
        action: FilledButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.openComputerDisplayRuntime(
                  deviceTarget: widget.deviceTarget,
                ),
          icon: const Icon(Icons.desktop_windows_rounded),
          label: const Text('View desktop'),
        ),
      );
    } else if (busy) {
      content = _ComputerEmptyState(
        icon: Icons.cloud_sync_rounded,
        title: firstSetup
            ? 'Preparing your computer'
            : 'Starting your computer',
        message: firstSetup
            ? 'NeoAgent is downloading and preparing the secure Linux system. This only happens the first time.'
            : 'Opening your saved desktop. Normal starts take less than 10 seconds.',
        action: const SizedBox(width: 220, child: LinearProgressIndicator()),
      );
    } else if (state == 'capacity_wait') {
      content = _ComputerEmptyState(
        icon: Icons.hourglass_top_rounded,
        title: 'All computer slots are busy',
        message:
            'No cloud-computer slot is free right now. Try again in a moment.',
        action: FilledButton.icon(
          onPressed: () => controller.startComputerRuntime(
            deviceTarget: widget.deviceTarget,
          ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    } else if (state == 'error') {
      final storageError = errorCode == 'COMPUTER_STORAGE_CAPACITY';
      final lastError =
          runtime['lastError']?.toString().trim() ?? '';
      content = _ComputerEmptyState(
        icon: storageError ? Icons.storage_rounded : Icons.cloud_off_rounded,
        title: storageError
            ? 'More free space is needed'
            : 'The computer could not start',
        message: lastError.isNotEmpty
            ? lastError
            : storageError
            ? 'Free some disk space on the NeoAgent host, then try again. Your existing computer data is safe.'
            : 'Try again. If this keeps happening, run NeoAgent Doctor to check the computer runtime.',
        action: FilledButton.icon(
          onPressed: () => controller.startComputerRuntime(
            deviceTarget: widget.deviceTarget,
          ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    } else {
      content = _ComputerEmptyState(
        icon: Icons.computer_rounded,
        title: state == 'sleeping'
            ? 'Your computer is asleep'
            : 'Your Linux computer',
        message:
            'A private desktop with Chromium, files, a text editor, terminal and Python. Your work stays saved between sessions.',
        action: FilledButton.icon(
          onPressed: () => controller.startComputerRuntime(
            deviceTarget: widget.deviceTarget,
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(state == 'sleeping' ? 'Wake computer' : 'Start computer'),
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
                        ? 'Android ready'
                        : starting
                        ? startupPhase.isEmpty
                              ? 'Starting Android…'
                              : startupPhase
                        : startError.isEmpty
                        ? 'Android stopped'
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
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: controller.isRunningDeviceAction
                        ? null
                        : controller.stopAndroidRuntime,
                    child: const Text('Stop'),
                  ),
                ] else if (starting)
                  TextButton(
                    onPressed: controller.isRunningDeviceAction
                        ? null
                        : controller.stopAndroidRuntime,
                    child: const Text('Cancel'),
                  )
                else
                  FilledButton.icon(
                    onPressed: controller.isRunningDeviceAction
                        ? null
                        : controller.startAndroidRuntime,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Android'),
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
                decoration: const InputDecoration(
                  labelText: 'Package name',
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
              child: const Text('Open'),
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
                    title: 'Starting Android',
                    message: startupPhase.isEmpty
                        ? 'The first start downloads the Android SDK and system image, which can take several minutes.'
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
                        ? 'Android is stopped'
                        : 'Android could not start',
                    message: startError.isEmpty
                        ? 'Start the managed Android environment when you need it.'
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
    final packageName = _androidAppController.text.trim();
    if (packageName.isEmpty) return;
    await widget.controller.openAndroidAppRuntime(packageName: packageName);
    await widget.controller.screenshotAndroidRuntime();
  }
}

/// Live Android frame with touch input.
///
/// Frames are polled, so the previously decoded bytes stay on screen until the
/// next frame has loaded — rebuilding a loading spinner between frames made the
/// surface flicker on every poll.
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
        return const _ComputerEmptyState(
          icon: Icons.broken_image_outlined,
          title: 'Frame unavailable',
          message: 'Refresh the Android screen to try again.',
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          button: true,
          label: 'Android screen — tap to touch, drag to swipe',
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

  static const List<({String key, IconData icon, String label})> _keys =
      <({String key, IconData icon, String label})>[
        (key: 'back', icon: Icons.arrow_back_rounded, label: 'Back'),
        (key: 'home', icon: Icons.circle_outlined, label: 'Home'),
        (key: 'app_switch', icon: Icons.crop_square_rounded, label: 'Recents'),
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
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      blurSigma: 16,
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
          _GlassSurface(
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
                      ? 'Let NeoAgent work on this computer'
                      : 'Available in the desktop app for macOS, Windows and Linux',
                  child: Opacity(
                    opacity: localSupported ? 1 : 0.45,
                    child: _DeviceSurfacePill(
                      selected: provider == 'local',
                      icon: Icons.laptop_rounded,
                      label: 'This device',
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
            icon: const Icon(Icons.school_outlined, size: 18),
            label: const Text('Teach'),
          ),
        if (onInterrupt != null)
          FilledButton.icon(
            key: const ValueKey<String>('computer-interrupt-ai'),
            onPressed: busy ? null : onInterrupt,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            icon: const Icon(Icons.front_hand_rounded, size: 18),
            label: const Text('Interrupt AI'),
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
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(state == 'sleeping' ? 'Wake' : 'Start'),
          ),
        if (onStop != null)
          IconButton(
            tooltip: 'Turn off computer',
            onPressed: busy ? null : onStop,
            icon: const Icon(Icons.power_settings_new_rounded),
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
      title: 'Starting your computer',
      subtitle: 'This may take a moment.',
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
            ? 'Preparing your computer'
            : 'Starting your computer',
        subtitle: firstSetup
            ? 'First-time setup is in progress.'
            : 'Opening your saved desktop.',
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
          title: 'Desktop failed to start',
          subtitle:
              desktop['error']?.toString().ifEmpty(
                'The Linux graphical session is not running.',
              ) ??
              'The Linux graphical session is not running.',
          icon: Icons.desktop_access_disabled_rounded,
          color: theme.colorScheme.error,
        );
      }
      if (state == 'agent_control') {
        return (
          title: 'NeoAgent is working',
          subtitle: 'You can follow along on the desktop.',
          icon: Icons.auto_awesome_rounded,
          color: theme.colorScheme.primary,
        );
      }
      if (state == 'user_control') {
        return (
          title: 'You are in control',
          subtitle: 'NeoAgent is waiting while you use the desktop.',
          icon: Icons.touch_app_rounded,
          color: Colors.green,
        );
      }
      return (
        title: local ? 'This device is ready' : 'Your computer is ready',
        subtitle: local
            ? 'NeoAgent can use the access you allow.'
            : 'Everything is available from the desktop.',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      );
    case 'teaching':
      return (
        title: 'Teaching in progress',
        subtitle: 'Complete the workflow on the desktop.',
        icon: Icons.fiber_manual_record_rounded,
        color: Colors.red,
      );
    case 'sleeping':
      return (
        title: 'Your computer is asleep',
        subtitle: 'Your apps and files are saved.',
        icon: Icons.bedtime_rounded,
        color: Colors.amber,
      );
    case 'capacity_wait':
      return (
        title: 'All computer slots are busy',
        subtitle: 'Try again in a moment.',
        icon: Icons.hourglass_top_rounded,
        color: Colors.amber,
      );
    case 'error':
      final storage = runtime['errorCode'] == 'COMPUTER_STORAGE_CAPACITY';
      return (
        title: storage ? 'More free space is needed' : 'Could not start',
        subtitle: storage
            ? 'Free some host storage and try again.'
            : 'Try again or run NeoAgent Doctor.',
        icon: storage ? Icons.storage_rounded : Icons.error_outline_rounded,
        color: theme.colorScheme.error,
      );
    default:
      return (
        title: local ? 'This device is paused' : 'Your computer is off',
        subtitle: local
            ? 'Start when you want NeoAgent to help here.'
            : 'Your apps and files remain saved.',
        icon: local ? Icons.laptop_rounded : Icons.computer_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      );
  }
}

class _LocalComputerPermissionPanel extends StatelessWidget {
  const _LocalComputerPermissionPanel({required this.controller});

  final NeoAgentController controller;

  static const Map<String, ({IconData icon, String label, String detail})>
  _definitions = <String, ({IconData icon, String label, String detail})>{
    'screen': (
      icon: Icons.visibility_rounded,
      label: 'Screen',
      detail: 'Let NeoAgent understand what is visible on your screen.',
    ),
    'input': (
      icon: Icons.touch_app_rounded,
      label: 'Mouse & keyboard',
      detail: 'Let NeoAgent click, type and move through your apps.',
    ),
    'files': (
      icon: Icons.folder_open_rounded,
      label: 'Workspace files',
      detail: 'Read and edit files inside your NeoAgent Workspace folder.',
    ),
    'shell': (
      icon: Icons.terminal_rounded,
      label: 'Commands & apps',
      detail: 'Run terminal commands and open apps or web pages.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = controller.localComputerPendingPermission;
    final permissions = controller.localComputerPermissions;
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
                      '${request.label} access needed',
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
                          child: const Text('Allow once'),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              controller.grantLocalComputerPermission(
                                pending,
                                remember: true,
                              ),
                          child: const Text('Always allow'),
                        ),
                        TextButton(
                          onPressed: () =>
                              controller.denyLocalComputerPermission(pending),
                          child: const Text('Not now'),
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
        title: const Text('Access permissions'),
        subtitle: Text(
          controller.localComputerConnecting
              ? 'Connecting…'
              : controller.localComputerConnected
              ? '${permissions.length} of 4 allowed'
              : 'Reconnecting this device…',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        children: <Widget>[
          Align(alignment: Alignment.centerLeft, child: permissionControls),
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
                icon: const Icon(Icons.settings_rounded),
                label: const Text('System privacy settings'),
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
              ? 'Connecting this device'
              : 'Keeping this device connected',
          message: connecting
              ? 'The secure local connection is being established.'
              : 'NeoAgent uses this computer automatically and asks before it uses your screen, mouse, keyboard, files or command line.',
          action: const SizedBox(width: 220, child: LinearProgressIndicator()),
        ),
      );
    }
    final permissions = controller.localComputerPermissions;
    return _ComputerSurface(
      child: _ComputerEmptyState(
        icon: Icons.desktop_windows_rounded,
        title: 'This desktop is connected',
        message:
            'Keep using your apps normally. NeoAgent works on the same screen and asks whenever it needs new access.\n\n'
            '${permissions.length} of 4 permissions allowed. Files are limited to your NeoAgent Workspace folder.',
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
                              ? 'Recording your demonstration'
                              : 'Creating your skill…',
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
                              ? '$elapsedLabel · Work through the task as you normally would.'
                              : 'NeoAgent is turning your demonstration into an adaptable workflow.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onStop != null)
                    FilledButton.icon(
                      onPressed: onStop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Finish'),
                    ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                ],
              )
            : Row(
                children: <Widget>[
                  const Icon(Icons.school_rounded),
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
                      decoration: const InputDecoration(
                        labelText: 'What should NeoAgent learn?',
                        hintText:
                            'Describe the outcome, then demonstrate it on the desktop',
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
                    icon: const Icon(Icons.fiber_manual_record_rounded),
                    label: const Text('Teach'),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: 'Close Teach Mode',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
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
    return Center(
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
    );
  }
}
