part of 'main.dart';

// Admin tabs for server-wide configuration: AI provider credentials, model
// availability, integration OAuth apps and server settings. Every value saved
// here applies to all accounts on the server.

// ── Shared pieces ─────────────────────────────────────────────────────────────

Map<String, String> _adminCfgFieldLabels = <String, String>{
  'clientId': appStrings.clientId,
  'clientSecret': appStrings.clientSecret,
  'redirectUri': appStrings.redirectUri,
  'tenantId': appStrings.tenantId,
  'apiKey': appStrings.apiKey,
  'enabled': appStrings.enabled,
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
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool stored;
  final ValueChanged<String>? onChanged;

  @override
  State<_AdminCfgSecretField> createState() => _AdminCfgSecretFieldState();
}

class _AdminCfgSecretFieldState extends State<_AdminCfgSecretField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
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
            : null,
        helperText: widget.stored
            ? appStrings.aValueIsStored
            : appStrings.nothingStoredYet,
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
        if (dirty)
          _StatusPill(label: appStrings.unsavedChanges, color: _warning),
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
    if (provider.isUrl) {
      return provider.configured ? 'Change' : appStrings.setUrl;
    }
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
                  ? '${appStrings.everyAccountOnThisServerUses}${provider.label}.'
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

  bool _savedAutoEnable = true;
  bool _autoEnable = true;

  bool get _dirty =>
      !setEquals(_savedDisabled, _disabled) || _savedAutoEnable != _autoEnable;

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
    _resetAutoEnable(data['autoEnableNewModels'] != false);
  }

  void _resetAutoEnable(bool value) {
    _savedAutoEnable = value;
    _autoEnable = value;
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
      _autoEnable = _savedAutoEnable;
      _saveError = null;
    });
  }

  Future<void> _save() async {
    await _runSave(() async {
      final data = await _client.saveAdminDisabledModels(
        _baseUrl,
        _disabled.toList()..sort(),
        autoEnableNewModels: _autoEnable,
      );
      _resetDisabled(_jsonStringList(data['disabledModels']).toSet());
      _resetAutoEnable(data['autoEnableNewModels'] != false);
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
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(appStrings.autoEnableNewModels),
            subtitle: Text(appStrings.autoEnableNewModelsHint),
            value: _autoEnable,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _saveNotice = null;
                    _autoEnable = value;
                  }),
          ),
          const SizedBox(height: 6),
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
    required this.isBoolean,
  });

  factory _AdminCfgIntegrationField.fromJson(Map<String, dynamic> json) {
    final value = json['value']?.toString() ?? '';
    return _AdminCfgIntegrationField(
      name: json['name']?.toString() ?? '',
      secret: json['secret'] == true,
      value: value,
      stored: json['configured'] == true || value.isNotEmpty,
      isBoolean: json['type'] == 'boolean',
    );
  }

  final String name;
  final bool secret;
  final bool isBoolean;

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
    required this.description,
  });

  factory _AdminCfgIntegration.fromJson(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    return _AdminCfgIntegration(
      key: key,
      label: json['label']?.toString() ?? key,
      configured: json['configured'] == true,
      description: json['description']?.toString(),
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
  final String? description;
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
    final integrations = <String, Map<String, Object>>{};
    for (final integration in _integrations) {
      for (final field in integration.fields) {
        final key = '${integration.key}.${field.name}';
        if (!_changed(key)) continue;
        final values = integrations.putIfAbsent(
          integration.key,
          () => <String, Object>{},
        );
        final value = _input(key).text.trim();
        values[field.name] = field.isBoolean ? value == 'true' : value;
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
          title: appStrings.globalIntegrationConfiguration,
          description: appStrings.globalIntegrationConfigurationDescription,
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
    final disabled = integration.fields.any(
      (field) =>
          field.isBoolean && field.name == 'enabled' && field.value == 'false',
    );
    var statusLabel = integration.configured
        ? appStrings.globalStatus
        : appStrings.perUserStatus;
    if (disabled) statusLabel = appStrings.disabled;
    return _SectionCard(
      title: integration.label,
      description: integration.description,
      trailing: _StatusPill(
        label: statusLabel,
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
    if (field.isBoolean) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        value: input.text == 'true',
        onChanged: _saving
            ? null
            : (value) {
                input.text = value.toString();
                _edited();
              },
      );
    }
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
        _AdminSignupKeysCard(controller: controller),
        _AdminCfgGeneralCard(controller: controller),
        _AdminCfgVmCard(controller: controller),
        _AdminCfgEmailCard(controller: controller),
      ],
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
    super.dispose();
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminConfig(_baseUrl, 'general');
    final settings = _jsonMap(data['settings']);
    _publicUrl.text = settings['publicUrl']?.toString() ?? '';
    _allowedOrigins.text = settings['allowedOrigins']?.toString() ?? '';
    _secureCookies = settings['secureCookies'] == true;
  }

  Future<void> _save() async {
    var problem = _adminCfgUrlProblem(_publicUrl.text, appStrings.publicUrl);
    problem ??= _adminCfgOriginsProblem(_allowedOrigins.text);
    if (problem != null) {
      _rejectSave(problem);
      return;
    }
    await _runSave(
      () => _client.saveAdminConfig(_baseUrl, 'general', <String, dynamic>{
        'publicUrl': _publicUrl.text.trim(),
        'secureCookies': _secureCookies,
        'allowedOrigins': _allowedOrigins.text.trim(),
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
                  '${appStrings.exactWebOriginsAllowedToMake}comma-separated.',
              keyboardType: TextInputType.url,
              onChanged: (_) => _onEdited(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SettingToggle(
          title: appStrings.secureCookies,
          subtitle: '${appStrings.requiredBehindHttpsOrATls}restart.',
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
  final TextEditingController _baseImagePath = TextEditingController();
  final TextEditingController _memoryMb = TextEditingController();
  final TextEditingController _cpus = TextEditingController();

  /// The smallest computer the server will run, from its settings.
  int _minMemoryMb = 1024;

  @override
  NeoAgentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _runLoad(_fetch);
  }

  @override
  void dispose() {
    _baseImagePath.dispose();
    _memoryMb.dispose();
    _cpus.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final data = await _client.fetchAdminConfig(_baseUrl, 'vm');
    final settings = _jsonMap(data['settings']);
    _baseImagePath.text = settings['vmBaseImage']?.toString() ?? '';
    _minMemoryMb = (settings['minMemoryMb'] as num?)?.toInt() ?? _minMemoryMb;
    _memoryMb.text = settings['maxMemoryMb']?.toString() ?? '';
    _cpus.text = settings['maxCpus']?.toString() ?? '';
  }

  Future<void> _save() async {
    final memoryMb = _parseBoundedInt(_memoryMb.text, min: _minMemoryMb);
    final cpus = _parseBoundedInt(_cpus.text, min: 1);
    String? problem;
    if (memoryMb == null) {
      problem = appStrings.maxMemoryMustBeAtLeastArg1Mb(_minMemoryMb);
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
        'vmBaseImage': _baseImagePath.text.trim(),
        'maxMemoryMb': memoryMb,
        'maxCpus': cpus,
      }),
      appStrings.cloudComputerSettingsSavedRestartThe,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: appStrings.cloudComputers,
      description:
          '${appStrings.baseImageAndSizeOfThe}${appStrings.accountsCloudComputersChangesApplyAfter}restart.',
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
                controller: _baseImagePath,
                label: appStrings.localBaseImagePath,
                hint: '/path/to/base.img',
                helper: appStrings.optionalWhenSetItIsUsed,
                onChanged: (_) => _onEdited(),
              ),
            ),
            _FormTextField(
              controller: _memoryMb,
              label: appStrings.maxMemoryPerComputerMb,
              helper: appStrings.atLeastArg1ComputersGetLess(_minMemoryMb),
              wholeNumber: true,
              onChanged: (_) => _onEdited(),
            ),
            _FormTextField(
              controller: _cpus,
              label: appStrings.maxVcpusPerComputer,
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
    problem ??= _adminCfgUrlProblem(
      _field('supportUrl').text,
      appStrings.supportUrl,
    );
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
    await _runSave(
      () async {
        _apply(await _client.saveAdminConfig(_baseUrl, 'email', payload));
      },
      clearPassword ? 'SMTP password removed.' : appStrings.emailSettingsSaved,
    );
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
                '${appStrings.accountEmailIsOffUntilThese}${_missing.join(', ')}.',
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
