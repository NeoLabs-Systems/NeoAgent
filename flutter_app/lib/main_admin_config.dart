part of 'main.dart';

// Admin tabs for server-wide configuration: AI provider credentials, model
// availability, integration OAuth apps, server settings and billing. Every
// value saved here applies to all accounts on the server.

// ── Shared pieces ─────────────────────────────────────────────────────────────

Map<String, String> _adminCfgFieldLabels = <String, String>{
  'clientId': appStrings.clientId,
  'clientSecret': appStrings.clientSecret,
  'redirectUri': appStrings.redirectUri,
  'tenantId': appStrings.tenantId,
  'apiKey': appStrings.apiKey,
};

/// What the server falls back to when an optional integration field is blank.
Map<String, String> _adminCfgFieldHints = <String, String>{
  'redirectUri': appStrings.blankUsesTheDefaultCallback,
  'tenantId': appStrings.blankUsesCommon,
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
  return isHttp ? null : appStrings.arg1MustBeAnHttpOr(label);
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
      helper = appStrings.nothingStoredYet;
    } else if (widget.storedHint.isEmpty) {
      helper = appStrings.aValueIsStored;
    } else {
      helper = appStrings.storedArg1(widget.storedHint);
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
            ? appStrings.leaveBlankToKeepTheStoredValue
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
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (dirty) _StatusPill(label: appStrings.unsavedChanges, color: _warning),
        if (dirty)
          TextButton(
            onPressed: saving ? null : onDiscard,
            child: Text(appStrings.discard),
          ),
        _SaveButton(
          saving: saving,
          onPressed: dirty ? onSave : null,
          label: appStrings.saveChanges,
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
      await _runSave(_fetch, appStrings.arg1Saved(provider.label));
    }
  }

  Future<void> _clear(_AdminCfgProvider provider) {
    return _confirmDelete(
      context,
      title: appStrings.clearArg1(provider.label),
      message: provider.isUrl
          ? appStrings.thisRemovesTheAddressForEveryAccount
          : appStrings.everyAccountOnThisServerLoses +
                appStrings.thatAddedTheirOwnKeyKeep,
      confirmLabel: 'Clear',
      onConfirm: () async {
        await _runSave(() async {
          await _client.saveAdminProvider(
            _baseUrl,
            key: provider.key,
            value: '',
          );
          await _fetch();
        }, appStrings.arg1Cleared(provider.label));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gate = _loadGate(_fetch);
    if (gate != null) return gate;
    final configured = _providers.where((p) => p.configured).length;
    return _SectionCard(
      title: appStrings.serverProviderCredentials,
      description:
          appStrings.apiKeysAndEndpointsForAi +
          appStrings.areSharedByEveryAccountOn +
          appStrings.addTheirOwnKeysInSettings,
      trailing: _RefreshButton(
        busy: _loading,
        onPressed: _saving ? null : () => _runLoad(_fetch),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MetaPill(
            icon: Icons.vpn_key_outlined,
            label: appStrings.arg1OfArg2Set(configured, _providers.length),
            color: configured > 0 ? _success : _textMuted,
          ),
          _saveFeedback(),
          const SizedBox(height: 14),
          if (_providers.isEmpty)
            _EmptyText(appStrings.thisServerReportsNoProviderSettings)
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
    if (provider.isUrl) return provider.configured ? 'Change' : appStrings.setUrl;
    return provider.configured ? 'Replace' : appStrings.addKey;
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
            subtitle: provider.isUrl ? 'Endpoint URL' : appStrings.apiKey,
            trailing: _StatusPill(
              label: configured ? 'Set' : appStrings.notSet,
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
                  icon: Icon(Icons.delete_outline, size: 18),
                  label: Text(appStrings.clear),
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
      problem = provider.isUrl ? 'Enter an address.' : appStrings.pasteAKey;
    } else if (provider.isUrl) {
      problem = _adminCfgUrlProblem(value, appStrings.theAddress);
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
      hint = appStrings.pasteANewKeyToReplace(provider.hint);
    } else {
      hint = appStrings.pasteTheKey;
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
                  ? appStrings.everyAccountOnThisServerUses +
                        '${provider.label}.'
                  : appStrings.usedByEveryAccountOnThis +
                        appStrings.ofItsOwnItIsNever,
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
                labelText: provider.isUrl ? 'URL' : appStrings.apiKey,
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
          child: Text(appStrings.cancel),
        ),
        _SaveButton(saving: _saving, onPressed: _save),
      ],
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

// Catalog labels end with the provider, e.g. "Claude Sonnet (OpenRouter)";
// the list groups by provider, so rows drop that suffix.
final RegExp _adminCfgProviderSuffix = RegExp(r'\s*\([^()]*\)$');

class _AdminCfgModel {
  const _AdminCfgModel({
    required this.id,
    required this.modelId,
    required this.label,
    required this.name,
    required this.provider,
    required this.priceTier,
    required this.inputCostPerM,
    required this.searchText,
  });

  factory _AdminCfgModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final modelId = json['modelId']?.toString() ?? id;
    final rawLabel = json['label']?.toString() ?? '';
    final label = rawLabel.isEmpty ? id : rawLabel;
    final stripped = label.replaceFirst(_adminCfgProviderSuffix, '');
    final provider = json['provider']?.toString() ?? '';
    final cost = json['inputCostPerM'];
    return _AdminCfgModel(
      id: id,
      modelId: modelId,
      label: label,
      name: stripped.isEmpty ? label : stripped,
      provider: provider,
      priceTier: json['priceTier']?.toString() ?? '',
      inputCostPerM: cost is num ? cost.toDouble() : null,
      searchText: '$label\n$id\n${_providerPickerLabel(provider)}'
          .toLowerCase(),
    );
  }

  /// Provider-scoped selection id, the value stored in the disabled list.
  final String id;

  /// The id the provider itself uses.
  final String modelId;
  final String label;

  /// [label] without its trailing provider name.
  final String name;
  final String provider;
  final String priceTier;

  /// USD per million input tokens; null when unknown.
  final double? inputCostPerM;

  /// Lower-cased label, id and provider, built once for search.
  final String searchText;

  String get providerLabel =>
      provider.isEmpty ? 'Other' : _providerPickerLabel(provider);

  bool matches(String lowerQuery) => searchText.contains(lowerQuery);
}

/// Chat models live under `models`; SystemOne models under `systemOneModels`.
List<_AdminCfgModel> _adminCfgParseModels(
  Map<String, dynamic> data, {
  String key = 'models',
}) {
  return _jsonMapList(
    data[key],
  ).map(_AdminCfgModel.fromJson).where((model) => model.id.isNotEmpty).toList();
}

String _adminCfgModelPrice(double? perMillion) {
  if (perMillion == null) return appStrings.priceUnknown;
  if (perMillion == 0) return 'Free';
  var digits = 2;
  if (perMillion < 0.01) {
    digits = 4;
  } else if (perMillion < 1) {
    digits = 3;
  }
  return appStrings.arg11mInput(perMillion.toStringAsFixed(digits));
}

Color _adminCfgTierColor(String tier) {
  return switch (tier) {
    'free' || 'cheap' => _success,
    'medium' => _warning,
    'expensive' => _danger,
    _ => _textMuted,
  };
}

enum _AdminModelKind { chat, systemOne }

enum _AdminModelFilter { all, enabled, disabled }

/// One line of the availability list: a provider header, or a model below it.
class _AdminCfgListEntry {
  const _AdminCfgListEntry.provider(this.provider, this.models, this.expanded)
    : model = null;

  _AdminCfgListEntry.model(_AdminCfgModel this.model)
    : provider = model.provider,
      models = const <_AdminCfgModel>[],
      expanded = true;

  final String provider;
  final List<_AdminCfgModel> models;
  final bool expanded;
  final _AdminCfgModel? model;
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
  List<_AdminCfgModel> _systemOneModels = const <_AdminCfgModel>[];
  Set<String> _savedDisabled = <String>{};
  Set<String> _disabled = <String>{};
  _AdminModelKind _kind = _AdminModelKind.chat;
  _AdminModelFilter _filter = _AdminModelFilter.all;

  /// Providers whose group is open or shut against the default: shut when
  /// browsing, open while a search or filter narrows the list.
  final Set<String> _flipped = <String>{};

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
    _systemOneModels = _adminCfgParseModels(data, key: 'systemOneModels')
      ..sort(_compareModels);
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
    return a.searchText.compareTo(b.searchText);
  }

  int _enabledCount(Iterable<_AdminCfgModel> models) =>
      models.where((model) => !_disabled.contains(model.id)).length;

  /// Filters by the saved state, so a row does not vanish while it is edited.
  bool _isShown(_AdminCfgModel model, String query) {
    if (query.isNotEmpty && !model.matches(query)) return false;
    return switch (_filter) {
      _AdminModelFilter.all => true,
      _AdminModelFilter.enabled => !_savedDisabled.contains(model.id),
      _AdminModelFilter.disabled => _savedDisabled.contains(model.id),
    };
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
    }, appStrings.modelAvailabilitySaved);
  }

  /// Search, filter and catalog changes start every group from its default.
  void _narrow(VoidCallback change) {
    setState(() {
      change();
      _flipped.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gate = _loadGate(_fetch);
    if (gate != null) return gate;

    final catalog = _kind == _AdminModelKind.chat ? _models : _systemOneModels;
    final query = _search.text.trim().toLowerCase();
    final shown = catalog.where((model) => _isShown(model, query)).toList();
    final groups = <String, List<_AdminCfgModel>>{};
    for (final model in shown) {
      groups.putIfAbsent(model.provider, () => <_AdminCfgModel>[]).add(model);
    }
    final openByDefault =
        query.isNotEmpty ||
        _filter != _AdminModelFilter.all ||
        groups.length == 1;
    final entries = <_AdminCfgListEntry>[];
    for (final group in groups.entries) {
      final expanded = openByDefault != _flipped.contains(group.key);
      entries.add(
        _AdminCfgListEntry.provider(group.key, group.value, expanded),
      );
      if (expanded) entries.addAll(group.value.map(_AdminCfgListEntry.model));
    }
    final anyExpanded = entries.any((entry) => entry.model != null);
    final changes =
        _savedDisabled.difference(_disabled).length +
        _disabled.difference(_savedDisabled).length;
    // Every line is one fixed height, so the panel fits its lines up to a cap
    // and the list lays out without measuring rows.
    const lineHeight = 52.0;
    final maxListHeight = (MediaQuery.sizeOf(context).height * 0.62).clamp(
      360.0,
      760.0,
    );
    final listHeight = entries.isEmpty
        ? lineHeight * 3
        : (entries.length * lineHeight + 2).clamp(0.0, maxListHeight);

    return _SectionCard(
      title: appStrings.modelAvailability,
      description: _kind == _AdminModelKind.chat
          ? appStrings.chooseWhichModelsEveryAccountOn +
                appStrings.runWhileAnyModelIsSwitched +
                appStrings.laterStartSwitchedOffToo
          : appStrings.systemOneAdminAvailability,
      trailing: _RefreshButton(
        busy: _loading,
        onPressed: _saving ? null : () => _runLoad(_fetch),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_AdminModelKind>(
              showSelectedIcon: false,
              segments: <ButtonSegment<_AdminModelKind>>[
                ButtonSegment<_AdminModelKind>(
                  value: _AdminModelKind.chat,
                  icon: Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(
                    '${appStrings.chatModels}  '
                    '${_enabledCount(_models)}/${_models.length}',
                  ),
                ),
                ButtonSegment<_AdminModelKind>(
                  value: _AdminModelKind.systemOne,
                  icon: Icon(Icons.bolt_rounded, size: 18),
                  label: Text(
                    '${appStrings.systemOneModels}  '
                    '${_enabledCount(_systemOneModels)}/${_systemOneModels.length}',
                  ),
                ),
              ],
              selected: <_AdminModelKind>{_kind},
              onSelectionChanged: (selection) =>
                  _narrow(() => _kind = selection.first),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 360,
                child: _SearchField(
                  controller: _search,
                  hintText: appStrings.searchModelsOrProviders,
                  onChanged: (_) => _narrow(() {}),
                  onClear: () => _narrow(_search.clear),
                ),
              ),
              SegmentedButton<_AdminModelFilter>(
                showSelectedIcon: false,
                segments: <ButtonSegment<_AdminModelFilter>>[
                  ButtonSegment<_AdminModelFilter>(
                    value: _AdminModelFilter.all,
                    label: Text(appStrings.all),
                  ),
                  ButtonSegment<_AdminModelFilter>(
                    value: _AdminModelFilter.enabled,
                    label: Text(appStrings.enabled),
                  ),
                  ButtonSegment<_AdminModelFilter>(
                    value: _AdminModelFilter.disabled,
                    label: Text(appStrings.disabled),
                  ),
                ],
                selected: <_AdminModelFilter>{_filter},
                onSelectionChanged: (selection) =>
                    _narrow(() => _filter = selection.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                appStrings.arg1Shown(shown.length),
                style: TextStyle(color: _textMuted, fontSize: 13),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: shown.isEmpty || _enabledCount(shown) == shown.length
                    ? null
                    : () => _setEnabled(shown, true),
                child: Text(
                  query.isEmpty && _filter == _AdminModelFilter.all
                      ? appStrings.enableAll
                      : appStrings.enableShown,
                ),
              ),
              TextButton(
                onPressed: _enabledCount(shown) == 0
                    ? null
                    : () => _setEnabled(shown, false),
                child: Text(
                  query.isEmpty && _filter == _AdminModelFilter.all
                      ? appStrings.disableAll
                      : appStrings.disableShown,
                ),
              ),
              if (groups.length > 1)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _flipped.clear();
                    if (anyExpanded == openByDefault) {
                      _flipped.addAll(groups.keys);
                    }
                  }),
                  icon: Icon(
                    anyExpanded ? Icons.unfold_less : Icons.unfold_more,
                    size: 18,
                  ),
                  label: Text(
                    anyExpanded ? appStrings.collapseAll : appStrings.expandAll,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: listHeight,
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(AppRadius.tag),
            ),
            clipBehavior: Clip.antiAlias,
            child: entries.isEmpty
                ? _AdminCfgListMessage(
                    catalog.isEmpty
                        ? (_kind == _AdminModelKind.chat
                              ? appStrings.addAProviderCredentialFirstIts +
                                    appStrings.theProviderAnswers
                              : appStrings.addATypesafeOrOpenrouterKey)
                        : appStrings.noModelMatchesArg1(_search.text.trim()),
                  )
                : ListView.builder(
                    key: PageStorageKey<_AdminModelKind>(_kind),
                    itemExtent: lineHeight,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final model = entry.model;
                      if (model != null) {
                        return _AdminCfgModelRow(
                          model: model,
                          enabled: !_disabled.contains(model.id),
                          onChanged: (enabled) =>
                              _setEnabled(<_AdminCfgModel>[model], enabled),
                        );
                      }
                      return _AdminCfgProviderHeader(
                        provider: entry.provider,
                        enabledCount: _enabledCount(entry.models),
                        total: entry.models.length,
                        expanded: entry.expanded,
                        first: index == 0,
                        onToggleExpanded: () => setState(() {
                          if (!_flipped.remove(entry.provider)) {
                            _flipped.add(entry.provider);
                          }
                        }),
                        onSetAll: (enabled) =>
                            _setEnabled(entry.models, enabled),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (_dirty) ...<Widget>[
                _StatusPill(
                  label: appStrings.arg1UnsavedChanges(changes),
                  color: _warning,
                ),
                TextButton(
                  onPressed: _saving ? null : _discard,
                  child: Text(appStrings.discard),
                ),
              ],
              _SaveButton(
                saving: _saving,
                onPressed: _dirty ? _save : null,
                label: appStrings.saveChanges,
              ),
            ],
          ),
          _saveFeedback(),
        ],
      ),
    );
  }
}

class _AdminCfgListMessage extends StatelessWidget {
  const _AdminCfgListMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
      ),
    );
  }
}

/// A collapsible provider group: how many of its listed models are on, and
/// one checkbox for all of them.
class _AdminCfgProviderHeader extends StatelessWidget {
  const _AdminCfgProviderHeader({
    required this.provider,
    required this.enabledCount,
    required this.total,
    required this.expanded,
    required this.first,
    required this.onToggleExpanded,
    required this.onSetAll,
  });

  final String provider;
  final int enabledCount;
  final int total;
  final bool expanded;
  final bool first;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onSetAll;

  @override
  Widget build(BuildContext context) {
    final bool? allOn = enabledCount == total
        ? true
        : (enabledCount == 0 ? false : null);
    return Material(
      color: _bgSecondary,
      child: InkWell(
        onTap: onToggleExpanded,
        child: Container(
          padding: const EdgeInsets.only(left: 8, right: 8),
          decoration: BoxDecoration(
            border: Border(
              top: first ? BorderSide.none : BorderSide(color: _border),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                color: _textSecondary,
              ),
              const SizedBox(width: 6),
              Checkbox(
                tristate: true,
                value: allOn,
                onChanged: (_) => onSetAll(allOn != true),
              ),
              const SizedBox(width: 6),
              Icon(
                _providerPickerIcon(provider),
                size: 18,
                color: _providerPickerColor(provider),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  provider.isEmpty ? 'Other' : _providerPickerLabel(provider),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                appStrings.arg1OfArg2Enabled(enabledCount, total),
                style: TextStyle(color: _textMuted, fontSize: 12.5),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
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
    final cost = model.inputCostPerM;
    return InkWell(
      onTap: () => onChanged(!enabled),
      child: Padding(
        padding: const EdgeInsets.only(left: 38, right: 8),
        child: Row(
          children: <Widget>[
            Checkbox(
              value: enabled,
              onChanged: (value) => onChanged(value == true),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    model.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? _textPrimary : _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (model.modelId != model.name)
                    Text(
                      model.modelId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _monoStyle(size: 11.5, color: _textMuted),
                    ),
                ],
              ),
            ),
            if (cost != null) ...<Widget>[
              const SizedBox(width: 12),
              Text(
                _adminCfgModelPrice(cost),
                style: TextStyle(
                  color: enabled
                      ? _adminCfgTierColor(model.priceTier)
                      : _textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
        appStrings.arg1RedirectUri(integration.label),
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
    }, appStrings.integrationSettingsSaved);
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
          title: appStrings.integrationApps,
          description:
              appStrings.oauthAppCredentialsThatLetAccounts +
              appStrings.microsoftSlackAndTheOtherIntegrations +
              appStrings.everyAccountOnThisServerSecrets +
              appStrings.oneBlankToKeepWhatIs,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InlineNote(
                icon: Icons.link_rounded,
                message:
                    appStrings.leaveARedirectUriBlankTo +
                    appStrings.integrationsOauthCallbackAndRegisterThat +
                    appStrings.addressWithTheProvider,
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
        label: integration.configured ? 'Configured' : appStrings.notSet,
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
      title: appStrings.liveVoice,
      description:
          appStrings.serverDefaultsForInAppVoice +
          appStrings.speechToSpeechModelUsingThe +
          appStrings.providersEachAccountCanStillPick +
          appStrings.blankValuesUseTheProviderDefaults,
      child: _FieldGrid(
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String>('live-voice-provider:$selected'),
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: '',
                child: Text(appStrings.defaultOpenai),
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
            label: appStrings.model,
            hint: provider['defaultModel']?.toString(),
            onChanged: (_) => _edited(),
          ),
          _FormTextField(
            controller: _input('liveVoice.voice'),
            label: appStrings.voice,
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
    }, enabled ? 'Sign-up is open.' : appStrings.signUpIsClosed);
    if (!saved && mounted) setState(() => _signupEnabled = previous);
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
                title: appStrings.allowNewSignUps,
                subtitle:
                    appStrings.whenOffOnlyExistingAccountsCan +
                    appStrings.serverWithNoAccountsYetAlways +
                    appStrings.oneRegister,
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
  }

  Future<void> _save() async {
    final interval = _parseBoundedInt(_ingestionInterval.text, min: 1000);
    var problem = _adminCfgUrlProblem(_publicUrl.text, appStrings.publicUrl);
    problem ??= _adminCfgOriginsProblem(_allowedOrigins.text);
    if (problem == null && interval == null) {
      problem = appStrings.memoryIngestionIntervalMustBeAt;
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
        'memoryIngestionIntervalMs': interval,
      }),
      appStrings.generalSettingsSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.general,
      description: appStrings.howThisServerIsReachedPlus,
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
                label: appStrings.publicUrl,
                hint: 'https://agent.example.com',
                helper:
                    appStrings.theAddressPeopleAndOauthProviders +
                    appStrings.thisServer,
                keyboardType: TextInputType.url,
                onChanged: (_) => _onEdited(),
              ),
            ),
            _FormTextField(
              controller: _allowedOrigins,
              label: appStrings.allowedOrigins,
              hint: 'https://app.example.com, https://…',
              helper:
                  appStrings.exactWebOriginsAllowedToMake +
                  'comma-separated.',
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _ingestionInterval,
              label: appStrings.memoryIngestionIntervalMs,
              helper: appStrings.atLeast1000AppliesAfterA,
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SettingToggle(
          title: appStrings.secureCookies,
          subtitle:
              appStrings.requiredBehindHttpsOrATls +
              'restart.',
          value: _secureCookies,
          onChanged: (value) => setState(() {
            _secureCookies = value;
            _saveNotice = null;
          }),
        ),
        const SizedBox(height: 12),
        _SaveButton(
          saving: _saving,
          onPressed: _save,
          label: appStrings.saveGeneralSettings,
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
    var problem = _adminCfgUrlProblem(_baseImageUrl.text, appStrings.baseImageUrl);
    if (problem == null && memoryMb == null) {
      problem = appStrings.memoryMustBeAtLeast512;
    }
    if (problem == null && cpus == null) {
      problem = appStrings.useAtLeast1Vcpu;
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
      appStrings.cloudComputerSettingsSavedRestartThe,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.cloudComputers,
      description:
          appStrings.baseImageAndSizeOfThe +
          appStrings.accountsCloudComputersChangesApplyAfter +
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
                label: appStrings.baseImageUrl,
                hint: 'https://cloud-images.ubuntu.com/…',
                keyboardType: TextInputType.url,
                onChanged: (_) => _onEdited(),
              ),
            ),
            _WideField(
              _FormTextField(
                controller: _baseImagePath,
                label: appStrings.localBaseImagePath,
                hint: '/path/to/base.img',
                helper: appStrings.optionalWhenSetItIsUsed,
                onChanged: (_) => _onEdited(),
              ),
            ),
            _FormTextField(
              controller: _memoryMb,
              label: appStrings.memoryMb,
              helper: appStrings.atLeast512,
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _cpus,
              label: 'vCPUs',
              helper: appStrings.atLeast1,
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SaveButton(
          saving: _saving,
          onPressed: _save,
          label: appStrings.saveCloudComputerSettings,
        ),
        _saveFeedback(),
      ],
    );
  }
}

typedef _AdminCfgEmailToggle = ({String key, String title, String subtitle});

List<_AdminCfgEmailToggle> _adminCfgEmailToggles = <_AdminCfgEmailToggle>[
  (
    key: 'smtpSecure',
    title: appStrings.implicitTls,
    subtitle: appStrings.useTlsFromTheStartOf,
  ),
  (
    key: 'smtpRequireTls',
    title: appStrings.requireStarttls,
    subtitle: appStrings.refuseToSendUnlessTheConnection,
  ),
  (
    key: 'smtpRejectUnauthorized',
    title: appStrings.rejectInvalidTlsCertificates,
    subtitle: appStrings.turnOffOnlyForAMail,
  ),
  (
    key: 'requireSignupConfirmation',
    title: appStrings.confirmNewSignUps,
    subtitle: appStrings.newAccountsConfirmTheirEmailAddress,
  ),
  (
    key: 'requireEmailChangeConfirmation',
    title: appStrings.confirmEmailChanges,
    subtitle: appStrings.aChangedEmailAddressIsConfirmed,
  ),
  (
    key: 'notifyUnusualLogin',
    title: appStrings.unusualSignInAlerts,
    subtitle: appStrings.emailAccountOwnersAboutSignIns,
  ),
  (
    key: 'notifyAccountChanges',
    title: appStrings.accountChangeAlerts,
    subtitle: appStrings.emailAccountOwnersWhenTheirAccount,
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
      problem = appStrings.smtpPortMustBeAWhole;
    } else if (ttl == null) {
      problem = appStrings.linkLifetimeMustBeFrom1;
    }
    problem ??= _adminCfgUrlProblem(
      _field('publicUrl').text,
      appStrings.publicUrlOverride,
    );
    problem ??= _adminCfgUrlProblem(_field('supportUrl').text, appStrings.supportUrl);
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
    }, clearPassword ? 'SMTP password removed.' : appStrings.emailSettingsSaved);
  }

  Future<void> _removePassword() {
    return _confirmDelete(
      context,
      title: appStrings.removeTheSmtpPassword,
      message:
          appStrings.mailServersThatNeedAPassword +
          appStrings.oneIsSavedOtherChangesIn,
      confirmLabel: 'Remove',
      onConfirm: () => _save(clearPassword: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loaded = !_loading && _loadError == null;
    return _SectionCard(
      title: appStrings.serviceEmail,
      description:
          appStrings.theMailAccountNeoagentSendsSign +
          appStrings.alertsAndOtherAccountEmailFrom,
      trailing: loaded
          ? _StatusPill(
              label: _configured ? 'Ready' : appStrings.notConfigured,
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
                appStrings.accountEmailIsOffUntilThese +
                '${_missing.join(', ')}.',
          ),
          const SizedBox(height: 16),
        ],
        _FieldGrid(
          children: <Widget>[
            _WideField(
              _FormTextField(
                controller: _field('from'),
                label: appStrings.senderAddress,
                hint: appStrings.neoagentNoReplyExampleCom,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _onEdited(),
              ),
            ),
            _FormTextField(
              controller: _field('smtpHost'),
              label: appStrings.smtpHost,
              hint: 'smtp.example.com',
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _smtpPort,
              label: appStrings.smtpPort,
              hint: '587',
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('smtpUser'),
              label: appStrings.smtpUsername,
              onChanged: (_) => _onEdited(),
            ),
            _AdminCfgSecretField(
              controller: _smtpPassword,
              label: appStrings.smtpPassword,
              stored: _passwordStored,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('replyTo'),
              label: appStrings.replyToAddress,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('brandName'),
              label: appStrings.brandName,
              hint: 'NeoAgent',
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('publicUrl'),
              label: appStrings.publicUrlOverride,
              helper: appStrings.forLinksInEmailsBlankUses,
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _field('supportUrl'),
              label: appStrings.supportUrl,
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _tokenTtlHours,
              label: appStrings.linkLifetimeHours,
              helper: appStrings.howLongConfirmationLinksStayValid,
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
              label: appStrings.saveEmailSettings,
            ),
            if (_passwordStored)
              TextButton.icon(
                onPressed: _saving ? null : _removePassword,
                style: TextButton.styleFrom(foregroundColor: _danger),
                icon: Icon(Icons.delete_outline, size: 18),
                label: Text(appStrings.removeSmtpPassword),
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
          _EmptyCard(
            title: appStrings.billingIsOff,
            subtitle:
                appStrings.plansAndSubscriptionsShowUpHere +
                appStrings.onAndTheServerHasRestarted,
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
      _rejectSave(appStrings.freeTrialMustBeAWhole);
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
    }, appStrings.billingSetupSaved);
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.controller.showBillingSection;
    return _SectionCard(
      title: appStrings.stripeBilling,
      description:
          appStrings.stripeKeysForPaidPlansPoint +
          appStrings.publicUrlApiBillingWebhookAnd +
          appStrings.hereSecretsAreWriteOnlyLeave,
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
                ? appStrings.billingIsTurnedOnButNot +
                      appStrings.serverToStartIt
                : appStrings.billingIsTurnedOffButStill +
                      appStrings.serverToStopIt,
          ),
          const SizedBox(height: 12),
        ],
        _SettingToggle(
          title: appStrings.billingEnabled,
          subtitle:
              appStrings.offerSubscriptionPlansThroughStripeTurning +
              appStrings.offTakesEffectAfterAServer,
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
              label: appStrings.publishableKey,
              hint: 'pk_live_…',
              onChanged: (_) => _onEdited(),
            ),
            _AdminCfgSecretField(
              controller: _secretKey,
              label: appStrings.secretKey,
              stored: _secretKeyStored,
              storedHint: _secretKeyHint,
              placeholder: 'sk_live_…',
              onChanged: (_) => _onEdited(),
            ),
            _AdminCfgSecretField(
              controller: _webhookSecret,
              label: appStrings.webhookSigningSecret,
              stored: _webhookSecretStored,
              placeholder: 'whsec_…',
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _trialDays,
              label: appStrings.freeTrialDays,
              helper: appStrings.n0TurnsTrialsOff,
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SaveButton(
          saving: _saving,
          onPressed: _save,
          label: appStrings.saveBillingSetup,
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
  if (limit == null) return appStrings.arg1Default(window);
  return appStrings.arg1Arg2Tokens2(window, _formatTokenCount(limit));
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
        plan == null ? 'Plan created.' : appStrings.arg1Saved(plan.name),
      );
    }
  }

  Future<void> _deactivate(_BillingPlan plan) {
    return _confirmDelete(
      context,
      title: appStrings.deactivateArg1(plan.name),
      message:
          appStrings.thePlanStopsBeingOfferedIt +
          appStrings.existingSubscribersKeepAccessUntilTheir,
      confirmLabel: 'Deactivate',
      onConfirm: () async {
        await _runSave(() async {
          await _client.deleteAdminBillingPlan(_baseUrl, plan.id);
          await _fetch();
        }, appStrings.arg1Deactivated(plan.name));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.plans,
      description: appStrings.theSubscriptionPlansPeopleCanChoose,
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
          icon: Icon(Icons.add_rounded, size: 18),
          label: Text(appStrings.newPlan),
        ),
        _saveFeedback(),
        const SizedBox(height: 14),
        if (_plans.isEmpty)
          _EmptyText(appStrings.noPlansYet)
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
                    ? appStrings.allModels
                    : appStrings.arg1ModelArg2(modelCount, modelCount == 1 ? '' : 's'),
              ),
              if (featureCount > 0)
                _Tag(appStrings.arg1FeatureArg2(featureCount, featureCount == 1 ? '' : 's')),
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
                icon: Icon(Icons.edit_outlined, size: 18),
                label: Text(appStrings.edit),
              ),
              if (plan.isActive)
                TextButton.icon(
                  onPressed: busy ? null : onDeactivate,
                  style: TextButton.styleFrom(foregroundColor: _danger),
                  icon: Icon(Icons.block_rounded, size: 18),
                  label: Text(appStrings.deactivate),
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
      return appStrings.planIdMayOnlyUseLetters;
    }
    if (_name.text.trim().isEmpty) return appStrings.giveThePlanAName;
    if (_parseBoundedInt(_price.text, min: 0) == null) {
      return appStrings.priceMustBeAWholeNumber;
    }
    if (!_currencyPattern.hasMatch(_currency.text.trim())) {
      return appStrings.currencyMustBeA3Letter;
    }
    if (!_isOptionalWholeNumber(_sortOrder)) {
      return appStrings.sortOrderMustBeAWhole;
    }
    if (!_isOptionalWholeNumber(_limit4h) ||
        !_isOptionalWholeNumber(_limitWeekly)) {
      return appStrings.tokenLimitsMustBeWholeNumbers;
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
                plan == null ? 'New plan' : appStrings.editArg1(plan.displayName),
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
                    child: Text(appStrings.cancel),
                  ),
                  const SizedBox(width: 8),
                  _SaveButton(
                    saving: _saving,
                    onPressed: _save,
                    label: _isNew ? 'Create plan' : appStrings.savePlan,
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
              label: appStrings.planId,
              hint: 'plan_pro',
              helper: _isNew
                  ? appStrings.optionalAndPermanentBlankGeneratesOne
                  : appStrings.aPlanSIdCanT,
              enabled: _isNew,
            ),
            _FormTextField(controller: _name, label: appStrings.name, hint: 'Pro'),
            _WideField(
              _FormTextField(controller: _description, label: appStrings.description),
            ),
            _FormTextField(
              controller: _price,
              label: appStrings.priceInCents,
              helper: appStrings.smallestCurrencyUnit1900Is19,
              wholeNumber: true,
            ),
            _FormTextField(
              controller: _currency,
              label: appStrings.currency,
              hint: 'usd',
            ),
            DropdownButtonFormField<String>(
              initialValue: _interval,
              decoration: InputDecoration(labelText: appStrings.billingInterval),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'month', child: Text(appStrings.monthly)),
                DropdownMenuItem(value: 'year', child: Text(appStrings.yearly)),
                DropdownMenuItem(value: '', child: Text(appStrings.oneTimeFree)),
              ],
              onChanged: (value) =>
                  setState(() => _interval = value ?? 'month'),
            ),
            _FormTextField(
              controller: _sortOrder,
              label: appStrings.sortOrder,
              helper: appStrings.lowerNumbersAreListedFirst,
              wholeNumber: true,
            ),
            _WideField(
              _FormTextField(
                controller: _stripePriceId,
                label: appStrings.stripePriceId,
                hint: 'price_…',
              ),
            ),
            _FormTextField(
              controller: _limit4h,
              label: appStrings.n4HourTokenLimit,
              helper: appStrings.blankUsesTheServerDefault,
              wholeNumber: true,
            ),
            _FormTextField(
              controller: _limitWeekly,
              label: appStrings.weeklyTokenLimit,
              helper: appStrings.blankUsesTheServerDefault,
              wholeNumber: true,
            ),
            _WideField(
              _FormTextField(
                controller: _features,
                label: appStrings.features,
                helper: appStrings.onePerLineShownOnThe,
                maxLines: 5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          appStrings.allowedModels,
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          appStrings.tickTheModelsThisPlanMay +
          appStrings.everyModel,
          style: TextStyle(color: _textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        _modelsSection(),
        const SizedBox(height: 8),
        _SettingToggle(
          title: 'Active',
          subtitle: appStrings.offeredToPeopleChoosingAPlan,
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
        label: appStrings.modelIds,
        helper:
            appStrings.theModelListCouldNotBe +
            appStrings.commasOrLeaveBlankForEvery,
      );
    }
    if (models == null) return const _LoadingPlaceholder();
    if (models.isEmpty) {
      return _EmptyText(appStrings.noModelsAreAvailableYet);
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
          decoration: InputDecoration(
            hintText: appStrings.searchModels,
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appStrings.arg1Selected(widget.selected.length),
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
                    appStrings.noMatches,
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
                        appStrings.arg1Arg22(model.providerLabel, model.id),
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
      userName: displayName.isEmpty ? appStrings.userArg1(userId) : displayName,
      email: _asText(json['email'], fallback: ''),
      planId: _asText(json['plan_id'] ?? plan['id'], fallback: ''),
      planName: _asText(
        json['plan_name'] ?? plan['name'],
        fallback: appStrings.unknownPlan,
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

Map<String, String> _adminCfgSubscriptionFilters = <String, String>{
  '': 'All',
  'active': 'Active',
  'trialing': 'Trialing',
  'past_due': appStrings.pastDue,
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
      title: appStrings.subscriptions,
      description:
          appStrings.everyAccountSSubscriptionMostRecently +
          appStrings.overrideAssignsAPlanWithoutGoing,
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
            ? appStrings.noSubscriptionsYet
            : appStrings.noArg1Subscriptions(filter.toLowerCase()),
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
                appStrings.arg1Arg2OfArg3(_offset + 1, last, _total),
                style: TextStyle(color: _textMuted, fontSize: 12.5),
              ),
            ),
            IconButton(
              tooltip: appStrings.previousPage,
              onPressed: _offset == 0
                  ? null
                  : () => _showPage(offset: math.max(0, _offset - _pageSize)),
              icon: Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: appStrings.nextPage,
              onPressed: last >= _total
                  ? null
                  : () => _showPage(offset: _offset + _pageSize),
              icon: Icon(Icons.chevron_right_rounded),
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
                _Tag(appStrings.periodEndsArg1(_formatIsoDate(subscription.periodEnd))),
              if (subscription.cancelAtPeriodEnd)
                _Tag(appStrings.cancelsAtPeriodEnd, color: _warning),
            ],
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onOverride,
            icon: Icon(Icons.swap_horiz_rounded, size: 16),
            label: Text(appStrings.overridePlan),
          ),
        ],
      ),
    );
  }
}
