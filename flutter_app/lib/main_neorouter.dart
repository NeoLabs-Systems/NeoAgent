part of 'main.dart';

/// "Connect NeoRouter": one sign-in sends chat, System One, speech to text,
/// live voice, memory search, images and web search through a NeoRouter.
/// The admin console shows it for the whole server ([scope] 'server'); for a
/// person's own account ('user') it is a row in Settings → Models → Bring
/// your own key, laid out like the other providers there. Each kind of work
/// can be switched off again under Manage; it then goes back to its usual
/// provider.
class NeoRouterConnectCard extends StatefulWidget {
  const NeoRouterConnectCard({
    super.key,
    required this.controller,
    required this.scope,
  });

  final NeoAgentController controller;
  final String scope;

  @override
  State<NeoRouterConnectCard> createState() => _NeoRouterConnectCardState();
}

class _NeoRouterConnectCardState extends State<NeoRouterConnectCard> {
  Map<String, dynamic>? _state;
  String? _loadError;
  bool _busy = false;
  Map<String, dynamic>? _pending;

  /// Bumped by every start and cancel, so a cancelled sign-in that is still
  /// polling can never touch a newer one.
  int _attempt = 0;

  bool get _server => widget.scope == 'server';

  Map<String, dynamic> get _mine =>
      _neoMap(_state?[_server ? 'server' : 'user']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await widget.controller.fetchNeoRouter();
      if (!mounted) return;
      setState(() {
        _state = state;
        _loadError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadError = widget.controller.friendlyErrorMessage(error),
        );
      }
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.friendlyErrorMessage(error))),
    );
  }

  Future<void> _connect() async {
    final controller = widget.controller;
    final pending = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _NeoRouterConnectDialog(controller: controller, scope: widget.scope),
    );
    if (pending == null || !mounted) return;
    final attempt = ++_attempt;
    bool isCurrent() => mounted && attempt == _attempt;
    setState(() => _pending = pending);
    try {
      await controller.waitForNeoRouterConnect(
        pending['id']?.toString() ?? '',
        isActive: isCurrent,
      );
      if (!mounted || !isCurrent()) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appStrings.neoRouterConnected)));
      await _load();
    } catch (error) {
      if (isCurrent()) _showError(error);
    } finally {
      if (isCurrent()) setState(() => _pending = null);
    }
  }

  void _cancel() {
    setState(() {
      _attempt++;
      _pending = null;
    });
  }

  Future<void> _manage() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _NeoRouterRolesDialog(
        controller: widget.controller,
        scope: widget.scope,
        allRoles: _neoList(
          _state?['roles'],
        ).map((item) => item.toString()).toList(),
        connection: _mine,
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _disconnect() async {
    await _confirmDelete(
      context,
      title: appStrings.neoRouterDisconnect,
      message: appStrings.neoRouterDisconnectBody,
      confirmLabel: appStrings.neoRouterDisconnect,
      onConfirm: () async {
        setState(() => _busy = true);
        try {
          await widget.controller.disconnectNeoRouter(widget.scope);
          await _load();
        } catch (error) {
          if (mounted) _showError(error);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }

  Widget _row() {
    final pending = _pending;
    if (pending != null) {
      return _SettingsRow(
        anchor: 'neorouter',
        label: 'NeoRouter',
        description: appStrings.neoRouterWaitingArg1(
          pending['userCode']?.toString() ?? '',
        ),
        control: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            TextButton(
              onPressed: () => widget.controller
                  .openNeoRouterApproval(pending['url']?.toString() ?? '')
                  .catchError(_showError),
              child: Text(appStrings.neoRouterOpenAgain),
            ),
            TextButton(onPressed: _cancel, child: Text(appStrings.cancel)),
          ],
        ),
      );
    }
    if (_state == null) {
      return _SettingsRow(
        anchor: 'neorouter',
        label: 'NeoRouter',
        description: _loadError,
        control: _loadError == null
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(onPressed: _load, child: Text(appStrings.refresh)),
      );
    }
    final mine = _mine;
    if (mine['connected'] != true) {
      // The server's own NeoRouter stays unnamed here: people only learn
      // that one is in use, never where it lives.
      final serverInUse =
          !_server && _neoMap(_state?['server'])['connected'] == true;
      return _SettingsRow(
        anchor: 'neorouter',
        label: 'NeoRouter',
        description: serverInUse
            ? appStrings.neoRouterServerInUse
            : _server
            ? null
            : appStrings.neoRouterUserDescription,
        control: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _StatusPill(label: appStrings.notSetUp, color: _textMuted),
            OutlinedButton(
              onPressed: _busy ? null : _connect,
              child: Text(appStrings.connect),
            ),
          ],
        ),
      );
    }
    final reachable = mine['offer'] is Map;
    return _SettingsRow(
      anchor: 'neorouter',
      label: 'NeoRouter',
      description: reachable
          ? mine['address']?.toString()
          : appStrings.neoRouterUnreachable,
      control: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _StatusPill(
            label: appStrings.connected,
            color: reachable ? _success : _warning,
          ),
          OutlinedButton(
            onPressed: _busy ? null : _manage,
            child: Text(appStrings.manage),
          ),
          IconButton(
            tooltip: appStrings.neoRouterDisconnect,
            onPressed: _busy ? null : _disconnect,
            icon: Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_server) return _row();
    return _SectionCard(
      title: 'NeoRouter',
      description: appStrings.neoRouterServerDescription,
      child: _row(),
    );
  }
}

/// Asks for the NeoRouter address and starts its device sign-in. Pops with
/// the started sign-in (`id`, `url`, `userCode`) once NeoRouter answered.
class _NeoRouterConnectDialog extends StatefulWidget {
  const _NeoRouterConnectDialog({
    required this.controller,
    required this.scope,
  });

  final NeoAgentController controller;
  final String scope;

  @override
  State<_NeoRouterConnectDialog> createState() =>
      _NeoRouterConnectDialogState();
}

class _NeoRouterConnectDialogState extends State<_NeoRouterConnectDialog> {
  final TextEditingController _address = TextEditingController();
  bool _starting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final address = _address.text.trim();
    if (address.isEmpty || _starting) return;
    setState(() {
      _starting = true;
      _errorMessage = null;
    });
    try {
      final pending = await widget.controller.startNeoRouterConnect(
        widget.scope,
        address,
      );
      if (mounted) Navigator.of(context).pop(pending);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = widget.controller.friendlyErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(appStrings.neoRouterConnect),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.scope == 'server'
                  ? appStrings.neoRouterServerDescription
                  : appStrings.neoRouterUserDescription,
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              autofocus: true,
              autocorrect: false,
              enabled: !_starting,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: appStrings.neoRouterAddress,
                hintText: 'https://router.example.com',
              ),
              onSubmitted: (_) => _start(),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: _danger)),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _starting ? null : () => Navigator.of(context).pop(),
          child: Text(appStrings.cancel),
        ),
        FilledButton(
          onPressed: _starting ? null : _start,
          child: _starting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(appStrings.connect),
        ),
      ],
    );
  }
}

/// The kinds of work that go through the connected NeoRouter, one switch
/// each, with how much the router has for them. Saves on every switch.
class _NeoRouterRolesDialog extends StatefulWidget {
  const _NeoRouterRolesDialog({
    required this.controller,
    required this.scope,
    required this.allRoles,
    required this.connection,
  });

  final NeoAgentController controller;
  final String scope;
  final List<String> allRoles;
  final Map<String, dynamic> connection;

  @override
  State<_NeoRouterRolesDialog> createState() => _NeoRouterRolesDialogState();
}

class _NeoRouterRolesDialogState extends State<_NeoRouterRolesDialog> {
  late Set<String> _roles = _neoList(
    widget.connection['roles'],
  ).map((item) => item.toString()).toSet();
  bool _saving = false;
  String? _errorMessage;

  Future<void> _setRole(String role, bool on) async {
    final previous = _roles;
    final next = <String>{...previous};
    on ? next.add(role) : next.remove(role);
    setState(() {
      _roles = next;
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.controller.saveNeoRouterRoles(widget.scope, next.toList());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _roles = previous;
        _errorMessage = widget.controller.friendlyErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _roleLabel(String role) => switch (role) {
    'chat' => appStrings.neoRouterRoleChat,
    'system_one' => appStrings.neoRouterRoleSystemOne,
    'transcription' => appStrings.neoRouterRoleTranscription,
    'live' => appStrings.neoRouterRoleLive,
    'embeddings' => appStrings.neoRouterRoleEmbeddings,
    'images' => appStrings.neoRouterRoleImages,
    'search' => appStrings.neoRouterRoleSearch,
    _ => role,
  };

  // How many models NeoRouter has for this work; when there are none, why:
  // the key may not use them, or (System One) only safety classifiers exist.
  String _roleAvailability(
    String role,
    Map<String, dynamic> counts,
    Map<String, dynamic> notAllowed,
  ) {
    final available = _asInt(counts[role]);
    if (available > 0) return appStrings.neoRouterModelCountArg1(available);
    final hidden = _asInt(notAllowed[role]);
    if (hidden > 0) return appStrings.neoRouterNotAllowedArg1(hidden);
    if (role == 'system_one') return appStrings.neoRouterNoDecisionModels;
    return appStrings.neoRouterNoModels;
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.connection['offer'] is Map
        ? _neoMap(widget.connection['offer'])
        : null;
    final counts = _neoMap(offer?['roles']);
    final notAllowed = _neoMap(offer?['notAllowed']);
    return AlertDialog(
      title: const Text('NeoRouter'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                offer == null
                    ? appStrings.neoRouterUnreachable
                    : widget.scope == 'server'
                    ? appStrings.neoRouterServerDescription
                    : appStrings.neoRouterUserDescription,
                style: TextStyle(color: _textSecondary, height: 1.4),
              ),
              const SizedBox(height: 8),
              for (final role in widget.allRoles)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_roleLabel(role)),
                  subtitle: offer == null
                      ? null
                      : Text(
                          _roleAvailability(role, counts, notAllowed),
                          style: TextStyle(color: _textSecondary),
                        ),
                  value: _roles.contains(role),
                  onChanged: _saving ? null : (value) => _setRole(role, value),
                ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: TextStyle(color: _danger)),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appStrings.close),
        ),
      ],
    );
  }
}

Map<String, dynamic> _neoMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Object?> _neoList(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];
