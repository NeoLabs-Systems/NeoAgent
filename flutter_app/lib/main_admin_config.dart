part of 'main.dart';

// Admin tabs for server-wide configuration: AI provider credentials, model
// availability, integration OAuth apps, server settings and billing. Every
// value saved here applies to all accounts on the server.

// ── Shared pieces ─────────────────────────────────────────────────────────────

const Map<String, String> _adminCfgFieldLabels = <String, String>{
  'clientId': 'Client ID',
  'clientSecret': 'Client secret',
  'redirectUri': 'Redirect URI',
  'tenantId': 'Tenant ID',
  'apiKey': 'API key',
};

/// What the server falls back to when an optional integration field is blank.
const Map<String, String> _adminCfgFieldHints = <String, String>{
  'redirectUri': 'Blank uses the default callback',
  'tenantId': 'Blank uses "common"',
};

const List<String> _adminCfgLiveVoiceFields = <String>[
  'provider',
  'model',
  'voice',
];

/// Null when [text] is blank or an http(s) address with a host, otherwise
/// the problem to show.
String? _adminCfgUrlProblem(String text, String label) {
  final value = text.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  final isHttp =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
  return isHttp ? null : '$label must be an http:// or https:// address.';
}

/// Checks a comma-separated origin list entry by entry.
String? _adminCfgOriginsProblem(String text) {
  for (final entry in text.split(',')) {
    final origin = entry.trim();
    if (origin.isEmpty) continue;
    final problem = _adminCfgUrlProblem(origin, '"$origin"');
    if (problem != null) return problem;
  }
  return null;
}

/// A write-only secret: the stored value is never shown, and leaving the
/// field blank keeps it.
class _AdminCfgSecretField extends StatefulWidget {
  const _AdminCfgSecretField({
    required this.controller,
    required this.label,
    required this.stored,
    this.storedHint = '',
    this.placeholder,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool stored;
  final String storedHint;
  final String? placeholder;
  final ValueChanged<String>? onChanged;

  @override
  State<_AdminCfgSecretField> createState() => _AdminCfgSecretFieldState();
}

class _AdminCfgSecretFieldState extends State<_AdminCfgSecretField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final String helper;
    if (!widget.stored) {
      helper = 'Nothing stored yet.';
    } else if (widget.storedHint.isEmpty) {
      helper = 'A value is stored.';
    } else {
      helper = 'Stored: ${widget.storedHint}';
    }
    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.stored
            ? 'Leave blank to keep the stored value'
            : widget.placeholder,
        helperText: helper,
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show' : 'Hide',
          onPressed: () => setState(() => _obscured = !_obscured),
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

/// Unsaved-changes state with discard and save, for forms saved as a whole.
class _AdminCfgDirtyBar extends StatelessWidget {
  const _AdminCfgDirtyBar({
    required this.dirty,
    required this.saving,
    required this.onDiscard,
    required this.onSave,
    this.leading,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onSave;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (leading != null) leading,
        if (dirty) _StatusPill(label: 'Unsaved changes', color: _warning),
        if (dirty)
          TextButton(
            onPressed: saving ? null : onDiscard,
            child: const Text('Discard'),
          ),
        _SaveButton(
          saving: saving,
          onPressed: dirty ? onSave : null,
          label: 'Save changes',
        ),
      ],
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

class _AdminCfgProvider {
  const _AdminCfgProvider({
    required this.key,
    required this.label,
    required this.isUrl,
    required this.configured,
    required this.hint,
  });

  factory _AdminCfgProvider.fromJson(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    return _AdminCfgProvider(
      key: key,
      label: json['label']?.toString() ?? key,
      isUrl: json['type'] == 'url',
      configured: json['configured'] == true,
      hint: json['hint']?.toString() ?? '',
    );
  }

  final String key;
  final String label;
  final bool isUrl;
  final bool configured;

  /// A masked key, or the whole address for a URL setting.
  final String hint;
}

class _AdminProvidersTab extends StatefulWidget {
  const _AdminProvidersTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminProvidersTab> createState() => _AdminProvidersTabState();
}

class _AdminProvidersTabState extends State<_AdminProvidersTab>
    with _LoadSaveState<_AdminProvidersTab> {
  List<_AdminCfgProvider> _providers = const <_AdminCfgProvider>[];

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminProviders(_baseUrl);
    _providers = _jsonMapList(data['providers'])
        .map(_AdminCfgProvider.fromJson)
        .where((provider) => provider.key.isNotEmpty)
        .toList();
  }

  Future<void> _edit(_AdminCfgProvider provider) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AdminCfgProviderDialog(
        controller: widget.controller,
        provider: provider,
      ),
    );
    if (saved == true && mounted) {
      await _runSave(_fetch, '${provider.label} saved.');
    }
  }

  Future<void> _clear(_AdminCfgProvider provider) {
    return _confirmDelete(
      context,
      title: 'Clear ${provider.label}?',
      message: provider.isUrl
          ? 'This removes the address for every account on this server.'
          : 'Every account on this server loses this shared key. Accounts '
                'that added their own key keep using it.',
      confirmLabel: 'Clear',
      onConfirm: () async {
        await _runSave(() async {
          await _client.saveAdminProvider(
            _baseUrl,
            key: provider.key,
            value: '',
          );
          await _fetch();
        }, '${provider.label} cleared.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gate = _loadGate(_fetch);
    if (gate != null) return gate;
    final configured = _providers.where((p) => p.configured).length;
    return _SectionCard(
      title: 'Server provider credentials',
      description:
          'API keys and endpoints for AI, search and voice providers. They '
          'are shared by every account on this server; accounts can still '
          'add their own keys in Settings.',
      trailing: _RefreshButton(
        busy: _loading,
        onPressed: _saving ? null : () => _runLoad(_fetch),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MetaPill(
            icon: Icons.vpn_key_outlined,
            label: '$configured of ${_providers.length} set',
            color: configured > 0 ? _success : _textMuted,
          ),
          _saveFeedback(),
          const SizedBox(height: 14),
          if (_providers.isEmpty)
            const _EmptyText('This server reports no provider settings.')
          else
            for (final provider in _providers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AdminCfgProviderRow(
                  provider: provider,
                  busy: _saving,
                  onEdit: () => _edit(provider),
                  onClear: () => _clear(provider),
                ),
              ),
        ],
      ),
    );
  }
}

class _AdminCfgProviderRow extends StatelessWidget {
  const _AdminCfgProviderRow({
    required this.provider,
    required this.busy,
    required this.onEdit,
    required this.onClear,
  });

  final _AdminCfgProvider provider;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  String get _editLabel {
    if (provider.isUrl) return provider.configured ? 'Change' : 'Set URL';
    return provider.configured ? 'Replace' : 'Add key';
  }

  @override
  Widget build(BuildContext context) {
    final configured = provider.configured;
    return _RowSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RowHeader(
            title: provider.label,
            subtitle: provider.isUrl ? 'Endpoint URL' : 'API key',
            trailing: _StatusPill(
              label: configured ? 'Set' : 'Not set',
              color: configured ? _success : _textMuted,
            ),
          ),
          if (configured && provider.hint.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              provider.hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _monoStyle(color: _textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: Icon(
                  configured ? Icons.edit_outlined : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(_editLabel),
              ),
              if (configured)
                TextButton.icon(
                  onPressed: busy ? null : onClear,
                  style: TextButton.styleFrom(foregroundColor: _danger),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminCfgProviderDialog extends StatefulWidget {
  const _AdminCfgProviderDialog({
    required this.controller,
    required this.provider,
  });

  final NeoAgentController controller;
  final _AdminCfgProvider provider;

  @override
  State<_AdminCfgProviderDialog> createState() =>
      _AdminCfgProviderDialogState();
}

class _AdminCfgProviderDialogState extends State<_AdminCfgProviderDialog> {
  final TextEditingController _value = TextEditingController();
  bool _obscured = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.provider.isUrl) _value.text = widget.provider.hint;
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = widget.provider;
    final value = _value.text.trim();
    String? problem;
    if (value.isEmpty) {
      problem = provider.isUrl ? 'Enter an address.' : 'Paste a key.';
    } else if (provider.isUrl) {
      problem = _adminCfgUrlProblem(value, 'The address');
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.backendClient.saveAdminProvider(
        widget.controller.backendUrl,
        key: provider.key,
        value: value,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = widget.controller._friendlyErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final error = _error;
    final String hint;
    if (provider.isUrl) {
      hint = 'https://…';
    } else if (provider.configured) {
      hint = 'Paste a new key to replace ${provider.hint}';
    } else {
      hint = 'Paste the key';
    }
    return AlertDialog(
      backgroundColor: _bgCard,
      title: Text(provider.label),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              provider.isUrl
                  ? 'Every account on this server uses this address for '
                        '${provider.label}.'
                  : 'Used by every account on this server that has no key '
                        'of its own. It is never shown again after saving.',
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _value,
              autofocus: true,
              obscureText: !provider.isUrl && _obscured,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: provider.isUrl
                  ? TextInputType.url
                  : TextInputType.visiblePassword,
              onSubmitted: (_) {
                if (!_saving) _save();
              },
              decoration: InputDecoration(
                labelText: provider.isUrl ? 'URL' : 'API key',
                hintText: hint,
                suffixIcon: provider.isUrl
                    ? null
                    : IconButton(
                        tooltip: _obscured ? 'Show' : 'Hide',
                        onPressed: () => setState(() => _obscured = !_obscured),
                        icon: Icon(
                          _obscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
              ),
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 12),
              _InlineError(message: error),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        _SaveButton(saving: _saving, onPressed: _save),
      ],
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _AdminCfgModel {
  const _AdminCfgModel({
    required this.id,
    required this.label,
    required this.provider,
    required this.purpose,
    required this.priceTier,
    required this.inputCostPerM,
  });

  factory _AdminCfgModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final label = json['label']?.toString() ?? '';
    final cost = json['inputCostPerM'];
    return _AdminCfgModel(
      id: id,
      label: label.isEmpty ? id : label,
      provider: json['provider']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      priceTier: json['priceTier']?.toString() ?? '',
      inputCostPerM: cost is num ? cost.toDouble() : null,
    );
  }

  /// Provider-scoped selection id, the value stored in the disabled list.
  final String id;
  final String label;
  final String provider;
  final String purpose;
  final String priceTier;

  /// USD per million input tokens; null when unknown.
  final double? inputCostPerM;

  String get providerLabel => provider.isEmpty ? 'Other' : _titleCase(provider);

  bool matches(String lowerQuery) {
    return label.toLowerCase().contains(lowerQuery) ||
        id.toLowerCase().contains(lowerQuery) ||
        provider.contains(lowerQuery);
  }
}

List<_AdminCfgModel> _adminCfgParseModels(Map<String, dynamic> data) {
  return _jsonMapList(
    data['models'],
  ).map(_AdminCfgModel.fromJson).where((model) => model.id.isNotEmpty).toList();
}

String _adminCfgModelPrice(double? perMillion) {
  if (perMillion == null) return 'Price unknown';
  if (perMillion == 0) return 'Free';
  var digits = 2;
  if (perMillion < 0.01) {
    digits = 4;
  } else if (perMillion < 1) {
    digits = 3;
  }
  return '\$${perMillion.toStringAsFixed(digits)} / 1M input';
}

Color _adminCfgTierColor(String tier) {
  return switch (tier) {
    'free' || 'cheap' => _success,
    'medium' => _warning,
    'expensive' => _danger,
    _ => _textMuted,
  };
}

class _AdminModelsTab extends StatefulWidget {
  const _AdminModelsTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminModelsTab> createState() => _AdminModelsTabState();
}

class _AdminModelsTabState extends State<_AdminModelsTab>
    with _LoadSaveState<_AdminModelsTab> {
  final TextEditingController _search = TextEditingController();
  List<_AdminCfgModel> _models = const <_AdminCfgModel>[];
  Set<String> _savedDisabled = <String>{};
  Set<String> _disabled = <String>{};

  @override
  NeoAgentController get _controller => widget.controller;

  bool get _dirty => !setEquals(_savedDisabled, _disabled);

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminModels(_baseUrl);
    _models = _adminCfgParseModels(data)..sort(_compareModels);
    _resetDisabled(_jsonStringList(data['disabledModels']).toSet());
  }

  void _resetDisabled(Set<String> disabled) {
    _savedDisabled = disabled;
    _disabled = Set<String>.of(disabled);
  }

  /// Provider A–Z, then cheapest first (unknown prices last), then name.
  static int _compareModels(_AdminCfgModel a, _AdminCfgModel b) {
    final byProvider = a.provider.compareTo(b.provider);
    if (byProvider != 0) return byProvider;
    final aCost = a.inputCostPerM ?? double.infinity;
    final bCost = b.inputCostPerM ?? double.infinity;
    final byCost = aCost.compareTo(bCost);
    if (byCost != 0) return byCost;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  void _setEnabled(Iterable<_AdminCfgModel> models, bool enabled) {
    setState(() {
      _saveNotice = null;
      for (final model in models) {
        if (enabled) {
          _disabled.remove(model.id);
        } else {
          _disabled.add(model.id);
        }
      }
    });
  }

  void _discard() {
    setState(() {
      _disabled = Set<String>.of(_savedDisabled);
      _saveError = null;
    });
  }

  Future<void> _save() async {
    await _runSave(() async {
      final data = await _client.saveAdminDisabledModels(
        _baseUrl,
        _disabled.toList()..sort(),
      );
      _resetDisabled(_jsonStringList(data['disabledModels']).toSet());
    }, 'Model availability saved.');
  }

  @override
  Widget build(BuildContext context) {
    final gate = _loadGate(_fetch);
    if (gate != null) return gate;

    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? _models
        : _models.where((model) => model.matches(query)).toList();
    final groups = <String, List<_AdminCfgModel>>{};
    for (final model in visible) {
      groups.putIfAbsent(model.provider, () => <_AdminCfgModel>[]).add(model);
    }
    final enabledCount = _models
        .where((model) => !_disabled.contains(model.id))
        .length;
    final dirty = _dirty;
    final saveBar = _AdminCfgDirtyBar(
      dirty: dirty,
      saving: _saving,
      onDiscard: _discard,
      onSave: _save,
      leading: _MetaPill(
        icon: Icons.toggle_on_outlined,
        label: '$enabledCount of ${_models.length} enabled',
        color: _accent,
      ),
    );

    return _SectionStack(
      children: <Widget>[
        _AdminJevCard(controller: widget.controller),
        _SectionCard(
          title: 'Model availability',
          description:
              'Choose which models every account on this server can pick and '
              'run. While any model is switched off, models that providers add '
              'later start switched off too.',
          trailing: _RefreshButton(
            busy: _loading,
            onPressed: _saving ? null : () => _runLoad(_fetch),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SearchField(
                controller: _search,
                hintText: 'Search models or providers',
                onChanged: (_) => setState(() {}),
                onClear: () => setState(_search.clear),
              ),
              const SizedBox(height: 14),
              saveBar,
              _saveFeedback(),
            ],
          ),
        ),
        if (_models.isEmpty)
          const _EmptyCard(
            title: 'No models yet',
            subtitle:
                'Add a provider credential first. Its models show up here once '
                'the provider answers.',
          )
        else if (visible.isEmpty)
          _EmptyCard(
            title: 'No matches',
            subtitle: 'No model matches "${_search.text.trim()}".',
          )
        else
          for (final entry in groups.entries)
            _AdminCfgModelGroup(
              models: entry.value,
              filtered: query.isNotEmpty,
              disabled: _disabled,
              onToggle: (model, enabled) =>
                  _setEnabled(<_AdminCfgModel>[model], enabled),
              onSetAll: (enabled) => _setEnabled(entry.value, enabled),
            ),
        if (dirty)
          _PanelSurface(padding: const EdgeInsets.all(16), child: saveBar),
      ],
    );
  }
}

/// Server-wide Jev policy: each agent decides, on for everyone, or off.
class _AdminJevCard extends StatefulWidget {
  const _AdminJevCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminJevCard> createState() => _AdminJevCardState();
}

class _AdminJevCardState extends State<_AdminJevCard>
    with _LoadSaveState<_AdminJevCard> {
  String _policy = 'agent';
  bool _serverKey = false;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminJev(_baseUrl);
    _policy = _jevPolicyFrom(data['policy']);
    _serverKey = data['serverOpenRouterKey'] == true;
  }

  Future<void> _setPolicy(String policy) async {
    if (_saving || policy == _policy) return;
    final previous = _policy;
    setState(() => _policy = policy);
    final saved = await _runSave(
      () async {
        final data = await _client.setAdminJevPolicy(_baseUrl, policy);
        _policy = _jevPolicyFrom(data['policy']);
      },
      switch (policy) {
        'on' => 'Jev is on for every agent.',
        'off' => 'Jev is off on this server.',
        _ => 'Each agent now decides in its own settings.',
      },
    );
    if (!saved && mounted) setState(() => _policy = previous);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Jev decisions',
      description:
          'Jev is a decision model that makes the behind-the-scenes calls in '
          'a fraction of a second: routing, tool and skill choice, memory '
          'ranking, group-chat turn-taking, research sources, answer checks, '
          'and browser steps. '
          'It cuts waiting and model cost; every reply is still written by '
          'the agent\'s chat model. Jev runs through OpenRouter.',
      trailing: _StatusPill(label: 'Highly recommended', color: _accent),
      child:
          _loadGate(_fetch) ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'agent',
                    label: Text('Each agent decides'),
                    icon: Icon(Icons.tune),
                  ),
                  ButtonSegment<String>(
                    value: 'on',
                    label: Text('On for everyone'),
                    icon: Icon(Icons.bolt),
                  ),
                  ButtonSegment<String>(
                    value: 'off',
                    label: Text('Off'),
                    icon: Icon(Icons.block_outlined),
                  ),
                ],
                selected: <String>{_policy},
                showSelectedIcon: false,
                onSelectionChanged: _saving
                    ? null
                    : (selection) => _setPolicy(selection.first),
              ),
              const SizedBox(height: 12),
              Text(switch (_policy) {
                'on' =>
                  'Every agent uses Jev. Agents can no longer switch it off '
                      'in their settings.',
                'off' =>
                  'Jev is off for every agent, and its switch is hidden in '
                      'their settings.',
                _ =>
                  'Each agent switches Jev on under Settings › Models. It '
                      'starts off.',
              }, style: TextStyle(color: _textSecondary, height: 1.45)),
              if (!_serverKey && _policy != 'off') ...<Widget>[
                const SizedBox(height: 12),
                _InfoChip(
                  icon: Icons.key_outlined,
                  label:
                      'No server OpenRouter key yet. Add one under Providers, '
                      'or agents can use their own key under Advanced › Bring '
                      'your own key.',
                ),
              ],
              _saveFeedback(),
            ],
          ),
    );
  }
}

String _jevPolicyFrom(Object? value) =>
    value == 'on' || value == 'off' ? value as String : 'agent';

class _AdminCfgModelGroup extends StatelessWidget {
  const _AdminCfgModelGroup({
    required this.models,
    required this.filtered,
    required this.disabled,
    required this.onToggle,
    required this.onSetAll,
  });

  /// One provider's models (only those matching the search, if any).
  final List<_AdminCfgModel> models;
  final bool filtered;
  final Set<String> disabled;
  final void Function(_AdminCfgModel model, bool enabled) onToggle;
  final ValueChanged<bool> onSetAll;

  @override
  Widget build(BuildContext context) {
    final enabledCount = models
        .where((model) => !disabled.contains(model.id))
        .length;
    return _SectionCard(
      title: models.first.providerLabel,
      description:
          '$enabledCount of ${models.length} enabled'
          '${filtered ? ' (search results)' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 4,
            children: <Widget>[
              TextButton(
                onPressed: enabledCount == models.length
                    ? null
                    : () => onSetAll(true),
                child: Text(filtered ? 'Enable shown' : 'Enable all'),
              ),
              TextButton(
                onPressed: enabledCount == 0 ? null : () => onSetAll(false),
                child: Text(filtered ? 'Disable shown' : 'Disable all'),
              ),
            ],
          ),
          const Divider(height: 12),
          for (final model in models)
            _AdminCfgModelRow(
              model: model,
              enabled: !disabled.contains(model.id),
              onChanged: (enabled) => onToggle(model, enabled),
            ),
        ],
      ),
    );
  }
}

class _AdminCfgModelRow extends StatelessWidget {
  const _AdminCfgModelRow({
    required this.model,
    required this.enabled,
    required this.onChanged,
  });

  final _AdminCfgModel model;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.tag),
      onTap: () => onChanged(!enabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: AnimatedOpacity(
                opacity: enabled ? 1 : 0.5,
                duration: const Duration(milliseconds: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      model.label,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (model.label != model.id) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        model.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _monoStyle(size: 11.5, color: _textMuted),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (model.purpose.isNotEmpty) _Tag(model.purpose),
                        if (model.priceTier.isNotEmpty)
                          _Tag(
                            model.priceTier,
                            color: _adminCfgTierColor(model.priceTier),
                          ),
                        _Tag(_adminCfgModelPrice(model.inputCostPerM)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(value: enabled, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// ── Integrations ──────────────────────────────────────────────────────────────

class _AdminCfgIntegrationField {
  const _AdminCfgIntegrationField({
    required this.name,
    required this.secret,
    required this.value,
    required this.stored,
  });

  factory _AdminCfgIntegrationField.fromJson(Map<String, dynamic> json) {
    final value = json['value']?.toString() ?? '';
    return _AdminCfgIntegrationField(
      name: json['name']?.toString() ?? '',
      secret: json['secret'] == true,
      value: value,
      stored: json['configured'] == true || value.isNotEmpty,
    );
  }

  final String name;
  final bool secret;

  /// The current value of a plain field; always empty for a secret.
  final String value;
  final bool stored;

  String get label => _adminCfgFieldLabels[name] ?? name;
}

class _AdminCfgIntegration {
  const _AdminCfgIntegration({
    required this.key,
    required this.label,
    required this.configured,
    required this.fields,
  });

  factory _AdminCfgIntegration.fromJson(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    return _AdminCfgIntegration(
      key: key,
      label: json['label']?.toString() ?? key,
      configured: json['configured'] == true,
      fields: _jsonMapList(json['fields'])
          .map(_AdminCfgIntegrationField.fromJson)
          .where((field) => field.name.isNotEmpty)
          .toList(),
    );
  }

  final String key;
  final String label;
  final bool configured;
  final List<_AdminCfgIntegrationField> fields;
}

class _AdminIntegrationsTab extends StatefulWidget {
  const _AdminIntegrationsTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminIntegrationsTab> createState() => _AdminIntegrationsTabState();
}

class _AdminIntegrationsTabState extends State<_AdminIntegrationsTab>
    with _LoadSaveState<_AdminIntegrationsTab> {
  List<_AdminCfgIntegration> _integrations = const <_AdminCfgIntegration>[];
  List<Map<String, dynamic>> _liveVoiceProviders =
      const <Map<String, dynamic>>[];

  /// Inputs keyed by `integration.field` and `liveVoice.field`. They
  /// survive reloads so a field never loses its controller mid-frame.
  final Map<String, TextEditingController> _inputs =
      <String, TextEditingController>{};

  /// What each input held when loaded; secrets load blank (blank = keep).
  final Map<String, String> _loaded = <String, String>{};

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  @override
  void dispose() {
    for (final input in _inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminConfig(_baseUrl, 'integrations');
    final integrations = _jsonMapList(data['integrations'])
        .map(_AdminCfgIntegration.fromJson)
        .where((integration) => integration.key.isNotEmpty)
        .toList();
    final liveVoice = _jsonMap(data['liveVoice']);
    for (final integration in integrations) {
      for (final field in integration.fields) {
        _track('${integration.key}.${field.name}', field.value);
      }
    }
    for (final name in _adminCfgLiveVoiceFields) {
      _track('liveVoice.$name', liveVoice[name]?.toString() ?? '');
    }
    _liveVoiceProviders = _jsonMapList(
      _jsonMap(liveVoice['catalog'])['providers'],
    );
    _integrations = integrations;
  }

  void _track(String key, String value) {
    _loaded[key] = value;
    _inputs.putIfAbsent(key, TextEditingController.new).text = value;
  }

  TextEditingController _input(String key) => _inputs[key]!;

  bool _changed(String key) => _input(key).text.trim() != _loaded[key];

  bool get _dirty => _loaded.keys.any(_changed);

  void _edited() => setState(() => _saveNotice = null);

  void _discard() {
    setState(() {
      _loaded.forEach((key, value) => _input(key).text = value);
      _saveError = null;
    });
  }

  /// Only what changed. Live voice goes whole because the server rewrites all
  /// three of its values together.
  Map<String, dynamic> _changes() {
    final integrations = <String, Map<String, String>>{};
    for (final integration in _integrations) {
      for (final field in integration.fields) {
        final key = '${integration.key}.${field.name}';
        if (!_changed(key)) continue;
        final values = integrations.putIfAbsent(
          integration.key,
          () => <String, String>{},
        );
        values[field.name] = _input(key).text.trim();
      }
    }
    final liveVoiceChanged = _adminCfgLiveVoiceFields.any(
      (name) => _changed('liveVoice.$name'),
    );
    return <String, dynamic>{
      if (integrations.isNotEmpty) 'integrations': integrations,
      if (liveVoiceChanged)
        'liveVoice': <String, String>{
          for (final name in _adminCfgLiveVoiceFields)
            name: _input('liveVoice.$name').text.trim(),
        },
    };
  }

  String? _problem() {
    for (final integration in _integrations) {
      final key = '${integration.key}.redirectUri';
      if (!_loaded.containsKey(key) || !_changed(key)) continue;
      final problem = _adminCfgUrlProblem(
        _input(key).text,
        '${integration.label} redirect URI',
      );
      if (problem != null) return problem;
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      _rejectSave(problem);
      return;
    }
    final changes = _changes();
    if (changes.isEmpty) return;
    await _runSave(() async {
      await _client.saveAdminConfig(_baseUrl, 'integrations', changes);
      await _fetch();
    }, 'Integration settings saved.');
  }

  @override
  Widget build(BuildContext context) {
    final gate = _loadGate(_fetch);
    if (gate != null) return gate;
    final dirty = _dirty;
    final saveBar = _AdminCfgDirtyBar(
      dirty: dirty,
      saving: _saving,
      onDiscard: _discard,
      onSave: _save,
    );
    return _SectionStack(
      children: <Widget>[
        _SectionCard(
          title: 'Integration apps',
          description:
              'OAuth app credentials that let accounts connect Google, '
              'Microsoft, Slack and the other integrations. They apply to '
              'every account on this server. Secrets are write-only: leave '
              'one blank to keep what is stored.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _InlineNote(
                icon: Icons.link_rounded,
                message:
                    'Leave a Redirect URI blank to use <public URL>/api/'
                    'integrations/oauth/callback, and register that same '
                    'address with the provider.',
              ),
              const SizedBox(height: 14),
              saveBar,
              _saveFeedback(),
            ],
          ),
        ),
        for (final integration in _integrations) _integrationCard(integration),
        _liveVoiceCard(),
        if (dirty)
          _PanelSurface(padding: const EdgeInsets.all(16), child: saveBar),
      ],
    );
  }

  Widget _integrationCard(_AdminCfgIntegration integration) {
    return _SectionCard(
      title: integration.label,
      trailing: _StatusPill(
        label: integration.configured ? 'Configured' : 'Not set',
        color: integration.configured ? _success : _textMuted,
      ),
      child: _FieldGrid(
        children: <Widget>[
          for (final field in integration.fields)
            _fieldInput(integration.key, field),
        ],
      ),
    );
  }

  Widget _fieldInput(String integrationKey, _AdminCfgIntegrationField field) {
    final input = _input('$integrationKey.${field.name}');
    if (field.secret) {
      return _AdminCfgSecretField(
        controller: input,
        label: field.label,
        stored: field.stored,
        onChanged: (_) => _edited(),
      );
    }
    final isRedirect = field.name == 'redirectUri';
    return _FormTextField(
      controller: input,
      label: field.label,
      hint: _adminCfgFieldHints[field.name],
      keyboardType: isRedirect ? TextInputType.url : null,
      onChanged: (_) => _edited(),
    );
  }

  Widget _liveVoiceCard() {
    final providerInput = _input('liveVoice.provider');
    final selected = providerInput.text.trim();
    final provider = _liveVoiceProviders.firstWhere(
      (item) =>
          item['id']?.toString() == (selected.isEmpty ? 'openai' : selected),
      orElse: () => const <String, dynamic>{},
    );
    return _SectionCard(
      title: 'Live voice',
      description:
          'Server defaults for in-app voice calls. Calls run on a live '
          'speech-to-speech model using the OpenAI or Google key under '
          'Providers; each account can still pick its own model in Settings. '
          'Blank values use the provider defaults.',
      child: _FieldGrid(
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String>('live-voice-provider:$selected'),
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem(
                value: '',
                child: Text('Default (OpenAI)'),
              ),
              for (final item in _liveVoiceProviders)
                DropdownMenuItem(
                  value: item['id']?.toString() ?? '',
                  child: Text(item['label']?.toString() ?? ''),
                ),
            ],
            onChanged: (value) {
              providerInput.text = value ?? '';
              _edited();
            },
          ),
          _FormTextField(
            controller: _input('liveVoice.model'),
            label: 'Model',
            hint: provider['defaultModel']?.toString(),
            onChanged: (_) => _edited(),
          ),
          _FormTextField(
            controller: _input('liveVoice.voice'),
            label: 'Voice',
            hint: provider['defaultVoice']?.toString(),
            onChanged: (_) => _edited(),
          ),
        ],
      ),
    );
  }
}

// ── Configuration ─────────────────────────────────────────────────────────────

class _AdminConfigTab extends StatefulWidget {
  const _AdminConfigTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminConfigTab> createState() => _AdminConfigTabState();
}

class _AdminConfigTabState extends State<_AdminConfigTab> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return _SectionStack(
      children: <Widget>[
        _AdminCfgAccessCard(controller: controller),
        _AdminCfgGeneralCard(controller: controller),
        _AdminCfgVmCard(controller: controller),
        _AdminCfgEmailCard(controller: controller),
      ],
    );
  }
}

class _AdminCfgAccessCard extends StatefulWidget {
  const _AdminCfgAccessCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminCfgAccessCard> createState() => _AdminCfgAccessCardState();
}

class _AdminCfgAccessCardState extends State<_AdminCfgAccessCard>
    with _LoadSaveState<_AdminCfgAccessCard> {
  bool _signupEnabled = true;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminAccess(_baseUrl);
    _signupEnabled = data['signupEnabled'] != false;
  }

  Future<void> _setSignup(bool enabled) async {
    if (_saving) return;
    final previous = _signupEnabled;
    setState(() => _signupEnabled = enabled);
    final saved = await _runSave(() async {
      final data = await _client.setAdminSignupEnabled(_baseUrl, enabled);
      _signupEnabled = data['signupEnabled'] != false;
    }, enabled ? 'Sign-up is open.' : 'Sign-up is closed.');
    if (!saved && mounted) setState(() => _signupEnabled = previous);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Access',
      child:
          _loadGate(_fetch) ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SettingToggle(
                title: 'Allow new sign-ups',
                subtitle:
                    'When off, only existing accounts can sign in. A '
                    'server with no accounts yet always lets the first '
                    'one register.',
                value: _signupEnabled,
                onChanged: _setSignup,
              ),
              _saveFeedback(),
            ],
          ),
    );
  }
}

class _AdminCfgGeneralCard extends StatefulWidget {
  const _AdminCfgGeneralCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminCfgGeneralCard> createState() => _AdminCfgGeneralCardState();
}

class _AdminCfgGeneralCardState extends State<_AdminCfgGeneralCard>
    with _LoadSaveState<_AdminCfgGeneralCard> {
  final TextEditingController _publicUrl = TextEditingController();
  final TextEditingController _allowedOrigins = TextEditingController();
  final TextEditingController _ingestionInterval = TextEditingController();
  bool _secureCookies = false;
  bool _meshtasticEnabled = true;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  @override
  void dispose() {
    _publicUrl.dispose();
    _allowedOrigins.dispose();
    _ingestionInterval.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminConfig(_baseUrl, 'general');
    final settings = _jsonMap(data['settings']);
    _publicUrl.text = settings['publicUrl']?.toString() ?? '';
    _allowedOrigins.text = settings['allowedOrigins']?.toString() ?? '';
    _ingestionInterval.text =
        settings['memoryIngestionIntervalMs']?.toString() ?? '';
    _secureCookies = settings['secureCookies'] == true;
    _meshtasticEnabled = settings['meshtasticEnabled'] != false;
  }

  Future<void> _save() async {
    final interval = _parseBoundedInt(_ingestionInterval.text, min: 1000);
    var problem = _adminCfgUrlProblem(_publicUrl.text, 'Public URL');
    problem ??= _adminCfgOriginsProblem(_allowedOrigins.text);
    if (problem == null && interval == null) {
      problem = 'Memory ingestion interval must be at least 1000 ms.';
    }
    if (problem != null) {
      _rejectSave(problem);
      return;
    }
    await _runSave(
      () => _client.saveAdminConfig(_baseUrl, 'general', <String, dynamic>{
        'publicUrl': _publicUrl.text.trim(),
        'secureCookies': _secureCookies,
        'allowedOrigins': _allowedOrigins.text.trim(),
        'meshtasticEnabled': _meshtasticEnabled,
        'memoryIngestionIntervalMs': interval,
      }),
      'General settings saved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'General',
      description: 'How this server is reached, plus server-wide switches.',
      child: _loadGate(_fetch) ?? _form(),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldGrid(
          children: <Widget>[
            _WideField(
              _FormTextField(
                controller: _publicUrl,
                label: 'Public URL',
                hint: 'https://agent.example.com',
                helper:
                    'The address people and OAuth providers use to reach '
                    'this server.',
                keyboardType: TextInputType.url,
                onChanged: (_) => _onEdited(),
              ),
            ),
            _FormTextField(
              controller: _allowedOrigins,
              label: 'Allowed origins',
              hint: 'https://app.example.com, https://…',
              helper:
                  'Exact web origins allowed to make cross-origin requests, '
                  'comma-separated.',
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _ingestionInterval,
              label: 'Memory ingestion interval (ms)',
              helper: 'At least 1000. Applies after a server restart.',
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SettingToggle(
          title: 'Secure cookies',
          subtitle:
              'Required behind HTTPS or a TLS proxy. Applies after a server '
              'restart.',
          value: _secureCookies,
          onChanged: (value) => setState(() {
            _secureCookies = value;
            _saveNotice = null;
          }),
        ),
        _SettingToggle(
          title: 'Meshtastic',
          subtitle: 'Let accounts connect Meshtastic radios.',
          value: _meshtasticEnabled,
          onChanged: (value) => setState(() {
            _meshtasticEnabled = value;
            _saveNotice = null;
          }),
        ),
        const SizedBox(height: 12),
        _SaveButton(
          saving: _saving,
          onPressed: _save,
          label: 'Save general settings',
        ),
        _saveFeedback(),
      ],
    );
  }
}

class _AdminCfgVmCard extends StatefulWidget {
  const _AdminCfgVmCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminCfgVmCard> createState() => _AdminCfgVmCardState();
}

class _AdminCfgVmCardState extends State<_AdminCfgVmCard>
    with _LoadSaveState<_AdminCfgVmCard> {
  final TextEditingController _baseImageUrl = TextEditingController();
  final TextEditingController _baseImagePath = TextEditingController();
  final TextEditingController _memoryMb = TextEditingController();
  final TextEditingController _cpus = TextEditingController();

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  @override
  void dispose() {
    _baseImageUrl.dispose();
    _baseImagePath.dispose();
    _memoryMb.dispose();
    _cpus.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminConfig(_baseUrl, 'vm');
    final settings = _jsonMap(data['settings']);
    _baseImageUrl.text = settings['vmBaseImageUrl']?.toString() ?? '';
    _baseImagePath.text = settings['vmBaseImage']?.toString() ?? '';
    _memoryMb.text = settings['vmMemoryMb']?.toString() ?? '';
    _cpus.text = settings['vmCpus']?.toString() ?? '';
  }

  Future<void> _save() async {
    final memoryMb = _parseBoundedInt(_memoryMb.text, min: 512);
    final cpus = _parseBoundedInt(_cpus.text, min: 1);
    var problem = _adminCfgUrlProblem(_baseImageUrl.text, 'Base image URL');
    if (problem == null && memoryMb == null) {
      problem = 'Memory must be at least 512 MB.';
    }
    if (problem == null && cpus == null) {
      problem = 'Use at least 1 vCPU.';
    }
    if (problem != null) {
      _rejectSave(problem);
      return;
    }
    await _runSave(
      () => _client.saveAdminConfig(_baseUrl, 'vm', <String, dynamic>{
        'vmBaseImageUrl': _baseImageUrl.text.trim(),
        'vmBaseImage': _baseImagePath.text.trim(),
        'vmMemoryMb': memoryMb,
        'vmCpus': cpus,
      }),
      'Cloud computer settings saved. Restart the server to apply them.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Cloud computers',
      description:
          'Base image and size of the QEMU virtual machines that run '
          'accounts’ cloud computers. Changes apply after a server '
          'restart.',
      child: _loadGate(_fetch) ?? _form(),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldGrid(
          children: <Widget>[
            _WideField(
              _FormTextField(
                controller: _baseImageUrl,
                label: 'Base image URL',
                hint: 'https://cloud-images.ubuntu.com/…',
                keyboardType: TextInputType.url,
                onChanged: (_) => _onEdited(),
              ),
            ),
            _WideField(
              _FormTextField(
                controller: _baseImagePath,
                label: 'Local base image path',
                hint: '/path/to/base.img',
                helper: 'Optional. When set, it is used instead of the URL.',
                onChanged: (_) => _onEdited(),
              ),
            ),
            _FormTextField(
              controller: _memoryMb,
              label: 'Memory (MB)',
              helper: 'At least 512.',
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _cpus,
              label: 'vCPUs',
              helper: 'At least 1.',
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SaveButton(
          saving: _saving,
          onPressed: _save,
          label: 'Save cloud computer settings',
        ),
        _saveFeedback(),
      ],
    );
  }
}

typedef _AdminCfgEmailToggle = ({String key, String title, String subtitle});

const List<_AdminCfgEmailToggle> _adminCfgEmailToggles = <_AdminCfgEmailToggle>[
  (
    key: 'smtpSecure',
    title: 'Implicit TLS',
    subtitle: 'Use TLS from the start of the connection, usually on port 465.',
  ),
  (
    key: 'smtpRequireTls',
    title: 'Require STARTTLS',
    subtitle: 'Refuse to send unless the connection upgrades to TLS.',
  ),
  (
    key: 'smtpRejectUnauthorized',
    title: 'Reject invalid TLS certificates',
    subtitle: 'Turn off only for a mail server with a self-signed certificate.',
  ),
  (
    key: 'requireSignupConfirmation',
    title: 'Confirm new sign-ups',
    subtitle: 'New accounts confirm their email address before signing in.',
  ),
  (
    key: 'requireEmailChangeConfirmation',
    title: 'Confirm email changes',
    subtitle: 'A changed email address is confirmed before it is used.',
  ),
  (
    key: 'notifyUnusualLogin',
    title: 'Unusual sign-in alerts',
    subtitle: 'Email account owners about sign-ins that look unusual.',
  ),
  (
    key: 'notifyAccountChanges',
    title: 'Account change alerts',
    subtitle: 'Email account owners when their account details change.',
  ),
];

class _AdminCfgEmailCard extends StatefulWidget {
  const _AdminCfgEmailCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminCfgEmailCard> createState() => _AdminCfgEmailCardState();
}

class _AdminCfgEmailCardState extends State<_AdminCfgEmailCard>
    with _LoadSaveState<_AdminCfgEmailCard> {
  // The plain-text settings, keyed by their API names.
  final Map<String, TextEditingController> _text =
      <String, TextEditingController>{
        for (final key in const <String>[
          'from',
          'smtpHost',
          'smtpUser',
          'replyTo',
          'brandName',
          'publicUrl',
          'supportUrl',
        ])
          key: TextEditingController(),
      };
  final TextEditingController _smtpPort = TextEditingController();
  final TextEditingController _tokenTtlHours = TextEditingController();
  final TextEditingController _smtpPassword = TextEditingController();
  final Map<String, bool> _flags = <String, bool>{};
  bool _configured = false;
  List<String> _missing = const <String>[];
  bool _passwordStored = false;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  @override
  void dispose() {
    for (final input in _text.values) {
      input.dispose();
    }
    _smtpPort.dispose();
    _tokenTtlHours.dispose();
    _smtpPassword.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    _apply(await _client.fetchAdminConfig(_baseUrl, 'email'));
  }

  /// Takes the `{configured, missing, settings}` shape both GET and PUT return.
  void _apply(Map<String, dynamic> data) {
    final settings = _jsonMap(data['settings']);
    _text.forEach((key, input) {
      input.text = settings[key]?.toString() ?? '';
    });
    _smtpPort.text = settings['smtpPort']?.toString() ?? '';
    _tokenTtlHours.text = settings['tokenTtlHours']?.toString() ?? '';
    for (final toggle in _adminCfgEmailToggles) {
      _flags[toggle.key] = settings[toggle.key] == true;
    }
    _passwordStored = settings['smtpPasswordConfigured'] == true;
    _configured = data['configured'] == true;
    _missing = _jsonStringList(data['missing']);
    _smtpPassword.clear();
  }

  TextEditingController _field(String key) => _text[key]!;

  Future<void> _save({bool clearPassword = false}) async {
    final port = _parseBoundedInt(_smtpPort.text, min: 1, max: 65535);
    final ttl = _parseBoundedInt(_tokenTtlHours.text, min: 1, max: 8760);
    String? problem;
    if (port == null) {
      problem = 'SMTP port must be a whole number from 1 to 65535.';
    } else if (ttl == null) {
      problem = 'Link lifetime must be from 1 to 8760 hours.';
    }
    problem ??= _adminCfgUrlProblem(
      _field('publicUrl').text,
      'Public URL override',
    );
    problem ??= _adminCfgUrlProblem(_field('supportUrl').text, 'Support URL');
    if (problem != null) {
      _rejectSave(problem);
      return;
    }
    final payload = <String, dynamic>{
      for (final entry in _text.entries) entry.key: entry.value.text.trim(),
      ..._flags,
      'smtpPort': port,
      'tokenTtlHours': ttl,
      'smtpPassword': clearPassword ? '' : _smtpPassword.text.trim(),
      'clearSmtpPassword': clearPassword,
    };
    await _runSave(() async {
      _apply(await _client.saveAdminConfig(_baseUrl, 'email', payload));
    }, clearPassword ? 'SMTP password removed.' : 'Email settings saved.');
  }

  Future<void> _removePassword() {
    return _confirmDelete(
      context,
      title: 'Remove the SMTP password?',
      message:
          'Mail servers that need a password will refuse to send until a new '
          'one is saved. Other changes in this form are saved too.',
      confirmLabel: 'Remove',
      onConfirm: () => _save(clearPassword: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loaded = !_loading && _loadError == null;
    return _SectionCard(
      title: 'Service email',
      description:
          'The mail account NeoAgent sends sign-up confirmations, sign-in '
          'alerts and other account email from.',
      trailing: loaded
          ? _StatusPill(
              label: _configured ? 'Ready' : 'Not configured',
              color: _configured ? _success : _warning,
            )
          : null,
      child: _loadGate(_fetch) ?? _form(),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!_configured && _missing.isNotEmpty) ...<Widget>[
          _InlineNote(
            icon: Icons.warning_amber_rounded,
            color: _warning,
            message:
                'Account email is off until these are set: '
                '${_missing.join(', ')}.',
          ),
          const SizedBox(height: 16),
        ],
        _FieldGrid(
          children: <Widget>[
            _WideField(
              _FormTextField(
                controller: _field('from'),
                label: 'Sender address',
                hint: 'NeoAgent <no-reply@example.com>',
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _onEdited(),
              ),
            ),
            _FormTextField(
              controller: _field('smtpHost'),
              label: 'SMTP host',
              hint: 'smtp.example.com',
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _smtpPort,
              label: 'SMTP port',
              hint: '587',
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('smtpUser'),
              label: 'SMTP username',
              onChanged: (_) => _onEdited(),
            ),
            _AdminCfgSecretField(
              controller: _smtpPassword,
              label: 'SMTP password',
              stored: _passwordStored,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('replyTo'),
              label: 'Reply-To address',
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('brandName'),
              label: 'Brand name',
              hint: 'NeoAgent',
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('publicUrl'),
              label: 'Public URL override',
              helper: 'For links in emails. Blank uses the server public URL.',
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('supportUrl'),
              label: 'Support URL',
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _tokenTtlHours,
              label: 'Link lifetime (hours)',
              helper: 'How long confirmation links stay valid.',
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FieldGrid(
          children: <Widget>[
            for (final toggle in _adminCfgEmailToggles)
              _SettingToggle(
                title: toggle.title,
                subtitle: toggle.subtitle,
                value: _flags[toggle.key] ?? false,
                onChanged: (value) => setState(() {
                  _flags[toggle.key] = value;
                  _saveNotice = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _SaveButton(
              saving: _saving,
              onPressed: _save,
              label: 'Save email settings',
            ),
            if (_passwordStored)
              TextButton.icon(
                onPressed: _saving ? null : _removePassword,
                style: TextButton.styleFrom(foregroundColor: _danger),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove SMTP password'),
              ),
          ],
        ),
        _saveFeedback(),
      ],
    );
  }
}

// ── Billing ───────────────────────────────────────────────────────────────────

class _AdminBillingTab extends StatefulWidget {
  const _AdminBillingTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminBillingTab> createState() => _AdminBillingTabState();
}

class _AdminBillingTabState extends State<_AdminBillingTab> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return _SectionStack(
      children: <Widget>[
        _AdminCfgStripeCard(controller: controller),
        if (controller.showBillingSection) ...<Widget>[
          _AdminCfgPlansCard(controller: controller),
          _AdminCfgSubscriptionsCard(controller: controller),
        ] else
          const _EmptyCard(
            title: 'Billing is off',
            subtitle:
                'Plans and subscriptions show up here once billing is turned '
                'on and the server has restarted.',
          ),
      ],
    );
  }
}

class _AdminCfgStripeCard extends StatefulWidget {
  const _AdminCfgStripeCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminCfgStripeCard> createState() => _AdminCfgStripeCardState();
}

class _AdminCfgStripeCardState extends State<_AdminCfgStripeCard>
    with _LoadSaveState<_AdminCfgStripeCard> {
  final TextEditingController _publishableKey = TextEditingController();
  final TextEditingController _secretKey = TextEditingController();
  final TextEditingController _webhookSecret = TextEditingController();
  final TextEditingController _trialDays = TextEditingController();
  bool _billingEnabled = false;
  bool _savedBillingEnabled = false;
  bool _secretKeyStored = false;
  String _secretKeyHint = '';
  bool _webhookSecretStored = false;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  @override
  void dispose() {
    _publishableKey.dispose();
    _secretKey.dispose();
    _webhookSecret.dispose();
    _trialDays.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminConfig(_baseUrl, 'billing-setup');
    final settings = _jsonMap(data['settings']);
    _billingEnabled = settings['billingEnabled'] == true;
    _savedBillingEnabled = _billingEnabled;
    _publishableKey.text = settings['stripePublishableKey']?.toString() ?? '';
    _secretKeyStored = settings['stripeSecretKeyConfigured'] == true;
    _secretKeyHint = settings['stripeSecretKeyHint']?.toString() ?? '';
    _webhookSecretStored = settings['stripeWebhookSecretConfigured'] == true;
    _trialDays.text = settings['trialDays']?.toString() ?? '';
    _secretKey.clear();
    _webhookSecret.clear();
  }

  Future<void> _save() async {
    final trialDays = _parseBoundedInt(_trialDays.text, min: 0);
    if (trialDays == null) {
      _rejectSave('Free trial must be a whole number of days (0 or more).');
      return;
    }
    final secretKey = _secretKey.text.trim();
    final webhookSecret = _webhookSecret.text.trim();
    final payload = <String, dynamic>{
      'billingEnabled': _billingEnabled,
      'stripePublishableKey': _publishableKey.text.trim(),
      if (secretKey.isNotEmpty) 'stripeSecretKey': secretKey,
      if (webhookSecret.isNotEmpty) 'stripeWebhookSecret': webhookSecret,
      'trialDays': trialDays,
    };
    await _runSave(() async {
      await _client.saveAdminConfig(_baseUrl, 'billing-setup', payload);
      await _fetch();
    }, 'Billing setup saved.');
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.controller.showBillingSection;
    return _SectionCard(
      title: 'Stripe billing',
      description:
          'Stripe keys for paid plans. Point a Stripe webhook at '
          '<public URL>/api/billing/webhook and paste its signing secret '
          'here. Secrets are write-only: leave one blank to keep it.',
      trailing: _StatusPill(
        label: running ? 'Running' : 'Off',
        color: running ? _success : _textMuted,
      ),
      child: _loadGate(_fetch) ?? _form(running),
    );
  }

  Widget _form(bool running) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_savedBillingEnabled != running) ...<Widget>[
          _InlineNote(
            icon: Icons.restart_alt_rounded,
            color: _warning,
            message: _savedBillingEnabled
                ? 'Billing is turned on but not running yet. Restart the '
                      'server to start it.'
                : 'Billing is turned off but still running. Restart the '
                      'server to stop it.',
          ),
          const SizedBox(height: 12),
        ],
        _SettingToggle(
          title: 'Billing enabled',
          subtitle:
              'Offer subscription plans through Stripe. Turning this on or '
              'off takes effect after a server restart.',
          value: _billingEnabled,
          onChanged: (value) => setState(() {
            _billingEnabled = value;
            _saveNotice = null;
          }),
        ),
        const SizedBox(height: 8),
        _FieldGrid(
          children: <Widget>[
            _FormTextField(
              controller: _publishableKey,
              label: 'Publishable key',
              hint: 'pk_live_…',
              onChanged: (_) => _onEdited(),
            ),
            _AdminCfgSecretField(
              controller: _secretKey,
              label: 'Secret key',
              stored: _secretKeyStored,
              storedHint: _secretKeyHint,
              placeholder: 'sk_live_…',
              onChanged: (_) => _onEdited(),
            ),
            _AdminCfgSecretField(
              controller: _webhookSecret,
              label: 'Webhook signing secret',
              stored: _webhookSecretStored,
              placeholder: 'whsec_…',
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _trialDays,
              label: 'Free trial (days)',
              helper: '0 turns trials off.',
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SaveButton(
          saving: _saving,
          onPressed: _save,
          label: 'Save billing setup',
        ),
        _saveFeedback(),
      ],
    );
  }
}

/// A billing plan as the admin plan endpoints return it.
class _BillingPlan {
  const _BillingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.interval,
    required this.stripePriceId,
    required this.tokenLimit4h,
    required this.tokenLimitWeekly,
    required this.allowedModels,
    required this.features,
    required this.isActive,
    required this.sortOrder,
  });

  factory _BillingPlan.fromJson(Map<String, dynamic> json) {
    return _BillingPlan(
      id: _asText(json['id'], fallback: ''),
      name: _asText(json['name'], fallback: ''),
      description: _asText(json['description'], fallback: ''),
      priceCents: _asInt(json['price_cents']),
      currency: _asText(json['currency'], fallback: 'usd'),
      interval: _asText(json['interval'], fallback: ''),
      stripePriceId: _asText(json['stripe_price_id'], fallback: ''),
      tokenLimit4h: _asOptionalInt(json['token_limit_4h']),
      tokenLimitWeekly: _asOptionalInt(json['token_limit_weekly']),
      allowedModels: _jsonStringList(json['allowed_models']),
      features: _jsonStringList(json['features']),
      isActive: json['is_active'] == true || json['is_active'] == 1,
      sortOrder: _asInt(json['sort_order']),
    );
  }

  final String id;
  final String name;
  final String description;
  final int priceCents;
  final String currency;

  /// `month`, `year`, or empty for a one-time / free plan.
  final String interval;
  final String stripePriceId;

  /// Null means the server's default limit.
  final int? tokenLimit4h;
  final int? tokenLimitWeekly;

  /// Empty means every model is allowed.
  final List<String> allowedModels;
  final List<String> features;
  final bool isActive;
  final int sortOrder;

  String get displayName => name.isEmpty ? id : name;

  String get priceLabel {
    if (priceCents == 0) return 'Free';
    return _fmtPrice(priceCents, currency, interval: interval);
  }
}

String _adminCfgLimitLabel(String window, int? limit) {
  if (limit == null) return '$window: default';
  return '$window: ${_formatTokenCount(limit)} tokens';
}

class _AdminCfgPlansCard extends StatefulWidget {
  const _AdminCfgPlansCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminCfgPlansCard> createState() => _AdminCfgPlansCardState();
}

class _AdminCfgPlansCardState extends State<_AdminCfgPlansCard>
    with _LoadSaveState<_AdminCfgPlansCard> {
  List<_BillingPlan> _plans = const <_BillingPlan>[];

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminBillingPlans(_baseUrl);
    _plans = _jsonMapList(
      data['plans'],
    ).map(_BillingPlan.fromJson).where((plan) => plan.id.isNotEmpty).toList();
  }

  Future<void> _openEditor([_BillingPlan? plan]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _AdminCfgPlanDialog(controller: widget.controller, plan: plan),
    );
    if (saved == true && mounted) {
      await _runSave(
        _fetch,
        plan == null ? 'Plan created.' : '${plan.name} saved.',
      );
    }
  }

  Future<void> _deactivate(_BillingPlan plan) {
    return _confirmDelete(
      context,
      title: 'Deactivate ${plan.name}?',
      message:
          'The plan stops being offered. It is kept, not erased, and '
          'existing subscribers keep access until their period ends.',
      confirmLabel: 'Deactivate',
      onConfirm: () async {
        await _runSave(() async {
          await _client.deleteAdminBillingPlan(_baseUrl, plan.id);
          await _fetch();
        }, '${plan.name} deactivated.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Plans',
      description: 'The subscription plans people can choose from.',
      trailing: _RefreshButton(
        busy: _loading,
        onPressed: _saving ? null : () => _runLoad(_fetch),
      ),
      child: _loadGate(_fetch) ?? _list(),
    );
  }

  Widget _list() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _saving ? null : () => _openEditor(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New plan'),
        ),
        _saveFeedback(),
        const SizedBox(height: 14),
        if (_plans.isEmpty)
          const _EmptyText('No plans yet.')
        else
          for (final plan in _plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AdminCfgPlanRow(
                plan: plan,
                busy: _saving,
                onEdit: () => _openEditor(plan),
                onDeactivate: () => _deactivate(plan),
              ),
            ),
      ],
    );
  }
}

class _AdminCfgPlanRow extends StatelessWidget {
  const _AdminCfgPlanRow({
    required this.plan,
    required this.busy,
    required this.onEdit,
    required this.onDeactivate,
  });

  final _BillingPlan plan;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final modelCount = plan.allowedModels.length;
    final featureCount = plan.features.length;
    return _RowSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RowHeader(
            title: plan.displayName,
            subtitle: plan.id,
            monospaceSubtitle: true,
            trailing: _StatusPill(
              label: plan.isActive ? 'Active' : 'Inactive',
              color: plan.isActive ? _success : _textMuted,
            ),
          ),
          if (plan.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              plan.description,
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _Tag(plan.priceLabel, color: _accent),
              _Tag(_adminCfgLimitLabel('4h', plan.tokenLimit4h)),
              _Tag(_adminCfgLimitLabel('Weekly', plan.tokenLimitWeekly)),
              _Tag(
                modelCount == 0
                    ? 'All models'
                    : '$modelCount model${modelCount == 1 ? '' : 's'}',
              ),
              if (featureCount > 0)
                _Tag('$featureCount feature${featureCount == 1 ? '' : 's'}'),
              if (plan.stripePriceId.isNotEmpty) _Tag(plan.stripePriceId),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              if (plan.isActive)
                TextButton.icon(
                  onPressed: busy ? null : onDeactivate,
                  style: TextButton.styleFrom(foregroundColor: _danger),
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Deactivate'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminCfgPlanDialog extends StatefulWidget {
  const _AdminCfgPlanDialog({required this.controller, this.plan});

  final NeoAgentController controller;

  /// Null to create a new plan.
  final _BillingPlan? plan;

  @override
  State<_AdminCfgPlanDialog> createState() => _AdminCfgPlanDialogState();
}

class _AdminCfgPlanDialogState extends State<_AdminCfgPlanDialog> {
  static final RegExp _planIdPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
  static final RegExp _currencyPattern = RegExp(r'^[a-zA-Z]{3}$');

  final TextEditingController _id = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController(text: '0');
  final TextEditingController _currency = TextEditingController(text: 'usd');
  final TextEditingController _sortOrder = TextEditingController(text: '0');
  final TextEditingController _stripePriceId = TextEditingController();
  final TextEditingController _limit4h = TextEditingController();
  final TextEditingController _limitWeekly = TextEditingController();
  final TextEditingController _features = TextEditingController();

  /// Used instead of the picker when the model list can't be loaded.
  final TextEditingController _modelIds = TextEditingController();
  final Set<String> _allowedModels = <String>{};
  String _interval = 'month';
  bool _active = true;

  /// Null while the model list loads.
  List<_AdminCfgModel>? _models;
  bool _modelsFailed = false;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.plan == null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    if (plan != null) {
      _id.text = plan.id;
      _name.text = plan.name;
      _description.text = plan.description;
      _price.text = '${plan.priceCents}';
      _currency.text = plan.currency;
      _sortOrder.text = '${plan.sortOrder}';
      _stripePriceId.text = plan.stripePriceId;
      _limit4h.text = plan.tokenLimit4h?.toString() ?? '';
      _limitWeekly.text = plan.tokenLimitWeekly?.toString() ?? '';
      _features.text = plan.features.join('\n');
      _allowedModels.addAll(plan.allowedModels);
      _interval = plan.interval;
      _active = plan.isActive;
    }
    _loadModels();
  }

  @override
  void dispose() {
    for (final input in <TextEditingController>[
      _id,
      _name,
      _description,
      _price,
      _currency,
      _sortOrder,
      _stripePriceId,
      _limit4h,
      _limitWeekly,
      _features,
      _modelIds,
    ]) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _loadModels() async {
    try {
      final data = await widget.controller.backendClient.fetchAdminModels(
        widget.controller.backendUrl,
      );
      final models = _adminCfgParseModels(data)
        ..sort((a, b) {
          final byProvider = a.provider.compareTo(b.provider);
          if (byProvider != 0) return byProvider;
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
      if (mounted) setState(() => _models = models);
    } catch (_) {
      // The plan can still be saved: the ids are then typed by hand.
      if (!mounted) return;
      setState(() {
        _modelsFailed = true;
        _modelIds.text = _allowedModels.join(', ');
      });
    }
  }

  static bool _isOptionalWholeNumber(TextEditingController input) {
    final text = input.text.trim();
    return text.isEmpty || _parseBoundedInt(text, min: 0) != null;
  }

  String? _problem() {
    final id = _id.text.trim();
    if (_isNew && id.isNotEmpty && !_planIdPattern.hasMatch(id)) {
      return 'Plan ID may only use letters, numbers, underscores and hyphens.';
    }
    if (_name.text.trim().isEmpty) return 'Give the plan a name.';
    if (_parseBoundedInt(_price.text, min: 0) == null) {
      return 'Price must be a whole number of cents (0 or more).';
    }
    if (!_currencyPattern.hasMatch(_currency.text.trim())) {
      return 'Currency must be a 3-letter code such as usd.';
    }
    if (!_isOptionalWholeNumber(_sortOrder)) {
      return 'Sort order must be a whole number.';
    }
    if (!_isOptionalWholeNumber(_limit4h) ||
        !_isOptionalWholeNumber(_limitWeekly)) {
      return 'Token limits must be whole numbers, or blank for the default.';
    }
    return null;
  }

  List<String> _selectedModelIds() {
    if (!_modelsFailed) return _allowedModels.toList()..sort();
    return _modelIds.text
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _payload() {
    final id = _id.text.trim();
    final stripePriceId = _stripePriceId.text.trim();
    return <String, dynamic>{
      if (_isNew && id.isNotEmpty) 'id': id,
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price_cents': _asOptionalInt(_price.text) ?? 0,
      'currency': _currency.text.trim().toLowerCase(),
      'interval': _interval.isEmpty ? null : _interval,
      'stripe_price_id': stripePriceId.isEmpty ? null : stripePriceId,
      'token_limit_4h': _asOptionalInt(_limit4h.text),
      'token_limit_weekly': _asOptionalInt(_limitWeekly.text),
      'allowed_models': _selectedModelIds(),
      'features': _features.text
          .split('\n')
          .map((feature) => feature.trim())
          .where((feature) => feature.isNotEmpty)
          .toList(),
      'sort_order': _asOptionalInt(_sortOrder.text) ?? 0,
      'is_active': _active,
    };
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final client = widget.controller.backendClient;
    final baseUrl = widget.controller.backendUrl;
    final plan = widget.plan;
    try {
      if (plan == null) {
        await client.createAdminBillingPlan(baseUrl, _payload());
      } else {
        await client.updateAdminBillingPlan(baseUrl, plan.id, _payload());
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = widget.controller._friendlyErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final plan = widget.plan;
    return Dialog(
      backgroundColor: _bgCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
              child: Text(
                plan == null ? 'New plan' : 'Edit ${plan.displayName}',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
                child: _form(),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: _InlineError(message: error),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  _SaveButton(
                    saving: _saving,
                    onPressed: _save,
                    label: _isNew ? 'Create plan' : 'Save plan',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldGrid(
          children: <Widget>[
            _FormTextField(
              controller: _id,
              label: 'Plan ID',
              hint: 'plan_pro',
              helper: _isNew
                  ? 'Optional and permanent. Blank generates one.'
                  : 'A plan’s ID can’t change.',
              enabled: _isNew,
            ),
            _FormTextField(controller: _name, label: 'Name', hint: 'Pro'),
            _WideField(
              _FormTextField(controller: _description, label: 'Description'),
            ),
            _FormTextField(
              controller: _price,
              label: 'Price in cents',
              helper: 'Smallest currency unit: 1900 is 19.00.',
              wholeNumber: true,
            ),
            _FormTextField(
              controller: _currency,
              label: 'Currency',
              hint: 'usd',
            ),
            DropdownButtonFormField<String>(
              initialValue: _interval,
              decoration: const InputDecoration(labelText: 'Billing interval'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'month', child: Text('Monthly')),
                DropdownMenuItem(value: 'year', child: Text('Yearly')),
                DropdownMenuItem(value: '', child: Text('One-time / free')),
              ],
              onChanged: (value) =>
                  setState(() => _interval = value ?? 'month'),
            ),
            _FormTextField(
              controller: _sortOrder,
              label: 'Sort order',
              helper: 'Lower numbers are listed first.',
              wholeNumber: true,
            ),
            _WideField(
              _FormTextField(
                controller: _stripePriceId,
                label: 'Stripe price ID',
                hint: 'price_…',
              ),
            ),
            _FormTextField(
              controller: _limit4h,
              label: '4-hour token limit',
              helper: 'Blank uses the server default.',
              wholeNumber: true,
            ),
            _FormTextField(
              controller: _limitWeekly,
              label: 'Weekly token limit',
              helper: 'Blank uses the server default.',
              wholeNumber: true,
            ),
            _WideField(
              _FormTextField(
                controller: _features,
                label: 'Features',
                helper: 'One per line, shown on the pricing page.',
                maxLines: 5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Allowed models',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Tick the models this plan may use. Leave all unticked to allow '
          'every model.',
          style: TextStyle(color: _textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        _modelsSection(),
        const SizedBox(height: 8),
        _SettingToggle(
          title: 'Active',
          subtitle: 'Offered to people choosing a plan.',
          value: _active,
          onChanged: (value) => setState(() => _active = value),
        ),
      ],
    );
  }

  Widget _modelsSection() {
    final models = _models;
    if (_modelsFailed) {
      return _FormTextField(
        controller: _modelIds,
        label: 'Model IDs',
        helper:
            'The model list could not be loaded. Enter model IDs separated by '
            'commas, or leave blank for every model.',
      );
    }
    if (models == null) return const _LoadingPlaceholder();
    if (models.isEmpty) {
      return const _EmptyText('No models are available yet.');
    }
    return _AdminCfgModelPicker(
      models: models,
      selected: _allowedModels,
      onChanged: (modelId, selected) => setState(() {
        if (selected) {
          _allowedModels.add(modelId);
        } else {
          _allowedModels.remove(modelId);
        }
      }),
    );
  }
}

class _AdminCfgModelPicker extends StatefulWidget {
  const _AdminCfgModelPicker({
    required this.models,
    required this.selected,
    required this.onChanged,
  });

  final List<_AdminCfgModel> models;
  final Set<String> selected;
  final void Function(String modelId, bool selected) onChanged;

  @override
  State<_AdminCfgModelPicker> createState() => _AdminCfgModelPickerState();
}

class _AdminCfgModelPickerState extends State<_AdminCfgModelPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.models
        : widget.models.where((model) => model.matches(query)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search models',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.selected.length} selected',
          style: TextStyle(color: _textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(AppRadius.tag),
          ),
          clipBehavior: Clip.antiAlias,
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    'No matches',
                    style: TextStyle(color: _textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final model = visible[index];
                    return CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: widget.selected.contains(model.id),
                      onChanged: (value) =>
                          widget.onChanged(model.id, value == true),
                      title: Text(
                        model.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${model.providerLabel} · ${model.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// An account's subscription, from the admin subscription list (with the
/// account's name and email) or from one account's subscription endpoint
/// (with the plan nested under `plan`).
class _BillingSubscription {
  const _BillingSubscription({
    required this.userId,
    required this.username,
    required this.userName,
    required this.email,
    required this.planId,
    required this.planName,
    required this.priceLabel,
    required this.status,
    required this.periodEnd,
    required this.cancelAtPeriodEnd,
    required this.billedByStripe,
  });

  factory _BillingSubscription.fromJson(Map<String, dynamic> json) {
    final plan = _jsonMap(json['plan']);
    final userId = _asInt(json['user_id']);
    final username = _asText(json['username'], fallback: '');
    final displayName = _asText(json['display_name'], fallback: username);
    final cancelAtPeriodEnd = json['cancel_at_period_end'];
    return _BillingSubscription(
      userId: userId,
      username: username,
      userName: displayName.isEmpty ? 'User #$userId' : displayName,
      email: _asText(json['email'], fallback: ''),
      planId: _asText(json['plan_id'] ?? plan['id'], fallback: ''),
      planName: _asText(
        json['plan_name'] ?? plan['name'],
        fallback: 'Unknown plan',
      ),
      priceLabel: plan.isEmpty ? '' : _BillingPlan.fromJson(plan).priceLabel,
      status: _asText(json['status'], fallback: 'active'),
      periodEnd: _asText(json['current_period_end'], fallback: ''),
      cancelAtPeriodEnd:
          cancelAtPeriodEnd == true || _asInt(cancelAtPeriodEnd) == 1,
      billedByStripe: _asText(
        json['stripe_subscription_id'],
        fallback: '',
      ).isNotEmpty,
    );
  }

  /// The `{subscription: …}` answer of the single-account endpoints; null
  /// when the account has no subscription.
  static _BillingSubscription? fromResponse(Map<String, dynamic> json) {
    final raw = json['subscription'];
    if (raw is! Map) return null;
    return _BillingSubscription.fromJson(Map<String, dynamic>.from(raw));
  }

  final int userId;
  final String username;

  /// Display name, else username, else the account id.
  final String userName;
  final String email;
  final String planId;
  final String planName;

  /// Only known when the plan came nested; empty in list rows.
  final String priceLabel;
  final String status;
  final String periodEnd;
  final bool cancelAtPeriodEnd;
  final bool billedByStripe;

  /// Only manual (admin-assigned) plans can be canceled here; Stripe-billed
  /// ones belong to the user's billing portal.
  bool get cancelable => !billedByStripe && status != 'canceled';
}

const Map<String, String> _adminCfgSubscriptionFilters = <String, String>{
  '': 'All',
  'active': 'Active',
  'trialing': 'Trialing',
  'past_due': 'Past due',
  'canceled': 'Canceled',
};

class _AdminCfgSubscriptionsCard extends StatefulWidget {
  const _AdminCfgSubscriptionsCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_AdminCfgSubscriptionsCard> createState() =>
      _AdminCfgSubscriptionsCardState();
}

class _AdminCfgSubscriptionsCardState extends State<_AdminCfgSubscriptionsCard>
    with _LoadSaveState<_AdminCfgSubscriptionsCard> {
  static const int _pageSize = 25;

  String _status = '';
  int _offset = 0;
  int _total = 0;
  List<_BillingSubscription> _rows = const <_BillingSubscription>[];

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminSubscriptions(
      _baseUrl,
      limit: _pageSize,
      offset: _offset,
      status: _status,
    );
    _rows = _jsonMapList(
      data['subscriptions'],
    ).map(_BillingSubscription.fromJson).toList();
    _total = _asInt(data['total']);
  }

  Future<void> _override(_BillingSubscription subscription) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AdminOpsSubscriptionDialog(
        controller: widget.controller,
        userId: subscription.userId,
        username: subscription.username,
      ),
    );
    if (mounted) _runLoad(_fetch);
  }

  void _showPage({String? status, required int offset}) {
    _status = status ?? _status;
    _offset = offset;
    _runLoad(_fetch);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Subscriptions',
      description:
          'Every account’s subscription, most recently changed first. '
          'Override assigns a plan without going through Stripe.',
      trailing: _RefreshButton(
        busy: _loading,
        onPressed: () => _runLoad(_fetch),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final filter in _adminCfgSubscriptionFilters.entries)
                ChoiceChip(
                  label: Text(filter.value),
                  selected: _status == filter.key,
                  onSelected: _loading
                      ? null
                      : (_) => _showPage(status: filter.key, offset: 0),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _loadGate(_fetch) ?? _results(),
        ],
      ),
    );
  }

  Widget _results() {
    if (_rows.isEmpty) {
      final filter = _adminCfgSubscriptionFilters[_status] ?? _status;
      return _EmptyText(
        _status.isEmpty
            ? 'No subscriptions yet.'
            : 'No ${filter.toLowerCase()} subscriptions.',
      );
    }
    final last = _offset + _rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final subscription in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AdminCfgSubscriptionRow(
              subscription: subscription,
              onOverride: () => _override(subscription),
            ),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${_offset + 1}–$last of $_total',
                style: TextStyle(color: _textMuted, fontSize: 12.5),
              ),
            ),
            IconButton(
              tooltip: 'Previous page',
              onPressed: _offset == 0
                  ? null
                  : () => _showPage(offset: math.max(0, _offset - _pageSize)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: last >= _total
                  ? null
                  : () => _showPage(offset: _offset + _pageSize),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminCfgSubscriptionRow extends StatelessWidget {
  const _AdminCfgSubscriptionRow({
    required this.subscription,
    required this.onOverride,
  });

  final _BillingSubscription subscription;
  final VoidCallback onOverride;

  @override
  Widget build(BuildContext context) {
    final status = subscription.status;
    return _RowSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RowHeader(
            title: subscription.userName,
            subtitle: subscription.email,
            trailing: _StatusPill(
              label: _titleCase(status.replaceAll('_', ' ')),
              color: _statusColor(status),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _Tag(subscription.planName, color: _accent),
              if (subscription.periodEnd.isNotEmpty)
                _Tag('Period ends ${_formatIsoDate(subscription.periodEnd)}'),
              if (subscription.cancelAtPeriodEnd)
                _Tag('Cancels at period end', color: _warning),
            ],
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onOverride,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Override plan'),
          ),
        ],
      ),
    );
  }
}
