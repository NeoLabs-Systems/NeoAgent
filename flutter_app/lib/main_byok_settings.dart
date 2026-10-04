part of 'main.dart';

/// Self-service "bring your own key" settings: lets a user store their own
/// per-provider API keys, or a custom OpenAI-compatible endpoint, instead of
/// relying on the shared server keys. Keys are encrypted server-side and are
/// never shown again once saved -- only a "configured" state is displayed.
class _ByokSettingsCard extends StatefulWidget {
  const _ByokSettingsCard({required this.controller});

  final NeoAgentController controller;

  @override
  State<_ByokSettingsCard> createState() => _ByokSettingsCardState();
}

class _ByokSettingsCardState extends State<_ByokSettingsCard> {
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await widget.controller.refreshByokProviders();
    if (mounted) setState(() => _loadedOnce = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final providers = controller.byokProviders;
    return _SettingsGroup(
      anchor: 'apiKeys',
      title: appStrings.bringYourOwnKey2,
      description: appStrings.settingsApiKeysDescription,
      trailing: IconButton(
        tooltip: appStrings.refresh,
        onPressed: controller.isLoadingByokProviders ? null : _load,
        icon: controller.isLoadingByokProviders
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.refresh_rounded),
      ),
      children: <Widget>[
        if (!_loadedOnce && controller.isLoadingByokProviders)
          const _SettingsBlock(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (providers.isEmpty)
          _SettingsBlock(
            child: Text(
              appStrings.noProvidersAreAvailableToConfigure,
              style: TextStyle(color: _textSecondary),
            ),
          )
        else
          for (final provider in providers)
            _ByokProviderRow(controller: controller, provider: provider),
      ],
    );
  }
}

class _ByokProviderRow extends StatelessWidget {
  const _ByokProviderRow({required this.controller, required this.provider});

  final NeoAgentController controller;
  final Map<String, dynamic> provider;

  @override
  Widget build(BuildContext context) {
    final id = provider['id']?.toString() ?? '';
    final label = provider['label']?.toString() ?? id;
    final description = provider['description']?.toString() ?? '';
    final configured = provider['configured'] == true;
    final isCustomEndpoint = provider['isCustomEndpoint'] == true;
    final supportsApiKey = provider['supportsApiKey'] == true;
    // A provider with no API key concept (e.g. Ollama) is only ever "yours"
    // by pointing it at a custom address -- same connect-a-URL flow as a
    // custom OpenAI-compatible endpoint.
    final isUrlOnly = isCustomEndpoint || !supportsApiKey;
    final customLabel = provider['customLabel']?.toString() ?? '';
    final baseUrl = provider['baseUrl']?.toString() ?? '';

    final title = isUrlOnly && customLabel.isNotEmpty ? customLabel : label;
    return _SettingsRow(
      label: title,
      description: configured && isUrlOnly && baseUrl.isNotEmpty
          ? baseUrl
          : description.isEmpty
          ? null
          : description,
      control: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _StatusPill(
            label: configured ? 'Using your key' : appStrings.notSetUp,
            color: configured ? _success : _textMuted,
          ),
          OutlinedButton(
            onPressed: () => _openEditDialog(context),
            child: Text(
              configured
                  ? 'Update'
                  : (isUrlOnly ? 'Connect endpoint' : appStrings.addKey),
            ),
          ),
          if (configured)
            IconButton(
              tooltip: appStrings.remove,
              onPressed: () => _confirmRemove(context),
              icon: Icon(Icons.delete_outline, size: 18),
            ),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final providerId = provider['id']?.toString() ?? '';
    final providerLabel = provider['label']?.toString() ?? providerId;
    final supportsApiKey = provider['supportsApiKey'] == true;
    final isCustom = provider['isCustomEndpoint'] == true || !supportsApiKey;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ByokEditDialog(
        controller: controller,
        providerId: providerId,
        providerLabel: providerLabel,
        isCustomEndpoint: isCustom,
        supportsApiKey: supportsApiKey,
        requiresBaseUrl: provider['requiresBaseUrl'] == true,
        supportsBaseUrl: provider['supportsBaseUrl'] == true,
        defaultBaseUrl: provider['defaultBaseUrl']?.toString() ?? '',
        initialBaseUrl: provider['baseUrl']?.toString() ?? '',
        initialLabel: provider['customLabel']?.toString() ?? '',
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final providerId = provider['id']?.toString() ?? '';
    final providerLabel = provider['label']?.toString() ?? providerId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appStrings.removeArg1Key(providerLabel)),
        content: Text(
          appStrings.runsWillFallBackToThe(providerLabel),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(appStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            child: Text(appStrings.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.clearByokProvider(providerId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appStrings.arg1KeyRemoved(providerLabel))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appStrings.couldNotRemoveKeyArg1(e))),
        );
      }
    }
  }
}

class _ByokEditDialog extends StatefulWidget {
  const _ByokEditDialog({
    required this.controller,
    required this.providerId,
    required this.providerLabel,
    required this.isCustomEndpoint,
    required this.supportsApiKey,
    required this.requiresBaseUrl,
    required this.supportsBaseUrl,
    required this.defaultBaseUrl,
    required this.initialBaseUrl,
    required this.initialLabel,
  });

  final NeoAgentController controller;
  final String providerId;
  final String providerLabel;
  final bool isCustomEndpoint;
  final bool supportsApiKey;
  final bool requiresBaseUrl;
  final bool supportsBaseUrl;
  final String defaultBaseUrl;
  final String initialBaseUrl;
  final String initialLabel;

  @override
  State<_ByokEditDialog> createState() => _ByokEditDialogState();
}

class _ByokEditDialogState extends State<_ByokEditDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _labelController;
  bool _obscureKey = true;
  bool _saving = false;
  bool _testing = false;
  String? _testMessage;
  bool? _testOk;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController(
      text: widget.initialBaseUrl.isNotEmpty
          ? widget.initialBaseUrl
          : widget.defaultBaseUrl,
    );
    _labelController = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final apiKey = _apiKeyController.text.trim();
    if (widget.supportsApiKey && apiKey.isEmpty) {
      setState(() {
        _testOk = false;
        _testMessage = appStrings.enterAnApiKeyFirst;
      });
      return;
    }
    setState(() {
      _testing = true;
      _testMessage = null;
      _testOk = null;
    });
    try {
      final result = await widget.controller.testByokProvider(
        widget.providerId,
        apiKey: widget.supportsApiKey ? apiKey : null,
        baseUrl: widget.supportsBaseUrl ? _baseUrlController.text.trim() : null,
      );
      setState(() {
        _testOk = result['ok'] == true;
        _testMessage = result['ok'] == true
            ? (result['message']?.toString() ?? appStrings.connectionLooksGood)
            : (result['error']?.toString() ?? appStrings.couldNotConnect);
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final apiKey = _apiKeyController.text.trim();
    if (widget.supportsApiKey && apiKey.isEmpty) {
      setState(() => _errorMessage = appStrings.anApiKeyIsRequired);
      return;
    }
    final baseUrl = _baseUrlController.text.trim();
    final baseUrlRequired = widget.requiresBaseUrl || !widget.supportsApiKey;
    if (baseUrlRequired && baseUrl.isEmpty) {
      setState(() => _errorMessage = appStrings.aBaseUrlIsRequiredFor);
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.controller.saveByokProvider(
        widget.providerId,
        apiKey: widget.supportsApiKey ? apiKey : '',
        baseUrl: widget.supportsBaseUrl ? baseUrl : null,
        label: widget.isCustomEndpoint ? _labelController.text.trim() : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _testing;
    final baseUrlRequired = widget.requiresBaseUrl || !widget.supportsApiKey;
    return AlertDialog(
      title: Text(
        widget.isCustomEndpoint
            ? appStrings.connectACustomEndpoint
            : appStrings.yourArg1Key(widget.providerLabel),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.isCustomEndpoint
                  ? appStrings.pointNeoagentAtAnyOpenaiCompatible +
                      appStrings.apiYourOwnServerASelf +
                      appStrings.hostedProvider
                  : appStrings.pasteYourArg1ApiKeyBelow(widget.providerLabel) +
                      appStrings.storedEncryptedAndOnlyUsedFor,
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (widget.isCustomEndpoint) ...<Widget>[
              TextField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: appStrings.nameOptional,
                  hintText: appStrings.eGMyLocalServer,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.supportsBaseUrl) ...<Widget>[
              TextField(
                controller: _baseUrlController,
                decoration: InputDecoration(
                  labelText: baseUrlRequired ? 'Base URL' : appStrings.baseUrlOptional,
                  hintText: widget.defaultBaseUrl.isNotEmpty
                      ? widget.defaultBaseUrl
                      : 'https://api.example.com/v1',
                  helperText: appStrings.mustBeReachableOnThePublic +
                      appStrings.privateNetworkAddressesArenTAllowed,
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
            ],
            if (widget.supportsApiKey) ...<Widget>[
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: appStrings.apiKey,
                  hintText: 'sk-...',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : _test,
                icon: _testing
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(appStrings.testConnection),
              ),
            ),
            if (_testMessage != null)
              Text(
                _testMessage!,
                style: TextStyle(
                  color: _testOk == true ? _success : _danger,
                  fontSize: 12.5,
                ),
              ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: _danger)),
            ],
            const SizedBox(height: 4),
            Text(
              appStrings.serverUsageLimitsDonTApply,
              style: TextStyle(color: _textMuted, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(appStrings.cancel),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(appStrings.save),
        ),
      ],
    );
  }
}
