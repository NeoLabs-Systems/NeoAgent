part of 'main.dart';

// Admin console tabs for running the server: overview, updates and logs;
// user accounts; usage analytics; and the read-only SQL console. Each tab
// keeps its own data in its State — none of it lives on the controller.

/// Compact style for the text actions in rows and toolbars.
ButtonStyle _adminOpsActionStyle({Color? color}) {
  return TextButton.styleFrom(
    foregroundColor: color,
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}

// ── Server tab ────────────────────────────────────────────────────────────────

class _AdminOpsServerInfo {
  const _AdminOpsServerInfo({
    required this.version,
    required this.gitBranch,
    required this.gitSha,
    required this.nodeVersion,
    required this.uptime,
    required this.updatePhase,
    required this.update,
    required this.environment,
  });

  factory _AdminOpsServerInfo.fromJson(Map<String, dynamic> json) {
    final updateJson = _jsonMap(json['updateStatus']);
    return _AdminOpsServerInfo(
      environment: _jsonMap(
        json['environment'],
      ).map((key, value) => MapEntry(key, value?.toString() ?? '')),
      version: _asText(json['version'] ?? json['packageVersion']),
      gitBranch: _asText(json['gitBranch']),
      gitSha: _asText(json['gitSha']),
      nodeVersion: _asText(json['nodeVersion']),
      uptime: Duration(seconds: _asDouble(json['uptime']).round()),
      updatePhase: _asText(updateJson['phase'], fallback: ''),
      // The channel and deployment flags sit at the top level of the payload,
      // the live update state under `updateStatus`.
      update: UpdateStatusSnapshot.fromJson(<String, dynamic>{
        ...json,
        ...updateJson,
      }),
    );
  }

  final String version;
  final String gitBranch;
  final String gitSha;
  final String nodeVersion;
  final Duration uptime;
  final String updatePhase;
  final UpdateStatusSnapshot update;

  /// Non-secret runtime settings (PORT, PUBLIC_URL, …), read-only.
  final Map<String, String> environment;

  bool get isUpdating => update.state == 'running';

  String get shortSha => gitSha.length > 10 ? gitSha.substring(0, 10) : gitSha;

  String get deploymentLabel =>
      update.deploymentMode == 'managed' ? 'Managed' : 'Self-hosted';
}

class _AdminOpsHealthCheck {
  const _AdminOpsHealthCheck({
    required this.label,
    required this.detail,
    required this.passed,
  });

  factory _AdminOpsHealthCheck.fromJson(Map<String, dynamic> json) {
    return _AdminOpsHealthCheck(
      label: _asText(json['label'] ?? json['id']),
      detail: _asText(json['detail'], fallback: ''),
      passed: json['passed'] == true,
    );
  }

  final String label;
  final String detail;
  final bool passed;
}

class _AdminServerTab extends StatefulWidget {
  const _AdminServerTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminServerTab> createState() => _AdminServerTabState();
}

class _AdminServerTabState extends State<_AdminServerTab> {
  _AdminOpsServerInfo? _info;
  List<_AdminOpsHealthCheck> _checks = const <_AdminOpsHealthCheck>[];
  bool _loading = true;
  String? _error;
  bool _updateBusy = false;
  String? _updateError;
  Timer? _updatePoll;
  Timer? _overviewRefresh;

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadOverview();
    // Health and uptime stay current while the tab is open.
    _overviewRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadOverview(),
    );
  }

  @override
  void dispose() {
    _updatePoll?.cancel();
    _overviewRefresh?.cancel();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final client = _controller.backendClient;
      final url = _controller.backendUrl;
      final results = await Future.wait(<Future<Map<String, dynamic>>>[
        client.fetchAdminVersion(url),
        client.fetchAdminHealth(url),
      ]);
      if (!mounted) return;
      setState(() {
        _info = _AdminOpsServerInfo.fromJson(results[0]);
        _checks = _jsonMapList(
          results[1]['results'],
        ).map(_AdminOpsHealthCheck.fromJson).toList(growable: false);
        _loading = false;
        _error = null;
      });
      _syncUpdatePolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _controller._friendlyErrorMessage(error);
      });
    }
  }

  void _reloadOverview() {
    setState(() => _loading = true);
    _loadOverview();
  }

  /// Polls the version endpoint while an update runs so progress stays live.
  void _syncUpdatePolling() {
    if (_info?.isUpdating != true) {
      _updatePoll?.cancel();
      _updatePoll = null;
      return;
    }
    _updatePoll ??= Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollUpdateStatus(),
    );
  }

  Future<void> _pollUpdateStatus() async {
    try {
      final json = await _controller.backendClient.fetchAdminVersion(
        _controller.backendUrl,
      );
      if (!mounted) return;
      setState(() => _info = _AdminOpsServerInfo.fromJson(json));
      _syncUpdatePolling();
    } catch (_) {
      // The server restarts at the end of an update; keep polling until it
      // answers again.
    }
  }

  /// The controller's update methods report failures through its shared
  /// error slot. Move that message next to the update controls instead.
  String? _takeControllerError() {
    final message = _controller.errorMessage;
    if (message != null) _controller.clearInlineError();
    return message;
  }

  Future<void> _setChannel(String channel) async {
    setState(() {
      _updateBusy = true;
      _updateError = null;
    });
    await _controller.setReleaseChannel(channel);
    final error = _takeControllerError();
    if (!mounted) return;
    setState(() {
      _updateBusy = false;
      _updateError = error;
    });
    if (error == null) await _loadOverview();
  }

  Future<void> _startUpdate() async {
    final info = _info;
    if (info == null) return;
    await _confirmDelete(
      context,
      title: appStrings.updateTheServer,
      message:
          appStrings.neoagentInstallsTheLatestArg1(info.update.releaseChannelLabel.toLowerCase()) +
          appStrings.releaseAndRestartsConnectedAppsReconnect,
      confirmLabel: appStrings.updateNow,
      onConfirm: () async {
        if (!mounted) return;
        setState(() {
          _updateBusy = true;
          _updateError = null;
        });
        await _controller.triggerUpdate();
        final error = _takeControllerError();
        if (!mounted) return;
        setState(() {
          _updateBusy = false;
          _updateError = error;
        });
        await _loadOverview();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return _SectionStack(
      children: <Widget>[
        _SectionCard(
          title: 'Server',
          description: appStrings.theNeoagentInstanceThisAppIs,
          trailing: _RefreshButton(busy: _loading, onPressed: _reloadOverview),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                _InlineError(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
                if (info != null) const SizedBox(height: 14),
              ],
              if (info != null)
                _AdminOpsFactGrid(
                  facts: <(String, String)>[
                    ('Version', info.version),
                    (appStrings.releaseChannel, info.update.releaseChannelLabel),
                    ('Branch', info.gitBranch),
                    ('Commit', info.shortSha),
                    ('Deployment', info.deploymentLabel),
                    ('Node.js', info.nodeVersion),
                    ('Uptime', _formatElapsed(info.uptime)),
                  ],
                )
              else if (_loading)
                const _LoadingPlaceholder(),
            ],
          ),
        ),
        if (info != null) ...<Widget>[
          _AdminOpsUpdateCard(
            info: info,
            busy: _updateBusy,
            error: _updateError,
            onDismissError: () => setState(() => _updateError = null),
            onChannelChanged: _setChannel,
            onUpdate: _startUpdate,
          ),
          _AdminOpsHealthCard(checks: _checks),
          if (info.environment.isNotEmpty)
            _SectionCard(
              title: appStrings.environment,
              description:
                  appStrings.runtimeSettingsThisServerStartedWith +
                  appStrings.configurationOrInTheEnvFile,
              child: _AdminOpsFactGrid(
                facts: <(String, String)>[
                  for (final entry in info.environment.entries)
                    (entry.key, entry.value.isEmpty ? '—' : entry.value),
                ],
              ),
            ),
        ],
        _AdminOpsLogsPanel(controller: widget.controller),
      ],
    );
  }
}

class _AdminOpsFactGrid extends StatelessWidget {
  const _AdminOpsFactGrid({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final width =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                .floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: 16,
          children: <Widget>[
            for (final (label, value) in facts)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label.toUpperCase(),
                      style: _monoStyle(
                        size: 10,
                        color: _textMuted,
                        weight: FontWeight.w600,
                      ).copyWith(letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminOpsUpdateCard extends StatelessWidget {
  const _AdminOpsUpdateCard({
    required this.info,
    required this.busy,
    required this.error,
    required this.onDismissError,
    required this.onChannelChanged,
    required this.onUpdate,
  });

  final _AdminOpsServerInfo info;
  final bool busy;
  final String? error;
  final VoidCallback onDismissError;
  final ValueChanged<String> onChannelChanged;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final update = info.update;
    final running = info.isUpdating;
    final canControl = update.allowSelfUpdate && !running && !busy;
    final channel = update.releaseChannel.toLowerCase() == 'beta'
        ? 'beta'
        : 'stable';
    return _SectionCard(
      title: appStrings.updates,
      description:
          appStrings.installNewReleasesAndChooseWhich,
      trailing: _StatusPill(label: update.badgeLabel, color: update.badgeColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            update.message,
            style: TextStyle(
              fontSize: 13.5,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
          if (running) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: update.progress / 100,
                minHeight: 6,
                backgroundColor: _bgSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(_info),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              <String>[
                '${update.progress}%',
                if (info.updatePhase.isNotEmpty) info.updatePhase,
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
          if (!update.allowSelfUpdate) ...<Widget>[
            const SizedBox(height: 14),
            _InlineNote(
              icon: Icons.lock_outline_rounded,
              message:
                  appStrings.thisIsAManagedDeploymentIts +
                  appStrings.updatesSoSelfUpdateAndChannel,
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: 14),
            _InlineError(message: error!, onDismiss: onDismissError),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'stable',
                    label: Text(appStrings.stable),
                    icon: Icon(Icons.verified_outlined),
                  ),
                  ButtonSegment<String>(
                    value: 'beta',
                    label: Text(appStrings.beta),
                    icon: Icon(Icons.science_outlined),
                  ),
                ],
                selected: <String>{channel},
                onSelectionChanged: canControl
                    ? (selection) => onChannelChanged(selection.first)
                    : null,
              ),
              FilledButton.icon(
                onPressed: canControl ? onUpdate : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.system_update_alt_rounded, size: 18),
                label: Text(running ? 'Updating…' : appStrings.updateNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminOpsHealthCard extends StatelessWidget {
  const _AdminOpsHealthCard({required this.checks});

  final List<_AdminOpsHealthCheck> checks;

  @override
  Widget build(BuildContext context) {
    final failing = checks.where((check) => !check.passed).length;
    return _SectionCard(
      title: appStrings.healthChecks,
      description: appStrings.coreServicesThisServerDependsOn,
      trailing: checks.isEmpty
          ? null
          : _StatusPill(
              label: failing == 0 ? 'All passing' : appStrings.arg1Failing(failing),
              color: failing == 0 ? _success : _danger,
            ),
      child: checks.isEmpty
          ? _EmptyText(appStrings.theServerReportedNoHealthChecks)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < checks.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, color: _border),
                  _AdminOpsHealthRow(check: checks[i]),
                ],
              ],
            ),
    );
  }
}

class _AdminOpsHealthRow extends StatelessWidget {
  const _AdminOpsHealthRow({required this.check});

  final _AdminOpsHealthCheck check;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            check.passed ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 18,
            color: check.passed ? _success : _danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  check.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                if (check.detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    check.detail,
                    style: TextStyle(fontSize: 12.5, color: _textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logs ──────────────────────────────────────────────────────────────────────

enum _AdminOpsLogFilter { all, errors, warnings }

class _AdminOpsLogEntry {
  const _AdminOpsLogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  factory _AdminOpsLogEntry.fromJson(Map<String, dynamic> json) {
    return _AdminOpsLogEntry(
      level: _asText(json['type'], fallback: 'log').toLowerCase(),
      message: json['message']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }

  final String level;
  final String message;

  /// ISO-8601, so it also sorts chronologically as a string.
  final String timestamp;

  bool matches(_AdminOpsLogFilter filter) {
    switch (filter) {
      case _AdminOpsLogFilter.all:
        return true;
      case _AdminOpsLogFilter.errors:
        return level == 'error';
      case _AdminOpsLogFilter.warnings:
        return level == 'warn';
    }
  }
}

class _AdminOpsIssue {
  _AdminOpsIssue(this.message, this.lastTimestamp);

  final String message;
  int count = 1;
  String lastTimestamp;
}

/// Error-level entries grouped by message, so a repeated failure shows up
/// once with a count. Most recent first.
List<_AdminOpsIssue> _adminOpsGroupIssues(List<_AdminOpsLogEntry> logs) {
  final groups = <String, _AdminOpsIssue>{};
  for (final entry in logs) {
    if (entry.level != 'error') continue;
    final message = entry.message.trim();
    if (message.isEmpty) continue;
    final existing = groups[message];
    if (existing == null) {
      groups[message] = _AdminOpsIssue(message, entry.timestamp);
      continue;
    }
    existing.count += 1;
    if (entry.timestamp.compareTo(existing.lastTimestamp) > 0) {
      existing.lastTimestamp = entry.timestamp;
    }
  }
  return groups.values.toList()
    ..sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
}

String _adminOpsLogTime(String timestamp) {
  final time = _parseOptionalTimestamp(timestamp);
  if (time == null) return '';
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return appStrings.arg1Arg2Arg32(month, day, _formatTimeOnly(time));
}

Color _adminOpsLevelColor(String level) {
  switch (level) {
    case 'error':
      return _danger;
    case 'warn':
      return _warning;
    case 'info':
      return _info;
    default:
      return _textMuted;
  }
}

class _AdminOpsLogsPanel extends StatefulWidget {
  const _AdminOpsLogsPanel({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminOpsLogsPanel> createState() => _AdminOpsLogsPanelState();
}

class _AdminOpsLogsPanelState extends State<_AdminOpsLogsPanel> {
  static const int _collapsedIssueCount = 5;

  /// Newest first.
  List<_AdminOpsLogEntry> _logs = const <_AdminOpsLogEntry>[];
  List<_AdminOpsIssue> _issues = const <_AdminOpsIssue>[];
  bool _loading = true;
  String? _error;
  _AdminOpsLogFilter _filter = _AdminOpsLogFilter.all;
  bool _showAllIssues = false;
  Timer? _refresh;

  /// Entries at or before this timestamp are hidden by "Clear view"; the
  /// server's log is untouched.
  String? _clearedThrough;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  List<_AdminOpsLogEntry> get _visibleLogs {
    final cleared = _clearedThrough;
    if (cleared == null) return _logs;
    return _logs
        .where((entry) => entry.timestamp.compareTo(cleared) > 0)
        .toList(growable: false);
  }

  Future<void> _copyAll() async {
    final lines = _visibleLogs.reversed
        .map(
          (entry) => appStrings.arg1Arg2Arg33(entry.timestamp, entry.level, entry.message),
        )
        .join('\n');
    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(appStrings.logCopied)));
  }

  void _clearView() {
    if (_logs.isEmpty) return;
    setState(() => _clearedThrough = _logs.first.timestamp);
  }

  Future<void> _load() async {
    try {
      final json = await widget.controller.backendClient.fetchAdminLogs(
        widget.controller.backendUrl,
      );
      final logs = _jsonMapList(json['logs'])
          .map(_AdminOpsLogEntry.fromJson)
          .toList()
          .reversed
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _issues = _adminOpsGroupIssues(logs);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.controller._friendlyErrorMessage(error);
      });
    }
  }

  void _reload() {
    setState(() => _loading = true);
    _load();
  }

  int _countFor(_AdminOpsLogFilter filter) {
    return _visibleLogs.where((entry) => entry.matches(filter)).length;
  }

  String _filterLabel(_AdminOpsLogFilter filter) {
    switch (filter) {
      case _AdminOpsLogFilter.all:
        return appStrings.all;
      case _AdminOpsLogFilter.errors:
        return 'Errors';
      case _AdminOpsLogFilter.warnings:
        return 'Warnings';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialLoad = _loading && _logs.isEmpty;
    return _SectionStack(
      children: <Widget>[
        _SectionCard(
          title: appStrings.issues,
          description: appStrings.errorsFromTheRecentLogGrouped,
          trailing: initialLoad
              ? null
              : _StatusPill(
                  label: _issues.isEmpty
                      ? 'None'
                      : appStrings.arg1Arg23(_issues.length, _issues.length == 1 ? 'issue' : 'issues'),
                  color: _issues.isEmpty ? _success : _danger,
                ),
          child: initialLoad ? const _LoadingPlaceholder() : _buildIssues(),
        ),
        _SectionCard(
          title: appStrings.logs,
          description: appStrings.recentServerOutputNewestFirst,
          trailing: _RefreshButton(busy: _loading, onPressed: _reload),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                _InlineError(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  for (final filter in _AdminOpsLogFilter.values)
                    ChoiceChip(
                      label: Text(
                        appStrings.arg1Arg2(_filterLabel(filter), _countFor(filter)),
                      ),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  TextButton.icon(
                    style: _adminOpsActionStyle(),
                    onPressed: _visibleLogs.isEmpty ? null : _copyAll,
                    icon: Icon(Icons.copy, size: 16),
                    label: Text(appStrings.copyAll),
                  ),
                  if (_clearedThrough == null)
                    TextButton.icon(
                      style: _adminOpsActionStyle(),
                      onPressed: _logs.isEmpty ? null : _clearView,
                      icon: Icon(Icons.clear_all, size: 16),
                      label: Text(appStrings.clearView),
                    )
                  else
                    TextButton.icon(
                      style: _adminOpsActionStyle(),
                      onPressed: () => setState(() => _clearedThrough = null),
                      icon: Icon(Icons.history, size: 16),
                      label: Text(appStrings.showEarlier),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (initialLoad)
                const _LoadingPlaceholder()
              else
                _AdminOpsLogViewer(
                  entries: _visibleLogs
                      .where((entry) => entry.matches(_filter))
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIssues() {
    if (_issues.isEmpty) {
      return _EmptyText(
        _error == null
            ? appStrings.noErrorsInTheRecentLog
            : appStrings.issuesAppearOnceTheLogLoads,
      );
    }
    final shown = _showAllIssues
        ? _issues
        : _issues.take(_collapsedIssueCount).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < shown.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: _border),
                _AdminOpsIssueRow(issue: shown[i]),
              ],
            ],
          ),
        ),
        if (_issues.length > _collapsedIssueCount)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: _adminOpsActionStyle(),
              onPressed: () => setState(() => _showAllIssues = !_showAllIssues),
              child: Text(
                _showAllIssues ? 'Show fewer' : appStrings.showAllArg1(_issues.length),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminOpsIssueRow extends StatelessWidget {
  const _AdminOpsIssueRow({required this.issue});

  final _AdminOpsIssue issue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              issue.message,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: _monoStyle(color: _danger),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (issue.count > 1)
                Text(
                  '×${issue.count}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _danger,
                  ),
                ),
              Text(
                _adminOpsLogTime(issue.lastTimestamp),
                style: _monoStyle(size: 11, color: _textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminOpsLogViewer extends StatelessWidget {
  const _AdminOpsLogViewer({required this.entries});

  final List<_AdminOpsLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: _bgSecondary,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    );
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: decoration,
        child: Center(
          child: Text(
            appStrings.noLogEntries,
            style: TextStyle(fontSize: 13, color: _textMuted),
          ),
        ),
      );
    }
    return Container(
      height: 420,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 560;
          return SelectionArea(
            child: ListView.builder(
              primary: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, index) =>
                  _AdminOpsLogLine(entry: entries[index], stacked: stacked),
            ),
          );
        },
      ),
    );
  }
}

class _AdminOpsLogLine extends StatelessWidget {
  const _AdminOpsLogLine({required this.entry, required this.stacked});

  final _AdminOpsLogEntry entry;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final levelColor = _adminOpsLevelColor(entry.level);
    final time = Text(
      _adminOpsLogTime(entry.timestamp),
      style: _monoStyle(size: 11.5, color: _textMuted),
    );
    final level = Text(
      entry.level.toUpperCase(),
      style: _monoStyle(size: 11, color: levelColor, weight: FontWeight.w700),
    );
    final message = Text(
      entry.message,
      style: _monoStyle(
        color: entry.level == 'error' || entry.level == 'warn'
            ? levelColor
            : _textPrimary,
      ),
    );
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[time, const SizedBox(width: 8), level]),
            message,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 116, child: time),
          SizedBox(width: 52, child: level),
          Expanded(child: message),
        ],
      ),
    );
  }
}

// ── Users tab ─────────────────────────────────────────────────────────────────

class _AdminOpsUser {
  const _AdminOpsUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.emailVerified,
    required this.createdAt,
    required this.lastLogin,
    required this.fourHourLimit,
    required this.weeklyLimit,
    required this.runCount,
    required this.storageBytes,
    required this.isAdmin,
    required this.managedBy,
  });

  factory _AdminOpsUser.fromJson(Map<String, dynamic> json) {
    final username = _asText(json['username'], fallback: '');
    return _AdminOpsUser(
      id: _asInt(json['id']),
      username: username,
      displayName: _asText(json['display_name'], fallback: username),
      email: _asText(json['email'], fallback: ''),
      emailVerified: _asText(
        json['email_verified_at'],
        fallback: '',
      ).isNotEmpty,
      createdAt: _parseOptionalTimestamp(json['created_at']?.toString()),
      lastLogin: _parseOptionalTimestamp(json['last_login']?.toString()),
      fourHourLimit: _asOptionalInt(json['rate_limit_4h']),
      weeklyLimit: _asOptionalInt(json['rate_limit_weekly']),
      runCount: _asInt(json['run_count']),
      storageBytes: _asInt(json['storage_bytes']),
      isAdmin: json['is_admin'] == 1 || json['is_admin'] == true,
      managedBy: _asText(json['managed_by'], fallback: ''),
    );
  }

  final int id;
  final String username;
  final String displayName;
  final String email;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final int? fourHourLimit;
  final int? weeklyLimit;
  final int runCount;
  final int storageBytes;
  final bool isAdmin;

  /// Username of the account's team manager, or empty.
  final String managedBy;

  String get initial =>
      displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase();
}

class _AdminUsersTab extends StatefulWidget {
  const _AdminUsersTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<_AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _requestId = 0;
  List<_AdminOpsUser> _users = const <_AdminOpsUser>[];
  bool _loading = true;
  String? _error;
  String? _notice;
  final Set<int> _busyUserIds = <int>{};

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    // Search-as-you-type can overlap requests; only the latest one may land.
    final requestId = ++_requestId;
    try {
      final json = await _controller.backendClient.fetchAdminUsers(
        _controller.backendUrl,
        query: _searchController.text,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _users = _jsonMapList(
          json['users'],
        ).map(_AdminOpsUser.fromJson).toList(growable: false);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = _controller._friendlyErrorMessage(error);
      });
    }
  }

  void _reload() {
    _searchDebounce?.cancel();
    setState(() => _loading = true);
    _loadUsers();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _reload);
    // Rebuild for the clear button.
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _reload();
  }

  String _errorFor(Object error, _AdminOpsUser user) {
    if (error is BackendException && error.code == 'ADMIN_ACCOUNT') {
      return appStrings.arg1IsAnAdminSoThe(user.username) +
          appStrings.hereRevokeAdminWithNeoagentAdmin(user.username);
    }
    return _controller._friendlyErrorMessage(error);
  }

  /// Runs [action] for [user] with a row spinner; its result is the success
  /// notice to show.
  Future<void> _runUserAction(
    _AdminOpsUser user,
    Future<String> Function() action,
  ) async {
    setState(() {
      _busyUserIds.add(user.id);
      _error = null;
      _notice = null;
    });
    try {
      final notice = await action();
      if (!mounted) return;
      setState(() => _notice = notice);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorFor(error, user));
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(user.id));
    }
  }

  Future<void> _signOutEverywhere(_AdminOpsUser user) {
    return _confirmDelete(
      context,
      title: appStrings.signOutArg1Everywhere(user.username),
      message:
          appStrings.everyActiveSessionForThisAccount +
          appStrings.againRightAway,
      confirmLabel: appStrings.signOutEverywhere,
      onConfirm: () => _runUserAction(user, () async {
        await _controller.backendClient.revokeAdminUserSessions(
          _controller.backendUrl,
          user.id,
        );
        return appStrings.signedArg1OutOfEverySession(user.username);
      }),
    );
  }

  Future<void> _editRateLimits(_AdminOpsUser user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _AdminOpsUserLimitsDialog(controller: _controller, user: user),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _error = null;
      _notice = appStrings.savedRateLimitsForArg1(user.username);
    });
    await _loadUsers();
  }

  Future<void> _manageSubscription(_AdminOpsUser user) {
    return showDialog<void>(
      context: context,
      builder: (_) => _AdminOpsSubscriptionDialog(
        controller: _controller,
        userId: user.id,
        username: user.username,
      ),
    );
  }

  Future<void> _deleteUser(_AdminOpsUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminOpsDeleteUserDialog(username: user.username),
    );
    if (confirmed != true || !mounted) return;
    await _runUserAction(user, () async {
      await _controller.backendClient.deleteAdminUser(
        _controller.backendUrl,
        user.id,
      );
      if (mounted) {
        setState(() {
          _users = _users
              .where((candidate) => candidate.id != user.id)
              .toList(growable: false);
        });
      }
      return appStrings.deletedArg1AndAllOfTheir(user.username);
    });
  }

  String get _summary {
    final count = _users.length;
    final noun = count == 1 ? 'account' : 'accounts';
    final query = _searchController.text.trim();
    return query.isEmpty ? '$count $noun' : appStrings.arg1Arg2MatchingArg3(count, noun, query);
  }

  @override
  Widget build(BuildContext context) {
    final showSubscription = _controller.showBillingSection;
    return _SectionStack(
      children: <Widget>[
        _AdminOpsDefaultLimitsCard(controller: _controller),
        _SectionCard(
          title: appStrings.accounts,
          description: _loading && _users.isEmpty
              ? appStrings.loadingAccounts
              : _summary,
          trailing: _RefreshButton(busy: _loading, onPressed: _reload),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SearchField(
                controller: _searchController,
                hintText: appStrings.searchByUsernameOrEmail,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
              _SaveFeedback(
                error: _error,
                notice: _notice,
                onDismissError: () => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              if (_loading && _users.isEmpty)
                const _LoadingPlaceholder()
              else if (_users.isEmpty)
                _EmptyText(appStrings.noAccountsFound)
              else
                for (final user in _users)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdminOpsUserRow(
                      user: user,
                      busy: _busyUserIds.contains(user.id),
                      showSubscription: showSubscription,
                      onSignOut: () => _signOutEverywhere(user),
                      onRateLimits: () => _editRateLimits(user),
                      onSubscription: () => _manageSubscription(user),
                      onDelete: () => _deleteUser(user),
                    ),
                  ),
              const SizedBox(height: 4),
              _InlineNote(
                icon: Icons.gpp_maybe_outlined,
                color: _warning,
                message:
                    appStrings.deletePermanentlyErasesAnAccountAnd +
                    appStrings.runsMessagesMemoriesIntegrationsFilesAnd +
                    appStrings.sessionsGdprArt17AdminAccounts +
                    'here.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminOpsUserRow extends StatelessWidget {
  const _AdminOpsUserRow({
    required this.user,
    required this.busy,
    required this.showSubscription,
    required this.onSignOut,
    required this.onRateLimits,
    required this.onSubscription,
    required this.onDelete,
  });

  final _AdminOpsUser user;
  final bool busy;
  final bool showSubscription;
  final VoidCallback onSignOut;
  final VoidCallback onRateLimits;
  final VoidCallback onSubscription;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final facts = <(IconData, String)>[
      (Icons.event_outlined, appStrings.joinedArg1(_formatDate(user.createdAt))),
      (
        Icons.login_rounded,
        user.lastLogin == null
            ? appStrings.neverSignedIn
            : appStrings.lastSignInArg1(_formatDate(user.lastLogin)),
      ),
      (
        Icons.bolt_outlined,
        appStrings.arg1Arg23(_formatNumber(user.runCount), user.runCount == 1 ? 'run' : 'runs'),
      ),
      (Icons.folder_outlined, _formatBytes(user.storageBytes)),
      if (user.managedBy.isNotEmpty)
        (Icons.groups_2_outlined, appStrings.inArg1STeam(user.managedBy)),
      if (user.email.isNotEmpty && !user.emailVerified)
        (Icons.mark_email_unread_outlined, appStrings.emailUnverified),
      if (user.fourHourLimit != null)
        (
          Icons.timer_outlined,
          appStrings.n4hLimitArg1(_formatTokenCount(user.fourHourLimit!)),
        ),
      if (user.weeklyLimit != null)
        (
          Icons.date_range_outlined,
          appStrings.weeklyLimitArg1(_formatTokenCount(user.weeklyLimit!)),
        ),
    ];
    final subtitle = user.email.isEmpty
        ? '@${user.username}'
        : appStrings.arg1Arg26(user.username, user.email);

    return _RowSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentMuted,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  user.initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _accentHover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          user.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        if (user.isAdmin)
                          _StatusPill(label: 'Admin', color: _accentHover),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: _textSecondary),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: <Widget>[
              for (final (icon, label) in facts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 14, color: _textMuted),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(fontSize: 12.5, color: _textMuted),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            children: <Widget>[
              TextButton.icon(
                style: _adminOpsActionStyle(),
                onPressed: busy ? null : onSignOut,
                icon: Icon(Icons.logout_rounded, size: 16),
                label: Text(appStrings.signOutEverywhere),
              ),
              TextButton.icon(
                style: _adminOpsActionStyle(),
                onPressed: busy ? null : onRateLimits,
                icon: Icon(Icons.speed_rounded, size: 16),
                label: Text(appStrings.rateLimits),
              ),
              if (showSubscription)
                TextButton.icon(
                  style: _adminOpsActionStyle(),
                  onPressed: busy ? null : onSubscription,
                  icon: Icon(Icons.credit_card_outlined, size: 16),
                  label: Text(appStrings.subscription),
                ),
              if (user.isAdmin)
                Tooltip(
                  message:
                      appStrings.revokeAdminWithNeoagentAdminRevoke(user.username),
                  child: TextButton.icon(
                    style: _adminOpsActionStyle(),
                    onPressed: null,
                    icon: Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(appStrings.delete),
                  ),
                )
              else
                TextButton.icon(
                  style: _adminOpsActionStyle(color: _danger),
                  onPressed: busy ? null : onDelete,
                  icon: Icon(Icons.delete_outline_rounded, size: 16),
                  label: Text(appStrings.delete),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 4-hour and weekly token budget fields of the default limits card and
/// the per-account dialog.
class _AdminOpsLimitFields extends StatelessWidget {
  const _AdminOpsLimitFields({
    required this.fourHour,
    required this.weekly,
    required this.fourHourHelper,
    required this.weeklyHelper,
  });

  final TextEditingController fourHour;
  final TextEditingController weekly;
  final String fourHourHelper;
  final String weeklyHelper;

  @override
  Widget build(BuildContext context) {
    return _FieldGrid(
      children: <Widget>[
        _FormTextField(
          controller: fourHour,
          label: appStrings.n4HourLimitTokens,
          helper: fourHourHelper,
          wholeNumber: true,
        ),
        _FormTextField(
          controller: weekly,
          label: appStrings.weeklyLimitTokens,
          helper: weeklyHelper,
          wholeNumber: true,
        ),
      ],
    );
  }
}

class _AdminOpsDefaultLimitsCard extends StatefulWidget {
  const _AdminOpsDefaultLimitsCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminOpsDefaultLimitsCard> createState() =>
      _AdminOpsDefaultLimitsCardState();
}

class _AdminOpsDefaultLimitsCardState extends State<_AdminOpsDefaultLimitsCard>
    with _LoadSaveState<_AdminOpsDefaultLimitsCard> {
  final TextEditingController _fourHour = TextEditingController();
  final TextEditingController _weekly = TextEditingController();

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  @override
  void dispose() {
    _fourHour.dispose();
    _weekly.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final json = await _client.fetchAdminDefaultRateLimits(_baseUrl);
    _fourHour.text = _asOptionalInt(json['rate_limit_4h'])?.toString() ?? '';
    _weekly.text = _asOptionalInt(json['rate_limit_weekly'])?.toString() ?? '';
  }

  Future<void> _save() async {
    await _runSave(() async {
      await _client.saveAdminDefaultRateLimits(
        _baseUrl,
        fourHour: _asOptionalInt(_fourHour.text),
        weekly: _asOptionalInt(_weekly.text),
      );
      // Reload so emptied fields show the built-in default now in effect.
      await _fetch();
    }, appStrings.defaultRateLimitsSaved);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.defaultRateLimits,
      description:
          appStrings.tokenBudgetForEveryAccountWithout +
          appStrings.fieldEmptyToRestoreTheBuilt,
      child: _loadGate(_fetch) ?? _form(),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _AdminOpsLimitFields(
          fourHour: _fourHour,
          weekly: _weekly,
          fourHourHelper: appStrings.tokensAnyAccountMayUseIn,
          weeklyHelper: appStrings.tokensAnyAccountMayUseIn2,
        ),
        const SizedBox(height: 16),
        _SaveButton(saving: _saving, onPressed: _save, label: appStrings.saveDefaults),
        _saveFeedback(),
      ],
    );
  }
}

class _AdminOpsUserLimitsDialog extends StatefulWidget {
  const _AdminOpsUserLimitsDialog({
    required this.controller,
    required this.user,
  });

  final NeoAgentController controller;
  final _AdminOpsUser user;

  @override
  State<_AdminOpsUserLimitsDialog> createState() =>
      _AdminOpsUserLimitsDialogState();
}

class _AdminOpsUserLimitsDialogState extends State<_AdminOpsUserLimitsDialog> {
  final TextEditingController _fourHour = TextEditingController();
  final TextEditingController _weekly = TextEditingController();
  int? _defaultFourHour;
  int? _defaultWeekly;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fourHour.dispose();
    _weekly.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = _controller.backendClient;
      final url = _controller.backendUrl;
      final results = await Future.wait(<Future<Map<String, dynamic>>>[
        client.fetchAdminUserRateLimits(url, widget.user.id),
        client.fetchAdminDefaultRateLimits(url),
      ]);
      if (!mounted) return;
      final limits = _jsonMap(results[0]['limits']);
      setState(() {
        _fourHour.text =
            _asOptionalInt(limits['rate_limit_4h'])?.toString() ?? '';
        _weekly.text =
            _asOptionalInt(limits['rate_limit_weekly'])?.toString() ?? '';
        _defaultFourHour = _asOptionalInt(results[1]['rate_limit_4h']);
        _defaultWeekly = _asOptionalInt(results[1]['rate_limit_weekly']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _controller._friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _controller.backendClient.saveAdminUserRateLimits(
        _controller.backendUrl,
        userId: widget.user.id,
        fourHour: _asOptionalInt(_fourHour.text),
        weekly: _asOptionalInt(_weekly.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _controller._friendlyErrorMessage(error);
      });
    }
  }

  String _inheritHelper(int? fallback) {
    return fallback == null
        ? appStrings.emptyUsesTheServerDefault
        : appStrings.emptyUsesTheServerDefaultArg1(_formatTokenCount(fallback));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(appStrings.rateLimits),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              appStrings.tokenBudgetForArg1LeaveA(widget.user.username) +
              appStrings.toUseTheServerDefault,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const _LoadingPlaceholder()
            else
              _AdminOpsLimitFields(
                fourHour: _fourHour,
                weekly: _weekly,
                fourHourHelper: _inheritHelper(_defaultFourHour),
                weeklyHelper: _inheritHelper(_defaultWeekly),
              ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              _InlineError(message: _error!),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(appStrings.cancel),
        ),
        _SaveButton(saving: _saving, onPressed: _loading ? null : _save),
      ],
    );
  }
}

class _AdminOpsDeleteUserDialog extends StatefulWidget {
  const _AdminOpsDeleteUserDialog({required this.username});

  final String username;

  @override
  State<_AdminOpsDeleteUserDialog> createState() =>
      _AdminOpsDeleteUserDialogState();
}

class _AdminOpsDeleteUserDialogState extends State<_AdminOpsDeleteUserDialog> {
  final TextEditingController _confirmation = TextEditingController();

  bool get _matches => _confirmation.text.trim() == widget.username;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_matches) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(appStrings.deleteArg1(widget.username)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              appStrings.thisPermanentlyErasesTheAccountAnd +
              appStrings.runsMessagesMemoriesIntegrationsFilesAnd2 +
              appStrings.itCanTBeUndone,
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmation,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(
                labelText: appStrings.typeArg1ToConfirm(widget.username),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(appStrings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _danger,
            foregroundColor: Colors.white,
          ),
          onPressed: _matches ? _confirm : null,
          child: Text(appStrings.deleteAccount),
        ),
      ],
    );
  }
}

/// Shows an account's plan and lets an admin assign or cancel one. Opened
/// from the Users tab and from Billing › Subscriptions.
class _AdminOpsSubscriptionDialog extends StatefulWidget {
  const _AdminOpsSubscriptionDialog({
    required this.controller,
    required this.userId,
    required this.username,
  });

  final NeoAgentController controller;
  final int userId;
  final String username;

  @override
  State<_AdminOpsSubscriptionDialog> createState() =>
      _AdminOpsSubscriptionDialogState();
}

class _AdminOpsSubscriptionDialogState
    extends State<_AdminOpsSubscriptionDialog> {
  _BillingSubscription? _subscription;
  List<_BillingPlan> _plans = const <_BillingPlan>[];
  String? _selectedPlanId;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = _controller.backendClient;
      final url = _controller.backendUrl;
      final results = await Future.wait(<Future<Map<String, dynamic>>>[
        client.fetchAdminUserSubscription(url, widget.userId),
        client.fetchAdminBillingPlans(url),
      ]);
      if (!mounted) return;
      final subscription = _BillingSubscription.fromResponse(results[0]);
      final plans = _jsonMapList(results[1]['plans'])
          .map(_BillingPlan.fromJson)
          .where((plan) => plan.isActive || plan.id == subscription?.planId)
          .toList(growable: false);
      setState(() {
        _subscription = subscription;
        _plans = plans;
        _selectedPlanId = plans.any((plan) => plan.id == subscription?.planId)
            ? subscription?.planId
            : (plans.isEmpty ? null : plans.first.id);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _controller._friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _run(
    Future<_BillingSubscription?> Function() action,
    String notice,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final subscription = await action();
      if (!mounted) return;
      setState(() {
        _subscription = subscription;
        _notice = notice;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _controller._friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _assign() {
    final planId = _selectedPlanId;
    if (planId == null) return Future<void>.value();
    final planName = _plans.firstWhere((plan) => plan.id == planId).displayName;
    return _run(() async {
      final json = await _controller.backendClient.setAdminUserSubscription(
        _controller.backendUrl,
        userId: widget.userId,
        planId: planId,
      );
      return _BillingSubscription.fromResponse(json);
    }, appStrings.assignedArg1(planName));
  }

  Future<void> _cancel() {
    return _run(() async {
      final client = _controller.backendClient;
      final url = _controller.backendUrl;
      await client.cancelAdminUserSubscription(url, widget.userId);
      // Another subscription (e.g. a Stripe one) may still apply.
      final json = await client.fetchAdminUserSubscription(url, widget.userId);
      return _BillingSubscription.fromResponse(json);
    }, appStrings.subscriptionCanceled);
  }

  @override
  Widget build(BuildContext context) {
    final subscription = _subscription;
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(appStrings.subscription),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const _LoadingPlaceholder()
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    appStrings.planForArg1APlanAssigned(widget.username) +
                    appStrings.skipsStripeCheckout,
                    style: TextStyle(color: _textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(appStrings.currentPlan),
                  const SizedBox(height: 10),
                  if (subscription == null)
                    _EmptyText(appStrings.noSubscription)
                  else
                    _AdminOpsSubscriptionSummary(subscription: subscription),
                  const SizedBox(height: 18),
                  if (_plans.isEmpty)
                    _EmptyText(
                      appStrings.noActivePlansYetCreateOne,
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPlanId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: appStrings.assignPlan,
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final plan in _plans)
                          DropdownMenuItem<String>(
                            value: plan.id,
                            child: Text(
                              appStrings.arg1Arg22(plan.displayName, plan.priceLabel),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _selectedPlanId = value),
                    ),
                  _SaveFeedback(error: _error, notice: _notice),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appStrings.close),
        ),
        if (subscription != null && subscription.cancelable)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _danger),
            onPressed: _busy ? null : _cancel,
            child: Text(appStrings.cancelSubscription),
          ),
        FilledButton(
          onPressed: _loading || _busy || _selectedPlanId == null
              ? null
              : _assign,
          child: Text(appStrings.assignPlan),
        ),
      ],
    );
  }
}

class _AdminOpsSubscriptionSummary extends StatelessWidget {
  const _AdminOpsSubscriptionSummary({required this.subscription});

  final _BillingSubscription subscription;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                subscription.planName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subscription.priceLabel,
                style: TextStyle(fontSize: 12.5, color: _textMuted),
              ),
              if (subscription.billedByStripe) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  appStrings.billedThroughStripeSoItCan,
                  style: TextStyle(fontSize: 12, color: _textMuted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StatusPill(
          label: _titleCase(subscription.status.replaceAll('_', ' ')),
          color: _statusColor(subscription.status),
        ),
      ],
    );
  }
}

// ── Analytics tab ─────────────────────────────────────────────────────────────

class _AdminOpsAnalytics {
  const _AdminOpsAnalytics({
    required this.stats,
    required this.runsByDay,
    required this.newUsersByDay,
    required this.models,
    required this.statuses,
    required this.topUsers,
    required this.recentRuns,
  });

  factory _AdminOpsAnalytics.fromJson(Map<String, dynamic> json) {
    return _AdminOpsAnalytics(
      stats: <String, int>{
        for (final entry in _jsonMap(json['stats']).entries)
          entry.key: _asInt(entry.value),
      },
      runsByDay: <String, ({int runs, int tokens})>{
        for (final row in _jsonMapList(json['runsByDay']))
          _asText(row['date'], fallback: ''): (
            runs: _asInt(row['runs']),
            tokens: _asInt(row['tokens']),
          ),
      },
      newUsersByDay: <String, int>{
        for (final row in _jsonMapList(json['usersByDay']))
          _asText(row['date'], fallback: ''): _asInt(row['newUsers']),
      },
      models: <({String model, int runs, int tokens})>[
        for (final row in _jsonMapList(json['modelBreakdown']))
          (
            model: _asText(row['model'], fallback: 'unknown'),
            runs: _asInt(row['runs']),
            tokens: _asInt(row['tokens']),
          ),
      ],
      statuses: <({String status, int count})>[
        for (final row in _jsonMapList(json['statusBreakdown']))
          (
            status: _asText(row['status'], fallback: 'unknown'),
            count: _asInt(row['count']),
          ),
      ],
      topUsers: <({String name, int runs, int tokens, int storage})>[
        for (final row in _jsonMapList(json['topUsers']))
          (
            name: _asText(
              row['display_name'],
              fallback: _asText(row['username']),
            ),
            runs: _asInt(row['runs']),
            tokens: _asInt(row['tokens']),
            storage: _asInt(row['storage']),
          ),
      ],
      recentRuns: <({RunSummary run, String username})>[
        for (final row in _jsonMapList(json['recentRuns']))
          (run: RunSummary.fromJson(row), username: _asText(row['username'])),
      ],
    );
  }

  final Map<String, int> stats;

  /// Keyed by UTC day (`YYYY-MM-DD`); days without runs are absent.
  final Map<String, ({int runs, int tokens})> runsByDay;
  final Map<String, int> newUsersByDay;
  final List<({String model, int runs, int tokens})> models;
  final List<({String status, int count})> statuses;
  final List<({String name, int runs, int tokens, int storage})> topUsers;
  final List<({RunSummary run, String username})> recentRuns;

  int stat(String key) => stats[key] ?? 0;
}

/// `YYYY-MM-DD`, the key the analytics endpoint buckets days by.
String _adminOpsIsoDay(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

/// The last [count] UTC days, oldest first, matching the server's
/// `date(created_at)` buckets.
List<String> _adminOpsTrailingDays(int count) {
  final today = DateTime.now().toUtc();
  return <String>[
    for (var offset = count - 1; offset >= 0; offset--)
      _adminOpsIsoDay(today.subtract(Duration(days: offset))),
  ];
}

class _AdminAnalyticsTab extends StatefulWidget {
  const _AdminAnalyticsTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<_AdminAnalyticsTab> {
  static List<(int, String, String)> _ranges = <(int, String, String)>[
    (7, '7d', appStrings.n7Days),
    (30, '30d', appStrings.n30Days),
    (90, '90d', appStrings.n90Days),
    (365, '1y', appStrings.n365Days),
  ];

  int _rangeDays = 30;
  int _requestId = 0;
  _AdminOpsAnalytics? _data;
  bool _loading = true;
  String? _error;

  NeoAgentController get _controller => widget.controller;

  String get _rangeLabel =>
      _ranges.firstWhere((range) => range.$1 == _rangeDays).$3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Switching ranges quickly can overlap requests; keep only the latest.
    final requestId = ++_requestId;
    try {
      final json = await _controller.backendClient.fetchAdminAnalytics(
        _controller.backendUrl,
        rangeDays: _rangeDays,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _data = _AdminOpsAnalytics.fromJson(json);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = _controller._friendlyErrorMessage(error);
      });
    }
  }

  void _reload() {
    setState(() => _loading = true);
    _load();
  }

  void _setRange(int days) {
    _rangeDays = days;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: <ButtonSegment<int>>[
                for (final (days, short, long) in _ranges)
                  ButtonSegment<int>(
                    value: days,
                    label: Text(short),
                    tooltip: appStrings.lastArg1(long),
                  ),
              ],
              selected: <int>{_rangeDays},
              onSelectionChanged: (selection) => _setRange(selection.first),
            ),
            const Spacer(),
            _RefreshButton(busy: _loading, onPressed: _reload),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && data != null) ...<Widget>[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 14),
        ],
        if (_error != null) ...<Widget>[
          _InlineError(
            message: _error!,
            onDismiss: () => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
        ],
        if (data != null)
          _SectionStack(children: _buildReport(data))
        else if (_loading)
          const _LoadingPlaceholder(),
      ],
    );
  }

  List<Widget> _buildReport(_AdminOpsAnalytics data) {
    final days = _adminOpsTrailingDays(_rangeDays);
    final runBars = <({String day, int value, String tooltip})>[
      for (final day in days)
        (
          day: day,
          value: data.runsByDay[day]?.runs ?? 0,
          tooltip:
              appStrings.arg1Arg2Runs(_formatIsoDate(day), _formatNumber(data.runsByDay[day]?.runs ?? 0)) +
              appStrings.arg1Tokens(_formatTokenCount(data.runsByDay[day]?.tokens ?? 0)),
        ),
    ];
    final tokenBars = <({String day, int value, String tooltip})>[
      for (final day in days)
        (
          day: day,
          value: data.runsByDay[day]?.tokens ?? 0,
          tooltip:
              appStrings.arg1Arg2Tokens(_formatIsoDate(day), _formatTokenCount(data.runsByDay[day]?.tokens ?? 0)),
        ),
    ];
    final userBars = <({String day, int value, String tooltip})>[
      for (final day in days)
        (
          day: day,
          value: data.newUsersByDay[day] ?? 0,
          tooltip:
              appStrings.arg1Arg2NewAccounts(_formatIsoDate(day), data.newUsersByDay[day] ?? 0),
        ),
    ];
    final rangeRuns = runBars.fold<int>(0, (sum, bar) => sum + bar.value);
    final rangeUsers = userBars.fold<int>(0, (sum, bar) => sum + bar.value);
    final rangeTokens = tokenBars.fold<int>(0, (sum, bar) => sum + bar.value);
    final totalByStatus = data.statuses.fold<int>(
      0,
      (sum, entry) => sum + entry.count,
    );

    return <Widget>[
      _AdminOpsStatGrid(stats: _statTiles(data)),
      _AdminOpsPair(
        first: _SectionCard(
          title: appStrings.runsPerDay,
          description:
              appStrings.arg1RunsInTheLastArg2(_formatNumber(rangeRuns), _rangeLabel),
          child: _AdminOpsBarChart(bars: runBars, color: _accent),
        ),
        second: _SectionCard(
          title: appStrings.tokensPerDay,
          description:
              appStrings.arg1TokensInTheLastArg2(_formatTokenCount(rangeTokens), _rangeLabel),
          child: _AdminOpsBarChart(bars: tokenBars, color: _info),
        ),
      ),
      _SectionCard(
        title: appStrings.newAccountsPerDay,
        description:
            appStrings.arg1NewAccountsInTheLast(_formatNumber(rangeUsers), _rangeLabel),
        child: _AdminOpsBarChart(bars: userBars, color: _accentAlt),
      ),
      _AdminOpsPair(
        first: _SectionCard(
          title: 'Models',
          description: appStrings.mostUsedModelsInTheLast(_rangeLabel),
          child: _AdminOpsRankedList(
            emptyText: appStrings.noRunsInThisRange,
            items: <_AdminOpsRankedItem>[
              for (final entry in data.models)
                _AdminOpsRankedItem(
                  label: entry.model,
                  value: entry.runs,
                  valueLabel: appStrings.arg1Runs(_formatNumber(entry.runs)),
                  detail: appStrings.arg1Tokens(_formatTokenCount(entry.tokens)),
                  mono: true,
                ),
            ],
          ),
        ),
        second: _SectionCard(
          title: appStrings.runStatus,
          description: appStrings.everyRunOnThisServerAll,
          child: _AdminOpsRankedList(
            emptyText: appStrings.noRunsYet2,
            items: <_AdminOpsRankedItem>[
              for (final entry in data.statuses)
                _statusItem(entry.status, entry.count, totalByStatus),
            ],
          ),
        ),
      ),
      _SectionCard(
        title: appStrings.topUsers,
        description: appStrings.accountsByTokensUsedAllTime,
        child: _AdminOpsRankedList(
          emptyText: appStrings.noUsageYet,
          items: <_AdminOpsRankedItem>[
            for (final entry in data.topUsers)
              _AdminOpsRankedItem(
                label: entry.name,
                value: entry.tokens,
                valueLabel: appStrings.arg1Tokens(_formatTokenCount(entry.tokens)),
                detail:
                    appStrings.arg1RunsArg2(_formatNumber(entry.runs), _formatBytes(entry.storage)),
              ),
          ],
        ),
      ),
      _SectionCard(
        title: appStrings.recentRuns,
        description: appStrings.theLatestRunsAcrossEveryAccount,
        child: data.recentRuns.isEmpty
            ? _EmptyText(appStrings.noRunsYet2)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < data.recentRuns.length; i++) ...<Widget>[
                    if (i > 0) Divider(height: 1, color: _border),
                    _AdminOpsRecentRunRow(
                      run: data.recentRuns[i].run,
                      username: data.recentRuns[i].username,
                    ),
                  ],
                ],
              ),
      ),
    ];
  }

  List<({String title, String value, String helper})> _statTiles(
    _AdminOpsAnalytics data,
  ) {
    return <({String title, String value, String helper})>[
      (
        title: appStrings.totalUsers,
        value: _formatNumber(data.stat('totalUsers')),
        helper: appStrings.accountsOnThisServer,
      ),
      (
        title: appStrings.activeToday,
        value: _formatNumber(data.stat('activeToday')),
        helper: appStrings.signedInWithin24Hours,
      ),
      (
        title: appStrings.newThisWeek,
        value: _formatNumber(data.stat('newThisWeek')),
        helper: appStrings.joinedInTheLast7Days,
      ),
      (
        title: appStrings.activeSessions,
        value: _formatNumber(data.stat('activeSessions')),
        helper: appStrings.signedInDevices,
      ),
      (
        title: appStrings.totalRuns,
        value: _formatNumber(data.stat('totalRuns')),
        helper: appStrings.allTime,
      ),
      (
        title: appStrings.runsToday,
        value: _formatNumber(data.stat('runsToday')),
        helper: appStrings.last24Hours,
      ),
      (
        title: appStrings.runsThisWeek,
        value: _formatNumber(data.stat('runsThisWeek')),
        helper: appStrings.last7Days,
      ),
      (
        title: appStrings.successRate,
        value: '${data.stat('successRate')}%',
        helper: appStrings.runsThatCompleted,
      ),
      (
        title: appStrings.totalTokens,
        value: _formatTokenCount(data.stat('totalTokens')),
        helper: appStrings.allTime,
      ),
      (
        title: appStrings.tokensToday,
        value: _formatTokenCount(data.stat('tokensToday')),
        helper: appStrings.last24Hours,
      ),
      (
        title: appStrings.tokensPerRun,
        value: _formatTokenCount(data.stat('avgTokensPerRun')),
        helper: appStrings.averageAllTime,
      ),
      (
        title: appStrings.storage,
        value: _formatBytes(data.stat('totalStorage')),
        helper: appStrings.filesSavedByAllUsers,
      ),
    ];
  }

  _AdminOpsRankedItem _statusItem(String status, int count, int total) {
    // Same labels and colours as the Runs page.
    final run = RunSummary.fromJson(<String, dynamic>{'status': status});
    final percent = total == 0 ? 0 : (count * 100 / total).round();
    return _AdminOpsRankedItem(
      label: run.statusLabel,
      value: count,
      valueLabel: _formatNumber(count),
      detail: '$percent%',
      color: run.statusColor,
    );
  }
}

class _AdminOpsStatGrid extends StatelessWidget {
  const _AdminOpsStatGrid({required this.stats});

  final List<({String title, String value, String helper})> stats;

  int _columnsFor(double width) {
    if (width >= 1000) return 4;
    if (width >= 640) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final rows = <Widget>[];
        for (var start = 0; start < stats.length; start += columns) {
          if (start > 0) rows.add(const SizedBox(height: 12));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = start; i < start + columns; i++) ...<Widget>[
                    if (i > start) const SizedBox(width: 12),
                    Expanded(
                      child: i < stats.length
                          ? _OverviewCard(
                              title: stats[i].title,
                              value: stats[i].value,
                              helper: stats[i].helper,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// Two cards side by side on wide screens, stacked otherwise.
class _AdminOpsPair extends StatelessWidget {
  const _AdminOpsPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[first, const SizedBox(height: 16), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _AdminOpsBarChart extends StatelessWidget {
  const _AdminOpsBarChart({required this.bars, required this.color});

  static const double _height = 140;

  final List<({String day, int value, String tooltip})> bars;
  final Color color;

  static double _barHeight(int value, int peak) {
    if (value <= 0 || peak <= 0) return 2;
    return math.max(3, _height * value / peak);
  }

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final peak = bars.fold<int>(0, (max, bar) => math.max(max, bar.value));
    final gap = bars.length > 60 ? 0.0 : 2.0;
    final axisStyle = _monoStyle(size: 11, color: _textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: _height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final bar in bars)
                Expanded(
                  child: Tooltip(
                    message: bar.tooltip,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap / 2),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: double.infinity,
                          height: _barHeight(bar.value, peak),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: bar.value > 0 ? color : _border,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Text(_formatIsoDate(bars.first.day), style: axisStyle),
            const Spacer(),
            Text(appStrings.peakArg1(_formatNumber(peak)), style: axisStyle),
            const Spacer(),
            Text(_formatIsoDate(bars.last.day), style: axisStyle),
          ],
        ),
      ],
    );
  }
}

class _AdminOpsRankedItem {
  const _AdminOpsRankedItem({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.detail,
    this.color,
    this.mono = false,
  });

  final String label;
  final int value;
  final String valueLabel;
  final String? detail;
  final Color? color;
  final bool mono;
}

/// Rows with a bar proportional to the largest value in the list.
class _AdminOpsRankedList extends StatelessWidget {
  const _AdminOpsRankedList({required this.items, required this.emptyText});

  final List<_AdminOpsRankedItem> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _EmptyText(emptyText);
    final peak = items.fold<int>(0, (max, item) => math.max(max, item.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 14),
          _AdminOpsRankedRow(
            item: items[i],
            fraction: peak == 0 ? 0 : items[i].value / peak,
          ),
        ],
      ],
    );
  }
}

class _AdminOpsRankedRow extends StatelessWidget {
  const _AdminOpsRankedRow({required this.item, required this.fraction});

  final _AdminOpsRankedItem item;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: item.mono
                    ? _monoStyle(size: 12.5)
                    : TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              item.valueLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        if (item.detail != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(item.detail!, style: TextStyle(fontSize: 12, color: _textMuted)),
        ],
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: _bgSecondary,
            valueColor: AlwaysStoppedAnimation<Color>(item.color ?? _accent),
          ),
        ),
      ],
    );
  }
}

class _AdminOpsRecentRunRow extends StatelessWidget {
  const _AdminOpsRecentRunRow({required this.run, required this.username});

  final RunSummary run;
  final String username;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      '@$username',
      run.modelLabel,
      appStrings.arg1Tokens(_formatTokenCount(run.totalTokens)),
      run.createdAtLabel,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  run.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(label: run.statusLabel, color: run.statusColor),
        ],
      ),
    );
  }
}

// ── SQL tab ───────────────────────────────────────────────────────────────────

class _AdminOpsSqlResult {
  const _AdminOpsSqlResult({
    required this.columns,
    required this.rows,
    required this.truncated,
  });

  factory _AdminOpsSqlResult.fromJson(Map<String, dynamic> json) {
    final columns = _jsonStringList(json['columns']);
    return _AdminOpsSqlResult(
      columns: columns,
      rows: <List<String?>>[
        for (final row in _jsonMapList(json['rows']))
          <String?>[for (final column in columns) row[column]?.toString()],
      ],
      truncated: json['truncated'] == true,
    );
  }

  final List<String> columns;

  /// Cell text per row, in [columns] order; `null` is SQL NULL.
  final List<List<String?>> rows;
  final bool truncated;
}

/// Starting points for common questions; picking one fills the editor.
List<({String label, String query})> _adminOpsSqlTemplates =
    <({String label, String query})>[
      (
        label: appStrings.userSummary,
        query:
            'SELECT u.id, u.username, u.email,\n' +
            appStrings.uCreatedAtULastLogin +
            appStrings.countDistinctRIdAsRuns +
            '       COALESCE(SUM(r.total_tokens),0) AS tokens\n' +
            appStrings.fromUsersU +
            appStrings.leftJoinAgentRunsROn +
            appStrings.groupByUId +
            appStrings.orderByRunsDesc +
            appStrings.limit50,
      ),
      (
        label: appStrings.recentFailedRuns,
        query:
            'SELECT r.id, u.username, r.title, r.status,\n' +
            appStrings.rErrorRCreatedAt +
            appStrings.fromAgentRunsR +
            appStrings.joinUsersUOnUId +
            appStrings.whereRStatusFailed +
            appStrings.orderByRCreatedAtDesc +
            appStrings.limit50,
      ),
      (
        label: appStrings.artifactStorageByUser,
        query:
            'SELECT u.username,\n' +
            appStrings.countAIdAsFiles +
            appStrings.sumAByteSizeAsBytes +
            appStrings.roundSumAByteSize1048576 +
            appStrings.fromUsersU +
            appStrings.leftJoinArtifactsAOnA +
            appStrings.groupByUId +
            appStrings.orderByBytesDesc,
      ),
      (
        label: appStrings.activeSessions,
        query:
            'SELECT u.username, s.ip_address,\n' +
            appStrings.sUserAgentSCreatedAt +
            appStrings.fromUserSessionsS +
            appStrings.joinUsersUOnUId2 +
            appStrings.whereSRevokedAtIsNull +
            appStrings.andSExpiresAtDatetimeNow +
            appStrings.orderBySLastSeenAt +
            appStrings.limit50,
      ),
      (
        label: appStrings.runsPerDay30Days,
        query:
            'SELECT DATE(created_at) AS day,\n' +
            appStrings.countAsRuns +
            '       COALESCE(SUM(total_tokens),0) AS tokens\n' +
            appStrings.fromAgentRuns +
            appStrings.whereCreatedAtDatetimeNow30 +
            appStrings.groupByDay +
            appStrings.orderByDayDesc,
      ),
      (
        label: appStrings.mostUsedAgents,
        query:
            'SELECT a.slug, a.display_name, u.username AS owner,\n' +
            appStrings.countRIdAsRuns +
            appStrings.fromAgentsA +
            appStrings.joinUsersUOnUId3 +
            appStrings.leftJoinAgentRunsROn2 +
            appStrings.groupByAId +
            appStrings.orderByRunsDesc +
            appStrings.limit20,
      ),
      (
        label: appStrings.integrationConnections,
        query:
            'SELECT u.username, ic.provider_key,\n' +
            appStrings.icStatusIcAccountEmailIc +
            appStrings.fromIntegrationConnectionsIc +
            appStrings.joinUsersUOnUId4 +
            appStrings.orderByIcLastConnectedAt +
            appStrings.limit50,
      ),
      (
        label: appStrings.whoManagesWhom,
        query:
            'SELECT managed.username AS account,\n' +
            appStrings.managerUsernameAsManagedBy +
            appStrings.dAllowedPermissionsJsonAsAllowed +
            appStrings.dCreatedAtAsSince +
            appStrings.fromUserDelegationsD +
            appStrings.joinUsersManagedOnManagedId +
            appStrings.joinUsersManagerOnManagerId +
            appStrings.orderByManagerUsernameManagedUsername,
      ),
      (
        label: appStrings.allTables,
        query:
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      ),
      (
        label: appStrings.tableInfoUsers,
        query: "SELECT * FROM pragma_table_info('users')",
      ),
    ];

/// RFC 4180 CSV: fields with a comma, quote or newline are quoted.
String _adminOpsCsv(_AdminOpsSqlResult result) {
  String field(String? value) {
    final text = value ?? '';
    if (!text.contains(RegExp(r'[",\r\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  return <String>[
    result.columns.map(field).join(','),
    for (final row in result.rows) row.map(field).join(','),
  ].join('\n');
}

class _AdminSqlTab extends StatefulWidget {
  const _AdminSqlTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminSqlTab> createState() => _AdminSqlTabState();
}

class _AdminSqlTabState extends State<_AdminSqlTab> {
  final TextEditingController _query = TextEditingController();
  bool _running = false;
  String? _error;
  _AdminOpsSqlResult? _result;

  NeoAgentController get _controller => widget.controller;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final query = _query.text.trim();
    if (query.isEmpty || _running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final json = await _controller.backendClient.runAdminSql(
        _controller.backendUrl,
        query,
      );
      if (!mounted) return;
      setState(() {
        _result = _AdminOpsSqlResult.fromJson(json);
        _running = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = _controller._friendlyErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return _SectionStack(
      children: <Widget>[
        _SectionCard(
          title: appStrings.sqlConsole,
          description:
              'Query the live database. Only read-only SELECT and WITH ' +
              appStrings.queriesRunAnythingThatWritesIs,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: appStrings.insertATemplate,
                  onSelected: (query) {
                    _query.text = query;
                    _query.selection = TextSelection.collapsed(
                      offset: query.length,
                    );
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    for (final template in _adminOpsSqlTemplates)
                      PopupMenuItem<String>(
                        value: template.query,
                        child: Text(template.label),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.library_books_outlined,
                          size: 16,
                          color: _accent,
                        ),
                        const SizedBox(width: 6),
                        Text(appStrings.templates, style: TextStyle(color: _accent)),
                        Icon(Icons.arrow_drop_down, color: _accent),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(
                    LogicalKeyboardKey.enter,
                    control: true,
                  ): _run,
                  const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                      _run,
                },
                child: TextField(
                  controller: _query,
                  minLines: 6,
                  maxLines: 16,
                  keyboardType: TextInputType.multiline,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: _monoStyle(size: 13),
                  decoration: InputDecoration(
                    hintText:
                        'SELECT id, username, created_at FROM users LIMIT 10',
                    hintStyle: _monoStyle(size: 13, color: _textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _running ? null : _run,
                    icon: _running
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(appStrings.runQuery),
                  ),
                  Text(
                    appStrings.ctrlEnterRunsTheQuery,
                    style: TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          _InlineError(
            message: _error!,
            onDismiss: () => setState(() => _error = null),
          ),
        if (result != null)
          _SectionCard(
            title: appStrings.results,
            description:
                appStrings.arg1Arg23(_formatNumber(result.rows.length), result.rows.length == 1 ? 'row' : 'rows'),
            trailing: result.rows.isEmpty
                ? null
                : TextButton.icon(
                    style: _adminOpsActionStyle(),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _adminOpsCsv(result)),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(appStrings.copiedAsCsv)),
                      );
                    },
                    icon: Icon(Icons.copy, size: 16),
                    label: Text(appStrings.copyCsv),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (result.truncated) ...<Widget>[
                  _InlineNote(
                    icon: Icons.info_outline_rounded,
                    message:
                        appStrings.showingTheFirstArg1(_formatNumber(result.rows.length)) +
                        appStrings.rowsAddALimitOrA +
                        appStrings.theRest,
                  ),
                  const SizedBox(height: 12),
                ],
                if (result.rows.isEmpty)
                  _EmptyText(appStrings.theQueryReturnedNoRows)
                else
                  _AdminOpsSqlTable(result: result),
              ],
            ),
          ),
      ],
    );
  }
}

class _AdminOpsSqlTable extends StatelessWidget {
  const _AdminOpsSqlTable({required this.result});

  final _AdminOpsSqlResult result;

  @override
  Widget build(BuildContext context) {
    final nullStyle = _monoStyle(
      color: _textMuted,
    ).copyWith(fontStyle: FontStyle.italic);
    return Container(
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SelectionArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            primary: false,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 34,
              horizontalMargin: 14,
              columnSpacing: 28,
              headingRowColor: WidgetStatePropertyAll<Color>(_bgSecondary),
              headingTextStyle: _monoStyle(
                color: _textSecondary,
                weight: FontWeight.w700,
              ),
              dataTextStyle: _monoStyle(),
              columns: <DataColumn>[
                for (final column in result.columns)
                  DataColumn(label: Text(column)),
              ],
              rows: <DataRow>[
                for (final row in result.rows)
                  DataRow(
                    cells: <DataCell>[
                      for (final cell in row)
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Text(
                              cell ?? 'NULL',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: cell == null ? nullStyle : null,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
