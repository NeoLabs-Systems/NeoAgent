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
    final configuredCount = providers
        .where((p) => p['configured'] == true)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: _SectionTitle('Bring your own key')),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: controller.isLoadingByokProviders ? null : _load,
                  icon: controller.isLoadingByokProviders
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Use your own API key for a provider, or connect a custom "
              "OpenAI-compatible endpoint (your own server, or another "
              "hosted service). Your keys are encrypted and only usable by "
              "your account -- and usage on a model backed by your own key "
              "never counts against the shared usage limits.",
              style: TextStyle(color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaPill(
                  icon: Icons.vpn_key_outlined,
                  label: '$configuredCount key${configuredCount == 1 ? '' : 's'} configured',
                  color: configuredCount > 0 ? _success : _textMuted,
                ),
                _MetaPill(
                  icon: Icons.shield_outlined,
                  label: 'Encrypted, private to your account',
                  color: _info,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_loadedOnce && controller.isLoadingByokProviders)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (providers.isEmpty)
              Text(
                'No providers are available to configure yet.',
                style: TextStyle(color: _textSecondary),
              )
            else
              ...providers.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ByokProviderRow(
                    controller: controller,
                    provider: provider,
                  ),
                ),
              ),
          ],
        ),
      ),
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
    final customLabel = provider['customLabel']?.toString() ?? '';
    final baseUrl = provider['baseUrl']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isCustomEndpoint && customLabel.isNotEmpty
                          ? customLabel
                          : label,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(color: _textSecondary, fontSize: 12.5, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusPill(
                label: configured ? 'Using your key' : 'Not set up',
                color: configured ? _success : _textMuted,
              ),
            ],
          ),
          if (configured && isCustomEndpoint && baseUrl.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              baseUrl,
              style: TextStyle(color: _textSecondary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => _openEditDialog(context),
                icon: Icon(
                  configured ? Icons.edit_outlined : Icons.add_circle_outline,
                  size: 18,
                ),
                label: Text(configured ? 'Update' : (isCustomEndpoint ? 'Connect endpoint' : 'Add key')),
              ),
              if (configured)
                OutlinedButton.icon(
                  onPressed: () => _confirmRemove(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final providerId = provider['id']?.toString() ?? '';
    final providerLabel = provider['label']?.toString() ?? providerId;
    final isCustom = provider['isCustomEndpoint'] == true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ByokEditDialog(
        controller: controller,
        providerId: providerId,
        providerLabel: providerLabel,
        isCustomEndpoint: isCustom,
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
        title: Text('Remove $providerLabel key?'),
        content: Text(
          'Runs will fall back to the shared server key for $providerLabel, if one is configured. This can\'t be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.clearByokProvider(providerId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$providerLabel key removed.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove key: $e')),
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
    if (apiKey.isEmpty) {
      setState(() {
        _testOk = false;
        _testMessage = 'Enter an API key first.';
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
        apiKey: apiKey,
        baseUrl: widget.supportsBaseUrl ? _baseUrlController.text.trim() : null,
      );
      setState(() {
        _testOk = result['ok'] == true;
        _testMessage = result['ok'] == true
            ? (result['message']?.toString() ?? 'Connection looks good.')
            : (result['error']?.toString() ?? 'Could not connect.');
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
    if (apiKey.isEmpty) {
      setState(() => _errorMessage = 'An API key is required.');
      return;
    }
    final baseUrl = _baseUrlController.text.trim();
    if (widget.requiresBaseUrl && baseUrl.isEmpty) {
      setState(() => _errorMessage = 'A base URL is required for this endpoint.');
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.controller.saveByokProvider(
        widget.providerId,
        apiKey: apiKey,
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
    return AlertDialog(
      title: Text(
        widget.isCustomEndpoint
            ? 'Connect a custom endpoint'
            : 'Your ${widget.providerLabel} key',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.isCustomEndpoint
                  ? 'Point NeoAgent at any OpenAI-compatible Chat Completions '
                      'API -- your own server, a self-hosted model, or another '
                      'hosted provider.'
                  : "Paste your ${widget.providerLabel} API key below. It's "
                      "stored encrypted and only used for your own runs.",
              style: TextStyle(color: _textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (widget.isCustomEndpoint) ...<Widget>[
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  hintText: 'e.g. My local server',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.supportsBaseUrl) ...<Widget>[
              TextField(
                controller: _baseUrlController,
                decoration: InputDecoration(
                  labelText: widget.requiresBaseUrl ? 'Base URL' : 'Base URL (optional)',
                  hintText: widget.defaultBaseUrl.isNotEmpty
                      ? widget.defaultBaseUrl
                      : 'https://api.example.com/v1',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'API key',
                hintText: 'sk-...',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
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
                    : const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: const Text('Test connection'),
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
              'Server usage limits don\'t apply to models running on your own key.',
              style: TextStyle(color: _textMuted, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
