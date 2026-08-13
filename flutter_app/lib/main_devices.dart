part of 'main.dart';

enum _DeviceTab { computer, android }

enum _ComputerTool { desktop, files, terminal }

class DevicesPanel extends StatefulWidget {
  const DevicesPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<DevicesPanel> createState() => _DevicesPanelState();
}

class _DevicesPanelState extends State<DevicesPanel> {
  final TextEditingController _teachGoalController = TextEditingController();
  final TextEditingController _terminalController = TextEditingController();
  final TextEditingController _workspaceEditorController =
      TextEditingController();
  final TextEditingController _androidAppController = TextEditingController(
    text: _androidLaunchPlaceholder,
  );
  _DeviceTab _device = _DeviceTab.computer;
  _ComputerTool _computerTool = _ComputerTool.desktop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.refreshDevices());
    });
  }

  @override
  void dispose() {
    _teachGoalController.dispose();
    _terminalController.dispose();
    _workspaceEditorController.dispose();
    _androidAppController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: _device.index,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Devices', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        'One persistent computer for browser, apps, files and terminal.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: widget.controller.isRefreshingDevices
                      ? null
                      : () => widget.controller.refreshDevices(),
                  icon: widget.controller.isRefreshingDevices
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                onTap: (index) =>
                    setState(() => _device = _DeviceTab.values[index]),
                tabs: const <Tab>[
                  Tab(icon: Icon(Icons.computer_rounded), text: 'Computer'),
                  Tab(icon: Icon(Icons.android_rounded), text: 'Android'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _device == _DeviceTab.computer
                  ? _buildComputer(context)
                  : _buildAndroid(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComputer(BuildContext context) {
    final controller = widget.controller;
    final local = controller.computerProvider == 'local';
    final state = controller.computerRuntime['state']?.toString() ?? 'stopped';
    final running = <String>{
      'ready',
      'agent_control',
      'user_control',
      'teaching',
      'sleeping',
    }.contains(state);
    final starting = state == 'starting' || controller.isRunningDeviceAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ComputerProviderPicker(
          provider: controller.computerProvider,
          localSupported: controller.localComputerSupported,
          busy: controller.isRunningDeviceAction,
          onChanged: controller.selectComputerProvider,
        ),
        const SizedBox(height: 12),
        if (local) ...<Widget>[
          _LocalComputerPermissionPanel(controller: controller),
          const SizedBox(height: 12),
        ],
        _ComputerStatusBar(
          state: state,
          runtime: controller.computerRuntime,
          busy: controller.isRunningDeviceAction,
          onStart: running || starting ? null : controller.startComputerRuntime,
          onOpen: running ? controller.openComputerDisplayRuntime : null,
          onStop: running ? controller.stopComputerRuntime : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            _ToolButton(
              selected: _computerTool == _ComputerTool.desktop,
              icon: Icons.desktop_windows_rounded,
              label: 'Desktop',
              onPressed: () =>
                  setState(() => _computerTool = _ComputerTool.desktop),
            ),
            const SizedBox(width: 8),
            _ToolButton(
              selected: _computerTool == _ComputerTool.files,
              icon: Icons.folder_open_rounded,
              label: 'Files',
              onPressed: running
                  ? () {
                      setState(() => _computerTool = _ComputerTool.files);
                      unawaited(controller.refreshWorkspaceFiles());
                    }
                  : null,
            ),
            const SizedBox(width: 8),
            _ToolButton(
              selected: _computerTool == _ComputerTool.terminal,
              icon: Icons.terminal_rounded,
              label: 'Terminal',
              onPressed: running
                  ? () => setState(() => _computerTool = _ComputerTool.terminal)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_computerTool) {
            _ComputerTool.desktop => _buildDesktop(context, running),
            _ComputerTool.files => _buildFiles(context, running),
            _ComputerTool.terminal => _buildTerminal(context, running),
          },
        ),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context, bool running) {
    final controller = widget.controller;
    if (controller.computerProvider == 'local') {
      return _LocalComputerDesktop(controller: controller, running: running);
    }
    final displayUrl = controller.computerDisplayUrl;
    final teachStatus = controller.teachRuntime['status']?.toString() ?? 'idle';
    final teaching =
        teachStatus == 'recording' || teachStatus == 'synthesizing';

    return Column(
      children: <Widget>[
        _TeachBar(
          controller: _teachGoalController,
          status: teachStatus,
          runtime: controller.teachRuntime,
          enabled: running && !controller.isRunningDeviceAction,
          onGoalChanged: (_) => setState(() {}),
          onStart: () =>
              controller.startTeachRuntime(_teachGoalController.text),
          onStop: teaching && teachStatus == 'recording'
              ? controller.stopTeachRuntime
              : null,
          onCancel: teaching ? controller.cancelTeachRuntime : null,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: Colors.black,
              child: !running
                  ? const _ComputerEmptyState(
                      icon: Icons.computer_rounded,
                      title: 'Computer is stopped',
                      message:
                          'Start it to open the persistent lightweight Linux desktop.',
                    )
                  : displayUrl == null
                  ? _ComputerEmptyState(
                      icon: Icons.desktop_windows_rounded,
                      title: 'Desktop is ready',
                      message:
                          'Open the display to interact with Linux, Chromium and apps.',
                      action: FilledButton.icon(
                        onPressed: controller.isRunningDeviceAction
                            ? null
                            : controller.openComputerDisplayRuntime,
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('Open display'),
                      ),
                    )
                  : ComputerDisplay(
                      key: ValueKey<String>(displayUrl),
                      url: displayUrl,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiles(BuildContext context, bool running) {
    if (!running) {
      return const _ComputerEmptyState(
        icon: Icons.folder_off_outlined,
        title: 'Computer is stopped',
        message: 'Files live on the persistent computer data disk.',
      );
    }
    final controller = widget.controller;
    final selectedPath = controller.workspaceSelectedFilePath;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        final explorer = _WorkspaceBrowser(
          controller: controller,
          onOpenFile: (path) async {
            await controller.openWorkspaceFile(path);
            if (!mounted) return;
            _workspaceEditorController.text = controller.workspaceEditorContent;
            setState(() {});
          },
        );
        final editor = _WorkspaceEditor(
          path: selectedPath,
          controller: _workspaceEditorController,
          saving: controller.isSavingWorkspaceFile,
          onSave: selectedPath == null
              ? null
              : () => controller.saveWorkspaceFile(
                  _workspaceEditorController.text,
                ),
          onDownload: selectedPath == null
              ? null
              : () => controller.downloadWorkspaceFile(selectedPath),
        );
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: stacked
              ? Column(
                  children: <Widget>[
                    SizedBox(height: 220, child: explorer),
                    const Divider(height: 1),
                    Expanded(child: editor),
                  ],
                )
              : Row(
                  children: <Widget>[
                    SizedBox(width: 300, child: explorer),
                    const VerticalDivider(width: 1),
                    Expanded(child: editor),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTerminal(BuildContext context, bool running) {
    if (!running) {
      return const _ComputerEmptyState(
        icon: Icons.terminal_rounded,
        title: 'Computer is stopped',
        message: 'Start it to use the shell in the same persistent filesystem.',
      );
    }
    final controller = widget.controller;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF101418),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.terminal_rounded, color: Color(0xFF9DE2B2)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '/home/neo/workspace',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton.icon(
                  onPressed: controller.isRunningDeviceAction
                      ? null
                      : () => controller.launchComputerAppRuntime('terminal'),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open app'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  controller.computerTerminalOutput.isEmpty
                      ? 'NeoAgent Linux shell ready.\n'
                            'Python, pip, venv, git, curl, jq and standard Unix tools are available.'
                      : controller.computerTerminalOutput,
                  style: const TextStyle(
                    color: Color(0xFFD6E2E8),
                    fontFamily: 'monospace',
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _terminalController,
              enabled: !controller.isRunningDeviceAction,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                prefixText: r'$ ',
                prefixStyle: const TextStyle(color: Color(0xFF9DE2B2)),
                hintText: 'Enter a command',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A2026),
                suffixIcon: IconButton(
                  tooltip: 'Run',
                  onPressed: controller.isRunningDeviceAction
                      ? null
                      : () => _runTerminalCommand(),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              onSubmitted: (_) => _runTerminalCommand(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTerminalCommand() async {
    final command = _terminalController.text;
    if (command.trim().isEmpty) return;
    await widget.controller.executeComputerCommandRuntime(command);
    if (mounted) _terminalController.clear();
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

class _ComputerStatusBar extends StatelessWidget {
  const _ComputerStatusBar({
    required this.state,
    required this.runtime,
    required this.busy,
    required this.onStart,
    required this.onOpen,
    required this.onStop,
  });

  final String state;
  final Map<String, dynamic> runtime;
  final bool busy;
  final VoidCallback? onStart;
  final VoidCallback? onOpen;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resources = runtime['resources'] is Map
        ? Map<String, dynamic>.from(runtime['resources'] as Map)
        : const <String, dynamic>{};
    final statusColor = switch (state) {
      'ready' || 'user_control' || 'agent_control' => Colors.green,
      'teaching' => Colors.orange,
      'starting' || 'capacity_wait' || 'sleeping' => Colors.amber,
      'error' => theme.colorScheme.error,
      _ => Colors.grey,
    };
    final label = state.replaceAll('_', ' ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(Icons.circle, size: 12, color: statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label.isEmpty
                        ? 'Stopped'
                        : '${label[0].toUpperCase()}${label.substring(1)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (resources.isNotEmpty)
                    Text(
                      '${resources['memoryMb'] ?? '—'} MiB · ${resources['cpus'] ?? '—'} vCPU · ${runtime['accelerator'] ?? 'QEMU'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (runtime['provider'] == 'local')
                    Text(
                      runtime['device'] is Map
                          ? '${(runtime['device'] as Map)['label'] ?? 'This device'} · local session'
                          : 'Waiting for the NeoAgent desktop app',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (onOpen != null)
              OutlinedButton.icon(
                onPressed: busy ? null : onOpen,
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Display'),
              ),
            if (onOpen != null) const SizedBox(width: 8),
            if (onStart != null)
              FilledButton.icon(
                onPressed: busy ? null : onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start'),
              ),
            if (onStop != null)
              IconButton(
                tooltip: 'Stop computer',
                onPressed: busy ? null : onStop,
                icon: const Icon(Icons.stop_circle_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComputerProviderPicker extends StatelessWidget {
  const _ComputerProviderPicker({
    required this.provider,
    required this.localSupported,
    required this.busy,
    required this.onChanged,
  });

  final String provider;
  final bool localSupported;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(
              provider == 'local'
                  ? Icons.laptop_mac_rounded
                  : Icons.cloud_rounded,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Where should NeoAgent work?',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    provider == 'local'
                        ? 'Commands, files and screen control stay on this signed-in desktop.'
                        : 'A private persistent Linux computer with an isolated desktop.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                const ButtonSegment<String>(
                  value: 'cloud',
                  icon: Icon(Icons.cloud_rounded),
                  label: Text('Cloud'),
                ),
                ButtonSegment<String>(
                  value: 'local',
                  enabled: localSupported,
                  icon: const Icon(Icons.laptop_rounded),
                  label: const Text('This device'),
                  tooltip: localSupported
                      ? 'Use this desktop'
                      : 'Available in the macOS, Windows and Linux desktop app',
                ),
              ],
              selected: <String>{provider},
              onSelectionChanged: busy
                  ? null
                  : (selection) => onChanged(selection.first),
            ),
          ],
        ),
      ),
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
      label: 'See screen',
      detail: 'Screenshots and visual desktop context',
    ),
    'input': (
      icon: Icons.touch_app_rounded,
      label: 'Control input',
      detail: 'Mouse and keyboard actions',
    ),
    'files': (
      icon: Icons.folder_open_rounded,
      label: 'Files',
      detail: 'NeoAgent Workspace in your home folder',
    ),
    'shell': (
      icon: Icons.terminal_rounded,
      label: 'CLI and apps',
      detail: 'Run commands and open apps or URLs',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = controller.localComputerPendingPermission;
    final permissions = controller.localComputerPermissions;
    return Card(
      margin: EdgeInsets.zero,
      color: pending == null ? null : theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  controller.localComputerConnected
                      ? Icons.verified_user_rounded
                      : Icons.link_off_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.localComputerConnecting
                        ? 'Connecting this device…'
                        : controller.localComputerConnected
                        ? 'This device is connected'
                        : 'Waiting for the local control connection',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (controller.localComputerConnecting)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (controller.localComputerError?.isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                controller.localComputerError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (pending != null &&
                _definitions.containsKey(pending)) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'NeoAgent requests ${_definitions[pending]!.label.toLowerCase()} access',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton(
                    onPressed: () => controller.grantLocalComputerPermission(
                      pending,
                      remember: false,
                    ),
                    child: const Text('Allow for this session'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => controller.grantLocalComputerPermission(
                      pending,
                      remember: true,
                    ),
                    child: const Text('Always allow'),
                  ),
                  TextButton(
                    onPressed: () =>
                        controller.denyLocalComputerPermission(pending),
                    child: const Text('Deny'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _definitions.entries
                  .map((entry) {
                    final granted = permissions.contains(entry.key);
                    return ActionChip(
                      avatar: Icon(entry.value.icon, size: 18),
                      label: Text(
                        '${entry.value.label} · ${granted ? 'allowed' : 'ask'}',
                      ),
                      tooltip: entry.value.detail,
                      onPressed: granted
                          ? () => controller.revokeLocalComputerPermission(
                              entry.key,
                            )
                          : () => controller.grantLocalComputerPermission(
                              entry.key,
                              remember: true,
                            ),
                    );
                  })
                  .toList(growable: false),
            ),
            if (permissions.contains('screen') ||
                permissions.contains('input')) ...<Widget>[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => controller.openLocalComputerSystemPermission(
                    permissions.contains('screen') ? 'screen' : 'input',
                  ),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open system privacy settings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocalComputerDesktop extends StatelessWidget {
  const _LocalComputerDesktop({
    required this.controller,
    required this.running,
  });

  final NeoAgentController controller;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (!running) {
      return const _ComputerEmptyState(
        icon: Icons.laptop_rounded,
        title: 'This device is paused',
        message:
            'Start it when you want NeoAgent to work with your local apps, files and command line.',
      );
    }
    final permissions = controller.localComputerPermissions;
    return _ComputerEmptyState(
      icon: Icons.desktop_windows_rounded,
      title: 'NeoAgent can work on this desktop',
      message:
          'Switch to any app normally. NeoAgent uses the same Computer tools and agent loop, while every sensitive capability remains under your control.\n\n'
          '${permissions.length}/4 capabilities allowed · Local files stay in “NeoAgent Workspace”.',
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
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
  });

  final TextEditingController controller;
  final String status;
  final Map<String, dynamic> runtime;
  final bool enabled;
  final ValueChanged<String> onGoalChanged;
  final VoidCallback onStart;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;

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
    final timeline = _jsonMapList(runtime['timeline']);
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
                              ? 'Teach Mode recording'
                              : 'Creating adaptive skill…',
                        ),
                        if (goal.isNotEmpty)
                          Text(
                            goal,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '$elapsedLabel · ${runtime['eventCount'] ?? 0} events · ${runtime['screenshotCount'] ?? 0} semantic frames',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (timeline.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: timeline
                                  .map((event) {
                                    final atSeconds =
                                        (event['atMs'] as num? ?? 0) ~/ 1000;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Text(
                                        '${event['type'] ?? 'event'} +${atSeconds}s',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    );
                                  })
                                  .toList(growable: false),
                            ),
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

class _WorkspaceBrowser extends StatelessWidget {
  const _WorkspaceBrowser({required this.controller, required this.onOpenFile});

  final NeoAgentController controller;
  final Future<void> Function(String path) onOpenFile;

  @override
  Widget build(BuildContext context) {
    final entries = controller.workspaceEntries;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              if (controller.workspaceCurrentPath.isNotEmpty)
                IconButton(
                  tooltip: 'Up',
                  onPressed: () {
                    final parts = controller.workspaceCurrentPath.split('/')
                      ..removeLast();
                    controller.openWorkspaceDirectory(parts.join('/'));
                  },
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              Expanded(
                child: Text(
                  controller.workspaceCurrentPath.isEmpty
                      ? 'Workspace'
                      : controller.workspaceCurrentPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Refresh files',
                onPressed: controller.isLoadingWorkspaceFiles
                    ? null
                    : () => controller.refreshWorkspaceFiles(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: controller.isLoadingWorkspaceFiles && entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
              ? const Center(child: Text('This folder is empty.'))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final directory = entry['type']?.toString() == 'directory';
                    final path = entry['path']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      selected: path == controller.workspaceSelectedFilePath,
                      leading: Icon(
                        directory
                            ? Icons.folder_rounded
                            : Icons.description_outlined,
                      ),
                      title: Text(entry['name']?.toString() ?? path),
                      onTap: path.isEmpty
                          ? null
                          : directory
                          ? () => controller.openWorkspaceDirectory(path)
                          : () => onOpenFile(path),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _WorkspaceEditor extends StatelessWidget {
  const _WorkspaceEditor({
    required this.path,
    required this.controller,
    required this.saving,
    required this.onSave,
    required this.onDownload,
  });

  final String? path;
  final TextEditingController controller;
  final bool saving;
  final VoidCallback? onSave;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return const _ComputerEmptyState(
        icon: Icons.edit_document,
        title: 'Select a file',
        message:
            'Text files can be inspected and edited here or in Mousepad on the desktop.',
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  path!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Download',
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TextField(
            controller: controller,
            expands: true,
            minLines: null,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }
}
