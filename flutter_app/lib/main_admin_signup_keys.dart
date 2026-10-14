part of 'main.dart';

// Admin › Configuration: who may create an account. Sign-up is either open, or
// needs a one-time key; admins create keys singly or in batches, hand them out
// (copy or .txt export) and revoke the ones they no longer want used.

class _AdminCfgAccessCard extends StatefulWidget {
  const _AdminCfgAccessCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminCfgAccessCard> createState() => _AdminCfgAccessCardState();
}

class _AdminCfgAccessCardState extends State<_AdminCfgAccessCard>
    with _LoadSaveState<_AdminCfgAccessCard> {
  bool _keyRequired = false;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminAccess(_baseUrl);
    _keyRequired = data['signupKeyRequired'] == true;
  }

  Future<void> _setKeyRequired(bool required) async {
    if (_saving) return;
    final previous = _keyRequired;
    setState(() => _keyRequired = required);
    final saved = await _runSave(
      () async {
        final data = await _client.setAdminSignupKeyRequired(
          _baseUrl,
          required,
        );
        _keyRequired = data['signupKeyRequired'] == true;
      },
      required
          ? appStrings.adminSignupKeyRequiredNotice
          : appStrings.adminSignupOpenNotice,
    );
    if (!saved && mounted) setState(() => _keyRequired = previous);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.access,
      child:
          _loadGate(_fetch) ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SettingToggle(
                title: appStrings.adminRequireSignupKey,
                subtitle: appStrings.adminRequireSignupKeyHint,
                value: _keyRequired,
                onChanged: _setKeyRequired,
              ),
              _saveFeedback(),
            ],
          ),
    );
  }
}

enum _SignupKeyFilter { unused, used, revoked, all }

class _AdminSignupKeysCard extends StatefulWidget {
  const _AdminSignupKeysCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminSignupKeysCard> createState() => _AdminSignupKeysCardState();
}

class _AdminSignupKeysCardState extends State<_AdminSignupKeysCard>
    with _LoadSaveState<_AdminSignupKeysCard> {
  static const int _pageSize = 50;

  List<SignupKey> _keys = const <SignupKey>[];
  _SignupKeyFilter _filter = _SignupKeyFilter.unused;
  int _visibleCount = _pageSize;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    _keys = signupKeysFromResponse(
      await _client.fetchAdminSignupKeys(_baseUrl),
    );
  }

  int _count(_SignupKeyFilter filter) => filter == _SignupKeyFilter.all
      ? _keys.length
      : _keys.where((key) => _matches(key, filter)).length;

  bool _matches(SignupKey key, _SignupKeyFilter filter) {
    switch (filter) {
      case _SignupKeyFilter.unused:
        return key.status == SignupKeyStatus.unused;
      case _SignupKeyFilter.used:
        return key.status == SignupKeyStatus.used;
      case _SignupKeyFilter.revoked:
        return key.status == SignupKeyStatus.revoked;
      case _SignupKeyFilter.all:
        return true;
    }
  }

  List<SignupKey> get _filtered =>
      _keys.where((key) => _matches(key, _filter)).toList(growable: false);

  String _filterLabel(_SignupKeyFilter filter) {
    final count = _count(filter);
    switch (filter) {
      case _SignupKeyFilter.unused:
        return appStrings.signupKeysFilterUnused(count);
      case _SignupKeyFilter.used:
        return appStrings.signupKeysFilterUsed(count);
      case _SignupKeyFilter.revoked:
        return appStrings.signupKeysFilterRevoked(count);
      case _SignupKeyFilter.all:
        return appStrings.signupKeysFilterAll(count);
    }
  }

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateSignupKeysDialog(controller: widget.controller),
    );
    if (created == true && mounted) {
      setState(() => _filter = _SignupKeyFilter.unused);
      await _runLoad(_fetch);
    }
  }

  Future<void> _revoke(SignupKey key) async {
    await _confirmDelete(
      context,
      title: appStrings.signupKeyRevokeTitle,
      message: appStrings.signupKeyRevokeMessage,
      confirmLabel: appStrings.revoke,
      onConfirm: () => _runSave(() async {
        await _client.revokeAdminSignupKey(_baseUrl, key.id);
        await _fetch();
      }, appStrings.signupKeyRevoked),
    );
  }

  Future<void> _copy(String text, String notice) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
  }

  Future<void> _export(List<SignupKey> keys) async {
    final saved = await saveTextFile(
      fileName: _signupKeysFileName(_filter.name),
      contents: signupKeysAsText(keys),
      dialogTitle: appStrings.signupKeysSaveDialogTitle,
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(appStrings.signupKeysExported)));
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.signupKeys,
      description: appStrings.signupKeysDescription,
      trailing: FilledButton.icon(
        onPressed: _loading ? null : _create,
        icon: const Icon(Icons.add, size: 18),
        label: Text(appStrings.signupKeysNew),
      ),
      child: _loadGate(_fetch) ?? _buildBody(),
    );
  }

  Widget _buildBody() {
    final keys = _filtered;
    final visible = keys.take(_visibleCount).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final filter in _SignupKeyFilter.values)
              ChoiceChip(
                label: Text(_filterLabel(filter)),
                selected: _filter == filter,
                onSelected: (_) => setState(() {
                  _filter = filter;
                  _visibleCount = _pageSize;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (keys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              appStrings.signupKeysEmpty,
              style: TextStyle(color: _textMuted),
            ),
          )
        else ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () =>
                    _copy(signupKeysAsText(keys), appStrings.signupKeysCopied),
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: Text(appStrings.copyAll),
              ),
              OutlinedButton.icon(
                onPressed: () => unawaited(_export(keys)),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(appStrings.signupKeysExport),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final key in visible)
            _SignupKeyRow(
              signupKey: key,
              busy: _saving,
              onCopy: () => _copy(key.code, appStrings.signupKeyCopied),
              onRevoke: () => _revoke(key),
            ),
          if (keys.length > visible.length)
            Align(
              child: TextButton(
                onPressed: () => setState(() => _visibleCount += _pageSize),
                child: Text(
                  appStrings.signupKeysShowMore(keys.length - visible.length),
                ),
              ),
            ),
        ],
        _saveFeedback(),
      ],
    );
  }
}

class _SignupKeyRow extends StatelessWidget {
  const _SignupKeyRow({
    required this.signupKey,
    required this.busy,
    required this.onCopy,
    required this.onRevoke,
  });

  final SignupKey signupKey;
  final bool busy;
  final VoidCallback onCopy;
  final VoidCallback onRevoke;

  String get _details {
    final key = signupKey;
    final usedAt = _formatDate(key.usedAt);
    return <String>[
      if (key.label.isNotEmpty) key.label,
      switch (key.status) {
        SignupKeyStatus.used when key.usedByDeletedAccount =>
          appStrings.signupKeyUsedByDeletedArg1(usedAt),
        SignupKeyStatus.used => appStrings.signupKeyUsedByArg1Arg2(
          key.usedByUsername ?? '',
          usedAt,
        ),
        _ => appStrings.signupKeyCreatedArg1(_formatDate(key.createdAt)),
      },
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final unused = signupKey.status == SignupKeyStatus.unused;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText(
                  signupKey.code,
                  style: _monoStyle(
                    size: 14,
                    weight: FontWeight.w600,
                    color: unused ? _textPrimary : _textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _details,
                  style: TextStyle(color: _textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(label: _statusLabel, color: _statusColor),
          if (unused) ...<Widget>[
            IconButton(
              tooltip: appStrings.copy,
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 18),
            ),
            IconButton(
              tooltip: appStrings.revoke,
              onPressed: busy ? null : onRevoke,
              icon: const Icon(Icons.block_outlined, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  String get _statusLabel {
    switch (signupKey.status) {
      case SignupKeyStatus.unused:
        return appStrings.signupKeyStatusUnused;
      case SignupKeyStatus.used:
        return appStrings.signupKeyStatusUsed;
      case SignupKeyStatus.revoked:
        return appStrings.signupKeyStatusRevoked;
    }
  }

  Color get _statusColor {
    switch (signupKey.status) {
      case SignupKeyStatus.unused:
        return _success;
      case SignupKeyStatus.used:
        return _textMuted;
      case SignupKeyStatus.revoked:
        return _danger;
    }
  }
}

String _signupKeysFileName(String scope) {
  final now = DateTime.now();
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  return 'neoagent-signup-keys-$scope-$date.txt';
}

/// Creates a batch of keys and then shows them, ready to copy or export.
/// Pops `true` once keys were created.
class _CreateSignupKeysDialog extends StatefulWidget {
  const _CreateSignupKeysDialog({required this.controller});

  final NeoAgentController controller;

  @override
  State<_CreateSignupKeysDialog> createState() =>
      _CreateSignupKeysDialogState();
}

class _CreateSignupKeysDialogState extends State<_CreateSignupKeysDialog> {
  static const int _maxCount = 500;
  static const List<int> _presets = <int>[1, 10, 25, 100];

  final TextEditingController _countController = TextEditingController(
    text: '1',
  );
  final TextEditingController _labelController = TextEditingController();
  bool _busy = false;
  String? _error;
  List<SignupKey>? _created;

  int? get _count {
    final value = int.tryParse(_countController.text.trim());
    return value != null && value >= 1 && value <= _maxCount ? value : null;
  }

  @override
  void dispose() {
    _countController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final count = _count;
    if (count == null) {
      setState(() => _error = appStrings.signupKeysCountInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.controller.backendClient
          .createAdminSignupKeys(
            widget.controller.backendUrl,
            count: count,
            label: _labelController.text.trim(),
          );
      if (mounted) setState(() => _created = signupKeysFromResponse(response));
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.controller.friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyAll(List<SignupKey> keys) async {
    await Clipboard.setData(ClipboardData(text: signupKeysAsText(keys)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(appStrings.signupKeysCopied)));
  }

  Future<void> _export(List<SignupKey> keys) async {
    final saved = await saveTextFile(
      fileName: _signupKeysFileName('new'),
      contents: signupKeysAsText(keys),
      dialogTitle: appStrings.signupKeysSaveDialogTitle,
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(appStrings.signupKeysExported)));
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(
        created == null
            ? appStrings.signupKeysCreateTitle
            : appStrings.signupKeysReady(created.length),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: created == null ? _buildForm() : _buildResult(created),
        ),
      ),
      actions: created == null
          ? <Widget>[
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(appStrings.cancel),
              ),
              FilledButton(
                onPressed: _busy || _count == null ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(appStrings.signupKeysCreateAction(_count ?? 1)),
              ),
            ]
          : <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(appStrings.done),
              ),
            ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _countController,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => unawaited(_submit()),
          decoration: InputDecoration(
            labelText: appStrings.signupKeysCount,
            helperText: appStrings.signupKeysCountHelper,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final preset in _presets)
              ChoiceChip(
                label: Text('$preset'),
                selected: _count == preset,
                onSelected: _busy
                    ? null
                    : (_) => setState(() {
                        _countController.text = '$preset';
                        _error = null;
                      }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _labelController,
          enabled: !_busy,
          maxLength: 80,
          onSubmitted: (_) => unawaited(_submit()),
          decoration: InputDecoration(
            labelText: appStrings.signupKeysLabel,
            hintText: appStrings.signupKeysLabelHint,
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          _InlineError(message: _error!),
        ],
      ],
    );
  }

  Widget _buildResult(List<SignupKey> keys) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          appStrings.signupKeysReadyHint,
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: _RowSurface(
            child: SingleChildScrollView(
              child: SelectableText(
                keys.map((key) => key.code).join('\n'),
                style: _monoStyle(size: 14, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => unawaited(_copyAll(keys)),
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: Text(appStrings.copyAll),
            ),
            OutlinedButton.icon(
              onPressed: () => unawaited(_export(keys)),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(appStrings.signupKeysExport),
            ),
          ],
        ),
      ],
    );
  }
}
