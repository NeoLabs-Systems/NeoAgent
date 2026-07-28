part of 'main.dart';

class ServerPanel extends StatefulWidget {
  const ServerPanel({super.key, required this.controller});

  final NeoAgentController controller;

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
  bool _checking = true;
  bool _installing = false;
  bool _actionRunning = false;
  bool _showDetails = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runtimeManager = LocalRuntimeManager();
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
      final result = await _installer.install(_profile);
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
              'Manage the selected NeoAgent server and the verified runtime on this computer.',
        ),
        const SizedBox(height: 18),
        _selectedServerCard(),
        if (_supportsDesktopShell) ...<Widget>[
          const SizedBox(height: 16),
          _localRuntimeCard(),
        ],
      ],
    );
  }

  Widget _selectedServerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Icon(Icons.dns_outlined, color: _accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Selected NeoAgent server',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.controller.backendUrl,
                    style: TextStyle(color: _textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _localRuntimeCard() {
    final status = _status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'NeoAgent on this computer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_checking)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _StatusPill(
                    label: status?.running == true
                        ? 'Running'
                        : status?.installed == true
                        ? 'Needs attention'
                        : 'Not installed',
                    color: status?.running == true
                        ? _success
                        : status?.installed == true
                        ? _warning
                        : _textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status?.version == null
                  ? 'Install a signed, self-contained runtime. Node.js, npm, Git, and terminal commands are not required.'
                  : 'Runtime version ${status!.version}',
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
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
            const SizedBox(height: 18),
            if (!_installing) ...<Widget>[
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _installOrRepair,
                    icon: Icon(
                      status?.installed == true
                          ? Icons.build_outlined
                          : Icons.download_outlined,
                    ),
                    label: Text(
                      status?.installed == true
                          ? 'Verify and repair'
                          : 'Install NeoAgent',
                    ),
                  ),
                  if (status?.installed == true && status?.running != true)
                    OutlinedButton.icon(
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
                          : () => _runAction(LocalRuntimeAction.restart),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Restart'),
                    ),
                  if (status?.running == true)
                    OutlinedButton.icon(
                      onPressed: _actionRunning
                          ? null
                          : () => _runAction(LocalRuntimeAction.stop),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    ),
                  if (status?.backendUrl != null ||
                      _installResult?.backendUrl != null)
                    OutlinedButton.icon(
                      onPressed: _openLocalDashboard,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open dashboard'),
                    ),
                  if ((status?.backendUrl != null ||
                          _installResult?.backendUrl != null) &&
                      widget.controller.backendUrl !=
                          (_installResult?.backendUrl ?? status?.backendUrl))
                    OutlinedButton.icon(
                      onPressed: _useLocalServer,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Use this server'),
                    ),
                ],
              ),
            ] else ...<Widget>[
              Row(
                children: <Widget>[
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentEvent?.message ?? 'Preparing NeoAgent…',
                    ),
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
            if (_events.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              ExpansionTile(
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
                      subtitle: event.errorCode == null
                          ? null
                          : Text(event.errorCode!),
                    ),
                ],
              ),
            ],
            if (status?.installed == true) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Providers, integrations, voice, and optional capabilities can be completed from Settings at any time.',
                style: TextStyle(color: _textMuted, fontSize: 12, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
