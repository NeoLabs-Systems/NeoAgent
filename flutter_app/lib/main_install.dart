part of 'main.dart';

class ServerPanel extends StatefulWidget {
  const ServerPanel({super.key, required this.controller, this.runtimeManager});

  final NeoAgentController controller;
  final LocalRuntimeManager? runtimeManager;

  @override
  State<ServerPanel> createState() => _ServerPanelState();
}

class _ServerPanelState extends State<ServerPanel> {
  late final LocalRuntimeManager _runtimeManager;
  late final LocalBackendInstaller _installer;
  StreamSubscription<LocalBackendInstallEvent>? _eventSubscription;
  final List<LocalBackendInstallEvent> _events = <LocalBackendInstallEvent>[];
  LocalRuntimeStatus? _status;
  LocalBackendInstallEvent? _currentEvent;
  LocalBackendInstallResult? _installResult;
  LocalBackendSetupProfile _profile = LocalBackendSetupProfile.quick;
  String _channel = runtimeReleaseChannel;
  bool _checking = true;
  bool _installing = false;
  bool _actionRunning = false;
  bool _showDetails = false;
  bool _viewingLogs = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runtimeManager = widget.runtimeManager ?? LocalRuntimeManager();
    _installer = LocalBackendInstaller();
    _eventSubscription = _installer.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _currentEvent = event;
        _events.add(event);
      });
    });
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _installer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _checking = true);
    final status = await _runtimeManager.inspect();
    if (!mounted) return;
    setState(() {
      _status = status;
      _channel = status.releaseChannel ?? _channel;
      _checking = false;
    });
  }

  Future<void> _installOrRepair() async {
    setState(() {
      _installing = true;
      _errorMessage = null;
      _installResult = null;
      _currentEvent = null;
      _events.clear();
    });
    try {
      final result = await _installer.install(_profile, channel: _channel);
      if (!mounted) return;
      setState(() => _installResult = result);
      await _refresh();
    } on LocalBackendInstallerException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '${error.message} (${error.code})');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _runAction(LocalRuntimeAction action) async {
    setState(() {
      _actionRunning = true;
      _errorMessage = null;
    });
    try {
      final status = await _runtimeManager.runAction(action);
      if (!mounted) return;
      setState(() => _status = status);
    } on LocalRuntimeManagerException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = '${error.message} (${error.code})');
    } finally {
      if (mounted) setState(() => _actionRunning = false);
    }
  }

  Future<void> _showLocalLogs() async {
    setState(() {
      _viewingLogs = true;
      _errorMessage = null;
    });
    List<LocalRuntimeLogFile> logs;
    try {
      logs = await _runtimeManager.readRecentLogs();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = formatCaughtError(error);
        _viewingLogs = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _viewingLogs = false);

    // One field, so the whole thing can be selected, scrolled and pasted into a
    // bug report in a single go.
    final logText = logs.isEmpty
        ? 'The local runtime has not written a log file yet.'
        : logs
              .map(
                (log) =>
                    '=== ${log.path} ===\n'
                    '${log.content.isEmpty ? '(empty)' : log.content}',
              )
              .join('\n\n');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logs on this computer'),
        content: SizedBox(
          width: 760,
          height: 460,
          child: _LogView(text: logText),
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: logText));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(const SnackBar(content: Text('Logs copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy all'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocalDashboard() async {
    final rawUrl = _installResult?.backendUrl ?? _status?.backendUrl;
    final uri = Uri.tryParse(rawUrl ?? '');
    if (uri == null) return;
    await url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
  }

  Future<void> _useLocalServer() async {
    final result = _installResult;
    final backendUrl = result?.backendUrl ?? _status?.backendUrl;
    if (backendUrl == null || backendUrl.isEmpty) return;
    await widget.controller.saveBackendUrl(
      backendUrl,
      setupClaimToken: result?.claimToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        const _PageTitle(
          title: 'Server',
          subtitle:
              'See which NeoAgent server this window uses, and run the backend on this computer.',
        ),
        const SizedBox(height: 18),
        _connectionCard(),
        if (_supportsDesktopShell) ...<Widget>[
          const SizedBox(height: 16),
          _localRuntimeCard(),
          if (_showsAppUpdates) ...<Widget>[
            const SizedBox(height: 16),
            _appUpdateCard(),
          ],
        ],
      ],
    );
  }

  /// Whether this window is pointed at the runtime installed on this computer.
  ///
  /// Everything that reaches the local machine — the app updater and the local
  /// log reader — hangs off this. The status comes from the local runtime CLI
  /// and the comparison accepts loopback addresses only, so selecting a remote
  /// NeoAgent server can never turn these on.
  bool get _managesLocalBackend =>
      _supportsDesktopShell &&
      _status?.installed == true &&
      widget.controller.isLocalRuntimeBackend(_status?.backendUrl);

  bool get _showsAppUpdates =>
      _managesLocalBackend && widget.controller.appUpdaterConfigured;

  /// An update that activated a new runtime while the old process kept the
  /// port: the panel would otherwise show the installed version and imply the
  /// update is live.
  bool get _staleRuntimeProcess {
    final running = _status?.runningVersion;
    final installed = _status?.version;
    return running != null && installed != null && running != installed;
  }

  String? get _localBackendUrl =>
      _installResult?.backendUrl ?? _status?.backendUrl;

  Widget _cardTitle(String title, {Widget? trailing}) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _channelPicker({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment<String>(
          value: 'stable',
          label: Text('Stable'),
          icon: Icon(Icons.verified_outlined),
        ),
        ButtonSegment<String>(
          value: 'beta',
          label: Text('Beta'),
          icon: Icon(Icons.science_outlined),
        ),
      ],
      selected: <String>{value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }

  Widget _connectionCard() {
    final localUrl = _localBackendUrl;
    final usesLocalBackend = _managesLocalBackend;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cardTitle(
              'Connected server',
              trailing: _supportsDesktopShell
                  ? _StatusPill(
                      label: usesLocalBackend ? 'This computer' : 'Remote',
                      color: usesLocalBackend ? _success : _accentAlt,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              widget.controller.backendUrl,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            if (_supportsDesktopShell &&
                localUrl != null &&
                !usesLocalBackend) ...<Widget>[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _useLocalServer,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Use the server on this computer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _localRuntimeCard() {
    final status = _status;
    final installed = status?.installed == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cardTitle(
              'Backend on this computer',
              trailing: _checking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _StatusPill(
                      label: status?.running == true
                          ? 'Running'
                          : status?.errorCode != null
                          ? 'Needs attention'
                          : installed
                          ? 'Stopped'
                          : 'Not installed',
                      color: status?.running == true
                          ? _success
                          : status?.errorCode != null
                          ? _warning
                          : _textMuted,
                    ),
            ),
            const SizedBox(height: 10),
            if (!installed)
              Text(
                'Install a signed, self-contained runtime. Node.js, npm, Git, and terminal commands are not required.',
                style: TextStyle(color: _textSecondary, height: 1.45),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _MetaPill(
                    icon: Icons.inventory_2_outlined,
                    label: 'Runtime ${status?.version ?? 'unknown'}',
                  ),
                  if (status?.releaseChannel case final channel?)
                    _MetaPill(
                      icon: channel == 'beta'
                          ? Icons.science_outlined
                          : Icons.verified_outlined,
                      label: '${_channelLabel(channel)} channel',
                    ),
                  // The connection card already names it when it is the
                  // server in use, so only show the address otherwise.
                  if (_localBackendUrl case final url?)
                    if (!_managesLocalBackend)
                      _MetaPill(icon: Icons.dns_outlined, label: url),
                ],
              ),
            if (_staleRuntimeProcess) ...<Widget>[
              const SizedBox(height: 12),
              _InlineError(
                message:
                    'Version ${status?.version} is installed, but ${status?.runningVersion} is still running.'
                    ' Restart to finish the update.',
              ),
            ],
            if (status?.errorCode case final errorCode?) ...<Widget>[
              const SizedBox(height: 12),
              _InlineError(
                message: 'The local runtime needs repair ($errorCode).',
              ),
            ],
            if (_errorMessage case final message?) ...<Widget>[
              const SizedBox(height: 12),
              _InlineError(message: message),
            ],
            if (_installing) ...<Widget>[
              const SizedBox(height: 18),
              _installProgress(),
            ] else ...<Widget>[
              if (installed) ...<Widget>[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    if (status?.running == true)
                      OutlinedButton.icon(
                        onPressed: _actionRunning
                            ? null
                            : () => _runAction(LocalRuntimeAction.restart),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Restart'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _actionRunning
                            ? null
                            : () => _runAction(LocalRuntimeAction.start),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start'),
                      ),
                    if (status?.running == true)
                      OutlinedButton.icon(
                        onPressed: _actionRunning
                            ? null
                            : () => _runAction(LocalRuntimeAction.stop),
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop'),
                      ),
                    if (_managesLocalBackend)
                      OutlinedButton.icon(
                        onPressed: _viewingLogs ? null : _showLocalLogs,
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('View logs'),
                      ),
                    if (_localBackendUrl != null)
                      OutlinedButton.icon(
                        onPressed: _openLocalDashboard,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open dashboard'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              _installOrUpdateSection(installed: installed),
            ],
            if (_events.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              _setupDetails(),
            ],
          ],
        ),
      ),
    );
  }

  /// Installing and updating are the same operation, so they share one section:
  /// it opens on its own while nothing is installed yet, and stays out of the
  /// way once the backend is running.
  Widget _installOrUpdateSection({required bool installed}) {
    final installedChannel = _status?.releaseChannel;
    return ExpansionTile(
      initiallyExpanded: !installed,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 6),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(
        installed ? 'Update or repair' : 'Install the backend',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      children: <Widget>[
        Text('Setup', style: TextStyle(color: _textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        SegmentedButton<LocalBackendSetupProfile>(
          segments: const <ButtonSegment<LocalBackendSetupProfile>>[
            ButtonSegment<LocalBackendSetupProfile>(
              value: LocalBackendSetupProfile.quick,
              label: Text('Quickstart'),
              icon: Icon(Icons.bolt_rounded),
            ),
            ButtonSegment<LocalBackendSetupProfile>(
              value: LocalBackendSetupProfile.full,
              label: Text('Full setup'),
              icon: Icon(Icons.tune_rounded),
            ),
          ],
          selected: <LocalBackendSetupProfile>{_profile},
          onSelectionChanged: (selection) {
            setState(() => _profile = selection.first);
          },
        ),
        const SizedBox(height: 14),
        Text('Channel', style: TextStyle(color: _textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        _channelPicker(
          value: _channel,
          onChanged: (value) => setState(() => _channel = value),
        ),
        const SizedBox(height: 8),
        Text(
          installedChannel != null && installedChannel != _channel
              ? 'This switches the backend from the ${installedChannel.toLowerCase()} channel to the ${_channel.toLowerCase()} channel.'
              : _channel == 'beta'
              ? 'Beta installs the newest prerelease backend. Expect rough edges.'
              : 'Stable installs the latest published backend release.',
          style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _installOrRepair,
            icon: Icon(
              installed ? Icons.build_outlined : Icons.download_outlined,
            ),
            label: Text(installed ? 'Update and repair' : 'Install NeoAgent'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Providers, integrations, voice, and optional capabilities can be completed from Settings at any time.',
          style: TextStyle(color: _textMuted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _installProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_currentEvent?.message ?? 'Preparing NeoAgent…'),
            ),
            TextButton(
              onPressed: _installer.cancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _currentEvent?.progress,
          minHeight: 7,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }

  Widget _setupDetails() {
    return ExpansionTile(
      initiallyExpanded: _showDetails,
      onExpansionChanged: (value) {
        setState(() => _showDetails = value);
      },
      tilePadding: EdgeInsets.zero,
      title: const Text('Setup details'),
      children: <Widget>[
        for (final event in _events)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              event.state == 'failed'
                  ? Icons.error_outline
                  : event.state == 'completed'
                  ? Icons.check_circle_outline
                  : Icons.circle_outlined,
              color: event.state == 'failed'
                  ? _danger
                  : event.state == 'completed'
                  ? _success
                  : _textMuted,
              size: 18,
            ),
            title: Text(event.message),
            subtitle: event.errorCode == null ? null : Text(event.errorCode!),
          ),
      ],
    );
  }

  Widget _appUpdateCard() {
    final controller = widget.controller;
    final release = controller.availableAppUpdate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cardTitle(
              'Desktop app',
              trailing: release == null
                  ? null
                  : _StatusPill(label: 'Update ready', color: _accent),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _MetaPill(
                  icon: Icons.desktop_windows_outlined,
                  label:
                      'Version ${controller.installedAppVersion ?? 'unknown'}',
                ),
                _MetaPill(
                  icon: controller.appUpdateChannel == 'beta'
                      ? Icons.science_outlined
                      : Icons.verified_outlined,
                  label:
                      '${_channelLabel(controller.appUpdateChannel)} channel',
                ),
                _MetaPill(
                  icon: Icons.schedule_outlined,
                  label: 'Checked ${controller.appUpdateLastCheckedLabel}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Channel', style: TextStyle(color: _textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            _channelPicker(
              value: controller.appUpdateChannel,
              onChanged: (value) =>
                  unawaited(controller.setAppUpdateChannel(value)),
            ),
            if (release != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '${release.title} • ${release.channelLabel} • ${release.asset.sizeLabel}',
                style: TextStyle(color: _textSecondary, height: 1.45),
              ),
            ],
            if (controller.appUpdateErrorMessage
                case final message?) ...<Widget>[
              const SizedBox(height: 12),
              _InlineError(message: message),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                if (release != null)
                  FilledButton.icon(
                    onPressed: controller.isOpeningAppUpdate
                        ? null
                        : controller.openAppUpdate,
                    icon: const Icon(Icons.system_update_alt_rounded),
                    label: Text(
                      controller.isOpeningAppUpdate
                          ? 'Opening…'
                          : 'Download ${release.version}',
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: controller.isCheckingAppUpdate
                      ? null
                      : () => controller.checkForAppUpdates(),
                  icon: controller.isCheckingAppUpdate
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    controller.isCheckingAppUpdate ? 'Checking…' : 'Check now',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _channelLabel(String channel) => channel == 'beta' ? 'Beta' : 'Stable';
}

class _LogView extends StatefulWidget {
  const _LogView({required this.text});

  final String text;

  @override
  State<_LogView> createState() => _LogViewState();
}

class _LogViewState extends State<_LogView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        child: SelectableText(
          widget.text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
