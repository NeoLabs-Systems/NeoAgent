part of 'main.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum _ServerPhase {
  checking,
  prereqsFailed,
  notInstalled,
  installing,
  installed,
  installFailed,
}

enum _ServerTab { overview, configure, logs, update, danger }

extension _ServerTabX on _ServerTab {
  String get label {
    switch (this) {
      case _ServerTab.overview:
        return 'Overview';
      case _ServerTab.configure:
        return 'Configure';
      case _ServerTab.logs:
        return 'Logs';
      case _ServerTab.update:
        return 'Update';
      case _ServerTab.danger:
        return 'Danger';
    }
  }
}

// ─── Field descriptors ────────────────────────────────────────────────────────

class _EnvField {
  const _EnvField(this.key, this.label, {this.isSecret = false, this.hint = ''});

  final String key;
  final String label;
  final bool isSecret;
  final String hint;
}

const _serverFields = <_EnvField>[
  _EnvField('PORT', 'Port', hint: '3333'),
  _EnvField('PUBLIC_URL', 'Public URL', hint: 'https://neoagent.example.com'),
  _EnvField('NEOAGENT_DEPLOYMENT_MODE', 'Deployment mode', hint: 'self_hosted'),
  _EnvField('NEOAGENT_RELEASE_CHANNEL', 'Release channel', hint: 'stable'),
];

const _aiKeyFields = <_EnvField>[
  _EnvField('ANTHROPIC_API_KEY', 'Anthropic API key', isSecret: true),
  _EnvField('ANTHROPIC_BASE_URL', 'Anthropic base URL'),
  _EnvField('OPENAI_API_KEY', 'OpenAI API key', isSecret: true),
  _EnvField('OPENAI_BASE_URL', 'OpenAI base URL'),
  _EnvField('XAI_API_KEY', 'xAI API key', isSecret: true),
  _EnvField('XAI_BASE_URL', 'xAI base URL', hint: 'https://api.x.ai/v1'),
  _EnvField('GOOGLE_AI_KEY', 'Google AI key', isSecret: true),
  _EnvField('MINIMAX_API_KEY', 'MiniMax API key', isSecret: true),
  _EnvField('BRAVE_SEARCH_API_KEY', 'Brave Search API key', isSecret: true),
  _EnvField('OLLAMA_URL', 'Ollama URL', hint: 'http://localhost:11434'),
  _EnvField('DEEPGRAM_API_KEY', 'Deepgram API key', isSecret: true),
];

const _oauthFields = <_EnvField>[
  _EnvField('GOOGLE_OAUTH_CLIENT_ID', 'Google client ID', isSecret: true),
  _EnvField('GOOGLE_OAUTH_CLIENT_SECRET', 'Google client secret', isSecret: true),
  _EnvField('GOOGLE_OAUTH_REDIRECT_URI', 'Google redirect URI'),
  _EnvField('NOTION_OAUTH_CLIENT_ID', 'Notion client ID', isSecret: true),
  _EnvField('NOTION_OAUTH_CLIENT_SECRET', 'Notion client secret', isSecret: true),
  _EnvField('NOTION_OAUTH_REDIRECT_URI', 'Notion redirect URI'),
  _EnvField('MICROSOFT_OAUTH_CLIENT_ID', 'Microsoft client ID', isSecret: true),
  _EnvField('MICROSOFT_OAUTH_CLIENT_SECRET', 'Microsoft client secret', isSecret: true),
  _EnvField('MICROSOFT_OAUTH_REDIRECT_URI', 'Microsoft redirect URI'),
  _EnvField('MICROSOFT_OAUTH_TENANT_ID', 'Microsoft tenant ID'),
  _EnvField('SLACK_OAUTH_CLIENT_ID', 'Slack client ID', isSecret: true),
  _EnvField('SLACK_OAUTH_CLIENT_SECRET', 'Slack client secret', isSecret: true),
  _EnvField('SLACK_OAUTH_REDIRECT_URI', 'Slack redirect URI'),
  _EnvField('FIGMA_OAUTH_CLIENT_ID', 'Figma client ID', isSecret: true),
  _EnvField('FIGMA_OAUTH_CLIENT_SECRET', 'Figma client secret', isSecret: true),
  _EnvField('FIGMA_OAUTH_REDIRECT_URI', 'Figma redirect URI'),
  _EnvField('GITHUB_OAUTH_CLIENT_ID', 'GitHub client ID', isSecret: true),
  _EnvField('GITHUB_OAUTH_CLIENT_SECRET', 'GitHub client secret', isSecret: true),
  _EnvField('GITHUB_OAUTH_REDIRECT_URI', 'GitHub redirect URI'),
];

const _voiceFields = <_EnvField>[
  _EnvField('DEEPGRAM_BASE_URL', 'Deepgram base URL',
      hint: 'https://api.deepgram.com'),
  _EnvField('DEEPGRAM_MODEL', 'Deepgram model', hint: 'nova-3'),
  _EnvField('DEEPGRAM_LANGUAGE', 'Deepgram language', hint: 'multi'),
  _EnvField('TELNYX_WEBHOOK_TOKEN', 'Telnyx webhook token', isSecret: true),
];

// ─── .env helpers (pure functions) ────────────────────────────────────────────

Map<String, String> _parseEnvFile(String path) {
  final f = File(path);
  if (!f.existsSync()) return {};
  final result = <String, String>{};
  for (final line in f.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx < 0) continue;
    result[line.substring(0, idx).trim()] = line.substring(idx + 1);
  }
  return result;
}

void _writeEnvFile(String path, Map<String, String> updated) {
  final f = File(path);
  final original = f.existsSync() ? f.readAsLinesSync() : <String>[];
  final seen = <String>{};
  final out = <String>[];

  for (final line in original) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      out.add(line);
      continue;
    }
    final idx = line.indexOf('=');
    if (idx < 0) {
      out.add(line);
      continue;
    }
    final key = line.substring(0, idx).trim();
    seen.add(key);
    final newVal = updated[key];
    if (newVal != null && newVal.isNotEmpty) {
      out.add('$key=$newVal');
    } else if (newVal == null) {
      out.add(line); // preserve unmanaged keys untouched
    }
    // empty newVal → omit the line (clear the value)
  }

  for (final entry in updated.entries) {
    if (!seen.contains(entry.key) && entry.value.isNotEmpty) {
      out.add('${entry.key}=${entry.value}');
    }
  }

  f.writeAsStringSync('${out.join('\n')}\n');
}

// ─── ServerPanel ──────────────────────────────────────────────────────────────

class ServerPanel extends StatefulWidget {
  const ServerPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<ServerPanel> createState() => _ServerPanelState();
}

class _ServerPanelState extends State<ServerPanel> {
  _ServerPhase _phase = _ServerPhase.checking;
  _ServerTab _activeTab = _ServerTab.overview;

  // prereq / install
  String? _nodePath;
  String? _npmPath;
  bool _hasGit = false;
  String? _installDir;
  bool _serviceRegistered = false;
  bool _serviceRunning = false;
  bool _serviceActionRunning = false;

  // streaming
  final List<String> _log = [];
  final _logScrollCtrl = ScrollController();
  Process? _runningProcess;

  // install form
  final _portCtrl = TextEditingController(text: '3333');
  final _dirCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  // configure tab
  bool _configLoaded = false;
  bool _configSaving = false;
  final Map<String, TextEditingController> _envCtrl = {};
  bool _secureCookies = false;
  bool _trustProxy = false;

  LocalRuntimePaths get _runtimePaths => LocalRuntimePaths.fromEnvironment(
    Platform.environment,
    isWindows: Platform.isWindows,
  );
  String get _home => _runtimePaths.homeDirectory;
  String get _envPath => _runtimePaths.envFile;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _logScrollCtrl.dispose();
    _portCtrl.dispose();
    _dirCtrl.dispose();
    _keyCtrl.dispose();
    for (final c in _envCtrl.values) {
      c.dispose();
    }
    _runningProcess?.kill(ProcessSignal.sigterm);
    super.dispose();
  }

  Future<String?> _which(String cmd) async {
    try {
      final r = await Process.run(
          Platform.isWindows ? 'where' : 'which', [cmd]);
      if (r.exitCode == 0) {
        return (r.stdout as String).trim().split('\n').first.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _phase = _ServerPhase.checking);

    _nodePath = await _which('node');
    if (_nodePath == null && !Platform.isWindows) {
      for (final p in ['/opt/homebrew/bin/node', '/usr/local/bin/node']) {
        if (File(p).existsSync()) {
          _nodePath = p;
          break;
        }
      }
    }
    _npmPath = await _which('npm');
    _hasGit = (await _which('git')) != null;

    if (_nodePath == null || _npmPath == null || !_hasGit) {
      if (mounted) setState(() => _phase = _ServerPhase.prereqsFailed);
      return;
    }

    final defaultDir = '$_home/NeoAgent';
    if (File('$defaultDir/bin/neoagent.js').existsSync()) {
      _installDir = defaultDir;
      if (_dirCtrl.text.isEmpty) _dirCtrl.text = _installDir!;
    } else if (_dirCtrl.text.isNotEmpty &&
        File('${_dirCtrl.text}/bin/neoagent.js').existsSync()) {
      _installDir = _dirCtrl.text;
    } else {
      _installDir = null;
      if (_dirCtrl.text.isEmpty) _dirCtrl.text = defaultDir;
    }

    _serviceRegistered = _checkServiceRegistered();
    if (_serviceRegistered) {
      _serviceRunning = await _checkServiceRunning();
    }

    if (!mounted) return;
    setState(() {
      _phase = _serviceRegistered
          ? _ServerPhase.installed
          : _ServerPhase.notInstalled;
    });
  }

  bool _checkServiceRegistered() {
    if (Platform.isMacOS) {
      return File('$_home/Library/LaunchAgents/com.neoagent.plist')
          .existsSync();
    }
    if (Platform.isLinux) {
      return File('$_home/.config/systemd/user/neoagent.service').existsSync();
    }
    return File(_runtimePaths.pidFile).existsSync();
  }

  Future<bool> _checkServiceRunning() async {
    try {
      if (Platform.isMacOS) {
        final r = await Process.run('launchctl', ['list', 'com.neoagent']);
        return r.exitCode == 0;
      }
      if (Platform.isLinux) {
        final r = await Process.run(
          'systemctl',
          ['--user', 'is-active', '--quiet', 'neoagent'],
        );
        return r.exitCode == 0;
      }
    } catch (_) {}
    return false;
  }

  void _ensureEnvFile() {
    if (!File(_envPath).existsSync()) {
      Directory(_runtimePaths.runtimeHome).createSync(recursive: true);
      final port =
          _portCtrl.text.trim().isEmpty ? '3333' : _portCtrl.text.trim();
      final buf = StringBuffer()
        ..writeln('NODE_ENV=production')
        ..writeln('PORT=$port');
      final key = _keyCtrl.text.trim();
      if (key.isNotEmpty) buf.writeln('ANTHROPIC_API_KEY=$key');
      File(_envPath).writeAsStringSync(buf.toString());
    }
  }

  Future<void> _runStreamedCommand(
    List<String> args, {
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    if (_installDir == null) {
      onFailure();
      return;
    }
    final process = await Process.start(
      _nodePath!,
      args,
      workingDirectory: _installDir,
    );
    _runningProcess = process;

    void onChunk(String data) {
      if (!mounted) return;
      setState(() => _log.add(data));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollCtrl.hasClients) {
          _logScrollCtrl.jumpTo(_logScrollCtrl.position.maxScrollExtent);
        }
      });
    }

    process.stdout.transform(utf8.decoder).listen(onChunk);
    process.stderr.transform(utf8.decoder).listen(onChunk);

    final exit = await process.exitCode;
    _runningProcess = null;
    if (!mounted) return;
    if (exit == 0) {
      onSuccess();
    } else {
      onFailure();
    }
  }

  Future<void> _runInstall() async {
    final dir = _dirCtrl.text.trim().isEmpty
        ? '$_home/NeoAgent'
        : _dirCtrl.text.trim();
    if (!File('$dir/bin/neoagent.js').existsSync()) {
      setState(() {
        _phase = _ServerPhase.installFailed;
        _log
          ..clear()
          ..add('Cannot find $dir/bin/neoagent.js — check the install directory.\n');
      });
      return;
    }
    _installDir = dir;
    _ensureEnvFile();
    setState(() {
      _phase = _ServerPhase.installing;
      _log.clear();
    });
    await _runStreamedCommand(
      ['bin/neoagent.js', 'install'],
      onSuccess: () => _refresh(),
      onFailure: () => setState(() => _phase = _ServerPhase.installFailed),
    );
  }

  Future<void> _runUpdate() async {
    setState(() => _log.clear());
    await _runStreamedCommand(
      ['bin/neoagent.js', 'update'],
      onSuccess: () {
        setState(() => _log.add('\n✓ Update complete.\n'));
        _refresh();
      },
      onFailure: () =>
          setState(() => _log.add('\n✗ Update failed.\n')),
    );
  }

  Future<void> _runUninstall() async {
    setState(() => _log.clear());
    await _runStreamedCommand(
      ['bin/neoagent.js', 'uninstall'],
      onSuccess: () => _refresh(),
      onFailure: () =>
          setState(() => _log.add('\n✗ Uninstall failed.\n')),
    );
  }

  Future<void> _serviceAction(String cmd) async {
    if (_installDir == null || _nodePath == null || _serviceActionRunning) return;
    setState(() => _serviceActionRunning = true);
    final result = await Process.run(
      _nodePath!,
      ['bin/neoagent.js', cmd],
      workingDirectory: _installDir,
    );
    if (result.exitCode != 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to $cmd server (exit ${result.exitCode}).'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    if (mounted) setState(() => _serviceActionRunning = false);
    await _refresh();
  }

  void _openDashboard() {
    final port = _envCtrl['PORT']?.text.trim().isNotEmpty == true
        ? _envCtrl['PORT']!.text.trim()
        : _portCtrl.text.trim().isEmpty
            ? '3333'
            : _portCtrl.text.trim();
    final url = 'http://localhost:$port';
    if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isWindows) {
      Process.run('start', [url], runInShell: true);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [url]);
    }
  }

  void _loadConfig() {
    if (_configLoaded) return;
    final env = _parseEnvFile(_envPath);
    for (final group in [_serverFields, _aiKeyFields, _oauthFields, _voiceFields]) {
      for (final field in group) {
        _envCtrl[field.key] =
            TextEditingController(text: env[field.key] ?? '');
      }
    }
    _secureCookies =
        (env['SECURE_COOKIES'] ?? 'false').toLowerCase() == 'true';
    _trustProxy = (env['TRUST_PROXY'] ?? 'false').toLowerCase() == 'true';
    _configLoaded = true;
  }

  Future<void> _saveConfig() async {
    if (_installDir == null) return;
    setState(() => _configSaving = true);
    final updated = <String, String>{};
    for (final entry in _envCtrl.entries) {
      updated[entry.key] = entry.value.text.trim();
    }
    updated['SECURE_COOKIES'] = _secureCookies ? 'true' : 'false';
    updated['TRUST_PROXY'] = _trustProxy ? 'true' : 'false';
    updated['NODE_ENV'] = 'production';
    _writeEnvFile(_envPath, updated);
    if (mounted) {
      setState(() => _configSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved. Restart the server for changes to take effect.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        const _PageTitle(
          title: 'Server',
          subtitle:
              'Install and manage the NeoAgent background service on this machine.',
        ),
        const SizedBox(height: 16),
        _buildPhaseContent(),
      ],
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case _ServerPhase.checking:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(),
          ),
        );
      case _ServerPhase.prereqsFailed:
        return _buildPrereqFailed();
      case _ServerPhase.notInstalled:
        return _buildNotInstalled();
      case _ServerPhase.installing:
        return _buildInstalling();
      case _ServerPhase.installed:
        return _buildInstalled();
      case _ServerPhase.installFailed:
        return _buildInstallFailed();
    }
  }

  Widget _buildPrereqFailed() {
    final missing = <String>[];
    if (_nodePath == null) missing.add('Node.js (nodejs.org)');
    if (_npmPath == null) missing.add('npm (bundled with Node.js)');
    if (!_hasGit) missing.add('git (git-scm.com)');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _InlineError(
              message:
                  'Missing: ${missing.join(', ')}. Install them then click Retry.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotInstalled() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PrereqRow(label: 'Node.js', ok: _nodePath != null),
            const SizedBox(height: 6),
            _PrereqRow(label: 'npm', ok: _npmPath != null),
            const SizedBox(height: 6),
            _PrereqRow(label: 'git', ok: _hasGit),
            const Divider(height: 28),
            TextField(
              controller: _dirCtrl,
              decoration: const InputDecoration(
                labelText: 'Install directory',
                hintText: '~/NeoAgent',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '3333',
                prefixIcon: Icon(Icons.lan_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Anthropic API key (optional)',
                hintText: 'sk-ant-...',
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _runInstall,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _bgPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Install NeoAgent'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalling() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Installing NeoAgent...')),
                TextButton(
                  onPressed: () {
                    _runningProcess?.kill(ProcessSignal.sigterm);
                    setState(() => _phase = _ServerPhase.notInstalled);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InstallLogCard(lines: _log, scrollController: _logScrollCtrl),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalled() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Sub-navigation
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_ServerTab>(
                segments: _ServerTab.values
                    .map(
                      (t) => ButtonSegment<_ServerTab>(
                        value: t,
                        label: Text(t.label),
                      ),
                    )
                    .toList(),
                selected: {_activeTab},
                onSelectionChanged: (Set<_ServerTab> sel) {
                  final tab = sel.first;
                  if (tab == _ServerTab.configure) _loadConfig();
                  setState(() => _activeTab = tab);
                },
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 20),
            _buildActiveTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    switch (_activeTab) {
      case _ServerTab.overview:
        return _buildOverviewTab();
      case _ServerTab.configure:
        return _buildConfigureTab();
      case _ServerTab.logs:
        return _buildLogsTab();
      case _ServerTab.update:
        return _buildUpdateTab();
      case _ServerTab.danger:
        return _buildDangerTab();
    }
  }

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _StatusPill(
              label: _serviceRunning ? 'Running' : 'Stopped',
              color: _serviceRunning ? _success : _textSecondary,
            ),
            if (_serviceActionRunning) ...<Widget>[
              const SizedBox(width: 10),
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            const Spacer(),
            IconButton(
              onPressed: _serviceActionRunning ? null : _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh status',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _openDashboard,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _bgPrimary,
              ),
              icon: const Icon(Icons.open_in_browser_outlined),
              label: const Text('Open Dashboard'),
            ),
            if (!_serviceRunning)
              OutlinedButton.icon(
                onPressed: _serviceActionRunning ? null : () => _serviceAction('start'),
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('Start'),
              ),
            if (_serviceRunning)
              OutlinedButton.icon(
                onPressed: _serviceActionRunning ? null : () => _serviceAction('stop'),
                icon: const Icon(Icons.stop_outlined),
                label: const Text('Stop'),
              ),
            OutlinedButton.icon(
              onPressed: _serviceActionRunning ? null : () => _serviceAction('restart'),
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('Restart'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_installDir != null)
          Text(
            _installDir!,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }

  Widget _buildConfigureTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Server section
        _SectionLabel(label: 'Server'),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Secure cookies'),
          subtitle: const Text('Enable when behind HTTPS'),
          value: _secureCookies,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _secureCookies = v),
        ),
        SwitchListTile(
          title: const Text('Trust proxy'),
          subtitle: const Text('Enable when behind a reverse proxy'),
          value: _trustProxy,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _trustProxy = v),
        ),
        const SizedBox(height: 8),
        for (final f in _serverFields) ...<Widget>[
          _EnvTextField(field: f, controller: _envCtrl[f.key]!),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),

        // AI Keys section
        _SectionLabel(label: 'AI Keys'),
        const SizedBox(height: 12),
        for (final f in _aiKeyFields) ...<Widget>[
          _EnvTextField(field: f, controller: _envCtrl[f.key]!),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),

        // OAuth section (collapsed)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('OAuth integrations'),
          children: <Widget>[
            const SizedBox(height: 8),
            for (final f in _oauthFields) ...<Widget>[
              _EnvTextField(field: f, controller: _envCtrl[f.key]!),
              const SizedBox(height: 10),
            ],
          ],
        ),

        // Voice section (collapsed)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Voice & telephony'),
          children: <Widget>[
            const SizedBox(height: 8),
            for (final f in _voiceFields) ...<Widget>[
              _EnvTextField(field: f, controller: _envCtrl[f.key]!),
              const SizedBox(height: 10),
            ],
          ],
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _configSaving ? null : _saveConfig,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: _bgPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _configSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsTab() {
    final path = _runtimePaths.logFile;
    final f = File(path);
    String content;
    if (f.existsSync()) {
      final lines = f.readAsLinesSync();
      final tail =
          lines.length > 300 ? lines.sublist(lines.length - 300) : lines;
      content = tail.join('\n');
    } else {
      content = '(log file not found at $path)';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Last 300 lines', style: TextStyle(color: _textSecondary, fontSize: 12)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 340,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFE6EDF3),
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateTab() {
    final isRunning = _runningProcess != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pull the latest version and restart the service.',
          style: TextStyle(color: _textSecondary, height: 1.55),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed: isRunning ? null : _runUpdate,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _bgPrimary,
              ),
              icon: isRunning
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.system_update_outlined),
              label: const Text('Update NeoAgent'),
            ),
            if (isRunning) ...<Widget>[
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  _runningProcess?.kill(ProcessSignal.sigterm);
                  setState(() {});
                },
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
        if (_log.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _InstallLogCard(lines: _log, scrollController: _logScrollCtrl),
        ],
      ],
    );
  }

  Widget _buildDangerTab() {
    final isRunning = _runningProcess != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _danger.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.warning_outlined, color: _danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Uninstalling removes the service and stops NeoAgent from starting at login. Your data and configuration are preserved.',
                  style: TextStyle(color: _textSecondary, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: isRunning
              ? null
              : () => _confirmUninstall(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: _danger,
            side: BorderSide(color: _danger),
          ),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Uninstall NeoAgent'),
        ),
        if (_log.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _InstallLogCard(lines: _log, scrollController: _logScrollCtrl),
        ],
      ],
    );
  }

  Future<void> _confirmUninstall(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uninstall NeoAgent?'),
        content: const Text(
          'This removes the background service and prevents NeoAgent from starting at login. Your data and .env configuration are preserved.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _log.clear();
        _activeTab = _ServerTab.danger;
      });
      await _runUninstall();
    }
  }

  Widget _buildInstallFailed() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _InlineError(
                message: 'Installation failed. Check the log below.'),
            const SizedBox(height: 12),
            if (_log.isNotEmpty)
              _InstallLogCard(lines: _log, scrollController: _logScrollCtrl),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _runInstall,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

class _PrereqRow extends StatelessWidget {
  const _PrereqRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          ok ? Icons.check_circle_outline : Icons.cancel_outlined,
          color: ok ? _success : _danger,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: _textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _EnvTextField extends StatefulWidget {
  const _EnvTextField({required this.field, required this.controller});

  final _EnvField field;
  final TextEditingController controller;

  @override
  State<_EnvTextField> createState() => _EnvTextFieldState();
}

class _EnvTextFieldState extends State<_EnvTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.field.isSecret && _obscure,
      decoration: InputDecoration(
        labelText: widget.field.label,
        hintText: widget.field.hint.isNotEmpty ? widget.field.hint : null,
        suffixIcon: widget.field.isSecret
            ? IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}

class _InstallLogCard extends StatelessWidget {
  const _InstallLogCard({required this.lines, required this.scrollController});

  final List<String> lines;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(14),
        child: SelectableText(
          lines.isEmpty ? '(waiting for output…)' : lines.join(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFFE6EDF3),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
