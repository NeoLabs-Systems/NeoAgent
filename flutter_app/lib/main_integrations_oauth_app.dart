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
  final alternative = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OAuthAppSetupDialog(
      controller: controller,
      providerId: providerId,
      config: config,
    ),
  );
  if (alternative != null && context.mounted) {
    _openOfficialIntegrationSetupDialog(context, controller, alternative);
  }
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

  List<String> get _alternatives =>
      widget.controller.officialIntegrations
          .where((item) => item.id == widget.providerId)
          .firstOrNull
          ?.env
          .alternatives ??
      const <String>[];

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
    final confirmed = await _confirmIntegrationAction(
      context,
      title: appStrings.removeOAuthAppTitle(_providerLabel),
      body: appStrings.removeOAuthAppBody,
      confirmLabel: appStrings.remove,
    );
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
    return _IntegrationDialog(
      icon: _integrationIconFor(widget.controller, widget.providerId),
      title: appStrings.oauthAppSetupTitle(_providerLabel),
      subtitle: appStrings.oauthAppSetupIntro(_providerLabel),
      status: <_IntegrationSetupStatusItem>[
        _IntegrationSetupStatusItem(
          label: appStrings.clientSecret,
          status: _stored ? 'Configured' : appStrings.notConfigured,
          isConnected: _stored,
        ),
      ],
      error: _error,
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      body: <Widget>[
        if (_alternatives.isNotEmpty && !_stored) ...<Widget>[
          _IntegrationAlternatives(
            controller: widget.controller,
            providerIds: _alternatives,
            onOpen: (providerId) => Navigator.of(context).pop(providerId),
          ),
          const SizedBox(height: 4),
        ],
        _OAuthAppStep(
          number: 1,
          first: _alternatives.isEmpty || _stored,
          title: appStrings.oauthAppStepCreate,
          children: <Widget>[
            if (notes.isNotEmpty)
              Text(
                notes,
                style: TextStyle(color: _textSecondary, height: 1.45),
              ),
            if (consoleUrl.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => url_launcher.launchUrl(
                  Uri.parse(consoleUrl),
                  mode: url_launcher.LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(appStrings.openDeveloperConsole),
              ),
            ],
          ],
        ),
        _OAuthAppStep(
          number: 2,
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
          number: 3,
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
      ],
      leading: _stored
          ? _IntegrationDangerButton(
              label: appStrings.remove,
              onPressed: _busy ? null : _remove,
            )
          : null,
      actions: <Widget>[
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _IntegrationBusyLabel(busy: _busy, label: appStrings.save),
        ),
      ],
    );
  }
}

/// One numbered step of a setup flow, drawn as a timeline entry.
class _OAuthAppStep extends StatelessWidget {
  const _OAuthAppStep({
    required this.title,
    required this.children,
    this.number,
    this.first = false,
  });

  final String title;
  final List<Widget> children;
  final int? number;

  /// The first block of a dialog body needs no gap above it.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final number = this.number;
    final heading = Text(
      title,
      style: TextStyle(
        color: _textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 20),
      child: number == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[heading, const SizedBox(height: 10), ...children],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: heading,
                      ),
                      const SizedBox(height: 10),
                      ...children,
                    ],
                  ),
                ),
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

/// Other integrations that reach the same data without registering an app,
/// offered wherever setting up an OAuth app is asked for.
class _IntegrationAlternatives extends StatelessWidget {
  const _IntegrationAlternatives({
    required this.controller,
    required this.providerIds,
    required this.onOpen,
  });

  final NeoAgentController controller;
  final List<String> providerIds;
  final ValueChanged<String> onOpen;

  String _hint(String providerId) => switch (providerId) {
    'email' => appStrings.alternativeEmail,
    _ => PhoneSync.supported
        ? appStrings.alternativePhone
        : appStrings.alternativePhoneElsewhere,
  };

  @override
  Widget build(BuildContext context) {
    final items = providerIds
        .map(
          (id) => controller.officialIntegrations
              .where((item) => item.id == id)
              .firstOrNull,
        )
        .whereType<OfficialIntegrationItem>()
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            appStrings.skipTheDeveloperConsole,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final item in items)
            ListTile(
              contentPadding: const EdgeInsets.only(right: 8),
              leading: _OfficialIntegrationIcon.named(
                icon: item.icon,
                label: item.label,
                size: 36,
              ),
              title: Text(item.label),
              subtitle: Text(_hint(item.id)),
              trailing: item.setUpOnPhoneOnly
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              enabled: !item.setUpOnPhoneOnly,
              onTap: () => onOpen(item.id),
            ),
        ],
      ),
    );
  }
}
