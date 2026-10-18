part of 'main.dart';

/// Setup for an official integration that signs in through an OAuth app the
/// user registers themselves, because the server has no global app for it.
Future<void> _showOAuthAppSetupDialog(
  BuildContext context,
  NeoAgentController controller,
  String providerId,
) async {
  Map<String, dynamic> config;
  try {
    config = await controller.getOfficialIntegrationConfig(providerId);
  } catch (error) {
    if (context.mounted) _showControllerError(context, controller, error);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OAuthAppSetupDialog(
      controller: controller,
      providerId: providerId,
      config: config,
    ),
  );
}

class _OAuthAppSetupDialog extends StatefulWidget {
  const _OAuthAppSetupDialog({
    required this.controller,
    required this.providerId,
    required this.config,
  });

  final NeoAgentController controller;
  final String providerId;
  final Map<String, dynamic> config;

  @override
  State<_OAuthAppSetupDialog> createState() => _OAuthAppSetupDialogState();
}

class _OAuthAppSetupDialogState extends State<_OAuthAppSetupDialog> {
  late final List<Map<String, dynamic>> _extraFields = _jsonMapList(
    widget.config['fields'],
  );
  late final TextEditingController _clientId = TextEditingController(
    text: widget.config['clientId']?.toString() ?? '',
  );
  final TextEditingController _clientSecret = TextEditingController();
  late final Map<String, TextEditingController> _fieldInputs =
      <String, TextEditingController>{
        for (final field in _extraFields)
          field['name'].toString(): TextEditingController(
            text: field['value']?.toString() ?? '',
          ),
      };
  bool _busy = false;
  String _error = '';

  bool get _stored => widget.config['hasClientSecret'] == true;

  String get _providerLabel =>
      widget.controller.officialIntegrations
          .where((item) => item.id == widget.providerId)
          .firstOrNull
          ?.label ??
      widget.providerId;

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    for (final input in _fieldInputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            widget.controller.errorMessage ?? appStrings.couldNotSaveOAuthApp;
      });
    }
  }

  Future<void> _save() => _run(
    () => widget.controller.saveOfficialIntegrationConfig(
      widget.providerId,
      config: <String, dynamic>{
        'clientId': _clientId.text.trim(),
        'clientSecret': _clientSecret.text.trim(),
        for (final entry in _fieldInputs.entries)
          entry.key: entry.value.text.trim(),
      },
    ),
  );

  Future<void> _remove() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (confirmContext) => AlertDialog(
            title: Text(appStrings.removeOAuthAppTitle(_providerLabel)),
            content: Text(appStrings.removeOAuthAppBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(confirmContext).pop(false),
                child: Text(appStrings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(confirmContext).pop(true),
                child: Text(appStrings.remove),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _run(
      () => widget.controller.clearOfficialIntegrationConfig(widget.providerId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.config['notes']?.toString() ?? '';
    final consoleUrl = widget.config['consoleUrl']?.toString() ?? '';
    final redirectUri = widget.config['redirectUri']?.toString() ?? '';
    final scopes = _jsonStringList(widget.config['scopes']);
    return AlertDialog(
      title: Text(appStrings.oauthAppSetupTitle(_providerLabel)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                appStrings.oauthAppSetupIntro(_providerLabel),
                style: TextStyle(color: _textSecondary, height: 1.45),
              ),
              _OAuthAppStep(
                title: appStrings.oauthAppStepCreate,
                children: <Widget>[
                  if (notes.isNotEmpty)
                    Text(
                      notes,
                      style: TextStyle(color: _textSecondary, height: 1.45),
                    ),
                  if (consoleUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => url_launcher.launchUrl(
                        Uri.parse(consoleUrl),
                        mode: url_launcher.LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(appStrings.openDeveloperConsole),
                    ),
                ],
              ),
              _OAuthAppStep(
                title: appStrings.oauthAppStepCallback,
                children: <Widget>[
                  _OAuthAppCopyableValue(
                    value: redirectUri,
                    copiedMessage: appStrings.callbackUrlCopied,
                  ),
                  if (scopes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      appStrings.oauthAppScopes,
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    _OAuthAppCopyableValue(
                      value: scopes.join('\n'),
                      copiedMessage: appStrings.scopesCopied,
                    ),
                  ],
                ],
              ),
              _OAuthAppStep(
                title: appStrings.oauthAppStepCredentials,
                children: <Widget>[
                  TextField(
                    controller: _clientId,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: appStrings.clientId,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AdminCfgSecretField(
                    controller: _clientSecret,
                    label: appStrings.clientSecret,
                    stored: _stored,
                  ),
                  for (final field in _extraFields) ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fieldInputs[field['name'].toString()],
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: field['label']?.toString(),
                        hintText: field['defaultValue']?.toString(),
                        helperText: field['hint']?.toString(),
                        helperMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
              if (_error.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(_error, style: TextStyle(color: _danger, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (_stored)
          TextButton(
            onPressed: _busy ? null : _remove,
            child: Text(appStrings.remove),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(appStrings.close),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? appStrings.saving : appStrings.save),
        ),
      ],
    );
  }
}

class _OAuthAppStep extends StatelessWidget {
  const _OAuthAppStep({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _OAuthAppCopyableValue extends StatelessWidget {
  const _OAuthAppCopyableValue({
    required this.value,
    required this.copiedMessage,
  });

  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return _RowSurface(
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(value, style: _monoStyle(size: 12.5)),
          ),
          IconButton(
            tooltip: appStrings.copy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(copiedMessage)));
            },
          ),
        ],
      ),
    );
  }
}
