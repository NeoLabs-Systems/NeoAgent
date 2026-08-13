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
  }

  @override
  void dispose() {
    _teachGoalController.dispose();
    _androidAppController.dispose();
    super.dispose();
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
    final state = controller.computerRuntime['state']?.toString() ?? 'stopped';
    final running = <String>{
      'ready',
      'agent_control',
      'user_control',
      'teaching',
    }.contains(state);
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
          runtime: controller.computerRuntime,
          busy: controller.isRunningDeviceAction,
          onProviderChanged: controller.selectComputerProvider,
          onStart: running || starting
              ? null
              : () => controller.startComputerRuntime(
                  deviceTarget: widget.deviceTarget,
                ),
          onStop: running
              ? () => controller.stopComputerRuntime(
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
          child: _buildDesktop(
            context,
            running: running,
            state: starting && !running ? 'starting' : state,
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
        onStart: controller.isRunningDeviceAction
            ? null
            : () => controller.startComputerRuntime(
                deviceTarget: widget.deviceTarget,
              ),
      );
    }
    final theme = Theme.of(context);
    final displayUrl = controller.computerDisplayUrl;
    final readiness = _jsonMap(controller.computerRuntime['readiness']);
    final firstSetup = readiness['imageReady'] != true;
    final busy = state == 'starting' || controller.isRunningDeviceAction;
    final errorCode = controller.computerRuntime['errorCode']?.toString() ?? '';

    if (running && displayUrl != null) {
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
    if (running) {
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
          label: const Text('Connect desktop'),
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
      content = _ComputerEmptyState(
        icon: storageError ? Icons.storage_rounded : Icons.cloud_off_rounded,
        title: storageError
            ? 'More free space is needed'
            : 'The computer could not start',
        message: storageError
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
                Icon(
                  Icons.circle,
                  size: 12,
                  color: online ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(online ? 'Android ready' : 'Android stopped'),
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
                ] else
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
            child: !online
                ? const _ComputerEmptyState(
                    icon: Icons.android_rounded,
                    title: 'Android is stopped',
                    message:
                        'Start the managed Android environment when you need it.',
                  )
                : screenshotPath == null
                ? _ComputerEmptyState(
                    icon: Icons.phone_android_rounded,
                    title: 'Android is ready',
                    message: 'Refresh to fetch the current device frame.',
                    action: FilledButton(
                      onPressed: controller.screenshotAndroidRuntime,
                      child: const Text('Show screen'),
                    ),
                  )
                : FutureBuilder<Uint8List>(
                    key: ValueKey<String>(screenshotPath),
                    future: controller.fetchRuntimeAssetBytes(screenshotPath),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return InteractiveViewer(
                          child: Center(
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const _ComputerEmptyState(
                          icon: Icons.broken_image_outlined,
                          title: 'Frame unavailable',
                          message: 'Refresh the Android screen to try again.',
                        );
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
          ),
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

class _DeviceSurfaceSwitch extends StatelessWidget {
  const _DeviceSurfaceSwitch({
    required this.value,
    required this.onChanged,
  });

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
      final firstSetup = !local && readiness['imageReady'] != true;
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
      return (
        title: local ? 'This device is ready' : 'Your computer is ready',
        subtitle: local
            ? 'NeoAgent can use the access you allow.'
            : 'Everything is available from the desktop.',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      );
    case 'agent_control':
      return (
        title: 'NeoAgent is working',
        subtitle: 'You can follow along on the desktop.',
        icon: Icons.auto_awesome_rounded,
        color: theme.colorScheme.primary,
      );
    case 'user_control':
      return (
        title: 'You are in control',
        subtitle: 'NeoAgent is waiting while you use the desktop.',
        icon: Icons.touch_app_rounded,
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
              : 'Waiting for this device to connect',
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

class _LocalComputerDesktop extends StatelessWidget {
  const _LocalComputerDesktop({
    required this.controller,
    required this.running,
    required this.state,
    required this.onStart,
  });

  final NeoAgentController controller;
  final bool running;
  final String state;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    if (!running) {
      return _ComputerSurface(
        child: _ComputerEmptyState(
          icon: state == 'starting' ? Icons.sync_rounded : Icons.laptop_rounded,
          title: state == 'starting'
              ? 'Connecting this device'
              : 'Use this computer with NeoAgent',
          message: state == 'starting'
              ? 'The secure local connection is being established.'
              : 'NeoAgent will ask before it uses your screen, mouse, keyboard, files or command line.',
          action: state == 'starting'
              ? const SizedBox(width: 220, child: LinearProgressIndicator())
              : FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Connect this device'),
                ),
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
