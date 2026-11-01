part of 'main.dart';

/// Adds a mailbox (and its calendar and contacts, where the provider has
/// them) to the Email & Calendar integration with an app password, or a
/// calendar by its iCal link. The providers come from the server, so this
/// dialog knows none of them.
Future<void> _showEmailAccountSetupDialog(
  BuildContext context,
  NeoAgentController controller,
) async {
  Map<String, dynamic> config;
  try {
    config = await controller.getOfficialIntegrationConfig('email');
  } catch (error) {
    if (context.mounted) _showControllerError(context, controller, error);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _EmailAccountSetupDialog(controller: controller, config: config),
  );
}

class _EmailAccountSetupDialog extends StatefulWidget {
  const _EmailAccountSetupDialog({
    required this.controller,
    required this.config,
  });

  final NeoAgentController controller;
  final Map<String, dynamic> config;

  @override
  State<_EmailAccountSetupDialog> createState() =>
      _EmailAccountSetupDialogState();
}

class _EmailAccountSetupDialogState extends State<_EmailAccountSetupDialog> {
  late final List<Map<String, dynamic>> _presets = _jsonMapList(
    widget.config['presets'],
  );
  late final List<Map<String, dynamic>> _accounts = _jsonMapList(
    widget.config['accounts'],
  );
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _imapHost = TextEditingController();
  final TextEditingController _imapPort = TextEditingController(text: '993');
  final TextEditingController _smtpHost = TextEditingController();
  final TextEditingController _smtpPort = TextEditingController(text: '465');
  final TextEditingController _caldavUrl = TextEditingController();
  final TextEditingController _carddavUrl = TextEditingController();
  final TextEditingController _feedUrl = TextEditingController();
  final TextEditingController _feedName = TextEditingController();

  Map<String, dynamic>? _preset;
  bool _calendar = true;
  bool _contacts = true;
  bool _passwordHidden = true;
  bool _busy = false;
  String _error = '';

  bool get _custom => _preset?['custom'] == true;
  bool get _feed => _preset?['feed'] == true;
  String get _presetLabel => _preset?['label']?.toString() ?? '';

  @override
  void dispose() {
    for (final input in <TextEditingController>[
      _email,
      _password,
      _username,
      _imapHost,
      _imapPort,
      _smtpHost,
      _smtpPort,
      _caldavUrl,
      _carddavUrl,
      _feedUrl,
      _feedName,
    ]) {
      input.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _form() => _feed
      ? <String, dynamic>{
          'preset': _preset?['id'],
          'url': _feedUrl.text.trim(),
          'name': _feedName.text.trim(),
        }
      : _mailboxForm();

  Map<String, dynamic> _mailboxForm() => <String, dynamic>{
    'preset': _preset?['id'],
    'email': _email.text.trim(),
    'password': _password.text,
    'username': _username.text.trim(),
    if (_custom) ...<String, dynamic>{
      'imap': <String, dynamic>{
        'host': _imapHost.text.trim(),
        'port': int.tryParse(_imapPort.text.trim()),
      },
      'smtp': <String, dynamic>{
        'host': _smtpHost.text.trim(),
        'port': int.tryParse(_smtpPort.text.trim()),
      },
      'caldavUrl': _caldavUrl.text.trim(),
      'carddavUrl': _carddavUrl.text.trim(),
    } else ...<String, dynamic>{
      'calendar': _calendar,
      'contacts': _contacts,
    },
  };

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final added = _feed ? _feedName.text.trim() : _email.text.trim();
      await widget.controller.saveOfficialIntegrationConfig(
        'email',
        config: _form(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added.isEmpty
                ? appStrings.calendarLinkAdded
                : appStrings.emailConnectedArg1(added),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            widget.controller.errorMessage ?? appStrings.couldNotConnectEmail;
      });
    }
  }

  void _openAlternative(String providerId) {
    Navigator.of(context).pop();
    final item = widget.controller.officialIntegrations
        .where((provider) => provider.id == providerId)
        .firstOrNull;
    if (item != null) _openIntegrationDetail(context, widget.controller, item);
  }

  @override
  Widget build(BuildContext context) {
    final preset = _preset;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          if (preset != null) ...<Widget>[
            IconButton(
              tooltip: appStrings.back,
              onPressed: _busy ? null : () => setState(() => _preset = null),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              preset == null ? appStrings.emailSetupTitle : _presetLabel,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: preset == null ? _providerPicker() : _accountForm(preset),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(preset == null ? appStrings.close : appStrings.cancel),
        ),
        if (preset != null && preset['unsupported'] != true)
          FilledButton(
            onPressed: _busy ? null : _connect,
            child: Text(_busy ? appStrings.emailChecking : appStrings.connect),
          ),
      ],
    );
  }

  Widget _providerPicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          appStrings.emailSetupIntro,
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
        if (_accounts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          for (final account in _accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _IntegrationSetupStatusItem(
                label: account['email']?.toString() ?? '',
                status: _jsonStringList(account['apps']).join(' · '),
                isConnected: true,
              ),
            ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final preset in _presets)
              _EmailPresetTile(
                preset: preset,
                onTap: () => setState(() {
                  _preset = preset;
                  _calendar = preset['calendar'] == true;
                  _contacts = preset['contacts'] == true;
                  _error = '';
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _accountForm(Map<String, dynamic> preset) {
    final help = preset['help']?.toString() ?? '';
    final passwordUrl = preset['passwordUrl']?.toString() ?? '';
    if (preset['unsupported'] == true) {
      final alternative = preset['alternativeProvider']?.toString() ?? '';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(help, style: TextStyle(color: _textSecondary, height: 1.45)),
          if (alternative.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _openAlternative(alternative),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                appStrings.emailOpenArg1(
                  widget.controller.officialIntegrations
                          .where((item) => item.id == alternative)
                          .firstOrNull
                          ?.label ??
                      alternative,
                ),
              ),
            ),
          ],
        ],
      );
    }
    if (_feed) return _feedForm(help);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _OAuthAppStep(
          title: _custom ? appStrings.emailStepServers : appStrings.emailStepPassword,
          children: <Widget>[
            Text(help, style: TextStyle(color: _textSecondary, height: 1.45)),
            if (passwordUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () => url_launcher.launchUrl(
                  Uri.parse(passwordUrl),
                  mode: url_launcher.LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(appStrings.emailOpenPasswordPageArg1(_presetLabel)),
              ),
            if (_custom) ..._serverFields(),
          ],
        ),
        _OAuthAppStep(
          title: appStrings.emailStepSignIn,
          children: <Widget>[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const <String>[AutofillHints.email],
              decoration: InputDecoration(
                labelText: appStrings.email,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _passwordHidden,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: appStrings.appPassword,
                helperText: appStrings.appPasswordHelper,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _passwordHidden = !_passwordHidden),
                  icon: Icon(
                    _passwordHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: appStrings.emailUsernameOptional,
                border: const OutlineInputBorder(),
              ),
            ),
            if (!_custom &&
                (preset['calendar'] == true ||
                    preset['contacts'] == true)) ...<Widget>[
              const SizedBox(height: 8),
              if (preset['calendar'] == true)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _calendar,
                  onChanged: (value) => setState(() => _calendar = value),
                  title: Text(appStrings.emailIncludeCalendar),
                ),
              if (preset['contacts'] == true)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _contacts,
                  onChanged: (value) => setState(() => _contacts = value),
                  title: Text(appStrings.emailIncludeContacts),
                ),
            ],
          ],
        ),
        if (_error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error, style: TextStyle(color: _danger, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _feedForm(String help) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(help, style: TextStyle(color: _textSecondary, height: 1.45)),
        const SizedBox(height: 16),
        TextField(
          controller: _feedUrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: appStrings.calendarLink,
            hintText: 'webcal://… or https://….ics',
            helperText: appStrings.calendarLinkHelper,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _feedName,
          decoration: InputDecoration(
            labelText: appStrings.calendarLinkName,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error, style: TextStyle(color: _danger, fontSize: 12)),
        ],
      ],
    );
  }

  List<Widget> _serverFields() {
    Widget server(TextEditingController host, TextEditingController port, String label) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: TextField(
                controller: host,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'mail.example.com',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: port,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: appStrings.port,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget url(TextEditingController input, String label) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: input,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'https://dav.example.com',
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    return <Widget>[
      server(_imapHost, _imapPort, appStrings.imapServer),
      server(_smtpHost, _smtpPort, appStrings.smtpServer),
      url(_caldavUrl, appStrings.caldavUrlOptional),
      url(_carddavUrl, appStrings.carddavUrlOptional),
    ];
  }
}

class _EmailPresetTile extends StatelessWidget {
  const _EmailPresetTile({required this.preset, required this.onTap});

  final Map<String, dynamic> preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = preset['label']?.toString() ?? '';
    final reaches = <String>[
      if (preset['feed'] != true) appStrings.email,
      if (preset['calendar'] == true || preset['feed'] == true)
        appStrings.triggerSectionCalendar,
    ];
    return SizedBox(
      width: 168,
      child: Material(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: <Widget>[
                _OfficialIntegrationIcon.named(
                  icon: preset['icon']?.toString() ?? 'mail',
                  label: label,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        maxLines: 2,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (preset['custom'] != true &&
                          preset['unsupported'] != true)
                        Text(
                          reaches.join(' · '),
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
