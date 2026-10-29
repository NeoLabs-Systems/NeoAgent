part of 'main.dart';

/// "Connect NeoRouter": one sign-in sends chat, System One, speech to text,
/// live voice, memory search, images and web search through a NeoRouter.
/// The admin console shows it for the whole server ([scope] 'server'),
/// Settings → Models for the person's own account ('user'). Each kind of
/// work can be switched off again; it then goes back to its usual provider.
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
  final TextEditingController _address = TextEditingController();
  Map<String, dynamic>? _state;
  String? _error;
  bool _busy = false;
  Map<String, dynamic>? _pending;

  /// Bumped by every start and cancel, so a cancelled sign-in that is still
  /// polling can never touch a newer one.
  int _attempt = 0;

  bool get _server => widget.scope == 'server';

  Map<String, dynamic> get _mine =>
      _neoMap(_state?[_server ? 'server' : 'user']);

  Map<String, dynamic> get _serverConnection => _neoMap(_state?['server']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final state = await widget.controller.fetchNeoRouter();
      if (!mounted) return;
      setState(() {
        _state = state;
        _error = null;
      });
      // People connect their own account to the server's NeoRouter.
      final suggested = _serverConnection['address']?.toString() ?? '';
      if (_address.text.isEmpty && suggested.isNotEmpty) {
        _address.text = suggested;
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.controller.friendlyErrorMessage(error));
      }
    }
  }

  Future<void> _connect() async {
    final controller = widget.controller;
    final attempt = ++_attempt;
    bool isCurrent() => mounted && attempt == _attempt;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pending = await controller.startNeoRouterConnect(
        widget.scope,
        _address.text.trim(),
      );
      if (!isCurrent()) return;
      setState(() => _pending = pending);
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
      if (isCurrent()) {
        setState(() => _error = controller.friendlyErrorMessage(error));
      }
    } finally {
      if (isCurrent()) {
        setState(() {
          _busy = false;
          _pending = null;
        });
      }
    }
  }

  void _cancel() {
    setState(() {
      _attempt++;
      _busy = false;
      _pending = null;
    });
  }

  Future<void> _setRole(String role, bool on) async {
    final roles = <String>{
      ..._neoList(_mine['roles']).map((item) => item.toString()),
    };
    on ? roles.add(role) : roles.remove(role);
    setState(() => _busy = true);
    try {
      await widget.controller.saveNeoRouterRoles(widget.scope, roles.toList());
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.controller.friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await _confirmDelete(
      context,
      title: appStrings.neoRouterDisconnect,
      message: appStrings.neoRouterDisconnectBody,
      confirmLabel: appStrings.neoRouterDisconnect,
      onConfirm: () async {
        await widget.controller.disconnectNeoRouter(widget.scope);
        await _load();
      },
    );
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

  List<Widget> _rows() {
    if (_state == null) {
      return <Widget>[
        _error == null
            ? const _SettingsBlock(
                child: Center(child: CircularProgressIndicator()),
              )
            : _SettingsBlock(child: _InlineError(message: _error!)),
      ];
    }
    final mine = _mine;
    final connected = mine['connected'] == true;
    final serverAddress = _serverConnection['address']?.toString() ?? '';
    return <Widget>[
      if (!_server && !connected && serverAddress.isNotEmpty)
        _SettingsBlock(
          child: _InlineNote(
            message: appStrings.neoRouterServerInUseArg1(serverAddress),
          ),
        ),
      if (connected) ..._connectedRows(mine) else _connectRow(),
      if (_error != null) _SettingsBlock(child: _InlineError(message: _error!)),
    ];
  }

  Widget _connectRow() {
    final pending = _pending;
    if (pending != null) {
      return _SettingsRow(
        label: appStrings.neoRouterConnect,
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
              onPressed: () => widget.controller.openNeoRouterApproval(
                pending['url']?.toString() ?? '',
              ),
              child: Text(appStrings.neoRouterOpenAgain),
            ),
            TextButton(onPressed: _cancel, child: Text(appStrings.cancel)),
          ],
        ),
      );
    }
    return _SettingsRow(
      label: appStrings.neoRouterAddress,
      fillControl: true,
      control: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _address,
              enabled: !_busy,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://router.example.com',
              ),
              onSubmitted: (_) => _connect(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: _busy ? null : _connect,
            child: Text(appStrings.neoRouterConnect),
          ),
        ],
      ),
    );
  }

  List<Widget> _connectedRows(Map<String, dynamic> mine) {
    final roles = _neoList(
      mine['roles'],
    ).map((item) => item.toString()).toSet();
    final offer = mine['offer'] is Map ? _neoMap(mine['offer']) : null;
    final counts = _neoMap(offer?['roles']);
    return <Widget>[
      _SettingsRow(
        label: appStrings.neoRouterConnectedArg1(
          mine['address']?.toString() ?? '',
        ),
        description: offer == null ? appStrings.neoRouterUnreachable : null,
        control: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _StatusPill(
              label: offer == null
                  ? appStrings.neoRouterUnreachable
                  : appStrings.neoRouterConnected,
              color: offer == null ? _warning : _success,
            ),
            OutlinedButton(
              onPressed: _busy ? null : _disconnect,
              child: Text(appStrings.neoRouterDisconnect),
            ),
          ],
        ),
      ),
      for (final role in _neoList(
        _state?['roles'],
      ).map((item) => item.toString()))
        _SettingsRow(
          label: _roleLabel(role),
          description: offer == null
              ? null
              : _asInt(counts[role]) > 0
              ? appStrings.neoRouterModelCountArg1(_asInt(counts[role]))
              : appStrings.neoRouterNoModels,
          control: Switch(
            value: roles.contains(role),
            onChanged: _busy ? null : (value) => _setRole(role, value),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    if (_server) {
      return _SectionCard(
        title: 'NeoRouter',
        description: appStrings.neoRouterServerDescription,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      );
    }
    return _SettingsGroup(
      anchor: 'neorouter',
      title: 'NeoRouter',
      description: appStrings.neoRouterUserDescription,
      children: rows,
    );
  }
}

Map<String, dynamic> _neoMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Object?> _neoList(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];
